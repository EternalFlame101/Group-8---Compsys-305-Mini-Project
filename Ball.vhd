library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Ball is
	generic (SIZE_CONST : positive := 8);
	
		port (pixel_column, pixel_row	: in  std_logic_vector(9 downto 0);
				ball_x, ball_y 			: in  std_logic_vector(9 downto 0);
				red, green, blue 			: out std_logic_vector(3 downto 0));		
end entity Ball;

architecture ball_behaviour of Ball is
	signal ball_on	: std_logic;
	signal size 	: std_logic_vector(9 downto 0);  
begin           
	size <= conv_std_logic_vector(SIZE_CONST, 10);

	ball_on <= '1' when (('0' & ball_x <= pixel_column + size) 
						and ('0' & pixel_column <= ball_x + size) -- x_position - size <= pixel_column <= x_position + size
						and ('0' & ball_y <= pixel_row + size) 
						and ('0' & pixel_row <= ball_y + size)) -- y_position - size <= pixel_row <= y_position + size
						else '0';

	red 	<= "1111" when (ball_on = '1') else "0000";
	green <= "1100" when (ball_on = '1') else "0000";
	blue 	<= "1111" when (ball_on = '1') else "0000";
end architecture ball_behaviour;