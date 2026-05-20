library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ---------------------------------------------------------------------------
-- Mouse_Lane_Controller
--
-- Translates raw mouse position + button signals into clean game-event pulses
-- (switch_left, switch_right, jump_trigger) for the Player FSM.
--
-- Screen geometry (matches Track_Generator / size_scaler.py):
--   HORIZON_ROW  = 320   (track starts here)
--   BUTTON_ROW_Y = 400   (midpoint between horizon 320 and bottom 479)
--
-- At row 400, depth = 400 - 320 = 80.
-- From size_scaler.py: z = 80/160 = 0.5, spread = 5 + 305*(0.5^1.1) = ~152
-- Track spans: centre(320) ± 152  =>  col 168 to col 472
-- Three equal lane thirds of that 304px width (~101px each):
--   Left   lane zone : col 168 – 269
--   Middle lane zone : col 270 – 371
--   Right  lane zone : col 372 – 472
--
-- Click semantics (left_click_raw = left mouse button):
--   Left-click on current lane          -> jump_trigger
--   Left-click on adjacent lane left    -> switch_left
--   Left-click on adjacent lane right   -> switch_right
--   Left-click two lanes away (L->R)    -> switch_left  + queues second switch_left  in Player
--   Left-click two lanes away (R->L)    -> switch_right + queues second switch_right in Player
--   Right-click anywhere on track       -> (reserved for dive/duck — passed through as right_click_out)
--
-- All outputs are single-vsync-cycle pulses (edge-detected on vsync rising edge).
-- ---------------------------------------------------------------------------

entity Mouse_Lane_Controller is
   port (
      clock            : in  std_logic;
      vertical_sync    : in  std_logic;
      -- Raw mouse inputs
      mouse_row        : in  std_logic_vector(9 downto 0);
      mouse_column     : in  std_logic_vector(9 downto 0);
      left_click_raw   : in  std_logic;
      right_click_raw  : in  std_logic;
      -- Current player lane (from Player output, registered each vsync)
      player_lane      : in  std_logic_vector(1 downto 0);
      -- Game-event pulse outputs to Player
      switch_left      : out std_logic;
      switch_right     : out std_logic;
      jump_trigger     : out std_logic;
      -- Dive pass-through (right click on track, for future duck implementation)
      dive_trigger     : out std_logic
   );
end entity Mouse_Lane_Controller;

architecture mlc_behaviour of Mouse_Lane_Controller is

   -- ── Track click-zone geometry (all in pixels) ──────────────────────────
   constant TRACK_ROW_TOP    : integer := 320;   -- horizon row
   constant TRACK_ROW_BOT    : integer := 479;   -- last visible row
   constant BUTTON_ZONE_TOP  : integer := 360;   -- click zone top  (generous vertical band)
   constant BUTTON_ZONE_BOT  : integer := 479;   -- click zone bottom

   -- Lane column boundaries at ~row 400 (see header calculation)
   constant LEFT_ZONE_L      : integer := 168;
   constant LEFT_ZONE_R      : integer := 269;
   constant MID_ZONE_L       : integer := 270;
   constant MID_ZONE_R       : integer := 371;
   constant RIGHT_ZONE_L     : integer := 372;
   constant RIGHT_ZONE_R     : integer := 472;

   -- ── Internal signals ───────────────────────────────────────────────────
   signal vsync_prev          : std_logic := '0';
   signal left_click_prev     : std_logic := '0';
   signal right_click_prev    : std_logic := '0';

   -- Which lane zone the cursor is currently in (0=left, 1=mid, 2=right, 3=none)
   signal cursor_zone         : integer range 0 to 3;

   -- Decoded current lane as integer
   signal current_lane_int    : integer range 0 to 2;

   -- Output registers
   signal switch_left_reg     : std_logic := '0';
   signal switch_right_reg    : std_logic := '0';
   signal jump_trigger_reg    : std_logic := '0';
   signal dive_trigger_reg    : std_logic := '0';

begin

   -- ── Combinational: which lane zone is the cursor in? ───────────────────
   cursor_zone <=
      0 when (conv_integer(mouse_row) >= BUTTON_ZONE_TOP and
              conv_integer(mouse_row) <= BUTTON_ZONE_BOT and
              conv_integer(mouse_column) >= LEFT_ZONE_L  and
              conv_integer(mouse_column) <= LEFT_ZONE_R)
      else
      1 when (conv_integer(mouse_row) >= BUTTON_ZONE_TOP and
              conv_integer(mouse_row) <= BUTTON_ZONE_BOT and
              conv_integer(mouse_column) >= MID_ZONE_L   and
              conv_integer(mouse_column) <= MID_ZONE_R)
      else
      2 when (conv_integer(mouse_row) >= BUTTON_ZONE_TOP and
              conv_integer(mouse_row) <= BUTTON_ZONE_BOT and
              conv_integer(mouse_column) >= RIGHT_ZONE_L and
              conv_integer(mouse_column) <= RIGHT_ZONE_R)
      else 3;   -- outside track zone

   current_lane_int <= conv_integer(player_lane);

   -- ── Sequential: decode click on vsync rising edge ──────────────────────
   Event_Decoder : process(clock)
   begin
      if rising_edge(clock) then
         vsync_prev <= vertical_sync;

         -- Default: pulses are one vsync wide
         switch_left_reg  <= '0';
         switch_right_reg <= '0';
         jump_trigger_reg <= '0';
         dive_trigger_reg <= '0';

         if (vertical_sync = '1') and (vsync_prev = '0') then

            -- ── Left click event ─────────────────────────────────────────
            if (left_click_raw = '1') and (left_click_prev = '0') then

               if cursor_zone = 3 then
                  -- Outside track: treat as raw left roll (switch left)
                  if current_lane_int /= 0 then
                     switch_left_reg <= '1';
                  end if;

               elsif cursor_zone = current_lane_int then
                  -- Clicked own lane -> jump
                  jump_trigger_reg <= '1';

               elsif cursor_zone < current_lane_int then
                  -- Clicked a lane to the left
                  -- cursor_zone=0, current=2 means two hops -> Player queues the second
                  switch_left_reg <= '1';

               else
                  -- Clicked a lane to the right
                  switch_right_reg <= '1';

               end if;
            end if;

            -- ── Right click event ────────────────────────────────────────
            if (right_click_raw = '1') and (right_click_prev = '0') then
               if cursor_zone /= 3 then
                  -- On-track right click -> dive (future duck)
                  dive_trigger_reg <= '1';
               else
                  -- Off-track right click -> raw right roll (switch right)
                  if current_lane_int /= 2 then
                     switch_right_reg <= '1';
                  end if;
               end if;
            end if;

            left_click_prev  <= left_click_raw;
            right_click_prev <= right_click_raw;

         end if;
      end if;
   end process Event_Decoder;

   -- ── Output assignments ─────────────────────────────────────────────────
   switch_left  <= switch_left_reg;
   switch_right <= switch_right_reg;
   jump_trigger <= jump_trigger_reg;
   dive_trigger <= dive_trigger_reg;

end architecture mlc_behaviour;