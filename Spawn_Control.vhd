library IEEE;
use IEEE.std_logic_1164.all;

entity Spawn_Control is
	port(
		clock			 :		in std_logic;
	   reset 		 : 	in std_logic;
		enable 		 :		in std_logic;
		lane_control : 	out std_logic_vector(2 downto 0)
	
end entity; 

architecture beh of Spawn_Control is 
	
	
	component lfsr_8bit is
		port(
			clock 	:	in std_logic;
			reset		:	in std_logic;
			enable 	:	in std_logic;
			output	: 	out std_logic
		);
	end component; 
	
	
	signal lane_0, lane_1, lane_2 : std_logic;
	signal enable_0, enable_1, enable_2 : std_logic;
begin


	-- LFSR for each lane
	LFSR0 : lfsr_8bit 
		generic map (SEED => "10110001");
		port map (clock => clock, reset => reset, enable => enable, output => lane_0);
	
	LFSR1 : lfsr_8bit 
		generic map (SEED => "01001101");
		port map (clock => clock, reset => reset, enable => enable, output => lane_1);
			
	LFSR2 : lfsr_8bit 
		generic map (SEED => "11010010");
		port map (clock => clock, reset => reset, enable => enable, output => lane_2);
	
	enable_0 <= not(lane_1 and lane_2);
	enable_1 <= not(lane_0 and lane_2);
	enable_2 <= not(lane_0 and lane_1);
	
	lane_control(0) <= lane_0 and enable_0;
	lane_control(1) <= lane_1 and enable_1;
	lane_control(2) <= lane_2 and enable_2;
	
	
end architecture beh;