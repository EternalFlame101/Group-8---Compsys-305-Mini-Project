library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ======= DO NOT REMOVE ==================
-- fixes VGA issues
library altera;
use altera.altera_primitives_components.all;

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
         PS2_DAT2            : inout std_logic;
         PS2_CLK2            : inout std_logic;

         -- SD card (DE0-CV onboard slot, native pin names)
         SD_CLK              : out   std_logic;
         SD_CMD              : out   std_logic;
         SD_DATA             : inout std_logic_vector(3 downto 0);

         GPIO_0              : out   std_logic_vector(35 downto 0));
end entity Top_Level;

architecture game_behaviour of Top_Level is
	-- ================== DO NOT REMOVE =========================================
	-- fixes the VGA issues
	signal video_clock_prebuffered : std_logic;

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

   component Cursor is
      generic (SIZE_CONST : positive := 8);
      port (pixel_column, pixel_row : in  std_logic_vector(9 downto 0);
            cursor_x, cursor_y          : in  std_logic_vector(9 downto 0);
            red, green, blue        : out std_logic_vector(3 downto 0));
   end component Cursor;

   component Graphics_Manager is
      port (clock : in std_logic;
				text_large_red,   text_large_green,   text_large_blue : in  std_logic_vector(3 downto 0);
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

   component Keyboard is
      port (clock              : in    std_logic;
            reset              : in    std_logic;
            ps2_data           : inout std_logic;
            ps2_clock          : inout std_logic;
            left_key           : out   std_logic;
            right_key          : out   std_logic;
            jump_key           : out   std_logic;
            dive_key           : out   std_logic);
   end component Keyboard;

   component VGA_Sync is
      port (pixel_clock                            : in  std_logic;
            red, green, blue                       : in  std_logic_vector(3 downto 0);
            video_on                               : out std_logic;
            horizontal_sync_out, vertical_sync_out : out std_logic;
            red_out, green_out, blue_out           : out std_logic_vector(3 downto 0);
            pixel_row, pixel_column                : out std_logic_vector(9 downto 0));
   end component VGA_Sync;

   -- Background pipeline components (game visuals)
   component Background_Generator is
      port (clock, vertical_sync          : in  std_logic;
            pixel_row, pixel_column       : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out  : out std_logic_vector(3 downto 0));
   end component Background_Generator;

   component Track_Generator is
      port (clock, vertical_sync         : in  std_logic;
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            cat_view_position            : in  std_logic_vector(7 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Track_Generator;

   component Background_Manager is
      port (clock : in std_logic;
				background_red, background_green, background_blue : in  std_logic_vector(3 downto 0);
            track_red,      track_green,      track_blue      : in  std_logic_vector(3 downto 0);
            red_out,        green_out,        blue_out        : out std_logic_vector(3 downto 0));
   end component Background_Manager;

   component Moving_Object is
      generic (REAL_HEIGHT : positive             := 60;
               REAL_WIDTH  : positive             := 80;
               LANE        : integer range 0 to 2 := 1);
      port (enable, clock, vertical_sync : in  std_logic;
            reset						 	 	  : in  std_logic;
				obj_type							  : in  std_logic_vector(2 downto 0);
				arrived				 			  : out std_logic;
            pixel_column, pixel_row      : in  std_logic_vector(9 downto 0);
            speed_select                 : in  std_logic_vector(1 downto 0);
            cat_view_position            : in  std_logic_vector(7 downto 0);
            row_out                      : out std_logic_vector(9 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Moving_Object;

   component Object_Manager is
      generic (SPRITE_0_LANE : integer range 0 to 2 := 1;
               SPRITE_1_LANE : integer range 0 to 2 := 0;
               SPRITE_2_LANE : integer range 0 to 2 := 2);
      port (sprite_0_red, sprite_0_green, sprite_0_blue : in  std_logic_vector(3 downto 0);
            sprite_1_red, sprite_1_green, sprite_1_blue : in  std_logic_vector(3 downto 0);
            sprite_2_red, sprite_2_green, sprite_2_blue : in  std_logic_vector(3 downto 0);
            cat_lane                                    : in  std_logic_vector(1 downto 0);
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
            start_sector       : in  std_logic_vector(31 downto 0);
            track_length       : in  std_logic_vector(31 downto 0);
            byte_address       : in  std_logic_vector(9 downto 0);
            spi_clock_out      : out std_logic;
            spi_mosi_out       : out std_logic;
            spi_miso_in        : in  std_logic;
            spi_chip_select_n  : out std_logic;
            init_done          : out std_logic;
            audio_ready        : out std_logic;
            init_failed        : out std_logic;
            state_indicator    : out std_logic_vector(3 downto 0);
            last_response_byte : out std_logic_vector(7 downto 0);
            read_byte          : out std_logic_vector(7 downto 0));
   end component SD_Init;

   component Hex_To_Seven_Segment is
      port (hex_value      : in  std_logic_vector(3 downto 0);
            seven_segments : out std_logic_vector(6 downto 0));
   end component Hex_To_Seven_Segment;

	component Audio_Playback is
      generic (CLOCK_FREQUENCY : positive := 50_000_000;
               SAMPLE_RATE     : positive := 44_100);
      port (clock        : in  std_logic;
            reset        : in  std_logic;
            audio_ready  : in  std_logic;
            buffer_byte  : in  std_logic_vector(7 downto 0);
            byte_address : out std_logic_vector(9 downto 0);
            dac_high     : out std_logic_vector(7 downto 0);
            dac_low      : out std_logic_vector(7 downto 0));
   end component Audio_Playback;

   component Start_Screen is
      port (video_clock                  : in  std_logic;
            reset                        : in  std_logic;
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            mouse_row, mouse_column      : in  std_logic_vector(9 downto 0);
            mouse_left_click             : in  std_logic;
            mouse_right_click            : in  std_logic;
            any_key_pressed              : in  std_logic;
            any_key_held                 : in  std_logic;
            sw0, sw1                     : in  std_logic;
            key2_pressed                 : in  std_logic;
            start_screen_active          : out std_logic;
				start_screen_fsm				  : in  std_logic;
            selected_mode                : out std_logic;
            latched_mode                 : out std_logic;
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Start_Screen;

   component Sprites_Display is
      generic (SPRITE_WIDTH  : positive := 32;
               SPRITE_HEIGHT : positive := 32;
               ADDR_BITS     : positive := 12;
               SCALE         : positive := 4;
               MIF_FILE      : string   := "Assets/Memory_Initialization_Files/jasper.mif");
      port (clock                        : in  std_logic;
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            sprite_x,  sprite_y          : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Sprites_Display;

   component Screen_Compositor is
      port (clock					  : in  std_logic;
				start_screen_active : in  std_logic;
				paused				  : in  std_logic;
				end_screen_active	  : in  std_logic;
            latched_mode        : in  std_logic;
            start_screen_red, start_screen_green, start_screen_blue : in std_logic_vector(3 downto 0);
				pause_text_red, pause_text_green, pause_text_blue : in std_logic_vector(3 downto 0);
            start_screen_sprite_red, start_screen_sprite_green, start_screen_sprite_blue : in std_logic_vector(3 downto 0);
            mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue : in std_logic_vector(3 downto 0);
            HUD_red, HUD_green, HUD_blue : in std_logic_vector(3 downto 0);
            training_red, training_green, training_blue : in std_logic_vector(3 downto 0);
            end_screen_red,     end_screen_green,     end_screen_blue  : in std_logic_vector(3 downto 0);
            game_red,     game_green,     game_blue     : in std_logic_vector(3 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Screen_Compositor;
	
	component Spawn_Control is
		port(clock         : in  std_logic;
			  reset         : in  std_logic;
			  vertical_sync : in  std_logic;
			  arrived_0     : in  std_logic;
			  arrived_1     : in  std_logic;
			  arrived_2     : in  std_logic;
			  lane_0_type   : out std_logic_vector(2 downto 0);
			  lane_1_type   : out std_logic_vector(2 downto 0);
			  lane_2_type   : out std_logic_vector(2 downto 0);
			  debug_vsync_pulse : out std_logic;
			  debug_lfsr        : out std_logic_vector(7 downto 0));
	end component Spawn_Control;

   component Player is
      generic (SCREEN_WIDTH           : positive := 640;
               SCREEN_HEIGHT          : positive := 480;
               SPRITE_SIZE            : positive := 64;
               SPRITE_SCALE           : positive := 2;
               WALK_FRAME_DURATION    : positive := 8;
               JUMP_TOTAL_FRAMES      : positive := 64;
               JUMP_PEAK_HEIGHT       : positive := 60;
               LANE_TRANSITION_FRAMES : positive := 64);
      port (clock, reset, enable, vertical_sync     : in  std_logic;
            pixel_row, pixel_column                 : in  std_logic_vector(9 downto 0);
            shift_left_input                        : in  std_logic;
            shift_right_input                       : in  std_logic;
            jump_input                              : in  std_logic;
            dive_input                              : in  std_logic;
            player_red, player_green, player_blue   : out std_logic_vector(3 downto 0);
            player_lane                             : out std_logic_vector(1 downto 0);
            player_state                            : out std_logic;
            player_dive                             : out std_logic;
            cat_view_position                       : out std_logic_vector(7 downto 0));
   end component Player;

   component Player_And_Objects_Manager is
      port (clock	: in std_logic;
				player_red,  player_green,  player_blue  : in  std_logic_vector(3 downto 0);
            objects_red, objects_green, objects_blue : in  std_logic_vector(3 downto 0);
            red_out,     green_out,     blue_out     : out std_logic_vector(3 downto 0));
   end component Player_And_Objects_Manager;
	
	component End_Screen is
		port (video_clock                  : in  std_logic;
				reset                        : in  std_logic;
				pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
				mouse_row, mouse_column      : in  std_logic_vector(9 downto 0);
				any_key_pressed              : in  std_logic;
				end_screen_outcome           : in  std_logic;
				end_screen                   : out std_logic;
				end_screen_active				  : in  std_logic;
				red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
	end component End_Screen;
	
	component Game_Master is
		port(clock            	: in  std_logic;
			  reset					: in  std_logic;
			  pause_input			: in 	std_logic;
			  god_mode			   : in	std_logic;
			  lane_0_obj_type   	: in  std_logic_vector(2 downto 0);
			  lane_1_obj_type   	: in  std_logic_vector(2 downto 0);
			  lane_2_obj_type   	: in  std_logic_vector(2 downto 0);
			  lane_0_obj_dist  	: in  std_logic_vector(9 downto 0);
			  lane_1_obj_dist  	: in  std_logic_vector(9 downto 0);
			  lane_2_obj_dist  	: in  std_logic_vector(9 downto 0);
			  lanes_arrived	   : in  std_logic;
			  player_lane			: in	std_logic_vector(1 downto 0);
			  player_state			: in 	std_logic;
			  player_dive			: in	std_logic;
			  startscreen_enable : in  std_logic; -- 0 = off, 1 = on, startscreen on/off
			  startscreen_fsm		: out std_logic;
			  mode_selected		: in  std_logic; -- 0 = training, 1 = normal/single player
			  game_enable		 	: out std_logic; -- 0 = pause, 1 = playing, game pause
			  endscreen_enable	: in  std_logic; -- 0 = off, 1 = on, win/lose screen
			  endscreen_fsm		: out std_logic;
			  endscreen_outcome  : out std_logic; -- 0 = lose, 1 = win
			  pause_fsm				: out std_logic;
			  speed_select     	: out std_logic_vector(1 downto 0); -- 00=freeze,01=slow,10=medium,11=fast
			  win_999            : in  std_logic; -- '1' = win condition is 999 for both modes
			  score            	: out std_logic_vector(9 downto 0);
			  lives					: out std_logic_vector(1 downto 0));
	end component Game_Master;
	
	component Game_Timer is
		generic (CLOCK_HZ : positive := 50_000_000);
		port (clock      : in  std_logic;
				reset      : in  std_logic;   -- synchronous reset, returns to 00:00
				enable     : in  std_logic;   -- pause/resume the timer
				min_tens   : out std_logic_vector(3 downto 0);
				min_ones   : out std_logic_vector(3 downto 0);
				sec_tens   : out std_logic_vector(3 downto 0);
				sec_ones   : out std_logic_vector(3 downto 0));
	end component Game_Timer;

	component HUD_Overlay is
		port (video_clock                   : in  std_logic;
				reset                         : in  std_logic;
				pixel_row, pixel_column       : in  std_logic_vector(9 downto 0);
				score                         : in  std_logic_vector(9 downto 0);
				HUD_enable                    : in  std_logic;
				HUD_active                    : out std_logic;
				health_digit 						: in std_logic_vector(1 downto 0);	-- raw hit counter from Game_Master
				game_mode    						: in std_logic;                     -- '0'=training(max 3), '1'=normal(max 1)
				min_tens, min_ones            : in  std_logic_vector(3 downto 0);
				sec_tens, sec_ones            : in  std_logic_vector(3 downto 0);
				score_h, score_t, score_o     : out std_logic_vector(3 downto 0);
				red_out, green_out, blue_out  : out std_logic_vector(3 downto 0));
	end component HUD_Overlay;

   -- ---------------------------------------------------------------------------
   -- Signals
   -- ---------------------------------------------------------------------------
   signal video_clock                    : std_logic;
   signal pll_locked                     : std_logic;
   signal vertical_sync, horizontal_sync : std_logic;
   signal video_on                       : std_logic;

   -- Graphics layer signals (background + track + moving objects)
   signal game_red, game_green, game_blue                                            	 	 : std_logic_vector(3 downto 0);
   signal background_layer_red, background_layer_green, background_layer_blue              : std_logic_vector(3 downto 0);
   signal track_layer_red,      track_layer_green,      track_layer_blue                   : std_logic_vector(3 downto 0);
   signal sprite_0_row,         sprite_1_row,           sprite_2_row                       : std_logic_vector(9 downto 0);
   signal sprite_0_red,         sprite_0_green,         sprite_0_blue                      : std_logic_vector(3 downto 0);
   signal sprite_1_red,         sprite_1_green,         sprite_1_blue                      : std_logic_vector(3 downto 0);
   signal sprite_2_red,         sprite_2_green,         sprite_2_blue                      : std_logic_vector(3 downto 0);
   signal background_composite_red, background_composite_green, background_composite_blue  : std_logic_vector(3 downto 0);
   signal sprite_composite_red,     sprite_composite_green,     sprite_composite_blue      : std_logic_vector(3 downto 0);

   -- Start screen output signals
   signal start_screen_red           : std_logic_vector(3 downto 0);
   signal start_screen_green         : std_logic_vector(3 downto 0);
   signal start_screen_blue          : std_logic_vector(3 downto 0);
   signal start_screen_sprite_red    : std_logic_vector(3 downto 0);
   signal start_screen_sprite_green  : std_logic_vector(3 downto 0);
   signal start_screen_sprite_blue   : std_logic_vector(3 downto 0);
   signal start_screen_active        : std_logic;
   signal selected_mode              : std_logic;
   signal latched_mode               : std_logic;
   signal any_key_pressed            : std_logic;
	signal any_key_pressed_prev		 : std_logic;
	signal any_key_pressed_rising		 : std_logic;
   signal keys_held                  : std_logic;
	
	signal startup_reset_counter : std_logic_vector(23 downto 0) := (others => '0');
   signal startup_reset         : std_logic;
   signal combined_reset        : std_logic;

   -- Final composited pixel values feeding VGA_Sync
   signal red_final, green_final, blue_final : std_logic_vector(3 downto 0);
   signal red_out,   green_out,   blue_out   : std_logic_vector(3 downto 0);

   signal pixel_row, pixel_column 		: std_logic_vector(9 downto 0);
   signal cursor_x_out, cursor_y_out 	: std_logic_vector(9 downto 0);

   -- Mouse signals (single mouse, now on PS/2 port 2)
   signal left_click   			: std_logic;
   signal right_click  			: std_logic;
   signal mouse_row    			: std_logic_vector(9 downto 0);
   signal mouse_column 			: std_logic_vector(9 downto 0);
   signal mouse_cursor_red   	: std_logic_vector(3 downto 0);
   signal mouse_cursor_green 	: std_logic_vector(3 downto 0);
   signal mouse_cursor_blue  	: std_logic_vector(3 downto 0);

   -- Keyboard signals (on PS/2 port 1).
   --   keyboard_left_key, keyboard_right_key: arrow keys for lane shifts
   --   keyboard_jump_key: spacebar OR up arrow (combined inside Keyboard.vhd)
   --   keyboard_dive_key: down arrow
   signal keyboard_left_key   : std_logic;
   signal keyboard_right_key  : std_logic;
   signal keyboard_jump_key   : std_logic;
   signal keyboard_dive_key   : std_logic;

   -- Combined player input signals.
   --   player_shift_left_input:  KEY(1)            OR keyboard left arrow
   --   player_shift_right_input: KEY(0)            OR keyboard right arrow
   --   player_jump_input:        mouse left click  OR keyboard space/up arrow
   --   player_dive_input:        mouse right click OR keyboard down arrow
   signal player_shift_left_input  : std_logic;
   signal player_shift_right_input : std_logic;
   signal player_jump_input        : std_logic;
   signal player_dive_input        : std_logic;

   -- Raw (un-gated) ORs and per-input gate latches. The gate is held closed
   -- while the start screen is active and until the source has been seen
   -- released at least once after the start screen closes. See Input_Gate
   -- process below for details.
   signal player_shift_left_raw    : std_logic;
   signal player_shift_right_raw   : std_logic;
   signal player_jump_raw          : std_logic;
   signal player_dive_raw          : std_logic;
   signal shift_left_gate_closed   : std_logic := '1';
   signal shift_right_gate_closed  : std_logic := '1';
   signal jump_gate_closed         : std_logic := '1';
   signal dive_gate_closed         : std_logic := '1';

   -- SD card signals
   signal init_done_signal       : std_logic;
   signal init_failed_signal     : std_logic;
   signal init_state_indicator   : std_logic_vector(3 downto 0);
   signal last_response_byte_sig : std_logic_vector(7 downto 0);

   signal sd_serial_clock 	: std_logic;
   signal sd_command      	: std_logic;
   signal sd_chip_select  	: std_logic;
   signal sd_data_in      	: std_logic;

   signal audio_dac_high 		: std_logic_vector(7 downto 0);   -- high byte -> new DAC (GPIO_0[19..12])
   signal audio_dac_low  		: std_logic_vector(7 downto 0);   -- low byte  -> old DAC (GPIO_0[11..4])
   signal dac_high_out        : std_logic_vector(7 downto 0);   -- muted-gated DAC high to GPIO
   signal dac_low_out         : std_logic_vector(7 downto 0);   -- muted-gated DAC low to GPIO
	signal audio_ready_signal 	: std_logic;
   signal audio_gated_ready   : std_logic;
   signal audio_sd_reset      : std_logic;
   signal sd_buffer_byte     	: std_logic_vector(7 downto 0);
   signal audio_byte_address 	: std_logic_vector(9 downto 0);
   signal sd_start_sector     : std_logic_vector(31 downto 0);
   signal sd_track_length     : std_logic_vector(31 downto 0);
   signal track_sel_prev      : std_logic_vector(2 downto 0) := "000";
   signal track_changed       : std_logic;
   signal endscreen_50_s1     : std_logic := '0';
   signal endscreen_50_s2     : std_logic := '0';
   signal endscreen_50_prev   : std_logic := '0';
   signal endscreen_50_rise   : std_logic;
	
	-- Spawn control signals 
	signal lane_0_type : std_logic_vector(2 downto 0);
	signal lane_1_type : std_logic_vector(2 downto 0);
	signal lane_2_type : std_logic_vector(2 downto 0);
	
	
	signal arrived_0, arrived_1, arrived_2 : std_logic;
	
	-- Testing
	signal debug_vsync_pulse : std_logic;
	signal debug_lfsr        : std_logic_vector(7 downto 0);
	signal arrived_sticky : std_logic := '0';

   -- Player signals
   signal player_red, player_green, player_blue                            : std_logic_vector(3 downto 0);
   signal player_lane                                                      : std_logic_vector(1 downto 0);
   signal player_state                                                     : std_logic;
   signal player_dive                                                      : std_logic;
   signal cat_view_position                                                : std_logic_vector(7 downto 0);
   signal combined_sprite_red, combined_sprite_green, combined_sprite_blue : std_logic_vector(3 downto 0);
	
	-- end screen colours
	signal end_screen_red	: std_logic_vector(3 downto 0);
	signal end_screen_green	: std_logic_vector(3 downto 0);
	signal end_screen_blue	: std_logic_vector(3 downto 0);
	
	-- paused
	signal pause_red   : std_logic_vector(3 downto 0);
	signal pause_green : std_logic_vector(3 downto 0);
	signal pause_blue  : std_logic_vector(3 downto 0);
	
	-- fsm output signals
	signal lane_0_enable : std_logic;
	signal lane_1_enable : std_logic;
	signal lane_2_enable	: std_logic;
	
	signal game_enable		: std_logic;
	signal endscreen_active	: std_logic;
	signal endscreen_outcome: std_logic;
	
	signal speed_select : std_logic_vector(1 downto 0);
	signal endscreen_fsm		: std_logic;
	signal startscreen_fsm	: std_logic;
	signal pause_fsm			: std_logic;
	
	signal startscreen_fsm_prev : std_logic := '0';
	signal endscreen_fsm_prev   : std_logic := '0';
	signal startscreen_fsm_rise : std_logic;
	signal endscreen_fsm_rise   : std_logic;
	
	-- HUD
	signal HUD_red, HUD_green, HUD_blue : std_logic_vector(3 downto 0);
	signal HUD_active                   : std_logic;
	signal score_hud                    : std_logic_vector(9 downto 0) := (others => '0');
	signal wave_scored                  : std_logic;
	signal lives								: std_logic_vector(1 downto 0);
	signal hud_min_tens 						: std_logic_vector(3 downto 0);
	signal hud_min_ones 						: std_logic_vector(3 downto 0);
	signal hud_sec_tens 						: std_logic_vector(3 downto 0);
	signal hud_sec_ones 						: std_logic_vector(3 downto 0);	
	signal score_h, score_t, score_o  	: std_logic_vector(3 downto 0);
	
begin
	-- ==================== DO NOT REMOVE ================================
	-- buffers video clock and fixes all issues to do with vga
	-- original issue is that clock fanouts was around 1000
	-- additional logic pushes too much and breaks it
	video_clock_buf : GLOBAL
		port map (
		  a_in  => video_clock_prebuffered,
		  a_out => video_clock
		);

   -- ---------------------------------------------------------------------------
   -- Startup reset: holds the PLL in reset for ~335 ms after power-on so it
   -- locks cleanly before any game logic starts.  RESET_N is intentionally NOT
   -- wired here: stopping the pixel clock mid-game prevents synchronous resets
   -- from processing, which is the root cause of the board-reset not working.
   -- All game logic still uses (not RESET_N) directly for its own resets.
   -- ---------------------------------------------------------------------------
   Startup_Reset_Process : process(CLOCK_50)
   begin
      if rising_edge(CLOCK_50) then
         if startup_reset_counter /= x"FFFFFF" then
            startup_reset_counter <= startup_reset_counter + 1;
            startup_reset         <= '1';
         else
            startup_reset <= '0';
         end if;
      end if;
   end process Startup_Reset_Process;

   -- ---------------------------------------------------------------------------
   -- Video PLL: produces a true 25 MHz pixel clock from 50 MHz input.
   -- ---------------------------------------------------------------------------
   Pixel_Clock_PLL : Video_PLL
      port map (refclk   => CLOCK_50,
                rst      => startup_reset,
                outclk_0 => video_clock_prebuffered,
                locked   => pll_locked);

   -- ---------------------------------------------------------------------------
   -- "Any key" detection. KEY[3:0] are active-low pushbuttons.
   -- ---------------------------------------------------------------------------
	-- futher rising edge press detection, so that it cannot be held down
	Rising_edge_key_press : process(video_clock)
	begin
		if rising_edge(video_clock) then
			if (not(RESET_N) = '1') then
				any_key_pressed_prev <= '0';
			else
				any_key_pressed_prev <= any_key_pressed;
				
				-- rising edge only
				if (any_key_pressed = '1' and any_key_pressed_prev = '0') then
					any_key_pressed_rising <= '1';
				else 
					any_key_pressed_rising <= '0';
				end if;
			end if;
		end if;
	end process Rising_edge_key_press;
	
	any_key_pressed <= (not KEY(0)) or (not KEY(1)) or (not KEY(2)) or (not KEY(3))
                       or left_click or right_click
							  or keyboard_left_key or keyboard_right_key or keyboard_jump_key or keyboard_dive_key;
   keys_held <= (not KEY(0)) or (not KEY(1)) or (not KEY(2)) or (not KEY(3));
									  

   -- ---------------------------------------------------------------------------
   -- Combined player input signals. The various sources work in parallel as
   -- alternative controls: holding any source high will register as the input
   -- being active. Player.vhd internally edge-detects all four so holding a
   -- key/button results in exactly one lane shift / jump / dive, not a
   -- continuous stream.
   --   Lane shifts: KEY(1)/KEY(0) on the FPGA board OR arrow keys on keyboard.
   --     KEY pins are active-low pushbuttons (pressed = '0'), so we invert.
   --   Jump:        mouse left click  OR keyboard spacebar/up arrow.
   --   Dive:        mouse right click OR keyboard down arrow.
   --
   -- The raw_* signals are the unfiltered ORs. The gated player_*_input
   -- signals further suppress them while the start screen is active, and
   -- until each source has been seen released at least once after the start
   -- screen closes. This prevents the click/keypress that picked the game
   -- mode from carrying over as a jump (or KEY-still-held inputs from
   -- causing an immediate lane shift) the instant gameplay begins.
   -- ---------------------------------------------------------------------------
   player_shift_left_raw  <= (not KEY(1)) or keyboard_left_key;
   player_shift_right_raw <= (not KEY(0)) or keyboard_right_key;
   player_jump_raw        <= left_click   or keyboard_jump_key;
   player_dive_raw        <= right_click  or keyboard_dive_key or (not KEY(2));

   -- Per-input "must be released once after start screen closes" latch.
   -- While start_screen_active = '1' the latch is forced to '1' (gate closed).
   -- After it falls, the latch clears only on a clock where the corresponding
   -- raw input is low -- i.e. the player has let go of whatever they were
   -- holding. From then on the gate is open until reset / next start screen.
   Input_Gate : process(video_clock)
   begin
      if rising_edge(video_clock) then
         if (RESET_N = '0') or (start_screen_active = '1') then
            shift_left_gate_closed  <= '1';
            shift_right_gate_closed <= '1';
            jump_gate_closed        <= '1';
            dive_gate_closed        <= '1';
         else
            if player_shift_left_raw  = '0' then shift_left_gate_closed  <= '0'; end if;
            if player_shift_right_raw = '0' then shift_right_gate_closed <= '0'; end if;
            if player_jump_raw        = '0' then jump_gate_closed        <= '0'; end if;
            if player_dive_raw        = '0' then dive_gate_closed        <= '0'; end if;
         end if;
      end if;
   end process Input_Gate;
	
   player_shift_left_input  <= player_shift_left_raw  and (not shift_left_gate_closed);
   player_shift_right_input <= player_shift_right_raw and (not shift_right_gate_closed);
   player_jump_input        <= player_jump_raw        and (not jump_gate_closed);
   player_dive_input        <= player_dive_raw        and (not dive_gate_closed);

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

   Mouse_Cursor_Sprite : Cursor
      generic map (SIZE_CONST => 8)
      port map (pixel_column => pixel_column,
                pixel_row    => pixel_row,
                cursor_x     => mouse_column,
                cursor_y     => mouse_row,
                red          => mouse_cursor_red,
                green        => mouse_cursor_green,
                blue         => mouse_cursor_blue);

   -- ===========================================================================
   -- GAME PIPELINE
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
      port map (clock             => video_clock,
                vertical_sync     => vertical_sync,
                pixel_row         => pixel_row,
                pixel_column      => pixel_column,
                cat_view_position => cat_view_position,
                red_out           => track_layer_red,
                green_out         => track_layer_green,
                blue_out          => track_layer_blue);

   Background_Compositor : Background_Manager
      port map (clock 				=> video_clock, 
					 background_red   => background_layer_red,
                background_green => background_layer_green,
                background_blue  => background_layer_blue,
                track_red        => track_layer_red,
                track_green      => track_layer_green,
                track_blue       => track_layer_blue,
                red_out          => background_composite_red,
                green_out        => background_composite_green,
                blue_out         => background_composite_blue);
					 
	-- =============================================================================
	-- registering stuff to make it run
	-- =============================================================================
	process(video_clock)
	begin
		 if rising_edge(video_clock) then
			  lane_0_enable <= (lane_0_type(2) or lane_0_type(1) or lane_0_type(0)) and game_enable;
			  lane_1_enable <= (lane_1_type(2) or lane_1_type(1) or lane_1_type(0)) and game_enable;
			  lane_2_enable <= (lane_2_type(2) or lane_2_type(1) or lane_2_type(0)) and game_enable;
		 end if;
	end process;
	
	Moving_Object_Lane_Two : Moving_Object
      generic map (REAL_HEIGHT => 60,
                   REAL_WIDTH  => 80,
                   LANE        => 2)
      port map (enable            => (lane_2_type(2) or lane_2_type(1) or lane_2_type(0)) and (game_enable),
                clock             => video_clock,
                vertical_sync     => vertical_sync,
                reset             => (not RESET_N) or (startscreen_fsm),
                obj_type          => lane_2_type,
                arrived           => arrived_2,
                pixel_column      => pixel_column,
                pixel_row         => pixel_row,
                speed_select      => speed_select,
                cat_view_position => cat_view_position,
                row_out           => sprite_2_row,
                red_out           => sprite_2_red,
                green_out         => sprite_2_green,
                blue_out          => sprite_2_blue);

   Moving_Object_Lane_One : Moving_Object
      generic map (REAL_HEIGHT => 60,
                   REAL_WIDTH  => 70,
                   LANE        => 1)
      port map (enable            => (lane_1_type(2) or lane_1_type(1) or lane_1_type(0)) and (game_enable),
                clock             => video_clock,
                vertical_sync     => vertical_sync,
                reset 			    => (not RESET_N) or (startscreen_fsm),
					 obj_type 		    => lane_1_type,
					 arrived			    => arrived_1,
                pixel_column      => pixel_column,
                pixel_row         => pixel_row,
                speed_select      => speed_select,
                cat_view_position => cat_view_position,
                row_out           => sprite_1_row,
                red_out           => sprite_1_red,
                green_out         => sprite_1_green,
                blue_out          => sprite_1_blue);

   Moving_Object_Lane_Zero : Moving_Object
      generic map (REAL_HEIGHT => 120,
                   REAL_WIDTH  => 70,
                   LANE        => 0)
      port map (enable            => (lane_0_type(2) or lane_0_type(1) or lane_0_type(0)) and (game_enable),
                clock             => video_clock,
                vertical_sync     => vertical_sync,
                reset             => (not RESET_N) or (startscreen_fsm),
                obj_type          => lane_0_type,
                arrived           => arrived_0,
                pixel_column      => pixel_column,
                pixel_row         => pixel_row,
                speed_select      => speed_select,
                cat_view_position => cat_view_position,
                row_out           => sprite_0_row,
                red_out           => sprite_0_red,
                green_out         => sprite_0_green,
                blue_out          => sprite_0_blue);

   Sprite_Compositor : Object_Manager
      generic map (SPRITE_0_LANE => 0,
                   SPRITE_1_LANE => 1,
                   SPRITE_2_LANE => 2)
      port map (sprite_0_red   => sprite_0_red,
                sprite_0_green => sprite_0_green,
                sprite_0_blue  => sprite_0_blue,
                sprite_1_red   => sprite_1_red,
                sprite_1_green => sprite_1_green,
                sprite_1_blue  => sprite_1_blue,
                sprite_2_red   => sprite_2_red,
                sprite_2_green => sprite_2_green,
                sprite_2_blue  => sprite_2_blue,
                cat_lane       => player_lane,
                red_out        => sprite_composite_red,
                green_out      => sprite_composite_green,
                blue_out       => sprite_composite_blue);

   Game_Graphics : Graphics_Manager
      port map (clock				=> video_clock,
					 text_large_red   => "0000",
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
                red_out          => game_red,
                green_out        => game_green,
                blue_out         => game_blue);

   -- ===========================================================================
   -- PERIPHERALS (stay on CLOCK_50 for protocol timing)
   -- ===========================================================================

   -- Keyboard now occupies the primary PS/2 port (PS2_DAT / PS2_CLK).
   Keyboard_Controller : Keyboard
      port map (clock     => CLOCK_50,
                reset     => not RESET_N,
                ps2_data  => PS2_DAT,
                ps2_clock => PS2_CLK,
                left_key  => keyboard_left_key,
                right_key => keyboard_right_key,
                jump_key  => keyboard_jump_key,
                dive_key  => keyboard_dive_key);

   -- Mouse moved to the secondary PS/2 port (PS2_DAT2 / PS2_CLK2).
   Mouse_Controller : Mouse
      port map (clock               => CLOCK_50,
                reset               => not RESET_N,
                mouse_data          => PS2_DAT2,
                mouse_clock         => PS2_CLK2,
                left_button         => left_click,
                right_button        => right_click,
                mouse_cursor_row    => mouse_row,
                mouse_cursor_column => mouse_column);

	SD_Initialiser : SD_Init
      port map (clock              => CLOCK_50,
                reset              => audio_sd_reset,
                start_init         => '1',
                start_sector       => sd_start_sector,
                track_length       => sd_track_length,
                byte_address       => audio_byte_address,
                spi_clock_out      => sd_serial_clock,
                spi_mosi_out       => sd_command,
                spi_miso_in        => sd_data_in,
                spi_chip_select_n  => sd_chip_select,
                init_done          => init_done_signal,
                audio_ready        => audio_ready_signal,
                init_failed        => init_failed_signal,
                state_indicator    => init_state_indicator,
                last_response_byte => last_response_byte_sig,
                read_byte          => sd_buffer_byte);
					 
	Audio_Generator : Audio_Playback
      generic map (CLOCK_FREQUENCY => 50_000_000,
                   SAMPLE_RATE     => 44_100)
      port map (clock        => CLOCK_50,
                reset        => audio_sd_reset,
                audio_ready  => audio_gated_ready,
                buffer_byte  => sd_buffer_byte,
                byte_address => audio_byte_address,
                dac_high     => audio_dac_high,
                dac_low      => audio_dac_low);

   -- ===========================================================================
   -- AUDIO CONTROL (SW9-SW4)
   -- SW9=1: normal play  SW9=0: audio reset (resets SD+playback to track start)
   -- SW8=1: pause        SW8=0: play
   -- SW7=1: mute (sector still advances)  SW7=0: normal
   -- SW6-4: 3-bit track select (jukebox)
   -- ===========================================================================

   -- Synchronise endscreen_fsm (video_clock domain) into CLOCK_50 domain.
   -- Two-flop synchroniser + prev register for rising-edge detection.
   End_Screen_Sync : process(CLOCK_50)
   begin
      if rising_edge(CLOCK_50) then
         endscreen_50_s1   <= endscreen_fsm;
         endscreen_50_s2   <= endscreen_50_s1;
         endscreen_50_prev <= endscreen_50_s2;
      end if;
   end process End_Screen_Sync;

   -- One-cycle pulse the moment the end screen appears.
   endscreen_50_rise <= endscreen_50_s2 and (not endscreen_50_prev);

   -- Track-selection change detector (SW6-4 in CLOCK_50 domain).
   Track_Change_Detector : process(CLOCK_50)
   begin
      if rising_edge(CLOCK_50) then
         track_sel_prev <= SW(6 downto 4);
      end if;
   end process Track_Change_Detector;

   track_changed <= '1' when track_sel_prev /= SW(6 downto 4) else '0';

   -- SD/audio reset triggers:
   --   RESET_N pressed    -> full reset
   --   SW9 = 0            -> hold at track start (user-controlled reset)
   --   track_changed      -> switch to first sector of newly selected track (any time)
   --   endscreen_50_rise  -> ONE pulse when end screen appears; SD reinits DURING end screen
   --                         so it is ready from track start the moment next game begins
   audio_sd_reset <= (not RESET_N) or (not SW(9)) or track_changed or endscreen_50_rise;

   -- Audio gate: silent on start screen or end screen; SW8=1 pauses; SW9=0 holds
   audio_gated_ready <= audio_ready_signal and (not startscreen_fsm) and (not endscreen_50_s2) and (not SW(8)) and SW(9);

   -- SW7=1 mutes both DACs (outputs x"80" = signed midpoint = silence); sector still progresses
   dac_high_out <= x"80" when SW(7) = '1' else audio_dac_high;
   dac_low_out  <= x"80" when SW(7) = '1' else audio_dac_low;

   -- Jukebox: map SW(6 downto 4) to start sector and track length (in sectors)
   -- Track lengths derived from the sector gap between consecutive track start addresses.
   -- UPDATE sd_track_length for Track 5 once its size is known.
   Jukebox_Process : process(SW)
   begin
      case SW(6 downto 4) is
         when "000" =>
            sd_start_sector <= x"03473BC0";                        -- Sector 55,000,000 - Subway Surfers
            sd_track_length <= conv_std_logic_vector(23776, 32);
         when "001" =>
            sd_start_sector <= x"034798A0";                        -- Sector 55,023,776 - Espresso
            sd_track_length <= conv_std_logic_vector(30280, 32);
         when "010" =>
            sd_start_sector <= x"03480EE8";                        -- Sector 55,054,056 - Rude!
            sd_track_length <= conv_std_logic_vector(34456, 32);
         when "011" =>
            sd_start_sector <= x"03489580";                        -- Sector 55,088,512 - Dracula (Remix)
            sd_track_length <= conv_std_logic_vector(36248, 32);
         when "100" =>
            sd_start_sector <= x"03492318";                        -- Sector 55,124,760 - AIZO (King Gnu)
            sd_track_length <= conv_std_logic_vector(37199, 32);
         when others =>
            sd_start_sector <= x"03473BC0";
            sd_track_length <= conv_std_logic_vector(23776, 32);
      end case;
   end process Jukebox_Process;

   -- ===========================================================================
   -- START SCREEN + BACKGROUND SPRITE + FINAL COMPOSITOR
   -- ===========================================================================

   Start_Screen_Inst : Start_Screen
      port map (video_clock         => video_clock,
                reset               => not(RESET_N) or startscreen_fsm_rise,
                pixel_row           => pixel_row,
                pixel_column        => pixel_column,
                mouse_row           => mouse_row,
                mouse_column        => mouse_column,
                mouse_left_click    => left_click,
                mouse_right_click   => right_click,
                any_key_pressed     => any_key_pressed,
                any_key_held        => any_key_pressed,
                sw0                 => SW(0),
                sw1                 => SW(1),
                key2_pressed        => not KEY(2),
                start_screen_active => start_screen_active,
					 start_screen_fsm		=> startscreen_fsm,
                selected_mode       => selected_mode,
                latched_mode        => latched_mode,
                red_out             => start_screen_red,
                green_out           => start_screen_green,
                blue_out            => start_screen_blue);

	-- Knee logo sprite, SCALE 8 = 512x512, intentionally overflows the screen.
	-- It's funny. Don't question it.
	-- sprite_x = 320 - 256 = 64
	-- sprite_y = 240 - 256 = -16, clamped to 0 (unsigned can't go negative)
	Start_Screen_Background_Sprite : Sprites_Display
		generic map (SPRITE_WIDTH  => 64,
						 SPRITE_HEIGHT => 64,
						 ADDR_BITS     => 12,
						 SCALE         => 8,
						 MIF_FILE      => "Assets/Memory_Initialization_Files/jasper.mif")
		port map (clock        => video_clock,
					 pixel_row    => pixel_row,
					 pixel_column => pixel_column,
					 sprite_x     => conv_std_logic_vector(64, 10),
					 sprite_y     => conv_std_logic_vector(0, 10),
					 red_out      => start_screen_sprite_red,
					 green_out    => start_screen_sprite_green,
					 blue_out     => start_screen_sprite_blue);
	
	My_Timer : Game_Timer
		generic map (CLOCK_HZ => 50_000_000)
		port map (clock    => CLOCK_50,       -- 50MHz system clock
					 reset    => (endscreen_fsm or (not RESET_N)),
					 enable   => game_enable,    -- from Game_Master
					 min_tens => hud_min_tens,
					 min_ones => hud_min_ones,
					 sec_tens => hud_sec_tens,
                sec_ones => hud_sec_ones);
					 
	HUD : HUD_Overlay
		port map (video_clock  => video_clock,
					 reset        => not RESET_N,
					 pixel_row    => pixel_row,
					 pixel_column => pixel_column,
					 score        => score_hud,
					 HUD_enable   => not start_screen_active,
					 HUD_active   => HUD_active,
					 health_digit => lives,
					 game_mode    => latched_mode,
					 min_tens     => hud_min_tens,
                min_ones     => hud_min_ones,
                sec_tens     => hud_sec_tens,
                sec_ones     => hud_sec_ones,
					 score_h 	  => score_h,
					 score_t 	  => score_t, 
					 score_o		  => score_o,
					 red_out      => HUD_red,
					 green_out    => HUD_green,
					 blue_out     => HUD_blue);
					 
	--=================================== Pause screen ==========================================
	Pause_Label : Word_Display
		generic map (STRING_LENGTH => 6,
						 SCALE         => 8)
		port map (clock        => video_clock,
					 characters   => "010000" &   -- P (char 16)
										  "000001" &   -- A (char  1)
										  "010101" &   -- U (char 21)
										  "010011" &   -- S (char 19)
										  "000101" &   -- E (char  5)
										  "000100",    -- D (char  4)
					 x_position   => conv_std_logic_vector(128, 10),
					 y_position   => conv_std_logic_vector(220, 10),
					 pixel_row    => pixel_row,
					 pixel_column => pixel_column,
					 red_out      => pause_red,
					 green_out    => pause_green,
					 blue_out     => pause_blue);
					 
	-- ================================== screen compositor=====================================

   Final_Compositor_Inst : Screen_Compositor
      port map (clock							=> video_clock,
					 start_screen_active       => startscreen_fsm,
					 paused							=> pause_fsm,
					 end_screen_active			=> endscreen_fsm,
                latched_mode              => latched_mode,
                start_screen_red          => start_screen_red,
                start_screen_green        => start_screen_green,
                start_screen_blue         => start_screen_blue,
					 pause_text_red						=>	pause_red,
					 pause_text_green					=>	pause_green,
					 pause_text_blue						=> pause_blue,
                start_screen_sprite_red   => start_screen_sprite_red,
                start_screen_sprite_green => start_screen_sprite_green,
                start_screen_sprite_blue  => start_screen_sprite_blue,
                mouse_cursor_red          => mouse_cursor_red,
                mouse_cursor_green        => mouse_cursor_green,
                mouse_cursor_blue         => mouse_cursor_blue,
                HUD_red                   => HUD_red,
                HUD_green                 => HUD_green,
                HUD_blue                  => HUD_blue,
                training_red              => "0000",
					 training_green            => "0000",
                training_blue             => "0000",
					 end_screen_red				=> end_screen_red,
					 end_screen_green				=>	end_screen_green,
					 end_screen_blue				=> end_screen_blue,
                game_red                  => game_red,
                game_green                => game_green,
                game_blue                 => game_blue,
                red_out                   => red_final,
                green_out                 => green_final,
                blue_out                  => blue_final);

   -- Player driven by KEY pushbuttons, mouse clicks, and keyboard in parallel.
   -- Player.vhd internally edge-detects shift_left_input, shift_right_input,
   -- jump_input, and dive_input so holding any source still produces exactly
   -- one discrete action per press (no key repeat).
   Player_Sprite_Renderer : Player
      generic map (SCREEN_WIDTH  => 640,
                   SCREEN_HEIGHT => 480,
                   SPRITE_SIZE   => 64,
                   SPRITE_SCALE  => 2)
      port map (clock             => video_clock,
                reset             => not RESET_N or startscreen_fsm,
					 enable				 => game_enable,
                vertical_sync     => vertical_sync,
                pixel_row         => pixel_row,
                pixel_column      => pixel_column,
                shift_left_input  => player_shift_left_input,
                shift_right_input => player_shift_right_input,
                jump_input        => player_jump_input,
                dive_input        => player_dive_input,
                player_red        => player_red,
                player_green      => player_green,
                player_blue       => player_blue,
                player_lane       => player_lane,
                player_state      => player_state,
                player_dive       => player_dive,
                cat_view_position => cat_view_position);

   Player_Object_Compositor : Player_And_Objects_Manager
      port map (clock 			=> video_clock,
					 player_red    => player_red,
                player_green  => player_green,
                player_blue   => player_blue,
                objects_red   => sprite_composite_red,
                objects_green => sprite_composite_green,
                objects_blue  => sprite_composite_blue,
                red_out       => combined_sprite_red,
                green_out     => combined_sprite_green,
                blue_out      => combined_sprite_blue);

		
	Spawn_Ctrl : Spawn_Control
		port map(clock 			=> video_clock,
					reset 			=> not(RESET_N),
					vertical_sync  => vertical_sync,
					arrived_0		=> arrived_0,
					arrived_1		=> arrived_1,
					arrived_2		=> arrived_2,
					lane_0_type		=> lane_0_type, 
					lane_1_type		=> lane_1_type,
					lane_2_type		=> lane_2_type,
					debug_vsync_pulse => debug_vsync_pulse,
					debug_lfsr        => debug_lfsr);
	
	
	-- ====================================================
	-- End screen
	-- ====================================================
	Ending_screen: End_Screen
		port map(video_clock			=> video_clock,
					reset					=> not(RESET_N) or endscreen_fsm_rise,
					pixel_row			=> pixel_row,
					pixel_column		=> pixel_column,
					mouse_row			=> mouse_row,
					mouse_column		=> mouse_column,
					any_key_pressed	=> any_key_pressed_rising,
					end_screen_outcome=> endscreen_outcome,
					end_screen			=> endscreen_active,
					end_screen_active => endscreen_fsm,
					red_out				=> end_screen_red,
					green_out			=> end_screen_green,
					blue_out				=> end_screen_blue);
	
	
	-- ===========================================================================
	-- FSM
	-- ===========================================================================
	FSM : Game_Master
		port map  (clock					=> video_clock,
					  reset					=> not(RESET_N),
					  pause_input			=> not KEY(3),
					  god_mode				=> SW(3),
					  lane_0_obj_type		=> lane_0_type,
					  lane_1_obj_type		=> lane_1_type,
					  lane_2_obj_type		=> lane_2_type,
					  lane_0_obj_dist		=> sprite_0_row,
					  lane_1_obj_dist		=> sprite_1_row,
					  lane_2_obj_dist		=> sprite_2_row,
					  lanes_arrived	   => arrived_0 or arrived_1 or arrived_2,
					  player_lane			=> player_lane,
					  player_state			=> player_state,
					  player_dive			=> player_dive,
					  startscreen_enable => start_screen_active,
					  startscreen_fsm		=> startscreen_fsm,
					  mode_selected		=> latched_mode,
					  game_enable			=> game_enable,
					  endscreen_enable	=> endscreen_active,
					  endscreen_fsm		=> endscreen_fsm,
					  endscreen_outcome	=> endscreen_outcome,
					  pause_fsm			   => pause_fsm,
					  speed_select			=> speed_select,
					  win_999				=> SW(2),
					  score					=> score_hud,
					  lives					=> lives);
					  
	process(video_clock)
	begin
		 if rising_edge(video_clock) then
			  startscreen_fsm_prev <= startscreen_fsm;
			  endscreen_fsm_prev   <= endscreen_fsm;
		 end if;
	end process;

	startscreen_fsm_rise <= startscreen_fsm and not startscreen_fsm_prev;
	endscreen_fsm_rise   <= endscreen_fsm   and not endscreen_fsm_prev;

   -- ---------------------------------------------------------------------------
   -- LED assignments
	-- ---------------------------------------------------------------------------
	
	 LEDR(3 downto 0) <= init_state_indicator;
   LEDR(4)          <= init_done_signal;
   LEDR(5)          <= pll_locked;
   LEDR(6)          <= start_screen_active;
   LEDR(7)          <= latched_mode;
   LEDR(8)          <= init_failed_signal;
   LEDR(9)          <= audio_ready_signal;

   -- Debug mirror to GPIO_0 header for oscilloscope probing
   GPIO_0(0) <= sd_serial_clock;   -- CLK
   GPIO_0(1) <= sd_chip_select;    -- CS (HIGH = deasserted, LOW = active)
   GPIO_0(2) <= sd_command;        -- MOSI
   GPIO_0(3) <= sd_data_in;        -- MISO

   -- High-byte DAC (new DAC, GPIO_0[19..12]) — B1=MSB, B8=LSB
   GPIO_0(19) <= dac_high_out(7);   -- B1 (MSB)
   GPIO_0(18) <= dac_high_out(6);   -- B2
   GPIO_0(17) <= dac_high_out(5);   -- B3
   GPIO_0(16) <= dac_high_out(4);   -- B4
   GPIO_0(15) <= dac_high_out(3);   -- B5
   GPIO_0(14) <= dac_high_out(2);   -- B6
   GPIO_0(13) <= dac_high_out(1);   -- B7
   GPIO_0(12) <= dac_high_out(0);   -- B8 (LSB)

   -- Low-byte DAC (old DAC, GPIO_0[11..4]) — B1=MSB, B8=LSB
   GPIO_0(11) <= dac_low_out(7);   -- B1 (MSB)
   GPIO_0(10) <= dac_low_out(6);   -- B2
   GPIO_0(9)  <= dac_low_out(5);   -- B3
   GPIO_0(8)  <= dac_low_out(4);   -- B4
   GPIO_0(7)  <= dac_low_out(3);   -- B5
   GPIO_0(6)  <= dac_low_out(2);   -- B6
   GPIO_0(5)  <= dac_low_out(1);   -- B7
   GPIO_0(4)  <= dac_low_out(0);   -- B8 (LSB)

   GPIO_0(35 downto 20) <= (others => '0');
	
	-- LFSR testing
	--	LEDR(8) <= vertical_sync;
	--	LEDR(7 downto 0) <= debug_lfsr;         -- should change pattern over time
	--
	--	LEDR(9) <= pll_locked;
	--	
	--	LEDR(1) <= arrived_1;
	--	LEDR(0) <= arrived_2;
	--	
	--	process(video_clock)
	--	begin
	--		 if rising_edge(video_clock) then
	--			  if arrived_0 = '1' then arrived_sticky <= '1'; end if;
	--		 end if;
	--	end process;
	--
	--	LEDR(2) <= arrived_sticky;
	
   -- HEX0/HEX1 show the byte at SW(8:0) of the read sector buffer
   Score_Digit_Zero : Hex_To_Seven_Segment
      port map (hex_value      => score_o,
                seven_segments => HEX0);

   Score_Digit_One : Hex_To_Seven_Segment
      port map (hex_value      => score_t,
                seven_segments => HEX1);

   Score_Digit_Two : Hex_To_Seven_Segment
      port map (hex_value      => score_h,
                seven_segments => HEX2);

	-- HEX4/HEX5 show the last raw SPI response byte (SD Error Codes)
   Hex_Response_Low : Hex_To_Seven_Segment
      port map (hex_value      => last_response_byte_sig(3 downto 0),
                seven_segments => HEX3);

   Hex_Response_High : Hex_To_Seven_Segment
      port map (hex_value      => last_response_byte_sig(7 downto 4),
                seven_segments => HEX4);

   Health_Digit : Hex_To_Seven_Segment
      port map (hex_value      => "00" & not(lives),
                seven_segments => HEX5);

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