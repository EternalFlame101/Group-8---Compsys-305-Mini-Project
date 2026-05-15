library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity TopLevel2 is
   port (CLOCK_50                     : in    std_logic;
         RESET_N                      : in    std_logic;
         KEY                          : in    std_logic_vector(3 downto 0);
         SW                           : in    std_logic_vector(9 downto 0);
			VGA_HS, VGA_VS               : out   std_logic;
         VGA_R, VGA_G, VGA_B          : out   std_logic_vector(3 downto 0);
         HEX0, HEX1, HEX2, HEX3, HEX5 : out   std_logic_vector(6 downto 0);
			PS2_DAT                      : inout std_logic;
         PS2_CLK                      : inout std_logic);
end entity TopLevel2;

architecture game_behaviour2 of TopLevel2 is

	-- Clock Divider (pll)
	component pll is
		port (
			refclk   : in  std_logic;
			rst      : in  std_logic; 
			outclk_0 : out std_logic;        
			locked   : out std_logic         
		);
	end component pll;

   -- components
   component Ball is
      generic (SIZE_CONST : positive := 8);
      port (pixel_column, pixel_row : in  std_logic_vector(9 downto 0);
            ball_x, ball_y          : in  std_logic_vector(9 downto 0);
            red, green, blue        : out std_logic_vector(3 downto 0));
   end component Ball;

   component Clock_Divider is
      generic (input_clock_frequency  : positive := 50_000_000;
               output_clock_frequency : positive := 25_000_000);
					
			port (input_clock  : in  std_logic;
					enable_pulse : out std_logic);
   end component Clock_Divider;

   component Graphics_Manager is
      port (text_large_red,   text_large_green,   text_large_blue : in  std_logic_vector(3 downto 0);
            text_small_red,   text_small_green,   text_small_blue : in  std_logic_vector(3 downto 0);
            background_red,   background_green,   background_blue : in  std_logic_vector(3 downto 0);
            sprite_red,       sprite_green,       sprite_blue     : in  std_logic_vector(3 downto 0);
            mouse_red,        mouse_green,        mouse_blue      : in  std_logic_vector(3 downto 0);
            red_out,          green_out,          blue_out        : out std_logic_vector(3 downto 0));
   end component Graphics_Manager;

   component Mouse is
      port (clock_25mhz, reset 		  : in    std_logic;
            left_button, right_button : out   std_logic;
            mouse_cursor_row          : out   std_logic_vector(9 downto 0);
            mouse_cursor_column       : out   std_logic_vector(9 downto 0);
            mouse_data                : inout std_logic;
            mouse_clk                 : inout std_logic);
   end component Mouse;

   component Orbiting_Ball is
      port (clock, vertical_sync    : in  std_logic;
            pixel_row, pixel_column : in  std_logic_vector(9 downto 0);
            radius                  : in  std_logic_vector(6 downto 0);
            left_click            	: in  std_logic;
            ball_x_out, ball_y_out  : out std_logic_vector(9 downto 0));
   end component Orbiting_Ball;

   component VGA_Sync is
      port (clock					                     : in  std_logic;
            red, green, blue                       : in  std_logic_vector(3 downto 0);
            video_on                               : out std_logic;
            horizontal_sync_out, vertical_sync_out : out std_logic;
            red_out, green_out, blue_out           : out std_logic_vector(3 downto 0);
            pixel_row, pixel_column                : out std_logic_vector(9 downto 0));
   end component VGA_Sync;

   component Word_Display is
      generic (STRING_LENGTH : positive := 16;
               SCALE         : positive := 1);
      port (clock          					: in  std_logic;
            x_position, y_position        : in  std_logic_vector(9 downto 0);
            pixel_row, pixel_column       : in  std_logic_vector(9 downto 0);
            characters                    : in  std_logic_vector((STRING_LENGTH * 6 - 1) downto 0);
            red_out, green_out, blue_out  : out std_logic_vector(3 downto 0));
   end component Word_Display;

	component Sprites_Display is
		generic (
        SPRITE_WIDTH  : positive := 64;
        SPRITE_HEIGHT : positive := 64;
        ADDR_BITS     : positive := 12;
		  SCALE 			 : positive := 1
		 );
		 port (
			  clock                        : in  std_logic;
			  pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
			  sprite_x,  sprite_y          : in  std_logic_vector(9 downto 0);
			  red_out, green_out, blue_out : out std_logic_vector(3 downto 0)
		 );
	end component Sprites_Display;
	
   component Background_Colour is
      port (clock, vertical_sync                                          : in  std_logic;
            dip_switch_0, dip_switch_1, dip_switch_2, dip_switch_3        : in  std_logic;
            push_button_0, push_button_1, push_button_2, push_button_3    : in  std_logic;
            red_out, green_out, blue_out                                  : out std_logic_vector(3 downto 0);
            seven_segment_display_digit_0, seven_segment_display_digit_1,
            seven_segment_display_digit_2, seven_segment_display_digit_3,
            seven_segment_display_digit_5                                 : out std_logic_vector(6 downto 0));
   end component Background_Colour;

   -- signals
   signal enable_pulse                   : std_logic;
   signal vertical_sync, horizontal_sync : std_logic;
   signal video_on                       : std_logic;
   signal left_click, right_click        : std_logic;
   signal mouse_column, mouse_row        : std_logic_vector(9 downto 0);

   signal red, green, blue               : std_logic_vector(3 downto 0);
   signal red1, green1, blue1            : std_logic_vector(3 downto 0);
   signal red2, green2, blue2            : std_logic_vector(3 downto 0);
   signal red3, green3, blue3            : std_logic_vector(3 downto 0);
   signal red4, green4, blue4            : std_logic_vector(3 downto 0);
   signal red5, green5, blue5            : std_logic_vector(3 downto 0);
   signal red_out, green_out, blue_out   : std_logic_vector(3 downto 0);
   signal pixel_row, pixel_column        : std_logic_vector(9 downto 0);
   signal ball_x_out, ball_y_out         : std_logic_vector(9 downto 0);
	
	signal clk_25 								  : std_logic;
	signal locked 								  : std_logic;

begin
	-- PLL clock
	Clock_25 : pll 
		port map (refclk   => CLOCK_50,
					 rst      => NOT RESET_N,
					 outclk_0 => clk_25,
					 locked	 => locked);
					 

   -- Clock Divider
   Divider : Clock_Divider
      port map (input_clock  => CLOCK_50,
                enable_pulse => enable_pulse);

   -- VGA
   VGA : VGA_Sync
      port map (clock               => CLOCK_50,
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

   -- Orbiting ball position
   Orbiting : Orbiting_Ball
      port map (clock          => CLOCK_50,
                vertical_sync  => vertical_sync,
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                radius         => conv_std_logic_vector(100, 7),
                left_click     => left_click,
                ball_x_out     => ball_x_out,
                ball_y_out     => ball_y_out);


   -- Mouse controller
   Mouse_Controller : Mouse
      port map (clock_25mhz         => clk_25,
                reset               => not RESET_N,
                mouse_data          => PS2_DAT,
                mouse_clk           => PS2_CLK,
                left_button         => left_click,
                right_button        => right_click,
                mouse_cursor_row    => mouse_row,
                mouse_cursor_column => mouse_column);

   -- Mouse cursor sprite
   Mouse_Sprite : Ball
      generic map (SIZE_CONST => 8)
		
			port map (pixel_column => pixel_column,
                   pixel_row    => pixel_row,
                   ball_x       => mouse_column,
                   ball_y       => mouse_row,
                   red          => red2,
                   green        => green2,
                   blue         => blue2);

   -- Background colour controller
   Background : Background_Colour
      port map (clock                          => CLOCK_50,
                vertical_sync                  => vertical_sync,
                dip_switch_0                   => SW(0),
                dip_switch_1                   => SW(1),
                dip_switch_2                   => SW(2),
                dip_switch_3                   => SW(3),
                push_button_0                  => KEY(0),
                push_button_1                  => KEY(1),
                push_button_2                  => KEY(2),
                push_button_3                  => KEY(3),
                red_out                        => red5,
                green_out                      => green5,
                blue_out                       => blue5,
                seven_segment_display_digit_0  => HEX0,
                seven_segment_display_digit_1  => HEX1,
                seven_segment_display_digit_2  => HEX2,
                seven_segment_display_digit_3  => HEX3,
                seven_segment_display_digit_5  => HEX5);

   -- Hello World small text
   Hello_World : Word_Display
      generic map (STRING_LENGTH => 11,
                   SCALE         => 1)
						 
			port map (clock          => CLOCK_50,
						 characters     => "001000" &  -- H = 8
                                     "000101" &  -- E = 5
                                     "001100" &  -- L = 12
												 "001100" &  -- L = 12
												 "001111" &  -- O = 15
                                     "100001" &  -- space = 33
                                     "010111" &  -- W = 23
                                     "001111" &  -- O = 15
                                     "010010" &  -- R = 18
                                     "001100" &  -- L = 12
                                     "000100",   -- D = 4
						 pixel_row      => pixel_row,
                   pixel_column   => pixel_column,
                   x_position     => conv_std_logic_vector(276, 10),
                   y_position     => conv_std_logic_vector(250, 10),
                   red_out        => red3,
                   green_out      => green3,
                   blue_out       => blue3);


   -- CHUD large text
   CHUD : Word_Display
      generic map (STRING_LENGTH => 4,
                   SCALE         => 2)
						 
			port map (clock          => CLOCK_50,
                   characters     => "000011" &  -- C = 3
                                     "001000" &  -- H = 8
                                     "010101" &  -- U = 21
                                     "000100",   -- D = 4
						 pixel_row      => pixel_row,
                   pixel_column   => pixel_column,
                   x_position     => conv_std_logic_vector(288, 10),
                   y_position     => conv_std_logic_vector(220, 10),
                   red_out        => red4,
                   green_out      => green4,
                   blue_out       => blue4);
						 
	Skull : Sprites_Display
		generic map (
        SPRITE_WIDTH  => 64,
        SPRITE_HEIGHT => 64,
        ADDR_BITS     => 12,
		  SCALE 			 => 8
		 )
		 port map (
			  clock 			=> CLOCK_50,
			  pixel_row 	=> pixel_row,
			  pixel_column => pixel_column,
			  sprite_x 		=> conv_std_logic_vector(100, 10), 
			  sprite_y 		=> conv_std_logic_vector(100, 10),      
			  red_out 		=> red1,
			  green_out 	=> green1,
			  blue_out 		=> blue1
		 );

   -- Graphics layer compositor
   Graphics : Graphics_Manager
      port map (text_large_red   => red4,
                text_large_green => green4,
                text_large_blue  => blue4,
                text_small_red   => red3,
                text_small_green => green3,
                text_small_blue  => blue3,
                background_red   => red5,
                background_green => green5,
                background_blue  => blue5,
                sprite_red       => red1,
                sprite_green     => green1,
                sprite_blue      => blue1,
                mouse_red        => red2,
                mouse_green      => green2,
                mouse_blue       => blue2,
                red_out          => red,
                green_out        => green,
                blue_out         => blue);

   -- VGA output
   VGA_R  <= red_out;
   VGA_G  <= green_out;
   VGA_B  <= blue_out;
   VGA_HS <= horizontal_sync;
	VGA_VS <= vertical_sync;
end architecture game_behaviour2;