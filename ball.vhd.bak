library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Ball is
	port (clock, enable_pulse 		: in std_logic;
			pixel_row, pixel_column	: in std_logic_vector(9 downto 0);
			ball_x, ball_y : in std_logic_vector(9 downto 0);
			red, green, blue 			: out std_logic);		
end entity Ball;

architecture ball_behavior of ball is
	signal ball_on									 : std_logic;
	signal size 									 : std_logic_vector(9 downto 0);  
begin           
	size <= conv_std_logic_vector(8,10);

	ball_on <= '1' when (('0' & ball_x <= pixel_column + size) 
						and ('0' & pixel_column <= ball_x + size) -- x_position - size <= pixel_column <= x_position + size
						and ('0' & ball_y <= pixel_row + size) 
						and ('0' & pixel_row <= ball_y + size)) -- y_position - size <= pixel_row <= y_position + size
						else '0';

	-- Colours for pixel data on video signal
	-- Keeping background white and square in red
	red 	<= '1';
	
	-- Turn off Green and Blue when displaying square
	green <= not ball_on;
	blue 	<= not ball_on;
end architecture ball_behavior;