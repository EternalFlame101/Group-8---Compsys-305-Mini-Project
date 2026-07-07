-- ------------------------------------------------------------------------------
-- Graphics_Manager
--   Composites the in-game visual layers into a single pixel stream in priority
--   order: text (large then small) over sprites over background, with the mouse
--   layer available on top. A layer contributes wherever it produces a non-zero
--   (non-transparent) pixel.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Graphics_Manager is
   port (clock : in std_logic;
         text_large_red,   text_large_green,   text_large_blue : in  std_logic_vector(3 downto 0);
         text_small_red,   text_small_green,   text_small_blue : in  std_logic_vector(3 downto 0);
         background_red,   background_green,   background_blue : in  std_logic_vector(3 downto 0);
         sprite_red,       sprite_green,       sprite_blue     : in  std_logic_vector(3 downto 0);
         mouse_red,        mouse_green,        mouse_blue      : in  std_logic_vector(3 downto 0);
         red_out,          green_out,          blue_out        : out std_logic_vector(3 downto 0));
end entity Graphics_Manager;

architecture graphics_manager_behaviour of Graphics_Manager is
   -- Active signals — true if that layer has anything to draw
   signal text_large_active : std_logic;
   signal text_small_active : std_logic;
   signal sprite_active     : std_logic;
   signal mouse_active      : std_logic;
   signal background_active : std_logic;

   signal red_reg    : std_logic_vector(3 downto 0);
   signal green_reg  : std_logic_vector(3 downto 0);
   signal blue_reg   : std_logic_vector(3 downto 0);

begin
   -- A layer is active if any channel is non zero
   text_large_active <= '1' when (text_large_red or text_large_green or text_large_blue) /= "0000" else '0';
   text_small_active <= '1' when (text_small_red or text_small_green or text_small_blue) /= "0000" else '0';
   sprite_active     <= '1' when (sprite_red     or sprite_green     or sprite_blue)     /= "0000" else '0';
   mouse_active      <= '1' when (mouse_red      or mouse_green      or mouse_blue)      /= "0000" else '0';
   background_active <= '1' when (background_red or background_green or background_blue) /= "0000" else '0';

   -- Priority mux — highest priority first, background always last
   red_reg   <= text_large_red   when text_large_active = '1' else
              text_small_red     when text_small_active = '1' else
              mouse_red          when mouse_active      = '1' else
              sprite_red         when sprite_active     = '1' else
              background_red;

   green_reg <= text_large_green when text_large_active = '1' else
              text_small_green   when text_small_active = '1' else
              mouse_green        when mouse_active      = '1' else
              sprite_green       when sprite_active     = '1' else
              background_green;

   blue_reg  <= text_large_blue  when text_large_active = '1' else
              text_small_blue    when text_small_active = '1' else
              mouse_blue         when mouse_active      = '1' else
              sprite_blue        when sprite_active     = '1' else
              background_blue;

   register_output : process(clock)
   begin
      if rising_edge(clock) then
         red_out <= red_reg;
         green_out <= green_reg;
         blue_out <= blue_reg;
      end if;
   end process register_output;
end architecture graphics_manager_behaviour;