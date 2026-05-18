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

   -- Background pipeline components (racing-game visuals)
   component Background_Generator is
      port (clock, vertical_sync          : in  std_logic;
            pixel_row, pixel_column       : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out  : out std_logic_vector(3 downto 0));
   end component Background_Generator;

   component Track_Generator is
      port (clock, vertical_sync          : in  std_logic;
            pixel_row, pixel_column       : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out  : out std_logic_vector(3 downto 0));
   end component Track_Generator;

   component Background_Manager is
      port (background_red, background_green, background_blue : in  std_logic_vector(3 downto 0);
            track_red,      track_green,      track_blue      : in  std_logic_vector(3 downto 0);
            red_out,        green_out,        blue_out        : out std_logic_vector(3 downto 0));
   end component Background_Manager;

   component Moving_Object is
      generic (REAL_HEIGHT : positive            := 60;
               REAL_WIDTH  : positive            := 80;
               LANE        : integer range 0 to 2 := 1);
      port (enable, clock, vertical_sync   : in  std_logic;
            pixel_column, pixel_row        : in  std_logic_vector(9 downto 0);
            speed                          : in  std_logic_vector(3 downto 0);
            red_out, green_out, blue_out   : out std_logic_vector(3 downto 0));
   end component Moving_Object;

   component Object_Manager is
      port (sprite_1_red, sprite_1_green, sprite_1_blue : in  std_logic_vector(3 downto 0);
            sprite_2_red, sprite_2_green, sprite_2_blue : in  std_logic_vector(3 downto 0);
            red_out,      green_out,      blue_out      : out std_logic_vector(3 downto 0));
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
            latched_mode                 : out std_logic_vector(1 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Start_Screen;

   component Sprites_Display is
      generic (SPRITE_WIDTH  : positive := 32;
               SPRITE_HEIGHT : positive := 32;
               ADDR_BITS     : positive := 12;
               SCALE         : positive := 4;
               MIF_FILE      : string   := "mif/jasper.mif");
      port (clock                        : in  std_logic;
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            sprite_x,  sprite_y          : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Sprites_Display;

   component Screen_Compositor is
      port (start_screen_active : in  std_logic;
            latched_mode        : in  std_logic_vector(1 downto 0);
            start_screen_red, start_screen_green, start_screen_blue : in std_logic_vector(3 downto 0);
            start_screen_sprite_red, start_screen_sprite_green, start_screen_sprite_blue : in std_logic_vector(3 downto 0);
            mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue : in std_logic_vector(3 downto 0);
            training_red, training_green, training_blue : in std_logic_vector(3 downto 0);
            racing_red,   racing_green,   racing_blue   : in std_logic_vector(3 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Screen_Compositor;
	
	component Player is
      generic (SCREEN_WIDTH        : positive := 640;
               SCREEN_HEIGHT       : positive := 480;
               SPRITE_SIZE         : positive := 32;
               SPRITE_SCALE        : positive := 4;
               WALK_FRAME_DURATION : positive := 10;
               JUMP_TOTAL_FRAMES   : positive := 120;
               JUMP_PEAK_HEIGHT    : positive := 60);
      port (clock, reset, vertical_sync             : in  std_logic;
            pixel_row, pixel_column                 : in  std_logic_vector(9 downto 0);
            mouse_left_click                        : in  std_logic;
            player_red, player_green, player_blue   : out std_logic_vector(3 downto 0);
            player_lane                             : out std_logic_vector(1 downto 0);
            player_state                            : out std_logic);
   end component Player;

   component Player_And_Objects_Manager is
      port (player_red,  player_green,  player_blue  : in  std_logic_vector(3 downto 0);
            objects_red, objects_green, objects_blue : in  std_logic_vector(3 downto 0);
            red_out,     green_out,     blue_out     : out std_logic_vector(3 downto 0));
   end component Player_And_Objects_Manager;

   -- ---------------------------------------------------------------------------
   -- Signals
   -- ---------------------------------------------------------------------------
   signal video_clock                    : std_logic;
   signal pll_locked                     : std_logic;
   signal vertical_sync, horizontal_sync : std_logic;
   signal video_on                       : std_logic;

   -- Training-mode graphics layer signals (orbiting ball + text + mouse demo)
   signal training_red, training_green, training_blue 				: std_logic_vector(3 downto 0);
   signal orbit_ball_red,  orbit_ball_green,  orbit_ball_blue  	: std_logic_vector(3 downto 0);
   signal mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue : std_logic_vector(3 downto 0);
   signal text_small_red,  text_small_green,  text_small_blue  	: std_logic_vector(3 downto 0);
   signal text_large_red,  text_large_green,  text_large_blue  	: std_logic_vector(3 downto 0);

   -- Racing-mode graphics layer signals (background + track + moving objects)
   signal racing_red, racing_green, racing_blue 														: std_logic_vector(3 downto 0);
   signal background_layer_red, background_layer_green, background_layer_blue 				: std_logic_vector(3 downto 0);
   signal track_layer_red,      track_layer_green,      track_layer_blue      				: std_logic_vector(3 downto 0);
   signal sprite_1_red,         sprite_1_green,         sprite_1_blue         				: std_logic_vector(3 downto 0);
   signal sprite_2_red,         sprite_2_green,         sprite_2_blue         				: std_logic_vector(3 downto 0);
   signal background_composite_red, background_composite_green, background_composite_blue : std_logic_vector(3 downto 0);
   signal sprite_composite_red,     sprite_composite_green,     sprite_composite_blue     : std_logic_vector(3 downto 0);

   -- Start screen output signals
   signal start_screen_red    		: std_logic_vector(3 downto 0);
   signal start_screen_green  		: std_logic_vector(3 downto 0);
   signal start_screen_blue   		: std_logic_vector(3 downto 0);
   signal start_screen_sprite_red   : std_logic_vector(3 downto 0);
   signal start_screen_sprite_green : std_logic_vector(3 downto 0);
   signal start_screen_sprite_blue  : std_logic_vector(3 downto 0);
   signal start_screen_active 		: std_logic;
   signal selected_mode       		: std_logic_vector(1 downto 0);
   signal latched_mode        		: std_logic_vector(1 downto 0);
   signal any_key_pressed     		: std_logic;

   -- Final composited pixel values feeding VGA_Sync
   signal red_final, green_final, blue_final : std_logic_vector(3 downto 0);
   signal red_out,   green_out,   blue_out   : std_logic_vector(3 downto 0);

   signal pixel_row, pixel_column : std_logic_vector(9 downto 0);
   signal ball_x_out, ball_y_out  : std_logic_vector(9 downto 0);

   -- Mouse signals
   signal left_click   : std_logic;
   signal right_click  : std_logic;
   signal mouse_row    : std_logic_vector(9 downto 0);
   signal mouse_column : std_logic_vector(9 downto 0);

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
	
	-- Player signals
   signal player_red, player_green, player_blue                            : std_logic_vector(3 downto 0);
   signal player_lane                                                      : std_logic_vector(1 downto 0);
   signal player_state                                                     : std_logic;
   signal combined_sprite_red, combined_sprite_green, combined_sprite_blue : std_logic_vector(3 downto 0);

begin

   -- ---------------------------------------------------------------------------
   -- Video PLL: produces a true 25 MHz pixel clock from 50 MHz input.
   -- ---------------------------------------------------------------------------
   Pixel_Clock_PLL : Video_PLL
      port map (refclk   => CLOCK_50,
                rst      => not RESET_N,
                outclk_0 => video_clock,
                locked   => pll_locked);

   -- ---------------------------------------------------------------------------
   -- "Any key" detection. KEY[3:0] are active-low pushbuttons.
   -- ---------------------------------------------------------------------------
   any_key_pressed <= not (KEY(3) and KEY(2) and KEY(1) and KEY(0));

   -- ---------------------------------------------------------------------------
   -- VGA sync (true 25 MHz pixel clock)
   -- ---------------------------------------------------------------------------
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

   -- ===========================================================================
   -- TRAINING MODE PIPELINE
   -- Orbiting ball + HELLO WORLD / OINK text + mouse cursor
   -- ===========================================================================

   Orbiting : Orbiting_Ball
      port map (clock         => video_clock,
                vertical_sync => vertical_sync,
                pixel_row     => pixel_row,
                pixel_column  => pixel_column,
                radius        => conv_std_logic_vector(100, 7),
                left_click    => left_click,
                ball_x_out    => ball_x_out,
                ball_y_out    => ball_y_out);

   Orbit_Ball_Sprite : Ball
      generic map (SIZE_CONST => 20)
      port map (pixel_column => pixel_column,
                pixel_row    => pixel_row,
                ball_x       => ball_x_out,
                ball_y       => ball_y_out,
                red          => orbit_ball_red,
                green        => orbit_ball_green,
                blue         => orbit_ball_blue);

   Mouse_Cursor_Sprite : Ball
      generic map (SIZE_CONST => 8)
      port map (pixel_column => pixel_column,
                pixel_row    => pixel_row,
                ball_x       => mouse_column,
                ball_y       => mouse_row,
                red          => mouse_cursor_red,
                green        => mouse_cursor_green,
                blue         => mouse_cursor_blue);

   Hello_World_Text : Word_Display
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
                red_out        => text_small_red,
                green_out      => text_small_green,
                blue_out       => text_small_blue);

   Oink_Text : Word_Display
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
                red_out        => text_large_red,
                green_out      => text_large_green,
                blue_out       => text_large_blue);

   Training_Graphics : Graphics_Manager
      port map (text_large_red   => text_large_red,
                text_large_green => text_large_green,
                text_large_blue  => text_large_blue,
                text_small_red   => text_small_red,
                text_small_green => text_small_green,
                text_small_blue  => text_small_blue,
                background_red   => "0000",
                background_green => "0000",
                background_blue  => "0000",
                sprite_red       => orbit_ball_red,
                sprite_green     => orbit_ball_green,
                sprite_blue      => orbit_ball_blue,
                mouse_red        => mouse_cursor_red,
                mouse_green      => mouse_cursor_green,
                mouse_blue       => mouse_cursor_blue,
                red_out          => training_red,
                green_out        => training_green,
                blue_out         => training_blue);

   -- ===========================================================================
   -- RACING MODE PIPELINE
   -- Sky/ground background + perspective track + two moving objects
   -- ===========================================================================

   Background_Layer : Background_Generator
      port map (clock         => video_clock,
                vertical_sync => vertical_sync,
                pixel_row     => pixel_row,
                pixel_column  => pixel_column,
                red_out       => background_layer_red,
                green_out     => background_layer_green,
                blue_out      => background_layer_blue);

   Track_Layer : Track_Generator
      port map (clock         => video_clock,
                vertical_sync => vertical_sync,
                pixel_row     => pixel_row,
                pixel_column  => pixel_column,
                red_out       => track_layer_red,
                green_out     => track_layer_green,
                blue_out      => track_layer_blue);

   Background_Compositor : Background_Manager
      port map (background_red   => background_layer_red,
                background_green => background_layer_green,
                background_blue  => background_layer_blue,
                track_red        => track_layer_red,
                track_green      => track_layer_green,
                track_blue       => track_layer_blue,
                red_out          => background_composite_red,
                green_out        => background_composite_green,
                blue_out         => background_composite_blue);

   Moving_Object_Lane_One : Moving_Object
      generic map (REAL_HEIGHT => 60,
                   REAL_WIDTH  => 80,
                   LANE        => 1)
      port map (enable        => not KEY(2),
                clock         => video_clock,
                vertical_sync => vertical_sync,
                pixel_column  => pixel_column,
                pixel_row     => pixel_row,
                speed         => conv_std_logic_vector(2, 4),
                red_out       => sprite_1_red,
                green_out     => sprite_1_green,
                blue_out      => sprite_1_blue);

   Moving_Object_Lane_Zero : Moving_Object
      generic map (REAL_HEIGHT => 120,
                   REAL_WIDTH  => 80,
                   LANE        => 0)
      port map (enable        => not KEY(3),
                clock         => video_clock,
                vertical_sync => vertical_sync,
                pixel_column  => pixel_column,
                pixel_row     => pixel_row,
                speed         => conv_std_logic_vector(2, 4),
                red_out       => sprite_2_red,
                green_out     => sprite_2_green,
                blue_out      => sprite_2_blue);

   Sprite_Compositor : Object_Manager
      port map (sprite_1_red   => sprite_1_red,
                sprite_1_green => sprite_1_green,
                sprite_1_blue  => sprite_1_blue,
                sprite_2_red   => sprite_2_red,
                sprite_2_green => sprite_2_green,
                sprite_2_blue  => sprite_2_blue,
                red_out        => sprite_composite_red,
                green_out      => sprite_composite_green,
                blue_out       => sprite_composite_blue);

   Racing_Graphics : Graphics_Manager
      port map (text_large_red   => "0000",
                text_large_green => "0000",
                text_large_blue  => "0000",
                text_small_red   => "0000",
                text_small_green => "0000",
                text_small_blue  => "0000",
                background_red   => background_composite_red,
                background_green => background_composite_green,
                background_blue  => background_composite_blue,
                sprite_red       => combined_sprite_red,
                sprite_green     => combined_sprite_green,
                sprite_blue      => combined_sprite_blue,
                mouse_red        => "0000",
                mouse_green      => "0000",
                mouse_blue       => "0000",
                red_out          => racing_red,
                green_out        => racing_green,
                blue_out         => racing_blue);

   -- ===========================================================================
   -- PERIPHERALS (stay on CLOCK_50 for protocol timing)
   -- ===========================================================================

   Mouse_Controller : Mouse
      port map (clock               => CLOCK_50,
                reset               => not RESET_N,
                mouse_data          => PS2_DAT,
                mouse_clock         => PS2_CLK,
                left_button         => left_click,
                right_button        => right_click,
                mouse_cursor_row    => mouse_row,
                mouse_cursor_column => mouse_column);

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

   -- ===========================================================================
   -- START SCREEN + BACKGROUND SPRITE + FINAL COMPOSITOR
   -- ===========================================================================

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
                latched_mode        => latched_mode,
                red_out             => start_screen_red,
                green_out           => start_screen_green,
                blue_out            => start_screen_blue);

   -- Knee logo sprite, drawn underneath the start-screen text.
   -- 32x32 base * SCALE 4 = 128x128 on screen.
   -- Centred on x=320: sprite_x = 320 - 64 = 256.
   -- Centred behind the title block (title centre y ~ 132): sprite_y = 132 - 64 = 68.
   -- So the sprite spans (256..384) x (68..196), sitting behind the title and credits.
   Start_Screen_Background_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => 32,
                   SPRITE_HEIGHT => 32,
                   ADDR_BITS     => 12,
                   SCALE         => 4,
                   MIF_FILE      => "mif/jasper.mif")
      port map (clock        => video_clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => conv_std_logic_vector(256, 10),
                sprite_y     => conv_std_logic_vector(68, 10),
                red_out      => start_screen_sprite_red,
                green_out    => start_screen_sprite_green,
                blue_out     => start_screen_sprite_blue);

   Final_Compositor_Inst : Screen_Compositor
      port map (start_screen_active      => start_screen_active,
                latched_mode             => latched_mode,
                start_screen_red         => start_screen_red,
                start_screen_green       => start_screen_green,
                start_screen_blue        => start_screen_blue,
                start_screen_sprite_red  => start_screen_sprite_red,
                start_screen_sprite_green => start_screen_sprite_green,
                start_screen_sprite_blue => start_screen_sprite_blue,
                mouse_cursor_red         => mouse_cursor_red,
                mouse_cursor_green       => mouse_cursor_green,
                mouse_cursor_blue        => mouse_cursor_blue,
                training_red             => training_red,
                training_green           => training_green,
                training_blue            => training_blue,
                racing_red               => racing_red,
                racing_green             => racing_green,
                racing_blue              => racing_blue,
                red_out                  => red_final,
                green_out                => green_final,
                blue_out                 => blue_final);
					 
	Player_Sprite_Renderer : Player
      generic map (SCREEN_WIDTH  => 640,
                   SCREEN_HEIGHT => 480,
                   SPRITE_SIZE   => 32,
                   SPRITE_SCALE  => 3)   -- change to 3 to use SCALE = 3
      port map (clock            => video_clock,
                reset            => not RESET_N,
                vertical_sync    => vertical_sync,
                pixel_row        => pixel_row,
                pixel_column     => pixel_column,
                mouse_left_click => left_click,
                player_red       => player_red,
                player_green     => player_green,
                player_blue      => player_blue,
                player_lane      => player_lane,
                player_state     => player_state);

   Player_Object_Compositor : Player_And_Objects_Manager
      port map (player_red    => player_red,
                player_green  => player_green,
                player_blue   => player_blue,
                objects_red   => sprite_composite_red,
                objects_green => sprite_composite_green,
                objects_blue  => sprite_composite_blue,
                red_out       => combined_sprite_red,
                green_out     => combined_sprite_green,
                blue_out      => combined_sprite_blue);

   -- ---------------------------------------------------------------------------
   -- LED assignments
   --   LEDR(3:0) = SD init state indicator
   --   LEDR(4)   = SD init done
   --   LEDR(5)   = PLL locked
   --   LEDR(6)   = start screen active
   --   LEDR(8:7) = latched game mode (00 none, 01 training, 10 single, 11 two)
   --   LEDR(9)   = SD read done
   -- ---------------------------------------------------------------------------
   LEDR(3 downto 0) <= init_state_indicator;
   LEDR(4)          <= init_done_signal;
   LEDR(5)          <= pll_locked;
   LEDR(6)          <= start_screen_active;
   LEDR(8 downto 7) <= latched_mode;
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