library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Top_Level is
   port (CLOCK_50            : in    std_logic;
         RESET_N             : in    std_logic;
         KEY                 : in    std_logic_vector(3 downto 0);
         SW                  : in    std_logic_vector(9 downto 0);
         VGA_HS, VGA_VS      : out   std_logic;
         VGA_R, VGA_G, VGA_B : out   std_logic_vector(3 downto 0);
         HEX0, HEX1, HEX2,
         HEX3, HEX4, HEX5    : out   std_logic_vector(6 downto 0);
         LEDR                : out   std_logic_vector(9 downto 0);
         PS2_DAT             : inout std_logic;
         PS2_CLK             : inout std_logic;

         -- SD card (DE0-CV onboard slot, native pin names)
         SD_CLK              : out   std_logic;
         SD_CMD              : out   std_logic;
         SD_DATA             : inout std_logic_vector(3 downto 0);

         GPIO_0              : out   std_logic_vector(35 downto 0));
end entity Top_Level;

architecture game_behaviour of Top_Level is

   -- ---------------------------------------------------------------------------
   -- Components
   -- ---------------------------------------------------------------------------
   -- Video_PLL is generated via Quartus IP Catalog.
   --   IP: "PLL Intel FPGA IP" (or "ALTERA_PLL" depending on Quartus version)
   --   Component name: Video_PLL
   --   refclk frequency: 50 MHz
   --   outclk_0 frequency: 25 MHz
   --   Reset: yes (rst)
   --   Locked output: yes
   component Video_PLL is
      port (refclk   : in  std_logic;
            rst      : in  std_logic;
            outclk_0 : out std_logic;
            locked   : out std_logic);
   end component Video_PLL;

   component Ball is
      generic (SIZE_CONST : positive := 8);
      port (pixel_column, pixel_row : in  std_logic_vector(9 downto 0);
            ball_x, ball_y          : in  std_logic_vector(9 downto 0);
            red, green, blue        : out std_logic_vector(3 downto 0));
   end component Ball;

   component Graphics_Manager is
      port (text_large_red,   text_large_green,   text_large_blue : in  std_logic_vector(3 downto 0);
            text_small_red,   text_small_green,   text_small_blue : in  std_logic_vector(3 downto 0);
            background_red,   background_green,   background_blue : in  std_logic_vector(3 downto 0);
            sprite_red,       sprite_green,       sprite_blue     : in  std_logic_vector(3 downto 0);
            mouse_red,        mouse_green,        mouse_blue      : in  std_logic_vector(3 downto 0);
            red_out,          green_out,          blue_out        : out std_logic_vector(3 downto 0));
   end component Graphics_Manager;

   component Mouse is
      port (clock, reset              : in    std_logic;
            left_button, right_button : out   std_logic;
            mouse_cursor_row          : out   std_logic_vector(9 downto 0);
            mouse_cursor_column       : out   std_logic_vector(9 downto 0);
            mouse_data                : inout std_logic;
            mouse_clock               : inout std_logic);
   end component Mouse;

   component Orbiting_Ball is
      port (clock, vertical_sync    : in  std_logic;
            pixel_row, pixel_column : in  std_logic_vector(9 downto 0);
            radius                  : in  std_logic_vector(6 downto 0);
            left_click              : in  std_logic;
            ball_x_out, ball_y_out  : out std_logic_vector(9 downto 0));
   end component Orbiting_Ball;

   component VGA_Sync is
      port (pixel_clock                            : in  std_logic;
            red, green, blue                       : in  std_logic_vector(3 downto 0);
            video_on                               : out std_logic;
            horizontal_sync_out, vertical_sync_out : out std_logic;
            red_out, green_out, blue_out           : out std_logic_vector(3 downto 0);
            pixel_row, pixel_column                : out std_logic_vector(9 downto 0));
   end component VGA_Sync;
	
	-- final graphics manager
	component Graphics_Manager is
		port (sprites_red,   	sprites_green,   		sprites_blue 	: in std_logic_vector(3 downto 0);
				background_red,	background_green,	 	background_blue: in std_logic_vector(3 downto 0);
				red_out, 			green_out,				blue_out 		: out std_logic_vector(3 downto 0));
	end component Graphics_Manager;
	
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
	
	-- sprites
	component Moving_Object is
		generic (REAL_HEIGHT : positive := 60;
					REAL_WIDTH : positive := 80;
					LANE : integer range 0 to 2 := 1);
		port (enable, clock, v_sync 		  	: in std_logic;
				pixel_column, pixel_row		  	: in  std_logic_vector(9 downto 0);
				speed								  	: in std_logic_vector(3 downto 0);
				red_out, green_out, blue_out 	: out std_logic_vector(3 downto 0));
	end component Moving_Object;
	
	component Object_Manager is
		port (sprite_1_red,   sprite_1_green,   sprite_1_blue 		: in  std_logic_vector(3 downto 0);
				sprite_2_red,   sprite_2_green,   sprite_2_blue 		: in  std_logic_vector(3 downto 0);
				red_out,          green_out,          blue_out        : out std_logic_vector(3 downto 0)); 
	end component Object_Manager;

   component Word_Display is
      generic (STRING_LENGTH : positive := 16;
               SCALE         : positive := 1);
      port (clock                        : in  std_logic;
            x_position, y_position       : in  std_logic_vector(9 downto 0);
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            characters                   : in  std_logic_vector((STRING_LENGTH * 6 - 1) downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Word_Display;

   component SD_Init is
      port (clock              : in  std_logic;
            reset              : in  std_logic;
            start_init         : in  std_logic;
            byte_address       : in  std_logic_vector(8 downto 0);
            spi_clock_out      : out std_logic;
            spi_mosi_out       : out std_logic;
            spi_miso_in        : in  std_logic;
            spi_chip_select_n  : out std_logic;
            init_done          : out std_logic;
            read_done          : out std_logic;
            init_failed        : out std_logic;
            state_indicator    : out std_logic_vector(3 downto 0);
            last_response_byte : out std_logic_vector(7 downto 0);
            read_byte          : out std_logic_vector(7 downto 0));
   end component SD_Init;

   component Hex_To_Seven_Segment is
      port (hex_value      : in  std_logic_vector(3 downto 0);
            seven_segments : out std_logic_vector(6 downto 0));
   end component Hex_To_Seven_Segment;

   component Audio_Test_Generator is
      generic (CLOCK_FREQUENCY : positive := 50_000_000;
               SAMPLE_RATE     : positive := 44_100);
      port (clock    : in  std_logic;
            reset    : in  std_logic;
            dac_data : out std_logic_vector(7 downto 0));
   end component Audio_Test_Generator;
	
	component Start_Screen is
      port (video_clock                  : in  std_logic;
            reset                        : in  std_logic;
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            mouse_row, mouse_column      : in  std_logic_vector(9 downto 0);
            mouse_left_click             : in  std_logic;
            any_key_pressed              : in  std_logic;
            start_screen_active          : out std_logic;
            selected_mode                : out std_logic_vector(1 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Start_Screen;

   -- ---------------------------------------------------------------------------
   -- Signals
   -- ---------------------------------------------------------------------------
   signal video_clock                    : std_logic;
   signal pll_locked                     : std_logic;
   signal vertical_sync, horizontal_sync : std_logic;
   signal video_on                       : std_logic;

   -- Game graphics layer signals (existing demo content)
   signal red_game, green_game, blue_game : std_logic_vector(3 downto 0);
   signal red1,     green1,     blue1     : std_logic_vector(3 downto 0);
   signal red2,     green2,     blue2     : std_logic_vector(3 downto 0);
   signal red3,     green3,     blue3     : std_logic_vector(3 downto 0);
   signal red4,     green4,     blue4     : std_logic_vector(3 downto 0);

   -- Start screen output signals
   signal start_screen_red    : std_logic_vector(3 downto 0);
   signal start_screen_green  : std_logic_vector(3 downto 0);
   signal start_screen_blue   : std_logic_vector(3 downto 0);
   signal start_screen_active : std_logic;
   signal selected_mode       : std_logic_vector(1 downto 0);
   signal any_key_pressed     : std_logic;

   -- Final composited pixel values feeding VGA_Sync
   signal red_final, green_final, blue_final : std_logic_vector(3 downto 0);
   signal red_out,   green_out,   blue_out   : std_logic_vector(3 downto 0);

   signal pixel_row, pixel_column : std_logic_vector(9 downto 0);
   signal ball_x_out, ball_y_out  : std_logic_vector(9 downto 0);

   -- SD card signals
   signal init_done_signal       : std_logic;
   signal init_failed_signal     : std_logic;
   signal init_state_indicator   : std_logic_vector(3 downto 0);
   signal last_response_byte_sig : std_logic_vector(7 downto 0);

   signal sd_serial_clock : std_logic;
   signal sd_command      : std_logic;
   signal sd_chip_select  : std_logic;
   signal sd_data_in      : std_logic;

   signal read_done_signal : std_logic;
   signal read_byte_signal : std_logic_vector(7 downto 0);

   signal audio_dac_data : std_logic_vector(7 downto 0);

begin

   -- ---------------------------------------------------------------------------
   -- Video PLL: produces a true 25 MHz pixel clock from 50 MHz input.
   -- Replaces the old Clock_Divider enable-pulse approach.
   -- ---------------------------------------------------------------------------
   Pixel_Clock_PLL : Video_PLL
      port map (refclk   => CLOCK_50,
                rst      => not RESET_N,
                outclk_0 => video_clock,
                locked   => pll_locked);

   -- ---------------------------------------------------------------------------
   -- "Any key" detection. KEY[3:0] are active-low pushbuttons, so any of them
   -- being held low means a key is pressed.
   -- Note: KEY(0) is shared with the SD card start_init trigger, so pressing it
   -- on the title screen will both advance the screen state and (re)trigger SD
   -- init. Wire your final "any key" source elsewhere later if you want them split.
   -- ---------------------------------------------------------------------------
   any_key_pressed <= not (KEY(3) and KEY(2) and KEY(1) and KEY(0));

   -- ---------------------------------------------------------------------------
   -- VGA sync (true 25 MHz pixel clock)
   -- ---------------------------------------------------------------------------
	-- colour
   signal bg_red, bg_green, bg_blue      : std_logic_vector(3 downto 0);
	signal t_red, t_green, t_blue      	  : std_logic_vector(3 downto 0);
	
	signal sprite_1_red, 
			 sprite_1_green,
			 sprite_1_blue 					  : std_logic_vector(3 downto 0);
			 
	signal sprite_2_red, 
			 sprite_2_green,
			 sprite_2_blue 					  : std_logic_vector(3 downto 0);
	
	signal layer_0_red,	
	       layer_0_green, 
			 layer_0_blue					  	  : std_logic_vector(3 downto 0);
			 
			 
	signal layer_1_red,	
	       layer_1_green, 
			 layer_1_blue					  	  : std_logic_vector(3 downto 0);
	
	signal red, green, blue   				  : std_logic_vector(3 downto 0);
   signal red_out, green_out, blue_out   : std_logic_vector(3 downto 0);
	
   signal pixel_row, pixel_column        : std_logic_vector(9 downto 0);

begin
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
					 red_out				=> layer_0_red,
					 green_out			=> layer_0_green,
					 blue_out			=> layer_0_blue);
	
	-- sprites
	Moving_obj1: Moving_Object
		generic map (REAL_HEIGHT 	=> 60,
						 REAL_WIDTH  	=> 80,
						 LANE 		 	=> 1)
		port map(enable 			=> NOT KEY(0),
					clock 			=> CLOCK_50, 
					v_sync			=> vertical_sync, 		  	
					pixel_column 	=> pixel_column, 
					pixel_row		=> pixel_row,	  	
					speed				=> conv_std_logic_vector(2, 4),
					red_out 			=> sprite_1_red,
					green_out 		=> sprite_1_green, 
					blue_out 		=> sprite_1_blue);
					
		Moving_obj2: Moving_Object
		generic map (REAL_HEIGHT 	=> 120,
						 REAL_WIDTH 	=> 80,	
						 LANE 			=> 0)
		port map(enable 			=> NOT KEY(1),
					clock 			=> CLOCK_50, 
					v_sync			=> vertical_sync, 		  	
					pixel_column 	=> pixel_column, 
					pixel_row		=> pixel_row,	  	
					speed				=> conv_std_logic_vector(2, 4),
					red_out 			=> sprite_2_red,
					green_out 		=> sprite_2_green, 
					blue_out 		=> sprite_2_blue);
	
	Sprites : Object_Manager
		port map(sprite_1_red 	=> sprite_1_red,
					sprite_1_green =>	sprite_1_green,
					sprite_1_blue 	=>	sprite_1_blue,
					sprite_2_red 	=> sprite_2_red,
					sprite_2_green =>	sprite_2_green,
					sprite_2_blue 	=>	sprite_2_blue,
					red_out			=> layer_1_red,
					green_out		=>	layer_1_green,
					blue_out			=> layer_1_blue);
	
	-- Final Manager
	Graphic_layering : Graphics_Manager
		port map(sprites_red 		=> layer_1_red,
					sprites_green		=> layer_1_green,
					sprites_blue		=> layer_1_blue,
					background_red		=> layer_0_red,
					background_green	=> layer_0_green,
					background_blue	=> layer_0_blue,
					red_out				=> red,
					green_out			=> green,
					blue_out				=> blue);
	
	-- VGA
   VGA : VGA_Sync
      port map (pixel_clock         => video_clock,
                red                 => red_final,
                green               => green_final,
                blue                => blue_final,
                red_out             => red_out,
                green_out           => green_out,
                blue_out            => blue_out,
                horizontal_sync_out => horizontal_sync,
                vertical_sync_out   => vertical_sync,
                video_on            => video_on,
                pixel_row           => pixel_row,
                pixel_column        => pixel_column);

   -- ---------------------------------------------------------------------------
   -- Orbiting ball (game graphics, runs in pixel clock domain)
   -- ---------------------------------------------------------------------------
   Orbiting : Orbiting_Ball
      port map (clock         => video_clock,
                vertical_sync => vertical_sync,
                pixel_row     => pixel_row,
                pixel_column  => pixel_column,
                radius        => conv_std_logic_vector(100, 7),
                left_click    => left_click,
                ball_x_out    => ball_x_out,
                ball_y_out    => ball_y_out);

   Sprite : Ball
      generic map (SIZE_CONST => 20)
      port map (pixel_column => pixel_column,
                pixel_row    => pixel_row,
                ball_x       => ball_x_out,
                ball_y       => ball_y_out,
                red          => red1,
                green        => green1,
                blue         => blue1);

   -- ---------------------------------------------------------------------------
   -- Mouse controller (stays on CLOCK_50 for PS/2 timing)
   -- ---------------------------------------------------------------------------
   Mouse_Controller : Mouse
      port map (clock               => CLOCK_50,
                reset               => not RESET_N,
                mouse_data          => PS2_DAT,
                mouse_clock         => PS2_CLK,
                left_button         => left_click,
                right_button        => right_click,
                mouse_cursor_row    => mouse_row,
                mouse_cursor_column => mouse_column);

   Mouse_Sprite : Ball
      generic map (SIZE_CONST => 8)
      port map (pixel_column => pixel_column,
                pixel_row    => pixel_row,
                ball_x       => mouse_column,
                ball_y       => mouse_row,
                red          => red2,
                green        => green2,
                blue         => blue2);

   -- ---------------------------------------------------------------------------
   -- Demo text: HELLO WORLD (small)
   -- ---------------------------------------------------------------------------
   Hello_World : Word_Display
      generic map (STRING_LENGTH => 11,
                   SCALE         => 1)
      port map (clock          => video_clock,
                characters     => "001000" &  -- H
                                  "000101" &  -- E
                                  "001100" &  -- L
                                  "001100" &  -- L
                                  "001111" &  -- O
                                  "100000" &  -- sp
                                  "010111" &  -- W
                                  "001111" &  -- O
                                  "010010" &  -- R
                                  "001100" &  -- L
                                  "000100",   -- D
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                x_position     => conv_std_logic_vector(276, 10),
                y_position     => conv_std_logic_vector(220, 10),
                red_out        => red3,
                green_out      => green3,
                blue_out       => blue3);

   -- ---------------------------------------------------------------------------
   -- Demo text: OINK (large)
   -- ---------------------------------------------------------------------------
   CHUD : Word_Display
      generic map (STRING_LENGTH => 4,
                   SCALE         => 2)
      port map (clock          => video_clock,
                characters     => "001111" &  -- O
                                  "001001" &  -- I
                                  "001110" &  -- N
                                  "001011",   -- K
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                x_position     => conv_std_logic_vector(288, 10),
                y_position     => conv_std_logic_vector(250, 10),
                red_out        => red4,
                green_out      => green4,
                blue_out       => blue4);

   -- ---------------------------------------------------------------------------
   -- Graphics compositor (game RGB)
   -- ---------------------------------------------------------------------------
   Graphics : Graphics_Manager
      port map (text_large_red   => red4,
                text_large_green => green4,
                text_large_blue  => blue4,
                text_small_red   => red3,
                text_small_green => green3,
                text_small_blue  => blue3,
                background_red   => "0000",
                background_green => "0000",
                background_blue  => "0000",
                sprite_red       => red1,
                sprite_green     => green1,
                sprite_blue      => blue1,
                mouse_red        => red2,
                mouse_green      => green2,
                mouse_blue       => blue2,
                red_out          => red_game,
                green_out        => green_game,
                blue_out         => blue_game);

   -- ---------------------------------------------------------------------------
   -- Final pixel mux:
   --   start_screen_active = '1' -> draw start screen, with mouse cursor on top
   --                                so the user can see what they're pointing at
   --   start_screen_active = '0' -> draw the game pipeline
   -- ---------------------------------------------------------------------------
	Final_Compositor : process(start_screen_active,
                              start_screen_red, start_screen_green, start_screen_blue,
                              red2,             green2,             blue2,
                              red_game,         green_game,         blue_game)
   begin
      if start_screen_active = '1' then
         if (red2 or green2 or blue2) /= "0000" then
            red_final   <= red2;
            green_final <= green2;
            blue_final  <= blue2;
         else
            red_final   <= start_screen_red;
            green_final <= start_screen_green;
            blue_final  <= start_screen_blue;
         end if;
      else
         red_final   <= red_game;
         green_final <= green_game;
         blue_final  <= blue_game;
      end if;
   end process Final_Compositor;

   -- ---------------------------------------------------------------------------
   -- SD card SPI initialiser (stays on CLOCK_50)
   -- ---------------------------------------------------------------------------
   SD_Initialiser : SD_Init
      port map (clock              => CLOCK_50,
                reset              => not RESET_N,
                start_init         => not KEY(0),
                byte_address       => SW(8 downto 0),
                spi_clock_out      => sd_serial_clock,
                spi_mosi_out       => sd_command,
                spi_miso_in        => sd_data_in,
                spi_chip_select_n  => sd_chip_select,
                init_done          => init_done_signal,
                read_done          => read_done_signal,
                init_failed        => init_failed_signal,
                state_indicator    => init_state_indicator,
                last_response_byte => last_response_byte_sig,
                read_byte          => read_byte_signal);

   Audio_Generator : Audio_Test_Generator
      port map (clock    => CLOCK_50,
                reset    => not RESET_N,
                dac_data => audio_dac_data);
					 
	Start_Screen_Inst : Start_Screen
      port map (video_clock         => video_clock,
                reset               => not RESET_N,
                pixel_row           => pixel_row,
                pixel_column        => pixel_column,
                mouse_row           => mouse_row,
                mouse_column        => mouse_column,
                mouse_left_click    => left_click,
                any_key_pressed     => any_key_pressed,
                start_screen_active => start_screen_active,
                selected_mode       => selected_mode,
                red_out             => start_screen_red,
                green_out           => start_screen_green,
                blue_out            => start_screen_blue);

   -- ---------------------------------------------------------------------------
   -- LED assignments
   --   LEDR(3:0) = SD init state indicator
   --   LEDR(4)   = SD init done
   --   LEDR(5)   = PLL locked
   --   LEDR(6)   = start screen active
   --   LEDR(8:7) = selected game mode (00 none, 01 training, 10 single, 11 two)
   --   LEDR(9)   = SD read done
   -- Note: init_failed is no longer mapped to a dedicated LED; HEX4/HEX5 still
   -- show the last raw SPI response byte if you need to debug an init failure.
   -- ---------------------------------------------------------------------------
   LEDR(3 downto 0) <= init_state_indicator;
   LEDR(4)          <= init_done_signal;
   LEDR(5)          <= pll_locked;
	LEDR(6)          <= start_screen_active;
   LEDR(8 downto 7) <= selected_mode;
   LEDR(9)          <= read_done_signal;

   -- Debug mirror to GPIO_0 header for oscilloscope probing
   GPIO_0(0) <= sd_serial_clock;   -- CLK
   GPIO_0(1) <= sd_chip_select;    -- CS (HIGH = deasserted, LOW = active)
   GPIO_0(2) <= sd_command;        -- MOSI
   GPIO_0(3) <= sd_data_in;        -- MISO

   -- DAC0800 data lines (B1 = MSB = audio_dac_data(7), B8 = LSB = audio_dac_data(0))
   GPIO_0(11) <= audio_dac_data(7);   -- B1 (MSB)
   GPIO_0(10) <= audio_dac_data(6);   -- B2
   GPIO_0(9)  <= audio_dac_data(5);   -- B3
   GPIO_0(8)  <= audio_dac_data(4);   -- B4
   GPIO_0(7)  <= audio_dac_data(3);   -- B5
   GPIO_0(6)  <= audio_dac_data(2);   -- B6
   GPIO_0(5)  <= audio_dac_data(1);   -- B7
   GPIO_0(4)  <= audio_dac_data(0);   -- B8 (LSB)

   GPIO_0(35 downto 12) <= (others => '0');

   -- HEX0/HEX1 show the byte at SW(8:0) of the read sector buffer
   Hex_Buffer_Low : Hex_To_Seven_Segment
      port map (hex_value      => read_byte_signal(3 downto 0),
                seven_segments => HEX0);

   Hex_Buffer_High : Hex_To_Seven_Segment
      port map (hex_value      => read_byte_signal(7 downto 4),
                seven_segments => HEX1);

   -- HEX4/HEX5 show the last raw SPI response byte (for debugging failures)
   Hex_Response_Low : Hex_To_Seven_Segment
      port map (hex_value      => last_response_byte_sig(3 downto 0),
                seven_segments => HEX4);

   Hex_Response_High : Hex_To_Seven_Segment
      port map (hex_value      => last_response_byte_sig(7 downto 4),
                seven_segments => HEX5);

   HEX2 <= "1111111";
   HEX3 <= "1111111";

   -- Physical SD pin connections
   SD_CLK     <= sd_serial_clock;
   SD_CMD     <= sd_command;
   SD_DATA(3) <= sd_chip_select;
   SD_DATA(2) <= '1';
   SD_DATA(1) <= '1';
   SD_DATA(0) <= 'Z';
   sd_data_in <= SD_DATA(0);

   -- ---------------------------------------------------------------------------
   -- VGA output
   -- ---------------------------------------------------------------------------
   VGA_R  <= red_out;
   VGA_G  <= green_out;
   VGA_B  <= blue_out;
   VGA_HS <= horizontal_sync;
   VGA_VS <= vertical_sync;

end architecture game_behaviour;