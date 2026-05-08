library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Moving_Object is
	generic (SIZE : positive := 8)
	port (clock, v_sync 					  : in std_logic;
			pixel_column, pixel_row		  : in  std_logic_vector(9 downto 0);
			row, column						  : in std_logic_vector(9 downto 0);
			red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Moving_Object;

architecture rtl of Moving_Object is
	signal obj_on	: std_logic;
	signal size 	: std_logic_vector(9 downto 0);  
begin
	Moving : process(clk)
	begin
		if rising_edge(clk) then
			
		end if;
	end process Moving;

	size <= conv_std_logic_vector(SIZE_CONST, 10);

	obj_on <= '1' when (('0' & column <= pixel_column + scaling) 
						and ('0' & pixel_column <= column + scaling)
						and ('0' & row <= pixel_row + scaling) 
						and ('0' & pixel_row <= row + scaling))
						else '0';

	red 	<= "0101" when (obj_on = '1') else "0000";
	green <= "0101" when (obj_on = '1') else "0000";
	blue 	<= "0101" when (obj_on = '1') else "0000";
end architecture rtl;