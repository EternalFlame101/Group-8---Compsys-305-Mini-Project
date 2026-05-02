library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Ball is
	port (clock, enable_pulse 		: in std_logic;
			pixel_row, pixel_column	: in std_logic_vector(9 downto 0);
			red, green, blue 			: out std_logic);		
end entity Ball;

architecture ball_behavior of ball is
	signal ball_on									 : std_logic;
	signal size 									 : std_logic_vector(9 downto 0);  
	signal ball_y_position, ball_x_position : std_logic_vector(9 downto 0);
begin           
	size <= conv_std_logic_vector(8,10);
	
	-- ball_x_position and ball_y_position show the (x,y) for the centre of ball
	ball_x_position <= conv_std_logic_vector(590,10);
	ball_y_position <= conv_std_logic_vector(350,10);


	ball_on <= '1' when (('0' & ball_x_position <= pixel_column + size) 
						and ('0' & pixel_column <= ball_x_position + size) -- x_position - size <= pixel_column <= x_position + size
						and ('0' & ball_y_position <= pixel_row + size) 
						and ('0' & pixel_row <= ball_y_position + size)) -- y_position - size <= pixel_row <= y_position + size
						else '0';

	-- Colours for pixel data on video signal
	-- Keeping background white and square in red
	red 	<= '1';
	
	-- Turn off Green and Blue when displaying square
	green <= not ball_on;
	blue 	<= not ball_on;
end architecture ball_behavior;