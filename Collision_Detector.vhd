library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Collision_Detector is
	port (lane_0_row, lane_1_row, lane_2_row 	: in std_logic_vector(9 downto 0);
			lane_0_obj, lane_1_obj, lane_2_obj 	: in std_logic; -- 0 short, 1 tall
			lane_0_active, lane_1_active, lane_2_active : in std_logic;
			player_lane									: in std_logic_vector(1 downto 0);
			player_state								: in std_logic; -- 0 grounded, 1 jumping
			lane_0_collision							: out std_logic;
			lane_1_collision							: out std_logic;
			lane_2_collision							: out std_logic);
end entity Collision_Detector;

architecture collision_detector_behaviour of Collision_Detector is
	signal t_lane_0_collision, t_lane_1_collision, t_lane_2_collision : std_logic;
begin
	t_lane_0_collision <= '1' when (lane_0_active = '1' and
											  player_lane = "00" and
											  lane_0_row <= conv_std_logic_vector(140, 10) and
											  (lane_0_obj = '1' or player_state = '0'))
								 else '0';

	t_lane_1_collision <= '1' when (lane_1_active = '1' and
											  player_lane = "01" and
											  lane_1_row <= conv_std_logic_vector(140, 10) and
											  (lane_1_obj = '1' or player_state = '0'))
								 else '0';

	t_lane_2_collision <= '1' when (lane_2_active = '1' and
											  player_lane = "10" and
											  lane_2_row <= conv_std_logic_vector(140, 10) and
											  (lane_2_obj = '1' or player_state = '0'))
                      else '0';
									
	lane_0_collision <= t_lane_0_collision;
	lane_1_collision <= t_lane_1_collision;
	lane_2_collision <= t_lane_2_collision;
	
end architecture collision_detector_behaviour;