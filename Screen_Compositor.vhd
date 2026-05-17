library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ------------------------------------------------------------------------------
-- Screen_Compositor
--   Selects between the three top-level visual pipelines and produces the
--   final pixel that feeds VGA_Sync. Pure combinational logic; the latching
--   that prevents mid-game mode changes happens inside Start_Screen.
--
--   Selection rules:
--     start_screen_active = '1'                 -> draw start screen, with the
--                                                  mouse cursor sprite
--                                                  overlaid so the user can
--                                                  see what they're aiming at
--     start_screen_active = '0', latched_mode = "10" or "11"
--                                                -> racing pipeline (single
--                                                   player or two player)
--     start_screen_active = '0', latched_mode = "01" or "00"
--                                                -> training pipeline
--                                                   (orbiting ball demo;
--                                                   "00" is the post-reset
--                                                   default before any
--                                                   selection has been made)
-- ------------------------------------------------------------------------------

entity Screen_Compositor is
   port (start_screen_active : in  std_logic;
         latched_mode        : in  std_logic_vector(1 downto 0);

         -- Start screen layer
         start_screen_red, start_screen_green, start_screen_blue : in std_logic_vector(3 downto 0);

         -- Mouse cursor sprite (overlay on start screen only)
         mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue : in std_logic_vector(3 downto 0);

         -- Training-mode pipeline output
         training_red, training_green, training_blue : in std_logic_vector(3 downto 0);

         -- Racing-mode pipeline output
         racing_red, racing_green, racing_blue : in std_logic_vector(3 downto 0);

         -- Final composited pixel
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Screen_Compositor;

architecture screen_compositor_behaviour of Screen_Compositor is

   signal mouse_cursor_active : std_logic;

begin

   -- Mouse cursor is "on" wherever its sprite has any non-zero colour channel.
   mouse_cursor_active <= '1' when (mouse_cursor_red or mouse_cursor_green or mouse_cursor_blue) /= "0000"
                          else '0';

   Final_Mux : process(start_screen_active, latched_mode, mouse_cursor_active,
                       start_screen_red, start_screen_green, start_screen_blue,
                       mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue,
                       training_red,     training_green,     training_blue,
                       racing_red,       racing_green,       racing_blue)
   begin
      if start_screen_active = '1' then
         -- Start screen with mouse cursor overlaid.
         if mouse_cursor_active = '1' then
            red_out   <= mouse_cursor_red;
            green_out <= mouse_cursor_green;
            blue_out  <= mouse_cursor_blue;
         else
            red_out   <= start_screen_red;
            green_out <= start_screen_green;
            blue_out  <= start_screen_blue;
         end if;
      else
         case latched_mode is
            when "10" | "11" =>
               red_out   <= racing_red;
               green_out <= racing_green;
               blue_out  <= racing_blue;
            when others =>
               red_out   <= training_red;
               green_out <= training_green;
               blue_out  <= training_blue;
         end case;
      end if;
   end process Final_Mux;

end architecture screen_compositor_behaviour;