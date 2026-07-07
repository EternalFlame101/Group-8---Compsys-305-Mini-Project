-- ------------------------------------------------------------------------------
-- Word_Display
--   Renders a fixed-length string of characters by instantiating one ROM_Display
--   per character in a generate loop.
--
--   TEXT_RED / TEXT_GREEN / TEXT_BLUE control the colour of all characters in
--   this word. Defaults to white (1111) so existing instantiations with no
--   colour generic map continue to work unchanged.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Word_Display is
   generic (STRING_LENGTH : positive                     := 16;
            SCALE         : positive                     := 1;
            TEXT_RED      : std_logic_vector(3 downto 0) := "1111";
            TEXT_GREEN    : std_logic_vector(3 downto 0) := "1111";
            TEXT_BLUE     : std_logic_vector(3 downto 0) := "1111");
   port (clock                        : in  std_logic;
         x_position, y_position       : in  std_logic_vector(9 downto 0);
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
         characters                   : in  std_logic_vector((STRING_LENGTH * 6 - 1) downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Word_Display;

architecture word_display_behaviour of Word_Display is

   component ROM_Display is
      generic (SCALE      : positive                    := 1;
               TEXT_RED   : std_logic_vector(3 downto 0) := "1111";
               TEXT_GREEN : std_logic_vector(3 downto 0) := "1111";
               TEXT_BLUE  : std_logic_vector(3 downto 0) := "1111");
      port (clock                        : in  std_logic;
            character_selection          : in  std_logic_vector(5 downto 0);
            x_position, y_position       : in  std_logic_vector(9 downto 0);
            pixel_column, pixel_row      : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component ROM_Display;

   type colour_array_type is array (0 to STRING_LENGTH - 1) of std_logic_vector(3 downto 0);

   signal array_red, array_green, array_blue : colour_array_type;

begin

   Generate_Line : for i in 0 to STRING_LENGTH - 1 generate
      Display_Character : ROM_Display
         generic map (SCALE      => SCALE,
                      TEXT_RED   => TEXT_RED,
                      TEXT_GREEN => TEXT_GREEN,
                      TEXT_BLUE  => TEXT_BLUE)
         port map (clock               => clock,
                   character_selection => characters(((STRING_LENGTH - i) * 6 - 1) downto ((STRING_LENGTH - i - 1) * 6)),
                   x_position          => x_position + conv_std_logic_vector((i * 8 * SCALE), 10),
                   y_position          => y_position,
                   pixel_row           => pixel_row,
                   pixel_column        => pixel_column,
                   red_out             => array_red(i),
                   green_out           => array_green(i),
                   blue_out            => array_blue(i));
   end generate Generate_Line;

   -- OR all character layers together (they are spatially non-overlapping)
   Combine_Pixels : process(array_red, array_green, array_blue)
      variable red, green, blue : std_logic_vector(3 downto 0);
   begin
      red   := "0000";
      green := "0000";
      blue  := "0000";

      for index in 0 to STRING_LENGTH - 1 loop
         red   := red   or array_red(index);
         green := green or array_green(index);
         blue  := blue  or array_blue(index);
      end loop;

      red_out   <= red;
      green_out <= green;
      blue_out  <= blue;
   end process Combine_Pixels;

end architecture word_display_behaviour;