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
	
	component VGA_Sync is
		 port (clock                           : in  std_logic;  -- 50MHz
				 enable_pulse                    : in  std_logic;  -- 25MHz enable
			    red, green, blue                : in  std_logic_vector(3 downto 0);
			    red_out, green_out, blue_out    : out std_logic_vector(3 downto 0);
			    horizontal_sync_out             : out std_logic;
			    vertical_sync_out               : out std_logic;
			    video_on                        : out std_logic;
			    pixel_row, pixel_column         : out std_logic_vector(9 downto 0));
	end component VGA_Sync;
	
	-- signals
	signal enable_pulse 							: std_logic;
	signal vertical_sync, horizontal_sync  : std_logic;
	signal video_on								: std_logic;
	
	signal red, green, blue 					: std_logic_vector(3 downto 0);
	signal red_out, green_out, blue_out 	: std_logic_vector(3 downto 0);
	signal pixel_row, pixel_column			: std_logic_vector(9 downto 0);
	
begin
	-- Clock Divider
	divider : Clock_Divider port map (input_clock => CLOCK_50, enable_pulse => enable_pulse);
	
	-- VGA defining
	VGA : VGA_Sync port map (clock => CLOCK_50, enable_pulse => enable_pulse, 
									 red => red, green => green, blue => blue,
									 red_out => red_out, green_out => green_out, blue_out => blue_out,
									 horizontal_sync_out => horizontal_sync,
									 vertical_sync_out => vertical_sync,
									 video_on => video_on,
									 pixel_row => pixel_row, pixel_column => pixel_column);
									 
	-- port 
	VGA_R  <= red_out;
	VGA_G  <= green_out;
	VGA_B  <= blue_out;
	VGA_HS <= horizontal_sync;
	VGA_VS <= vertical_sync;
end architecture game_behaviour;