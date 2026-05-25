library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Game_Master is
   port(clock             : in  std_logic;
        reset             : in  std_logic;
        lane_0_obj_type   : in  std_logic_vector(1 downto 0);
        lane_1_obj_type   : in  std_logic_vector(1 downto 0);
        lane_2_obj_type   : in  std_logic_vector(1 downto 0);
        lane_0_obj_dist   : in  std_logic_vector(9 downto 0);
        lane_1_obj_dist   : in  std_logic_vector(9 downto 0);
        lane_2_obj_dist   : in  std_logic_vector(9 downto 0);
        player_lane       : in  std_logic_vector(1 downto 0);
        player_state      : in  std_logic;
        startscreen_enable: in  std_logic;
        startscreen_fsm   : out std_logic;
        mode_selected     : in  std_logic;
        game_enable       : out std_logic;
        endscreen_enable  : in  std_logic;
        endscreen_fsm     : out std_logic;
        endscreen_outcome : out std_logic;
        speed             : out std_logic_vector(3 downto 0);
        score             : out std_logic_vector(5 downto 0));
end entity Game_Master;

architecture game_master_behaviour of Game_Master is

   type game_state_type is (INIT_SCREEN, TRAINING, NORMAL, PAUSE, WIN, LOSE);

   component Collision_Detector is
		port (lane_0_row, lane_1_row, lane_2_row 	: in std_logic_vector(9 downto 0);
				lane_0_obj_type, lane_1_obj_type, lane_2_obj_type 	: in std_logic_vector(1 downto 0);
				lane_0_active, lane_1_active, lane_2_active : in std_logic;
				player_lane									: in std_logic_vector(1 downto 0);
				player_state								: in std_logic;
				lane_0_object_collision					: out std_logic;
				lane_1_object_collision					: out std_logic;
				lane_2_object_collision					: out std_logic;
				lane_0_gift_collision					: out std_logic;
				lane_1_gift_collision					: out std_logic;
				lane_2_gift_collision					: out std_logic);
	end component Collision_Detector;

   signal current_state              : game_state_type := INIT_SCREEN;
   signal next_state                 : game_state_type;

   signal internal_game_enable       : std_logic;
   signal internal_endscreen_state   : std_logic;
   signal internal_score             : std_logic_vector(5 downto 0) := (others => '0');

   signal collision_guard            : std_logic := '0';
   signal guard_previous_game_enable : std_logic := '0';
   signal prev_collision             : std_logic := '0';
   signal start_seen_high            : std_logic := '0';

   signal lane_0_object_collision    : std_logic;
   signal lane_1_object_collision    : std_logic;
   signal lane_2_object_collision    : std_logic;
	
	signal lane_0_gift_collision    	 : std_logic;
   signal lane_1_gift_collision      : std_logic;
   signal lane_2_gift_collision      : std_logic;
	
	signal object_collision				 : std_logic;
	signal gift_collision				 : std_logic;
	
	signal any_collision					 : std_logic;
	
	signal lane_0_active					 : std_logic;
	signal lane_1_active					 : std_logic;
	signal lane_2_active					 : std_logic;
begin

	-- object collision
	lane_0_active <= '0' when (lane_0_obj_type = "00") else '1';
	lane_1_active <= '0' when (lane_1_obj_type = "00") else '1';
	lane_2_active <= '0' when (lane_2_obj_type = "00") else '1';

   Object_Collision_Detection : Collision_Detector
      port map (lane_0_row       => lane_0_obj_dist,
                lane_1_row       => lane_1_obj_dist,
                lane_2_row       => lane_2_obj_dist,
                lane_0_obj_type  => lane_0_obj_type,
                lane_1_obj_type  => lane_1_obj_type,
                lane_2_obj_type  => lane_2_obj_type,
                lane_0_active    => lane_0_active,
                lane_1_active    => lane_1_active,
                lane_2_active    => lane_2_active,
                player_lane      => player_lane,
                player_state     => player_state,
                lane_0_object_collision => lane_0_object_collision,
                lane_1_object_collision => lane_1_object_collision,
                lane_2_object_collision => lane_2_object_collision,
					 lane_0_gift_collision => lane_0_gift_collision,
                lane_1_gift_collision => lane_1_gift_collision,
                lane_2_gift_collision => lane_2_gift_collision);
					 
	object_collision <= lane_0_object_collision or lane_1_object_collision or lane_2_object_collision;
	gift_collision <= lane_0_gift_collision or lane_1_gift_collision or lane_2_gift_collision;
	
	any_collision <= gift_collision or object_collision;

   score <= internal_score;
   speed <= "0010";

   -- =========================================================================
   -- Sync process
   -- =========================================================================
   SYNC_PROCESS : process(clock)
   begin
      if rising_edge(clock) then
         if reset = '1' then
            current_state              <= INIT_SCREEN;
            collision_guard            <= '0';
            guard_previous_game_enable <= '0';
            prev_collision             <= '0';
            start_seen_high            <= '0';
            internal_score             <= (others => '0');
         else
            current_state              <= next_state;
            guard_previous_game_enable <= internal_game_enable;
            prev_collision             <= gift_collision;

            -- Arm start_seen_high once start screen confirmed active
            if current_state = INIT_SCREEN then
               if startscreen_enable = '1' then
                  start_seen_high <= '1';
               end if;
            else
               start_seen_high <= '0';
            end if;

            -- Collision guard: arms after first clean frame in game
            if internal_game_enable = '1' and guard_previous_game_enable = '0' then
               collision_guard <= '0';
            elsif internal_game_enable = '0' then
               collision_guard <= '0';
            elsif object_collision = '0' then
               collision_guard <= '1';
            end if;

            -- Score: increment on rising edge of collision only
            if current_state = NORMAL then
               if collision_guard = '1' and gift_collision = '1' and prev_collision = '0' then
                  internal_score <= internal_score + 1;
               end if;
            end if;
         end if;
      end if;
   end process SYNC_PROCESS;

   -- =========================================================================
   -- FSM output
   -- =========================================================================
   FSM_OUTPUT : process(current_state)
   begin
      internal_game_enable     <= '0';
      internal_endscreen_state <= '0';
      startscreen_fsm          <= '0';
      endscreen_fsm            <= '0';

      case current_state is
         when INIT_SCREEN =>
            startscreen_fsm          <= '1';
            internal_game_enable     <= '0';
            internal_endscreen_state <= '0';
         when TRAINING =>
            null;
         when NORMAL =>
            internal_game_enable     <= '1';
            internal_endscreen_state <= '0';
         when PAUSE =>
            internal_game_enable     <= '0';
         when WIN =>
            endscreen_fsm            <= '1';
            internal_endscreen_state <= '1';
         when LOSE =>
            endscreen_fsm            <= '1';
            internal_endscreen_state <= '0';
      end case;
   end process FSM_OUTPUT;

   game_enable       <= internal_game_enable;
   endscreen_outcome <= internal_endscreen_state;

   -- =========================================================================
   -- Next state
   -- =========================================================================
   FSM_NEXT_STATE : process(current_state,
                            startscreen_enable,
                            start_seen_high,
                            collision_guard,
                            object_collision,
                            endscreen_enable,
                            mode_selected)
   begin
      next_state <= current_state;

      case current_state is
         when INIT_SCREEN =>
            if start_seen_high = '1' and startscreen_enable = '0' then
               next_state <= NORMAL;
            end if;
         when TRAINING =>
            null;
         when NORMAL =>
            if (collision_guard = '1' and object_collision = '1') then
					next_state <= LOSE;
            end if;
         when PAUSE =>
            null;
         when WIN =>
            if endscreen_enable = '0' then
               next_state <= INIT_SCREEN;
            end if;
         when LOSE =>
            if endscreen_enable = '0' then
               next_state <= INIT_SCREEN;
            end if;
      end case;
   end process FSM_NEXT_STATE;

end architecture game_master_behaviour;