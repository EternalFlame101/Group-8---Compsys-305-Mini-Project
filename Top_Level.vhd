library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity Top_Level is
	port (CLOCK_50 			  			  : in std_logic;
			SW 					  			  : in std_logic_vector(9 downto 0);
			KEY 					  			  : in std_logic_vector(3 downto 0);
			HEX0, HEX1, HEX2, HEX3, HEX5 : out std_logic_vector(6 downto 0);
			VGA_R, VGA_G, VGA_B 			  : out std_logic_vector(3 downto 0);
			VGA_HS, VGA_VS 	           : out std_logic);						
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
		 port (clock                        : in  std_logic;  -- 50MHz
				 enable_pulse                 : in  std_logic;  -- 25MHz enable
			    red, green, blue             : in  std_logic_vector(3 downto 0);
			    red_out, green_out, blue_out : out std_logic_vector(3 downto 0);
			    horizontal_sync_out          : out std_logic;
			    vertical_sync_out            : out std_logic;
			    video_on                     : out std_logic;
			    pixel_row, pixel_column      : out std_logic_vector(9 downto 0));
	end component VGA_Sync;
	
	component Word_Display is
		generic (STR_LEN : positive := 16);

		port (clock, v_sync : in std_logic;
				characters : in std_logic_vector((STR_LEN * 6 - 1) downto 0);
				pixel_row, pixel_column		  : in std_logic_vector(9 downto 0);
				-- x and y will be bottom left most pixel
				x_pos, y_pos					  : in std_logic_vector(9 downto 0);
				red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
	end component Word_Display;
	
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
		
	-- displaying letter on screen
	line_of_text : Word_Display
						generic map (STR_LEN => 4)
						port map (clock          => CLOCK_50,
									 v_sync         => vertical_sync,
									 characters     => "000011" &   -- C = 3
															 "001000" &   -- H = 8
															 "010101" &   -- U = 21
															 "000100",    -- D = 4
									 pixel_row      => pixel_row,
									 pixel_column   => pixel_column,
									 x_pos          => conv_std_logic_vector(304, 10),
									 y_pos          => conv_std_logic_vector(236, 10),
									 red_out        => red,
									 green_out      => green,
									 blue_out       => blue);
									 
	-- port 
	VGA_R  <= red_out;
	VGA_G  <= green_out;
	VGA_B  <= blue_out;
	VGA_HS <= horizontal_sync;
	VGA_VS <= vertical_sync;
end architecture game_behaviour;