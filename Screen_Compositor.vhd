library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Screen_Compositor is
   port (start_screen_active : in  std_logic;
         end_screen_active   : in  std_logic;
         latched_mode        : in  std_logic;

         -- Start screen text layer
         start_screen_red,   start_screen_green,   start_screen_blue   : in std_logic_vector(3 downto 0);

         -- Start screen background sprite layer
         start_screen_sprite_red, start_screen_sprite_green, start_screen_sprite_blue : in std_logic_vector(3 downto 0);

         -- Mouse cursor sprite (overlay on start and end screen)
         mouse_cursor_red,   mouse_cursor_green,   mouse_cursor_blue   : in std_logic_vector(3 downto 0);

         -- End screen layer
         end_screen_red,     end_screen_green,     end_screen_blue     : in std_logic_vector(3 downto 0);

         -- Training-mode pipeline output
         training_red,       training_green,       training_blue       : in std_logic_vector(3 downto 0);

         -- Racing-mode pipeline output
         racing_red,         racing_green,         racing_blue         : in std_logic_vector(3 downto 0);

         -- Final composited pixel
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Screen_Compositor;

architecture screen_compositor_behaviour of Screen_Compositor is

   signal mouse_cursor_active        : std_logic;
   signal start_screen_text_active   : std_logic;
   signal start_screen_sprite_active : std_logic;
   signal end_screen_text_active     : std_logic;

begin

   mouse_cursor_active <= '1' when (mouse_cursor_red or mouse_cursor_green or mouse_cursor_blue) /= "0000"
                          else '0';

   start_screen_text_active <= '1' when (start_screen_red or start_screen_green or start_screen_blue) /= "0000"
                               else '0';

   start_screen_sprite_active <= '1' when (start_screen_sprite_red or start_screen_sprite_green or start_screen_sprite_blue) /= "0000"
                                 else '0';

   end_screen_text_active <= '1' when (end_screen_red or end_screen_green or end_screen_blue) /= "0000"
                             else '0';

   Final_Mux : process(start_screen_active, end_screen_active, latched_mode,
                       mouse_cursor_active, start_screen_text_active,
                       start_screen_sprite_active, end_screen_text_active,
                       start_screen_red,        start_screen_green,        start_screen_blue,
                       start_screen_sprite_red, start_screen_sprite_green, start_screen_sprite_blue,
                       mouse_cursor_red,        mouse_cursor_green,        mouse_cursor_blue,
                       end_screen_red,          end_screen_green,          end_screen_blue,
                       training_red,            training_green,            training_blue,
                       racing_red,              racing_green,              racing_blue)
   begin
      if start_screen_active = '1' then
         -- Start screen: mouse on top, then text, then sprite, then black
         if mouse_cursor_active = '1' then
            red_out   <= mouse_cursor_red;
            green_out <= mouse_cursor_green;
            blue_out  <= mouse_cursor_blue;
         elsif start_screen_text_active = '1' then
            red_out   <= start_screen_red;
            green_out <= start_screen_green;
            blue_out  <= start_screen_blue;
         elsif start_screen_sprite_active = '1' then
            red_out   <= start_screen_sprite_red;
            green_out <= start_screen_sprite_green;
            blue_out  <= start_screen_sprite_blue;
         else
            red_out   <= (others => '0');
            green_out <= (others => '0');
            blue_out  <= (others => '0');
         end if;

      elsif end_screen_active = '1' then
         -- End screen: mouse cursor on top, then end screen text, then black
         if mouse_cursor_active = '1' then
            red_out   <= mouse_cursor_red;
            green_out <= mouse_cursor_green;
            blue_out  <= mouse_cursor_blue;
         elsif end_screen_text_active = '1' then
            red_out   <= end_screen_red;
            green_out <= end_screen_green;
            blue_out  <= end_screen_blue;
         else
            red_out   <= (others => '0');
            green_out <= (others => '0');
            blue_out  <= (others => '0');
         end if;

      else
         -- Game running: racing or training based on latched_mode
         case latched_mode is
            when '1' =>
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