library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Bouncy_Ball is
	port (clock, enable_pulse, vertical_sync : in std_logic;
			push_button_1, push_button_2 	 	  : in std_logic;
         pixel_row, pixel_column	 		     : in std_logic_vector(9 downto 0);
			red, green, blue 			 		     : out std_logic);		
end entity Bouncy_Ball;

architecture bouncy_ball_behavior of bouncy_ball is
	signal ball_on				: std_logic;
	signal size 				: std_logic_vector(9 downto 0);  
	signal ball_y_position	: std_logic_vector(9 downto 0);
	signal ball_x_position	: std_logic_vector(10 downto 0);
	signal ball_y_motion		: std_logic_vector(9 downto 0);
begin           
	size <= conv_std_logic_vector(8,10);
	
	-- ball_x_position and ball_y_position show the (x,y) for the centre of ball
	ball_x_position <= conv_std_logic_vector(590,11);

	ball_on <= '1' when (('0' & ball_x_position <= '0' & pixel_column + size) 
						and ('0' & pixel_column <= '0' & ball_x_position + size) -- x_position - size <= pixel_column <= x_position + size
						and ('0' & ball_y_position <= pixel_row + size) 
						and ('0' & pixel_row <= ball_y_position + size)) -- y_position - size <= pixel_row <= y_position + size
						else '0';


	-- Colours for pixel data on video signal
	-- Changing the background and ball colour by push buttons
	Red 	<= push_button_1;
	Green <= (not push_button_2) and (not ball_on);
	Blue 	<= not ball_on;


	Move_Ball: process (vertical_sync)  	
	begin
		-- Move ball once every vertical sync
		if (rising_edge(vertical_sync)) then			
			-- Bounce off top or bottom of the screen
			if (('0' & ball_y_position >= conv_std_logic_vector(479,10) - size)) then
				ball_y_motion <= - conv_std_logic_vector(2,10);
			elsif (ball_y_position <= size) then 
				ball_y_motion <= conv_std_logic_vector(2,10);
			end if;
			-- Compute next ball Y position
			ball_y_position <= ball_y_position + ball_y_motion;
		end if;
	end process Move_Ball;
end architecture bouncy_ball_behavior;