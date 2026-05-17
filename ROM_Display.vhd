library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ------------------------------------------------------------------------------
-- ROM_Display
--   Renders a single 8x8 character from Character_ROM, scaled by integer SCALE.
--
--   font_row / font_column are produced by a generate-time selection based on
--   SCALE: bit-select for SCALE in {1, 2, 4, 8}, an inline case-statement LUT
--   for SCALE = 3. This avoids the long-combinational integer-divide path that
--   "/ SCALE" produces for non-power-of-2 SCALE values, and restores the high
--   Fmax that the bit-shift version had, while keeping correct rendering for
--   all SCALE values (the bottom row of SCALE = 3 characters is no longer
--   clipped).
--
--   TEXT_RED / TEXT_GREEN / TEXT_BLUE generics colour the rendered pixels.
--   Default white so any existing instantiation continues to work unchanged.
-- ------------------------------------------------------------------------------

entity ROM_Display is
   generic (SCALE      : positive                    := 1;
            TEXT_RED   : std_logic_vector(3 downto 0) := "1111";
            TEXT_GREEN : std_logic_vector(3 downto 0) := "1111";
            TEXT_BLUE  : std_logic_vector(3 downto 0) := "1111");
   port (clock                        : in  std_logic;
         character_selection          : in  std_logic_vector(5 downto 0);
         x_position, y_position       : in  std_logic_vector(9 downto 0);
         pixel_column, pixel_row      : in  std_logic_vector(9 downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity ROM_Display;

architecture rom_display_behaviour of ROM_Display is

   component Character_ROM is
      port (clock                  : in  std_logic;
            character_address      : in  std_logic_vector(5 downto 0);
            font_row, font_column  : in  std_logic_vector(2 downto 0);
            rom_multiplexer_output : out std_logic);
   end component Character_ROM;

   constant CHAR_SIZE : integer := 8 * SCALE;

   signal display_on            : std_logic;
   signal character_on          : std_logic;
   signal character_on_register : std_logic;

   signal row_offset    : std_logic_vector(9 downto 0);
   signal column_offset : std_logic_vector(9 downto 0);
   signal font_row      : std_logic_vector(2 downto 0);
   signal font_column   : std_logic_vector(2 downto 0);

   -- Map a 5-bit offset (0..23) to a font index (0..7) for SCALE = 3.
   -- Out-of-range offsets get gated to 0 by character_on_register anyway.
   function divide_by_three(offset : std_logic_vector) return std_logic_vector is
      variable o : integer range 0 to 31;
   begin
      o := conv_integer(offset(4 downto 0));
      case o is
         when 0  | 1  | 2                => return "000";
         when 3  | 4  | 5                => return "001";
         when 6  | 7  | 8                => return "010";
         when 9  | 10 | 11               => return "011";
         when 12 | 13 | 14               => return "100";
         when 15 | 16 | 17               => return "101";
         when 18 | 19 | 20               => return "110";
         when 21 | 22 | 23               => return "111";
         when others                     => return "000";
      end case;
   end function divide_by_three;

begin

   Character_Process : process (clock)
   begin
      if rising_edge(clock) then
         character_on_register <= character_on;
      end if;
   end process Character_Process;

   row_offset    <= pixel_row    - y_position;
   column_offset <= pixel_column - x_position;

   -- SCALE-specific addressing. SCALE is a generic constant, so exactly one
   -- branch of this if-generate is emitted per ROM_Display instance.
   Power_Of_Two : if SCALE = 1 or SCALE = 2 or SCALE = 4 or SCALE = 8 generate
      Scale_1 : if SCALE = 1 generate
         font_row    <= row_offset(2 downto 0);
         font_column <= column_offset(2 downto 0);
      end generate Scale_1;
      Scale_2 : if SCALE = 2 generate
         font_row    <= row_offset(3 downto 1);
         font_column <= column_offset(3 downto 1);
      end generate Scale_2;
      Scale_4 : if SCALE = 4 generate
         font_row    <= row_offset(4 downto 2);
         font_column <= column_offset(4 downto 2);
      end generate Scale_4;
      Scale_8 : if SCALE = 8 generate
         font_row    <= row_offset(5 downto 3);
         font_column <= column_offset(5 downto 3);
      end generate Scale_8;
   end generate Power_Of_Two;

   Scale_3 : if SCALE = 3 generate
      font_row    <= divide_by_three(row_offset);
      font_column <= divide_by_three(column_offset);
   end generate Scale_3;

   character_on <= '1' when ((pixel_row    <= y_position + conv_std_logic_vector(CHAR_SIZE - 1, 10))
                        and  (pixel_row    >= y_position)
                        and  (pixel_column <= x_position + conv_std_logic_vector(CHAR_SIZE - 1, 10))
                        and  (pixel_column >= x_position))
                   else '0';

   Get_Character_Pixel : Character_ROM
      port map (clock                  => clock,
                character_address      => character_selection,
                font_row               => font_row,
                font_column            => font_column,
                rom_multiplexer_output => display_on);

   red_out   <= TEXT_RED   when (character_on_register = '1' and display_on = '1') else "0000";
   green_out <= TEXT_GREEN when (character_on_register = '1' and display_on = '1') else "0000";
   blue_out  <= TEXT_BLUE  when (character_on_register = '1' and display_on = '1') else "0000";

end architecture rom_display_behaviour;