-- ------------------------------------------------------------------------------
-- Keyboard
--   PS/2 keyboard controller. Decodes a small set of scan codes into level-held
--   output signals, intended to be consumed by Player.vhd in place of (or in
--   parallel with) the mouse left/right click and jump input.
--
--   Mapped keys (Subway-Surfers-style controls):
--     Spacebar     -> jump_key  (level held while pressed)
--     Up arrow     -> jump_key  (level held while pressed)
--     Down arrow   -> dive_key  (placeholder; currently just a held level signal)
--     Left arrow   -> left_key
--     Right arrow  -> right_key
--
--   The output style is LEVEL (high while key is down, low when released). This
--   matches how the existing Mouse component drives mouse_left_click /
--   right_click, since Player.vhd already edge-detects these inputs internally
--   (click_previous / right_click_previous / jump_input_previous). So holding a
--   key does NOT cause repeated lane shifts -- exactly one shift per press,
--   identical behaviour to a mouse button click.
--
--   PS/2 protocol summary:
--     - 11 bits per byte: start (0), 8 data bits LSB-first, odd parity, stop (1)
--     - Device drives ps2_clock; we sample ps2_data on the falling edge
--     - "Make" code is sent on key press, "break" code (0xF0 followed by the
--       make code) is sent on release
--     - Arrow keys are "extended" -- the device sends 0xE0 first, then the make
--       code (e.g. up arrow press = 0xE0 0x75, up arrow release = 0xE0 0xF0
--       0x75). We track an extended_flag and a break_flag latch across bytes.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Keyboard is
   port (clock              : in    std_logic;
         reset              : in    std_logic;
         ps2_data           : inout std_logic;
         ps2_clock          : inout std_logic;
         left_key           : out   std_logic;
         right_key          : out   std_logic;
         jump_key           : out   std_logic;
         dive_key           : out   std_logic);
end entity Keyboard;

architecture keyboard_behaviour of Keyboard is

   -- ---------------------------------------------------------------------------
   -- PS/2 scan codes (Set 2, the default for almost all PS/2 keyboards)
   -- ---------------------------------------------------------------------------
   constant SCAN_CODE_SPACE        : std_logic_vector(7 downto 0) := x"29";
   constant SCAN_CODE_UP_ARROW     : std_logic_vector(7 downto 0) := x"75";
   constant SCAN_CODE_DOWN_ARROW   : std_logic_vector(7 downto 0) := x"72";
   constant SCAN_CODE_LEFT_ARROW   : std_logic_vector(7 downto 0) := x"6B";
   constant SCAN_CODE_RIGHT_ARROW  : std_logic_vector(7 downto 0) := x"74";
   constant SCAN_CODE_EXTENDED     : std_logic_vector(7 downto 0) := x"E0";
   constant SCAN_CODE_BREAK        : std_logic_vector(7 downto 0) := x"F0";

   -- ---------------------------------------------------------------------------
   -- Clock-edge detection.
   --   ps2_clock_filter follows the same 8-sample debounce pattern used by
   --   Mouse.vhd's Clock_Filter process: only transition the filtered value
   --   when 8 consecutive samples all agree. This makes the receiver immune to
   --   the spikes / ringing that PS/2 cables can pick up.
   --   ps2_clock_filter_previous holds the value from the previous system clock
   --   so we can detect a falling edge as (previous = '1' and current = '0').
   -- ---------------------------------------------------------------------------
   signal ps2_clock_filter_shift    : std_logic_vector(7 downto 0) := (others => '1');
   signal ps2_clock_filter          : std_logic := '1';
   signal ps2_clock_filter_previous : std_logic := '1';
   signal ps2_clock_falling_edge    : std_logic;

   -- ---------------------------------------------------------------------------
   -- Bit-receive logic.
   --   bit_index counts which bit of the 11-bit PS/2 frame is arriving next:
   --     0 -> start bit (always 0, ignored)
   --     1..8 -> data bits d0..d7 (LSB first); these go into byte_assembler(0..7)
   --     9 -> parity bit (ignored; we don't validate parity)
   --     10 -> stop bit (triggers byte_ready pulse)
   --   byte_assembler holds the data byte as it is built up bit-by-bit.
   --   received_byte holds the most recently completed byte.
   -- ---------------------------------------------------------------------------
   signal bit_index       : integer range 0 to 10 := 0;
   signal byte_assembler  : std_logic_vector(7 downto 0) := (others => '0');
   signal received_byte   : std_logic_vector(7 downto 0) := (others => '0');
   signal byte_ready      : std_logic := '0';

   -- ---------------------------------------------------------------------------
   -- Two flags that span across consecutive PS/2 bytes:
   --   extended_flag is set when 0xE0 is seen, and cleared after the next byte
   --     (the actual scan code) is processed.
   --   break_flag is set when 0xF0 is seen, and cleared after the next byte is
   --     processed. If break_flag is set when a scan code arrives, that key is
   --     being released (we drive its output low). Otherwise it is being
   --     pressed (we drive its output high).
   -- ---------------------------------------------------------------------------
   signal extended_flag : std_logic := '0';
   signal break_flag    : std_logic := '0';

   -- Internal level registers for each tracked key.
   signal left_key_reg  : std_logic := '0';
   signal right_key_reg : std_logic := '0';
   signal dive_key_reg  : std_logic := '0';

   -- Separate latches for space and up arrow, OR'd into jump_key, so that
   -- releasing one of them doesn't accidentally cancel a hold on the other.
   signal space_held    : std_logic := '0';
   signal up_arrow_held : std_logic := '0';

begin

   -- ---------------------------------------------------------------------------
   -- Tri-state the PS/2 lines. We never drive them in this design -- the
   -- keyboard is the master of the clock and we only need to read data. The
   -- 'Z' assignment lets external pull-ups hold the lines high when idle.
   -- ---------------------------------------------------------------------------
   ps2_data  <= 'Z';
   ps2_clock <= 'Z';

   -- ---------------------------------------------------------------------------
   -- PS/2 clock 8-sample filter + falling-edge detector.
   -- ---------------------------------------------------------------------------
   PS2_Clock_Filter_Process : process(clock)
   begin
      if rising_edge(clock) then
         ps2_clock_filter_shift <= ps2_clock_filter_shift(6 downto 0) & ps2_clock;
         if ps2_clock_filter_shift = "11111111" then
            ps2_clock_filter <= '1';
         elsif ps2_clock_filter_shift = "00000000" then
            ps2_clock_filter <= '0';
         end if;
         ps2_clock_filter_previous <= ps2_clock_filter;
      end if;
   end process PS2_Clock_Filter_Process;

   ps2_clock_falling_edge <= ps2_clock_filter_previous and not ps2_clock_filter;

   -- ---------------------------------------------------------------------------
   -- Bit receiver. On every falling edge of (filtered) ps2_clock, look at
   -- which bit position we are in and either ignore the bit (start/parity/stop)
   -- or write it into the appropriate slot of byte_assembler. When the stop
   -- bit arrives, latch byte_assembler into received_byte and pulse byte_ready
   -- for exactly one system clock cycle.
   -- ---------------------------------------------------------------------------
   Bit_Receiver_Process : process(clock)
   begin
      if rising_edge(clock) then
         byte_ready <= '0';

         if reset = '1' then
            bit_index      <= 0;
            byte_assembler <= (others => '0');
         elsif ps2_clock_falling_edge = '1' then
            case bit_index is
               when 0 =>
                  -- Start bit; discard. Reset assembler for the new frame.
                  byte_assembler <= (others => '0');
                  bit_index      <= 1;
               when 1 => byte_assembler(0) <= ps2_data; bit_index <= 2;
               when 2 => byte_assembler(1) <= ps2_data; bit_index <= 3;
               when 3 => byte_assembler(2) <= ps2_data; bit_index <= 4;
               when 4 => byte_assembler(3) <= ps2_data; bit_index <= 5;
               when 5 => byte_assembler(4) <= ps2_data; bit_index <= 6;
               when 6 => byte_assembler(5) <= ps2_data; bit_index <= 7;
               when 7 => byte_assembler(6) <= ps2_data; bit_index <= 8;
               when 8 => byte_assembler(7) <= ps2_data; bit_index <= 9;
               when 9 =>
                  -- Parity bit; discard.
                  bit_index <= 10;
               when 10 =>
                  -- Stop bit; latch the assembled byte and signal it.
                  received_byte <= byte_assembler;
                  byte_ready    <= '1';
                  bit_index     <= 0;
            end case;
         end if;
      end if;
   end process Bit_Receiver_Process;

   -- ---------------------------------------------------------------------------
   -- Scan-code decoder. Runs once per received byte. Handles the 0xE0 (extended)
   -- and 0xF0 (break) prefixes, then for the actual scan code sets or clears
   -- the appropriate key latch depending on whether break_flag was set.
   -- ---------------------------------------------------------------------------
   Scan_Code_Decoder_Process : process(clock)
   begin
      if rising_edge(clock) then
         if reset = '1' then
            extended_flag <= '0';
            break_flag    <= '0';
            left_key_reg  <= '0';
            right_key_reg <= '0';
            dive_key_reg  <= '0';
            space_held    <= '0';
            up_arrow_held <= '0';
         elsif byte_ready = '1' then
            if received_byte = SCAN_CODE_EXTENDED then
               extended_flag <= '1';
            elsif received_byte = SCAN_CODE_BREAK then
               break_flag <= '1';
            else
               -- This byte is the actual scan code. Decide press vs release
               -- from break_flag, then dispatch based on extended_flag.
               if extended_flag = '1' then
                  -- Extended (arrow keys)
                  case received_byte is
                     when SCAN_CODE_UP_ARROW =>
                        up_arrow_held <= not break_flag;
                     when SCAN_CODE_DOWN_ARROW =>
                        dive_key_reg  <= not break_flag;
                     when SCAN_CODE_LEFT_ARROW =>
                        left_key_reg  <= not break_flag;
                     when SCAN_CODE_RIGHT_ARROW =>
                        right_key_reg <= not break_flag;
                     when others =>
                        null;
                  end case;
               else
                  -- Non-extended (spacebar lives here)
                  case received_byte is
                     when SCAN_CODE_SPACE =>
                        space_held <= not break_flag;
                     when others =>
                        null;
                  end case;
               end if;

               -- Clear both flags after handling the scan code that followed them.
               extended_flag <= '0';
               break_flag    <= '0';
            end if;
         end if;
      end if;
   end process Scan_Code_Decoder_Process;

   -- ---------------------------------------------------------------------------
   -- jump_key is held high if EITHER spacebar OR up arrow is currently down.
   -- This avoids the corner case where the player taps space and then up arrow
   -- in quick succession -- releasing space wouldn't drop jump_key as long as
   -- up arrow is still held.
   -- ---------------------------------------------------------------------------
   left_key  <= left_key_reg;
   right_key <= right_key_reg;
   jump_key  <= space_held or up_arrow_held;
   dive_key  <= dive_key_reg;

end architecture keyboard_behaviour;