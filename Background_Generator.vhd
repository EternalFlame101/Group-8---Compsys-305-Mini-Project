library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

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
-- ------------------------------------------------------------------------------
entity Background_Generator is
   port (clock, vertical_sync         : in  std_logic;
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Background_Generator;

architecture background_generator_behaviour of Background_Generator is

   constant HORIZON_ROW : std_logic_vector(9 downto 0) := conv_std_logic_vector(320, 10);

   signal sky_on : std_logic;

begin

   -- Split the screen along the horizon row. NOTE: see entity header comment;
   -- this gives sky below the horizon, which is geometrically backwards.
   sky_on <= '1' when (pixel_row >= HORIZON_ROW) else '0';

   red_out   <= "0111";
   green_out <= "0111";
   blue_out  <= "1111" when (sky_on = '0') else "0111";

end architecture background_generator_behaviour;