library IEEE;
use IEEE.std_logic_1164.all;

entity Top_Level is
	port (CLOCK_50 				: in std_logic;
			VGA_R, VGA_G, VGA_B 	: out std_logic_vector(3 downto 0);
			VGA_HS, VGA_VS 		: out std_logic;
			KEY 						: in std_logic_vector(3 downto 0));
end entity Top_Level;

architecture game_behaviour of Top_Level is
	-- components
	component Clock_Divider is
		generic (input_clock_frequency  : positive := 50_000_000;
					output_clock_frequency : positive := 25_000_000);

		port (input_clock  : in std_logic;
				enable_pulse : out std_logic);
	end component Clock_Divider;

	component Bouncy_Ball is
	port (clock, enable_pulse, vertical_sync : in std_logic;
			push_button_1, push_button_2 	 	  : in std_logic;
         pixel_row, pixel_column	 		     : in std_logic_vector(9 downto 0);
			red, green, blue 			 		     : out std_logic);
	end component bouncy_ball;
	
	component VGA_Sync is
		port (clock, enable_pulse 				: in std_logic;
				red, green, blue	  				: in std_logic;
				red_out, green_out, blue_out  : out	std_logic;
				horizontal_sync_out				: out	std_logic;
				vertical_sync_out					: out	std_logic;
				pixel_row, pixel_column       : out std_logic_vector(9 downto 0));
	end component VGA_Sync;
	
	-- signals
	signal enable_pulse 							: std_logic;
	signal vert_sync, horzi_sync    			: std_logic;
	
	signal red, green, blue 					: std_logic;
	signal red_out, green_out, blue_out 	: std_logic;
	signal pixel_row, pixel_column			: std_logic_vector(9 downto 0);
	
begin
	-- Clock Divider
	divider : Clock_Divider port map (input_clock => CLOCK_50, enable_pulse => enable_pulse);
	
	-- ball
	ball : bouncy_ball port map (pb1 => KEY(0), pb2 => KEY(1), clk => CLOCK_50,
													vert_sync =>  vert_sync, 
													pixel_row => pixel_row, pixel_column => pixel_column,
													red => red, green => green, blue => blue);
	
	-- VGA defining
	VGA : VGA_Sync port map (clock => CLOCK_50, enable_pulse => enable_pulse, 
									 red => red, green => green, blue => blue,
									 red_out => red_out, green_out => green_out, blue_out => blue_out,
									 horizontal_sync_out => horzi_sync,
									 vertical_sync_out => vert_sync,
									 pixel_row => pixel_row, pixel_column => pixel_column);
									 
	-- port 
	VGA_R  <= red_out & "000";
	VGA_G  <= green_out & "000";
	VGA_B  <= blue_out & "000";
	VGA_HS <= horzi_sync;
	VGA_VS <= vert_sync;
end architecture game_behaviour;