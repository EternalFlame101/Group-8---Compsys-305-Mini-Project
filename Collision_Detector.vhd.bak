library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Collision_Detector is
	port (lane_0_row, lane_1_row, lane_2_row 	: in std_logic_vector(9 downto 0);
			lane_0_obj, lane_1_obj, lane_2_obj 	: in std_logic;
			player_lane									: in std_logic_vector(1 downto 0);
			player_state								: in std_logic;
			collision									: out std_logic;)
end entity Collision_Dectector;

architecture collision_detector_behaviour of Collision_Detector is
	signal lane_0_collision, lane_1_collision, lane_2_collision : std_logic;
begin
	lane_0_collision <= '1' when ((player_lane = "00" and (lane_0_row <= conv_std_logic_vector(155, 10))) and
											((lane_0_obj = '1') or
											 (lane_0_obj = '0' and player_state = '0'))
									else '0';
									
	lane_1_collision <= '1' when ((player_lane = "01" and (lane_1_row <= conv_std_logic_vector(155, 10))) and
											((lane_1_obj = '1') or
											 (lane_1_obj = '0' and player_state = '0'))
									else '0';
									
	lane_2_collision <= '1' when ((player_lane = "10" and (lane_2_row <= conv_std_logic_vector(155, 10))) and
											((lane_2_obj = '1') or
											 (lane_2_obj = '0' and player_state = '0'))
									else '0';
									
	collision <= lane_0_collision or lane_1_collision or lane_2_collision;
	
end architecture collision_detector_behaviour;