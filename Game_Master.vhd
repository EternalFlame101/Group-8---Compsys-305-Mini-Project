library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- add hud enable later

entity Game_Master is
   port(clock            	: in  std_logic;
		  reset					: in  std_logic;
		  lane_0_gift			: in 	std_logic; -- 0 for no gift in lane, 1 for gift in lane
		  lane_1_gift			: in 	std_logic;
		  lane_2_gift			: in 	std_logic;
        lane_0_obj_type  	: in  std_logic; -- 0 for short, 1 for tall
        lane_1_obj_type  	: in  std_logic;
        lane_2_obj_type  	: in  std_logic;
        lane_0_obj_dist  	: in  std_logic_vector(9 downto 0);
        lane_1_obj_dist  	: in  std_logic_vector(9 downto 0);
        lane_2_obj_dist  	: in  std_logic_vector(9 downto 0);
		  player_lane			: in	std_logic_vector(1 downto 0);
		  player_state			: in 	std_logic;
		  startscreen_enable : in 	std_logic; -- 0 = off, 1 = on, startscreen on/off
		  mode_selected		: in  std_logic; -- 0 = training, 1 = normal/single player
        game_enable		 	: out std_logic; -- 0 = pause, 1 = playing, game pause
		  endscreen_enable	: out std_logic; -- 0 = off, 1 = on, win/lose screen
		  endscreen_outcome  : out std_logic; -- 0 = lose, 1 = win
        speed            	: out std_logic_vector(3 downto 0); -- manages speed
        score            	: out std_logic_vector(5 downto 0));
end entity Game_Master;

architecture game_master_behaviour of Game_Master is
   -- state type (renamed so it does not clash with the game_state port)
   type game_state_type is (INIT_SCREEN, TRAINING, NORMAL, PAUSE, WIN, LOSE);

   -- components
	component Collision_Detector is
		port (lane_0_row, lane_1_row, lane_2_row 	: in std_logic_vector(9 downto 0);
				lane_0_obj, lane_1_obj, lane_2_obj 	: in std_logic;
				player_lane									: in std_logic_vector(1 downto 0);
				player_state								: in std_logic;
				lane_0_collision							: out std_logic;
				lane_1_collision							: out std_logic;
				lane_2_collision							: out std_logic);
	end component Collision_Detector;
	
   -- signals
	
	-- ===== state signals ================================
   signal current_state 					: game_state_type := INIT_SCREEN;
	signal next_state							: game_state_type;
	
	-- ===== screen signals ================================
	signal internal_game_enable 			: std_logic;
	signal internal_startscreen_enable 	: std_logic;
	signal internal_endscreen_enable		: std_logic;
	
	-- ===== lose win signals ===============================
	signal internal_endscreen_state 		: std_logic;
	
	-- ====== collision signals ==============================
	signal lane_0_collision 				: std_logic;
	signal lane_1_collision 				: std_logic;
	signal lane_2_collision 				: std_logic;
	signal obj_or_gift						: std_logic; -- 0 for obj, 1 for gift
	
	

begin
   -- start as init screen
   -- move onto either modes, training or normal
   -- pause is an enable that gates EVERYTHING, moves back to training or normal based on what mode it was in
   -- win and lose loops back to init screen
   -- training set number of waves -> init screen after completing
	
	-- ======== Collision ===================================
	Object_Collision: Collision_Detector
		port map (lane_0_row 		=> lane_0_obj_dist,
					 lane_1_row 		=> lane_1_obj_dist,
					 lane_2_row 		=> lane_2_obj_dist,
					 lane_0_obj 		=> lane_0_obj_type, 
					 lane_1_obj			=> lane_1_obj_type, 
					 lane_2_obj 		=> lane_2_obj_type,
					 player_lane		=> player_lane,	
					 player_state		=> player_state,
					 lane_0_collision	=> lane_0_collision,
					 lane_1_collision	=> lane_1_collision,
					 lane_2_collision => lane_2_collision);
	
	obj_or_gift <= '1' when ((lane_0_collision = '1' and lane_0_gift = '1') 
								 or (lane_1_collision = '1' and lane_1_gift = '1') 
								 or (lane_2_collision = '1' and lane_2_gift = '1')) 
							 else '0';
	
	
	SYNC_PROCESS : process(clock)
	begin
		if rising_edge(clock) then
			if (reset = '1') then
				current_state <= INIT_SCREEN;
			else
				current_state <= next_state;
			end if;
		end if;
	end process SYNC_PROCESS;
	
	FSM_OUTPUT: process(current_state)
	begin
		internal_game_enable      <= '0';
		internal_endscreen_enable <= '0';
		internal_endscreen_state  <= '0';
		case (current_state) is
			when INIT_SCREEN =>
				internal_game_enable 			<= '0';
				internal_endscreen_state		<= '1';
			when TRAINING =>
				-- do later not sure what to do here
				null;
			when NORMAL =>
				internal_game_enable 			<= '1';
				internal_endscreen_state		<= '1';
			when PAUSE =>
				internal_game_enable 			<= '0';
				internal_endscreen_state		<= '1';
			when WIN =>
				internal_game_enable 			<= '0';
				internal_endscreen_state		<= '1';
			when LOSE =>
				internal_game_enable 			<= '0';
				internal_endscreen_state		<= '0';
		end case;
	end process FSM_OUTPUT;
	
	-- mapping process signal to output
	game_enable <= internal_game_enable;
	endscreen_outcome <= internal_endscreen_state;
	
	FSM_NEXT_STATE: process(current_state, 
									lane_0_collision, 
									lane_1_collision, 
									lane_2_collision,
									startscreen_enable,
									mode_selected)
	begin
		next_state <= current_state;
		case (current_state) is
			when INIT_SCREEN =>
				if (startscreen_enable = '0') then
					if (mode_selected = '0') then
						next_state <= TRAINING;
					else
						next_state <= NORMAL;
					end if;
				end if;
			when TRAINING =>
				null;
			when NORMAL =>
				if (lane_0_collision or lane_1_collision or lane_2_collision) = '1' then
					if (obj_or_gift = '0') then
						null;
					else
						null;
					end if;
				end if;
			when PAUSE =>
				null;
			when WIN =>
				null;
			when LOSE =>
				null;
		end case;
	end process FSM_NEXT_STATE;


end architecture game_master_behaviour;