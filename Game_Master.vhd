library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Game_Master is
	port(clock					: in std_logic;
		  lane_0_obj_type		: in std_logic; -- 0 for obstacle, 1 for gift
		  lane_1_obj_type		: in std_logic;
		  lane_2_obj_type		: in std_logic;
		  lane_0_obj_dist		: in std_logic_vector(9 downto 0);
		  lane_1_obj_dist		: in std_logic_vector(9 downto 0);
		  lane_2_obj_dist		: in std_logic_vector(9 downto 0);
		  game_state			: out std_logic_vector(2 downto 0); -- 11 win, 10 pause, 01 playing, 00 lose
		  speed					: out std_logic_vector(3 downto 0); -- manages speed
		  score					: out std_logic_vector(9 downto 0);)
end entity Game_Master;

architecture game_master_behaviour of Game_Master is
	-- state type
	type game_state is (INIT_SCREEN, TRAINING, NORMAL, PAUSE, WIN, LOSE) := INIT_SCREEN;
	
	-- components
	
	
	-- signals
	
	
begin
	-- start as init screen
	-- move onto either modes, training or normal
	-- pause is a enable that gates EVERYTHING, moves back to training or normal based of what mode it was in
	-- win and lose loops back to init screen
	-- training set number of waves -> init screen after completeing
	
	
end architecture game_master