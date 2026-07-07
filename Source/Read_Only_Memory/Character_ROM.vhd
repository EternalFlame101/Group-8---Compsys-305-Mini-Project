-- ------------------------------------------------------------------------------
-- Character_ROM
--   64-character 8x8 font stored as a VHDL constant array. Synthesises to LUTs
--   (zero M10K blocks). When character_address is a compile-time constant (all
--   static Word_Display text), Quartus constant-folds the lookup entirely.
--
--   The clock port is kept for interface compatibility with ROM_Display but is
--   intentionally unused.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Character_ROM is
   port (clock                  : in  std_logic;
         font_column, font_row  : in  std_logic_vector(2 downto 0);
         character_address      : in  std_logic_vector(5 downto 0);
         rom_multiplexer_output : out std_logic);
end entity Character_ROM;

architecture character_rom_behaviour of Character_ROM is

   type font_rom_t is array(0 to 511) of std_logic_vector(7 downto 0);

   -- Font data extracted from tcgrom.mif (address_radix=oct, data_radix=bin).
   -- Layout: 64 characters x 8 rows, MSB = leftmost pixel column.
   constant FONT_ROM : font_rom_t := (
      -- Char  0 (@)
      x"3C",x"66",x"6E",x"6E",x"60",x"62",x"3C",x"00",
      -- Char  1 (A)
      x"18",x"3C",x"66",x"7E",x"66",x"66",x"66",x"00",
      -- Char  2 (B)
      x"7C",x"66",x"66",x"7C",x"66",x"66",x"7C",x"00",
      -- Char  3 (C)
      x"3C",x"66",x"60",x"60",x"60",x"66",x"3C",x"00",
      -- Char  4 (D)
      x"78",x"6C",x"66",x"66",x"66",x"6C",x"78",x"00",
      -- Char  5 (E)
      x"7E",x"60",x"60",x"78",x"60",x"60",x"7E",x"00",
      -- Char  6 (F)
      x"7E",x"60",x"60",x"78",x"60",x"60",x"60",x"00",
      -- Char  7 (G)
      x"3C",x"66",x"60",x"6E",x"66",x"66",x"3C",x"00",
      -- Char  8 (H)
      x"66",x"66",x"66",x"7E",x"66",x"66",x"66",x"00",
      -- Char  9 (I)
      x"3C",x"18",x"18",x"18",x"18",x"18",x"3C",x"00",
      -- Char 10 (J)
      x"1E",x"0C",x"0C",x"0C",x"0C",x"6C",x"38",x"00",
      -- Char 11 (K)
      x"66",x"6C",x"78",x"70",x"78",x"6C",x"66",x"00",
      -- Char 12 (L)
      x"60",x"60",x"60",x"60",x"60",x"60",x"7E",x"00",
      -- Char 13 (M)
      x"63",x"77",x"7F",x"6B",x"63",x"63",x"63",x"00",
      -- Char 14 (N)
      x"66",x"76",x"7E",x"7E",x"6E",x"66",x"66",x"00",
      -- Char 15 (O)
      x"3C",x"66",x"66",x"66",x"66",x"66",x"3C",x"00",
      -- Char 16 (P)
      x"7C",x"66",x"66",x"7C",x"60",x"60",x"60",x"00",
      -- Char 17 (Q)
      x"3C",x"66",x"66",x"66",x"66",x"3C",x"0E",x"00",
      -- Char 18 (R)
      x"7C",x"66",x"66",x"7C",x"78",x"6C",x"66",x"00",
      -- Char 19 (S)
      x"3C",x"66",x"60",x"3C",x"06",x"66",x"3C",x"00",
      -- Char 20 (T)
      x"7E",x"18",x"18",x"18",x"18",x"18",x"18",x"00",
      -- Char 21 (U)
      x"66",x"66",x"66",x"66",x"66",x"66",x"3C",x"00",
      -- Char 22 (V)
      x"66",x"66",x"66",x"66",x"66",x"3C",x"18",x"00",
      -- Char 23 (W)
      x"63",x"63",x"63",x"6B",x"7F",x"77",x"63",x"00",
      -- Char 24 (X)
      x"66",x"66",x"3C",x"18",x"3C",x"66",x"66",x"00",
      -- Char 25 (Y)
      x"66",x"66",x"66",x"3C",x"18",x"18",x"18",x"00",
      -- Char 26 (Z)
      x"7E",x"06",x"0C",x"18",x"30",x"60",x"7E",x"00",
      -- Char 27 (;)
      x"00",x"18",x"18",x"00",x"00",x"18",x"18",x"30",
      -- Char 28 (down arrow)
      x"18",x"18",x"18",x"18",x"7E",x"3C",x"18",x"00",
      -- Char 29 (:)
      x"00",x"18",x"18",x"00",x"00",x"18",x"18",x"00",
      -- Char 30 (up arrow)
      x"00",x"18",x"3C",x"7E",x"18",x"18",x"18",x"18",
      -- Char 31 (left arrow)
      x"00",x"10",x"30",x"7F",x"7F",x"30",x"10",x"00",
      -- Char 32 (space)
      x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",
      -- Char 33 (!)
      x"18",x"18",x"18",x"18",x"00",x"00",x"18",x"00",
      -- Char 34 (")
      x"66",x"66",x"66",x"00",x"00",x"00",x"00",x"00",
      -- Char 35 (#)
      x"66",x"66",x"FF",x"66",x"FF",x"66",x"66",x"00",
      -- Char 36 ($)
      x"18",x"3E",x"60",x"3C",x"06",x"7C",x"18",x"00",
      -- Char 37 (%)
      x"62",x"66",x"0C",x"18",x"30",x"66",x"46",x"00",
      -- Char 38 (&)
      x"3C",x"66",x"3C",x"38",x"67",x"66",x"3F",x"00",
      -- Char 39 (')
      x"06",x"0C",x"18",x"00",x"00",x"00",x"00",x"00",
      -- Char 40 (()
      x"0C",x"18",x"30",x"30",x"30",x"18",x"0C",x"00",
      -- Char 41 ())
      x"30",x"18",x"0C",x"0C",x"0C",x"18",x"30",x"00",
      -- Char 42 (*)
      x"00",x"66",x"3C",x"FF",x"3C",x"66",x"00",x"00",
      -- Char 43 (+)
      x"00",x"18",x"18",x"7E",x"18",x"18",x"00",x"00",
      -- Char 44 (,)
      x"00",x"00",x"00",x"00",x"00",x"18",x"18",x"30",
      -- Char 45 (-)
      x"00",x"00",x"00",x"7E",x"00",x"00",x"00",x"00",
      -- Char 46 (.)
      x"00",x"00",x"00",x"00",x"00",x"18",x"18",x"00",
      -- Char 47 (/)
      x"00",x"03",x"06",x"0C",x"18",x"30",x"60",x"00",
      -- Char 48 (0)
      x"3C",x"66",x"6E",x"76",x"66",x"66",x"3C",x"00",
      -- Char 49 (1)
      x"18",x"18",x"38",x"18",x"18",x"18",x"7E",x"00",
      -- Char 50 (2)
      x"3C",x"66",x"06",x"0C",x"30",x"60",x"7E",x"00",
      -- Char 51 (3)
      x"3C",x"66",x"06",x"1C",x"06",x"66",x"3C",x"00",
      -- Char 52 (4)
      x"06",x"0E",x"1E",x"66",x"7F",x"06",x"06",x"00",
      -- Char 53 (5)
      x"7E",x"60",x"7C",x"06",x"06",x"66",x"3C",x"00",
      -- Char 54 (6)
      x"3C",x"66",x"60",x"7C",x"66",x"66",x"3C",x"00",
      -- Char 55 (7)
      x"7E",x"66",x"0C",x"18",x"18",x"18",x"18",x"00",
      -- Char 56 (8)
      x"3C",x"66",x"66",x"3C",x"66",x"66",x"3C",x"00",
      -- Char 57 (9)
      x"3C",x"66",x"66",x"3E",x"06",x"66",x"3C",x"00",
      -- Char 58 (A, hex digit alias)
      x"18",x"3C",x"66",x"7E",x"66",x"66",x"66",x"00",
      -- Char 59 (B, hex digit alias)
      x"7C",x"66",x"66",x"7C",x"66",x"66",x"7C",x"00",
      -- Char 60 (C, hex digit alias)
      x"3C",x"66",x"60",x"60",x"60",x"66",x"3C",x"00",
      -- Char 61 (D, hex digit alias)
      x"78",x"6C",x"66",x"66",x"66",x"6C",x"78",x"00",
      -- Char 62 (E, hex digit alias)
      x"7E",x"60",x"60",x"78",x"60",x"60",x"7E",x"00",
      -- Char 63 (F, hex digit alias)
      x"7E",x"60",x"60",x"78",x"60",x"60",x"60",x"00"
   );

   signal rom_data    : std_logic_vector(7 downto 0);
   signal rom_address : integer range 0 to 511;

begin
   rom_address <= to_integer(unsigned(character_address)) * 8
                + to_integer(unsigned(font_row));
   rom_data    <= FONT_ROM(rom_address);

   -- MSB of each byte = leftmost pixel column (font_column 0).
   -- Invert column index so column 0 maps to bit 7.
   rom_multiplexer_output <= rom_data(7 - to_integer(unsigned(font_column)));

end architecture character_rom_behaviour;
