-- ------------------------------------------------------------------------------
-- Background_Generator
--   Renders a two-tone sky/ground background. The horizon is at vertical
--   pixel 320 (out of 480), giving a ground band on top and a sky band
--   below it. NOTE: This is inverted relative to a real-world view; flagged
--   for review with teammate before final integration.
--
--   This is purely combinational pixel-domain logic, but the clock and
--   vertical_sync ports are kept for symmetry with the other generator
--   blocks and in case animation is added later.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Background_Generator is
   port (clock, vertical_sync         : in  std_logic;
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Background_Generator;

architecture background_generator_behaviour of Background_Generator is

   component Background_ROM is
      generic (
        DEPTH     : positive := 12800;
        ADDR_BITS : positive := 14;
        MIF_FILE  : string   := "background.mif"
       );
       port (
           clock   : in  std_logic;
           address : in  std_logic_vector(13 downto 0);
           red     : out std_logic_vector(3 downto 0);
           green   : out std_logic_vector(3 downto 0);
           blue    : out std_logic_vector(3 downto 0)
       );
   end component Background_ROM;

   signal rom_address    : std_logic_vector(13 downto 0);

   signal rom_red, rom_green, rom_blue : std_logic_vector(3 downto 0);
   signal red_reg, green_reg, blue_reg : std_logic_vector(3 downto 0);

   constant HORIZON_ROW : std_logic_vector(9 downto 0) := conv_std_logic_vector(320, 10);

   signal sky_on : std_logic;

begin

   -- Split the screen along the horizon row. NOTE: see entity header comment;
   -- this gives sky below the horizon, which is geometrically backwards.
   sky_on <= '0' when (pixel_row >= HORIZON_ROW) else '1';

   BACKGROUND_INSTANCE : Background_ROM
      generic map (
         DEPTH     => 12800,
         ADDR_BITS => 14,
         MIF_FILE  => "background.mif"
      )
      port map (
         clock   => clock,
         address => rom_address,
         red     => rom_red,
         green   => rom_green,
         blue    => rom_blue
      );

   rom_address <= conv_std_logic_vector(
       (conv_integer(pixel_row) / 4) * 160 +
       (conv_integer(pixel_column) / 4), 14)
       when pixel_row < HORIZON_ROW
       else (others => '0');

   process(clock)
   begin
      if (rising_edge(clock)) then
         if (sky_on = '1') then
            red_reg   <= rom_red;
            green_reg <= rom_green;
            blue_reg  <= rom_blue;
         else
            red_reg   <= pixel_row(3 downto 0) xor pixel_column(3 downto 0);
            green_reg <= pixel_row(4 downto 1);
            blue_reg  <= "0000";
         end if;
      end if;
   end process;

   red_out <= red_reg;
   green_out <= green_reg;
   blue_out <= blue_reg;

end architecture background_generator_behaviour;