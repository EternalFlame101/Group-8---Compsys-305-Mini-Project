library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Top_Level is
   port (CLOCK_50                     : in    std_logic;
         RESET_N                      : in    std_logic;
         KEY                          : in    std_logic_vector(3 downto 0);
         SW                           : in    std_logic_vector(9 downto 0);
			VGA_HS, VGA_VS               : out   std_logic;
         VGA_R, VGA_G, VGA_B          : out   std_logic_vector(3 downto 0);
         HEX0, HEX1, HEX2, HEX3, HEX5 : out   std_logic_vector(6 downto 0);
			PS2_DAT                      : inout std_logic;
         PS2_CLK                      : inout std_logic);
end entity Top_Level;

architecture game_behaviour of Top_Level is
   -- components
	
	-- clock components
   component Clock_Divider is
      generic (input_clock_frequency  : positive := 50_000_000;
               output_clock_frequency : positive := 25_000_000);
					
			port (input_clock  : in  std_logic;
					enable_pulse : out std_logic);
   end component Clock_Divider;

	-- vga components
   component VGA_Sync is
      port (clock, enable_pulse                    : in  std_logic;
            red, green, blue                       : in  std_logic_vector(3 downto 0);
            video_on                               : out std_logic;
            horizontal_sync_out, vertical_sync_out : out std_logic;
            red_out, green_out, blue_out           : out std_logic_vector(3 downto 0);
            pixel_row, pixel_column                : out std_logic_vector(9 downto 0));
   end component VGA_Sync;
	
	-- Background components
	component Background_Generator is
		port (clock, v_sync 					  : in std_logic;
				pixel_row, pixel_column 	  : in std_logic_vector(9 downto 0);
				red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
	end component Background_Generator;
	
	component Track_Generator is
		port (clock, v_sync 					  : in std_logic;
				pixel_row, pixel_column 	  : in std_logic_vector(9 downto 0);
				red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
	end component Track_Generator;
	
	component Background_Manager is
		port (background_red,   background_green,   background_blue : in  std_logic_vector(3 downto 0);
				track_red,   		track_green,   	  track_blue 		: in  std_logic_vector(3 downto 0);
				red_out,          green_out,          blue_out        : out std_logic_vector(3 downto 0));
	end component Background_Manager;


   -- signals
   signal enable_pulse                   : std_logic;
   signal vertical_sync, horizontal_sync : std_logic;
   signal video_on                       : std_logic;

	-- colour
   signal bg_red, bg_green, bg_blue      : std_logic_vector(3 downto 0);
	signal t_red, t_green, t_blue      	  : std_logic_vector(3 downto 0);
	
	signal red,	green, blue					  : std_logic_vector(3 downto 0);
   signal red_out, green_out, blue_out   : std_logic_vector(3 downto 0);
	
   signal pixel_row, pixel_column        : std_logic_vector(9 downto 0);


begin
   -- Clock Divider
   Divider : Clock_Divider
      port map (input_clock  => CLOCK_50,
                enable_pulse => enable_pulse);

   -- VGA
   VGA : VGA_Sync
      port map (clock               => CLOCK_50,
                enable_pulse        => enable_pulse,
                red                 => red,
                green               => green,
                blue                => blue,
                red_out             => red_out,
                green_out           => green_out,
                blue_out            => blue_out,
                horizontal_sync_out => horizontal_sync,
                vertical_sync_out   => vertical_sync,
                video_on            => video_on,
                pixel_row           => pixel_row,
                pixel_column        => pixel_column);
					 
	-- Background
	Bckgnd : Background_Generator
		port map (clock 			=> CLOCK_50,
					 v_sync 			=> vertical_sync,
					 pixel_row 		=> pixel_row,
					 pixel_column 	=> pixel_column,
				    red_out 		=> bg_red,
					 green_out 		=> bg_green,
					 blue_out 		=> bg_blue);
	
	Track : Track_Generator
		port map (clock 			=> CLOCK_50,
					 v_sync 			=> vertical_sync,
					 pixel_row 		=> pixel_row,
					 pixel_column 	=> pixel_column,
					 red_out 		=> t_red,
					 green_out 		=> t_green,
					 blue_out 		=> t_blue);
			 
	Bckgnd_Manager : Background_Manager
		port map (background_red 	=> bg_red,
					 background_green	=> bg_green,
					 background_blue	=> bg_blue,
					 track_red			=> t_red,
				 	 track_green		=> t_green,
					 track_blue			=> t_blue,
					 red_out				=> red,
					 green_out			=> green,
					 blue_out			=> blue);


   -- VGA output
   VGA_R  <= red_out;
   VGA_G  <= green_out;
   VGA_B  <= blue_out;
   VGA_HS <= horizontal_sync;
	VGA_VS <= vertical_sync;
end architecture game_behaviour;