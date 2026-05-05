	library IEEE;
	use IEEE.std_logic_1164.all;

	entity Top_Level is
		port (CLOCK_50 : in std_logic;
				KEY 		: in std_logic_vector(3 downto 0);
				RESET_N  : in std_logic;

				VGA_R, VGA_G, VGA_B 	: out std_logic_vector(3 downto 0);
				VGA_HS, VGA_VS : out std_logic;
				PS2_DAT, PS2_CLK : inout std_logic);
	end entity Top_Level;

	architecture beh of Top_Level is
		-- Clock Divider
		component Clock_Divider is
			generic (input_clock_frequency  : positive := 50_000_000;
						output_clock_frequency : positive := 25_000_000);

			port (input_clock  : in std_logic;
					enable_pulse : out std_logic);
		end component Clock_Divider;
		
		-- Ball / Mouse
		component Ball is 
				port (clock, enable_pulse 		: in std_logic;
						pixel_row, pixel_column	: in std_logic_vector(9 downto 0);
						ball_x, ball_y : in std_logic_vector(9 downto 0);
						red, green, blue 			: out std_logic);	
		end component Ball;	
		
		-- VGA Sync
		component VGA_Sync is
			port (clock, enable_pulse 				: in std_logic;
					red, green, blue	  				: in std_logic;
					red_out, green_out, blue_out  : out	std_logic;
					horizontal_sync_out				: out	std_logic;
					vertical_sync_out					: out	std_logic;
					pixel_row, pixel_column       : out std_logic_vector(9 downto 0));
		end component VGA_Sync;
		
		-- Mouse
		component mouse IS
			port(clock_25Mhz, enable_pulse, reset 		: in std_logic;
				  mouse_data					: inout std_logic;
				  mouse_clk 					: inout std_logic;
				  left_button, right_button	: out std_logic;
				  mouse_cursor_row 			: out std_logic_vector(9 downto 0); 
				  mouse_cursor_column 		: out std_logic_vector(9 downto 0));       	
		end component mouse;

		
		-- signals
		signal enable_pulse 							: std_logic;
		signal vert_sync, horzi_sync    			: std_logic;
		
		signal left_btn, right_btn : std_logic;
		
		signal mouse_row, mouse_col : std_logic_vector(9 downto 0);
		
		
		signal red, green, blue 					: std_logic;
		signal red_out, green_out, blue_out 	: std_logic;
		signal pixel_row, pixel_column			: std_logic_vector(9 downto 0);
		
		signal clk_25 : std_logic;
		
	begin
		-- Clock Divider
		divider : Clock_Divider port map (input_clock => CLOCK_50, enable_pulse => enable_pulse);
		
		-- Mouse
		test_mouse : mouse port map (clock_25Mhz => CLOCK_50, enable_pulse => enable_pulse, reset => not RESET_N, mouse_data => PS2_DAT, mouse_clk => PS2_CLK,
											  left_button => left_btn, right_button => right_btn, mouse_cursor_row => mouse_row, 
											  mouse_cursor_column => mouse_col); 
											 -- Basically the ball should correspond to the same position of the mouse position. 
			
		-- Balls
		balls : Ball port map (clock => CLOCK_50, enable_pulse => enable_pulse, pixel_row => pixel_row, pixel_column => pixel_column,
									 ball_x => mouse_col, ball_y => mouse_row, red => red, green => green, blue => blue);	
		
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
	end architecture beh;

