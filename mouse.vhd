library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Mouse is
   port (clock_25mhz, reset              : in    std_logic;
         left_button, right_button : out   std_logic;
         mouse_cursor_row          : out   std_logic_vector(9 downto 0);
         mouse_cursor_column       : out   std_logic_vector(9 downto 0);
         mouse_data                : inout std_logic;
         mouse_clk               : inout std_logic);
end entity Mouse;

architecture mouse_behavior of Mouse is
   type state_type is (inhibit_transmission, load_command, load_command_2,
                       wait_output_ready, wait_command_acknowledgement, input_packets);

   signal mouse_state                                 : state_type;
   signal inhibit_wait_count                          : std_logic_vector(11 downto 0);
   signal character_in, character_out                 : std_logic_vector(7 downto 0);
   signal new_cursor_row, new_cursor_column           : std_logic_vector(9 downto 0);
   signal cursor_row, cursor_column                   : std_logic_vector(9 downto 0);
   signal input_count, output_count                   : std_logic_vector(3 downto 0);
   signal packet_count                                : std_logic_vector(1 downto 0);
   signal shift_in                                    : std_logic_vector(8 downto 0);
   signal shift_out                                   : std_logic_vector(10 downto 0);
   signal packet_character_1, packet_character_2,
          packet_character_3                          : std_logic_vector(7 downto 0);
   signal mouse_clock_buffer, data_ready,
          read_character                              : std_logic;
   signal input_ready_set, output_ready,
          send_character, send_data                   : std_logic;
   signal mouse_data_direction, mouse_data_out,
          mouse_data_buffer, mouse_clock_direction    : std_logic;
   signal mouse_clock_filter                          : std_logic;
   signal filter                                      : std_logic_vector(7 downto 0);
begin
   mouse_cursor_row    <= cursor_row;
   mouse_cursor_column <= cursor_column;

   -- Tri-state control logic for mouse data and clock lines
   mouse_data  <= 'Z' when mouse_data_direction  = '0' else mouse_data_buffer;
   mouse_clk <= 'Z' when mouse_clock_direction = '0' else mouse_clock_buffer;

   -- State machine to send init command and start receive process
   process (reset, clock_25mhz)
   begin
      if reset = '1' then
         mouse_state        <= inhibit_transmission;
         inhibit_wait_count <= conv_std_logic_vector(0, 12);
         send_data          <= '0';
      elsif clock_25mhz'event and clock_25mhz = '1' then
         case mouse_state is
            -- Mouse powers up and sends self test codes aa and 00 before board is downloaded.
            -- Pull clock line low to inhibit any transmissions from mouse.
            -- Need at least 60usec to stop a transmission in progress.
            when inhibit_transmission =>
               inhibit_wait_count <= inhibit_wait_count + 1;
               if inhibit_wait_count(11 downto 10) = "11" then
                  mouse_state <= load_command;
               end if;
               -- Enable streaming mode command f4
               character_out <= "11110100";
            -- Pull data low to signal data available to mouse
            when load_command =>
               send_data   <= '1';
               mouse_state <= load_command_2;
            when load_command_2 =>
               send_data   <= '1';
               mouse_state <= wait_output_ready;
            -- Wait for mouse to clock out all bits in command.
            -- Command sent is f4 (enable streaming mode),
            -- which tells the mouse to start sending 3-byte packets with movement data.
            when wait_output_ready =>
               send_data <= '0';
               if output_ready = '1' then
                  mouse_state <= wait_command_acknowledgement;
               else
                  mouse_state <= wait_output_ready;
               end if;
            -- Wait for mouse to send back command acknowledgement fa
            when wait_command_acknowledgement =>
               send_data <= '0';
               if input_ready_set = '1' then
                  mouse_state <= input_packets;
               end if;
            -- Release clock and data lines and go into mouse input mode.
            -- Stay in this state and receive 3-byte mouse data packets forever.
            -- Default rate is 100 packets per second.
            when input_packets =>
               mouse_state <= input_packets;
         end case;
      end if;
   end process;

   -- Mouse data tri-state control: '1' = FPGA drives, '0' = mouse drives
   with mouse_state select
      mouse_data_direction <= '0' when inhibit_transmission,
                              '0' when load_command,
                              '0' when load_command_2,
                              '1' when wait_output_ready,
                              '0' when wait_command_acknowledgement,
                              '0' when input_packets;

   -- Mouse clock tri-state control: '1' = FPGA drives, '0' = mouse drives
   with mouse_state select
      mouse_clock_direction <= '1' when inhibit_transmission,
                               '1' when load_command,
                               '1' when load_command_2,
                               '0' when wait_output_ready,
                               '0' when wait_command_acknowledgement,
                               '0' when input_packets;

   -- Input to FPGA tri-state buffer mouse clock line
   with mouse_state select
      mouse_clock_buffer <= '0' when inhibit_transmission,
                            '1' when load_command,
                            '1' when load_command_2,
                            '1' when wait_output_ready,
                            '1' when wait_command_acknowledgement,
                            '1' when input_packets;

   -- Filter for mouse clock
   Clock_Filter : process
   begin
      wait until clock_25mhz'event and clock_25mhz = '1';
      filter(7 downto 1) <= filter(6 downto 0);
      filter(0)          <= mouse_clk;
      if filter = "11111111" then
         mouse_clock_filter <= '1';
      elsif filter = "00000000" then
         mouse_clock_filter <= '0';
      end if;
   end process Clock_Filter;

   -- Send serial data to the mouse
   Send_UART : process (send_data, mouse_clock_filter)
   begin
      if send_data = '1' then
         output_count      <= "0000";
         send_character    <= '1';
         output_ready      <= '0';
         -- Send start bit(0) + command(f4) + parity bit(0) + stop bit(1)
         shift_out(8 downto 1) <= character_out;
         -- Start bit
         shift_out(0)      <= '0';
         -- Compute odd parity bit
         shift_out(9)      <= not (character_out(7) xor character_out(6) xor character_out(5) xor
                                   character_out(4) xor character_out(3) xor character_out(2) xor
                                   character_out(1) xor character_out(0));
         -- Stop bit
         shift_out(10)     <= '1';
         -- Data available flag to mouse (also acts as start bit)
         mouse_data_buffer <= '0';
      elsif mouse_clock_filter'event and mouse_clock_filter = '0' then
         if mouse_data_direction = '1' then
            if send_character = '1' then
               if output_count <= "1001" then
                  output_count          <= output_count + 1;
                  shift_out(9 downto 0) <= shift_out(10 downto 1);
                  shift_out(10)         <= '1';
                  mouse_data_buffer     <= shift_out(1);
                  output_ready          <= '0';
               else
                  send_character <= '0';
                  output_ready   <= '1';
                  output_count   <= "0000";
               end if;
            end if;
         end if;
      end if;
   end process Send_UART;

   -- Receive serial data from the mouse
   Receive_UART : process (reset, mouse_clock_filter)
   begin
      if reset = '1' then
         input_count    <= "0000";
         read_character <= '0';
         packet_count   <= "00";
         left_button    <= '0';
         right_button   <= '0';
         character_in   <= "00000000";
      elsif mouse_clock_filter'event and mouse_clock_filter = '0' then
         if mouse_data_direction = '0' then
            if mouse_data = '0' and read_character = '0' then
               read_character  <= '1';
               input_ready_set <= '0';
            else
               if read_character = '1' then
                  if input_count < "1001" then
                     input_count          <= input_count + 1;
                     shift_in(7 downto 0) <= shift_in(8 downto 1);
                     shift_in(8)          <= mouse_data;
                     input_ready_set      <= '0';
                  else
                     character_in    <= shift_in(7 downto 0);
                     read_character  <= '0';
                     input_ready_set <= '1';
                     packet_count    <= packet_count + 1;
                     -- packet_count = "00" is acknowledgement command, set cursor to middle of screen
                     if packet_count = "00" then
                        cursor_column     <= conv_std_logic_vector(320, 10);
                        cursor_row        <= conv_std_logic_vector(240, 10);
                        new_cursor_column <= conv_std_logic_vector(320, 10);
                        new_cursor_row    <= conv_std_logic_vector(240, 10);
                     elsif packet_count = "01" then
                        packet_character_1 <= shift_in(7 downto 0);
                        -- Limit cursor to screen edges.
                        -- All numbers are positive only; check for zero wrap-around.
                        -- Limits set higher since mouse can move up to 128 pixels per packet.
                        -- Check left screen limit
                        if (cursor_row < 128) and ((new_cursor_row > 256) or
                              (new_cursor_row < 2)) then
                           cursor_row <= conv_std_logic_vector(0, 10);
                        -- Check right screen limit
                        elsif new_cursor_row > 480 then
                           cursor_row <= conv_std_logic_vector(480, 10);
                        else
                           cursor_row <= new_cursor_row;
                        end if;
                        -- Check top screen limit
                        if (cursor_column < 128) and ((new_cursor_column > 256) or
                              (new_cursor_column < 2)) then
                           cursor_column <= conv_std_logic_vector(0, 10);
                        -- Check bottom screen limit
                        elsif new_cursor_column > 640 then
                           cursor_column <= conv_std_logic_vector(640, 10);
                        else
                           cursor_column <= new_cursor_column;
                        end if;
                     elsif packet_count = "10" then
                        packet_character_2 <= shift_in(7 downto 0);
                     elsif packet_count = "11" then
                        packet_character_3 <= shift_in(7 downto 0);
                     end if;
                     input_count <= conv_std_logic_vector(0, 4);
                     if packet_count = "11" then
                        packet_count <= "01";
                        -- Packet complete: process movement data.
                        -- Sign-extend x and y two's complement motion values
                        -- and add to current cursor address.
                        -- Y motion is negated since up = lower row address.
                        new_cursor_row    <= cursor_row - (packet_character_3(7) &
                                             packet_character_3(7) & packet_character_3);
                        new_cursor_column <= cursor_column + (packet_character_2(7) &
                                             packet_character_2(7) & packet_character_2);
                        left_button  <= packet_character_1(0);
                        right_button <= packet_character_1(1);
                     end if;
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process Receive_UART;
end architecture mouse_behavior;