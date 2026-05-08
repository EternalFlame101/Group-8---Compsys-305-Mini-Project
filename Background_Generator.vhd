library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Background_Generator is
	port (clock, v_sync 					  : in std_logic;
			pixel_row, pixel_column 	  : in std_logic_vector(9 downto 0);
			red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Background_Generator;

architecture rtl of Background_Generator is
	signal sky_on : std_logic;
begin
	-- split the skyline with ground element (more sky than ground)
	sky_on <= '1' when (pixel_row >= conv_std_logic_vector(320, 10)) else '0';
	
	red_out <= "0111";
	green_out <= "0111";
	blue_out <= "1111" when (sky_on = '0') else "0111";
end architecture rtl;