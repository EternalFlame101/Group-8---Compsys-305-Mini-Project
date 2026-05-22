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
--     start_screen_active = '1'                 -> compose start screen:
--                                                    1. Mouse cursor on top
--                                                    2. Start screen text below
--                                                    3. Start screen sprite as
--                                                       the background image
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

         -- Start screen text layer
         start_screen_red, start_screen_green, start_screen_blue : in std_logic_vector(3 downto 0);

         -- Start screen background sprite layer (drawn underneath text)
         start_screen_sprite_red, start_screen_sprite_green, start_screen_sprite_blue : in std_logic_vector(3 downto 0);

         -- Mouse cursor sprite (overlay on start screen only)
         mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue : in std_logic_vector(3 downto 0);

			-- HUD
			HUD_red, HUD_green, HUD_blue : in std_logic_vector(3 downto 0);
			
         -- Training-mode pipeline output
         training_red, training_green, training_blue : in std_logic_vector(3 downto 0);

         -- Racing-mode pipeline output
         racing_red, racing_green, racing_blue : in std_logic_vector(3 downto 0);

         -- Final composited pixel
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Screen_Compositor;

architecture screen_compositor_behaviour of Screen_Compositor is

   signal mouse_cursor_active        : std_logic;
   signal start_screen_text_active   : std_logic;
   signal start_screen_sprite_active : std_logic;
   signal HUD_active                 : std_logic;
   signal racing_or_training_red     : std_logic_vector(3 downto 0);
   signal racing_or_training_green   : std_logic_vector(3 downto 0);
   signal racing_or_training_blue    : std_logic_vector(3 downto 0);

begin

   mouse_cursor_active        <= '1' when (mouse_cursor_red    or mouse_cursor_green    or mouse_cursor_blue)    /= "0000" else '0';
   start_screen_text_active   <= '1' when (start_screen_red    or start_screen_green    or start_screen_blue)    /= "0000" else '0';
   start_screen_sprite_active <= '1' when (start_screen_sprite_red or start_screen_sprite_green or start_screen_sprite_blue) /= "0000" else '0';
   HUD_active                 <= '1' when (HUD_red             or HUD_green             or HUD_blue)             /= "0000" else '0';

   -- Pick racing or training based on latched_mode
   racing_or_training_red   <= racing_red      when (latched_mode = "10" or latched_mode = "11") else training_red;
   racing_or_training_green <= racing_green    when (latched_mode = "10" or latched_mode = "11") else training_green;
   racing_or_training_blue  <= racing_blue     when (latched_mode = "10" or latched_mode = "11") else training_blue;

   -- HUD overlays on top of whichever game pipeline is active
   -- Start screen layers override everything when start_screen_active = '1'
   red_out   <= mouse_cursor_red          when start_screen_active = '1' and mouse_cursor_active        = '1' else
                start_screen_red          when start_screen_active = '1' and start_screen_text_active   = '1' else
                start_screen_sprite_red   when start_screen_active = '1' and start_screen_sprite_active = '1' else
                "0000"                    when start_screen_active = '1' else
                HUD_red                   when HUD_active = '1' else
                racing_or_training_red;

   green_out <= mouse_cursor_green        when start_screen_active = '1' and mouse_cursor_active        = '1' else
                start_screen_green        when start_screen_active = '1' and start_screen_text_active   = '1' else
                start_screen_sprite_green when start_screen_active = '1' and start_screen_sprite_active = '1' else
                "0000"                    when start_screen_active = '1' else
                HUD_green                 when HUD_active = '1' else
                racing_or_training_green;

   blue_out  <= mouse_cursor_blue         when start_screen_active = '1' and mouse_cursor_active        = '1' else
                start_screen_blue         when start_screen_active = '1' and start_screen_text_active   = '1' else
                start_screen_sprite_blue  when start_screen_active = '1' and start_screen_sprite_active = '1' else
                "0000"                    when start_screen_active = '1' else
                HUD_blue                  when HUD_active = '1' else
                racing_or_training_blue;

end architecture screen_compositor_behaviour;