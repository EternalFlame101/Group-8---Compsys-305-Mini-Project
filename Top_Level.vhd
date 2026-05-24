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
      port (clock, vertical_sync         : in  std_logic;
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            cat_view_position            : in  std_logic_vector(7 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Track_Generator;

   component Background_Manager is
      port (background_red, background_green, background_blue : in  std_logic_vector(3 downto 0);
            track_red,      track_green,      track_blue      : in  std_logic_vector(3 downto 0);
            red_out,        green_out,        blue_out        : out std_logic_vector(3 downto 0));
   end component Background_Manager;

   component Moving_Object is
      generic (REAL_HEIGHT : positive             := 60;
               REAL_WIDTH  : positive             := 80;
               LANE        : integer range 0 to 2 := 1);
      port (enable, clock, vertical_sync : in  std_logic;
            reset						 	 		       : in  std_logic;
				    obj_type								     : in  std_logic_vector(1 downto 0);
				    arrived				 				       : out std_logic;
            pixel_column, pixel_row      : in  std_logic_vector(9 downto 0);
            speed                        : in  std_logic_vector(3 downto 0);
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
      generic (TOTAL_SECTORS : positive := 30280);
      port (clock              : in  std_logic;
            reset              : in  std_logic;
            start_init         : in  std_logic;
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
            any_key_pressed              : in  std_logic;
            start_screen_active          : out std_logic;
            selected_mode                : out std_logic;
            latched_mode                 : out std_logic;
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Start_Screen;

   component Sprites_Display is
      generic (SPRITE_WIDTH  : positive := 32;
               SPRITE_HEIGHT : positive := 32;
               ADDR_BITS     : positive := 12;
               SCALE         : positive := 4;
               MIF_FILE      : string   := "Images_To_mif/mif/jasper.mif");
      port (clock                        : in  std_logic;
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            sprite_x,  sprite_y          : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Sprites_Display;

   component Screen_Compositor is
      port (start_screen_active : in  std_logic;
            latched_mode        : in  std_logic;
            start_screen_red, start_screen_green, start_screen_blue : in std_logic_vector(3 downto 0);
            start_screen_sprite_red, start_screen_sprite_green, start_screen_sprite_blue : in std_logic_vector(3 downto 0);
            mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue : in std_logic_vector(3 downto 0);
            training_red, training_green, training_blue : in std_logic_vector(3 downto 0);
            racing_red,   racing_green,   racing_blue   : in std_logic_vector(3 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Screen_Compositor;
	
	component Spawn_Control is
		port(clock         : in  std_logic;
			  reset         : in  std_logic;
			  vertical_sync : in  std_logic;
			  arrived_0     : in  std_logic;
			  arrived_1     : in  std_logic;
			  arrived_2     : in  std_logic;
			  lane_0_type   : out std_logic_vector(1 downto 0);
			  lane_1_type   : out std_logic_vector(1 downto 0);
			  lane_2_type   : out std_logic_vector(1 downto 0);
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
      port (clock, reset, vertical_sync             : in  std_logic;
            pixel_row, pixel_column                 : in  std_logic_vector(9 downto 0);
            shift_left_input                        : in  std_logic;
            shift_right_input                       : in  std_logic;
            jump_input                              : in  std_logic;
            dive_input                              : in  std_logic;
            player_red, player_green, player_blue   : out std_logic_vector(3 downto 0);
            player_lane                             : out std_logic_vector(1 downto 0);
            player_state                            : out std_logic;
            cat_view_position                       : out std_logic_vector(7 downto 0));
   end component Player;

   component Player_And_Objects_Manager is
      port (player_red,  player_green,  player_blue  : in  std_logic_vector(3 downto 0);
            objects_red, objects_green, objects_blue : in  std_logic_vector(3 downto 0);
            red_out,     green_out,     blue_out     : out std_logic_vector(3 downto 0));
   end component Player_And_Objects_Manager;
	
	component Game_Master is
		port(clock            	: in  std_logic;
			  reset					: in  std_logic;
			  lane_0_gift			: in 	std_logic; -- 0 for no gift in lane, 1 for gift in lane
			  lane_1_gift			: in 	std_logic;
			  lane_2_gift			: in 	std_logic;
			  lane_0_obj_type  	: in  std_logic; -- 0 for short, 1 for tall
			  lane_1_obj_type  	: in  std_logic;
			  lane_2_obj_type  	: in  std_logic;
			  lane_0_obj_dist  	: in  std_logic_vector(9 downto 0);
			  lane_1_obj_dist  	: in  std_logic_vector(9 downto 0);
			  lane_2_obj_dist  	: in  std_logic_vector(9 downto 0);
			  player_lane			: in	std_logic_vector(1 downto 0);
			  player_state			: in 	std_logic;
			  startscreen_enable : in  std_logic; -- 0 = off, 1 = on, startscreen on/off
			  mode_selected		: in  std_logic; -- 0 = training, 1 = normal/single player
			  game_enable		 	: out std_logic; -- 0 = pause, 1 = playing, game pause
			  endscreen_enable	: out std_logic; -- 0 = off, 1 = on, win/lose screen
			  endscreen_outcome  : out std_logic; -- 0 = lose, 1 = win
			  speed            	: out std_logic_vector(3 downto 0); -- manages speed
			  score            	: out std_logic_vector(5 downto 0));
	end component Game_Master;

   -- ---------------------------------------------------------------------------
   -- Signals
   -- ---------------------------------------------------------------------------
   signal video_clock                    : std_logic;
   signal pll_locked                     : std_logic;
   signal vertical_sync, horizontal_sync : std_logic;
   signal video_on                       : std_logic;

   -- Training-mode graphics layer signals (orbiting ball + text + mouse demo)
   signal training_red, training_green, training_blue              : std_logic_vector(3 downto 0);
   signal orbit_ball_red,  orbit_ball_green,  orbit_ball_blue      : std_logic_vector(3 downto 0);
   signal mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue  : std_logic_vector(3 downto 0);
   signal text_small_red,  text_small_green,  text_small_blue      : std_logic_vector(3 downto 0);
   signal text_large_red,  text_large_green,  text_large_blue      : std_logic_vector(3 downto 0);

   -- Racing-mode graphics layer signals (background + track + moving objects)
   signal racing_red, racing_green, racing_blue                                            : std_logic_vector(3 downto 0);
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

   -- Final composited pixel values feeding VGA_Sync
   signal red_final, green_final, blue_final : std_logic_vector(3 downto 0);
   signal red_out,   green_out,   blue_out   : std_logic_vector(3 downto 0);

   signal pixel_row, pixel_column : std_logic_vector(9 downto 0);
   signal ball_x_out, ball_y_out  : std_logic_vector(9 downto 0);

   -- Mouse signals (single mouse, now on PS/2 port 2)
   signal left_click   : std_logic;
   signal right_click  : std_logic;
   signal mouse_row    : std_logic_vector(9 downto 0);
   signal mouse_column : std_logic_vector(9 downto 0);

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
	signal audio_ready_signal 	: std_logic;
   signal sd_buffer_byte     	: std_logic_vector(7 downto 0);
   signal audio_byte_address 	: std_logic_vector(9 downto 0);	
	
	-- Spawn control signals 
	signal lane_0_type : std_logic_vector(1 downto 0);
	signal lane_1_type : std_logic_vector(1 downto 0);
	signal lane_2_type : std_logic_vector(1 downto 0);
	
	
	signal arrived_0, arrived_1, arrived_2 : std_logic;
	
	-- Testing
	signal debug_vsync_pulse : std_logic;
	signal debug_lfsr        : std_logic_vector(7 downto 0);
	signal arrived_sticky : std_logic := '0';

   -- Player signals
   signal player_red, player_green, player_blue                            : std_logic_vector(3 downto 0);
   signal player_lane                                                      : std_logic_vector(1 downto 0);
   signal player_state                                                     : std_logic;
   signal cat_view_position                                                : std_logic_vector(7 downto 0);
   signal combined_sprite_red, combined_sprite_green, combined_sprite_blue : std_logic_vector(3 downto 0);
	
	-- fsm output signals
	signal lane_0_enable : std_logic;
	signal lane_1_enable : std_logic;
	signal lane_2_enable	: std_logic;
	
	signal game_enable		: std_logic;
	signal endscreen_enable : std_logic;
	signal endscreen_outcome: std_logic;
	
	signal speed	: std_logic_vector(3 downto 0);
	signal score	: std_logic_vector(5 downto 0);
	
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
   -- Video PLL: produces a true 25 MHz pixel clock from 50 MHz input.
   -- ---------------------------------------------------------------------------
   Pixel_Clock_PLL : Video_PLL
      port map (refclk   => CLOCK_50,
                rst      => not RESET_N,
                outclk_0 => video_clock_prebuffered,
                locked   => pll_locked);

   -- ---------------------------------------------------------------------------
   -- "Any key" detection. KEY[3:0] are active-low pushbuttons.
   -- ---------------------------------------------------------------------------
   any_key_pressed <= not (KEY(3) and KEY(2) and KEY(1) and KEY(0));

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
   player_dive_raw        <= right_click  or keyboard_dive_key;

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
      port map (clock             => video_clock,
                vertical_sync     => vertical_sync,
                pixel_row         => pixel_row,
                pixel_column      => pixel_column,
                cat_view_position => cat_view_position,
                red_out           => track_layer_red,
                green_out         => track_layer_green,
                blue_out          => track_layer_blue);

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
					 
	-- =============================================================================
	-- registering stuff to make it run
	-- =============================================================================
	process(video_clock)
	begin
		 if rising_edge(video_clock) then
			  lane_0_enable <= (lane_0_type(1) or lane_0_type(0)) and game_enable;
			  lane_1_enable <= (lane_1_type(1) or lane_1_type(0)) and game_enable;
			  lane_2_enable <= (lane_2_type(1) or lane_2_type(0)) and game_enable;
		 end if;
	end process;
	
	Moving_Object_Lane_Two : Moving_Object
      generic map (REAL_HEIGHT => 60,
                   REAL_WIDTH  => 80,
                   LANE        => 2)
      port map (enable            => (lane_2_type(1) or lane_2_type(0)) and game_enable,
                clock             => video_clock,
                vertical_sync     => vertical_sync,
                reset             => not RESET_N,
                obj_type          => lane_2_type,
                arrived           => arrived_2,
                pixel_column      => pixel_column,
                pixel_row         => pixel_row,
                speed             => conv_std_logic_vector(2, 4),
                cat_view_position => cat_view_position,
                row_out           => sprite_2_row,
                red_out           => sprite_2_red,
                green_out         => sprite_2_green,
                blue_out          => sprite_2_blue);

   Moving_Object_Lane_One : Moving_Object
      generic map (REAL_HEIGHT => 60,
                   REAL_WIDTH  => 70,
                   LANE        => 1)
      port map (enable            => (lane_1_type(1) or lane_1_type(0)) and game_enable,
                clock             => video_clock,
                vertical_sync     => vertical_sync,
                reset 			    => not RESET_N,
					 obj_type 		    => lane_1_type,
					 arrived			    => arrived_1,
                pixel_column      => pixel_column,
                pixel_row         => pixel_row,
                speed             => conv_std_logic_vector(2, 4),
                cat_view_position => cat_view_position,
                row_out           => sprite_1_row,
                red_out           => sprite_1_red,
                green_out         => sprite_1_green,
                blue_out          => sprite_1_blue);

   Moving_Object_Lane_Zero : Moving_Object
      generic map (REAL_HEIGHT => 120,
                   REAL_WIDTH  => 70,
                   LANE        => 0)
      port map (enable            => (lane_0_type(1) or lane_0_type(0)) and game_enable,
                clock             => video_clock,
                vertical_sync     => vertical_sync,
                reset             => not RESET_N,
                obj_type          => lane_0_type,
                arrived           => arrived_0,
                pixel_column      => pixel_column,
                pixel_row         => pixel_row,
                speed             => conv_std_logic_vector(2, 4),
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
      generic map (TOTAL_SECTORS => 30280)
      port map (clock              => CLOCK_50,
                reset              => not RESET_N,
                start_init         => not KEY(2),
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
                reset        => not RESET_N,
                audio_ready  => audio_ready_signal,
                buffer_byte  => sd_buffer_byte,
                byte_address => audio_byte_address,
                dac_high     => audio_dac_high,
                dac_low      => audio_dac_low);

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
      generic map (SPRITE_WIDTH  => 64,
                   SPRITE_HEIGHT => 64,
                   ADDR_BITS     => 12,
                   SCALE         => 2,
                   MIF_FILE      => "Images_To_mif/mif/jasper.mif")
      port map (clock        => video_clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => conv_std_logic_vector(256, 10),
                sprite_y     => conv_std_logic_vector(68, 10),
                red_out      => start_screen_sprite_red,
                green_out    => start_screen_sprite_green,
                blue_out     => start_screen_sprite_blue);

   Final_Compositor_Inst : Screen_Compositor
      port map (start_screen_active       => start_screen_active,
                latched_mode              => latched_mode,
                start_screen_red          => start_screen_red,
                start_screen_green        => start_screen_green,
                start_screen_blue         => start_screen_blue,
                start_screen_sprite_red   => start_screen_sprite_red,
                start_screen_sprite_green => start_screen_sprite_green,
                start_screen_sprite_blue  => start_screen_sprite_blue,
                mouse_cursor_red          => mouse_cursor_red,
                mouse_cursor_green        => mouse_cursor_green,
                mouse_cursor_blue         => mouse_cursor_blue,
                training_red              => training_red,
                training_green            => training_green,
                training_blue             => training_blue,
                racing_red                => racing_red,
                racing_green              => racing_green,
                racing_blue               => racing_blue,
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
                reset             => not RESET_N,
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
                cat_view_position => cat_view_position);

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
	
	
	-- ===========================================================================
	-- FSM
	-- ===========================================================================
	FSM : Game_Master
		port map  (clock					=> CLOCK_50,
					  reset					=> not RESET_N,
					  lane_0_gift			=> not(lane_0_type(1)),
					  lane_1_gift			=> not(lane_1_type(1)),
					  lane_2_gift			=> not(lane_2_type(1)),
					  lane_0_obj_type		=> lane_0_type(0),
					  lane_1_obj_type		=> lane_1_type(0),
					  lane_2_obj_type		=> lane_2_type(0),
					  lane_0_obj_dist		=> sprite_0_row,
					  lane_1_obj_dist		=> sprite_1_row,
					  lane_2_obj_dist		=> sprite_2_row,
					  player_lane			=> player_lane,
					  player_state			=> player_state,
					  startscreen_enable => start_screen_active,
					  mode_selected		=> latched_mode,
					  game_enable			=> game_enable,
					  endscreen_enable	=> endscreen_enable,
					  endscreen_outcome	=> endscreen_outcome,
					  speed					=> speed,
					  score					=> score);
	
	
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
   GPIO_0(19) <= audio_dac_high(7);   -- B1 (MSB)
   GPIO_0(18) <= audio_dac_high(6);   -- B2
   GPIO_0(17) <= audio_dac_high(5);   -- B3
   GPIO_0(16) <= audio_dac_high(4);   -- B4
   GPIO_0(15) <= audio_dac_high(3);   -- B5
   GPIO_0(14) <= audio_dac_high(2);   -- B6
   GPIO_0(13) <= audio_dac_high(1);   -- B7
   GPIO_0(12) <= audio_dac_high(0);   -- B8 (LSB)

   -- Low-byte DAC (old DAC, GPIO_0[11..4]) — B1=MSB, B8=LSB
   GPIO_0(11) <= audio_dac_low(7);   -- B1 (MSB)
   GPIO_0(10) <= audio_dac_low(6);   -- B2
   GPIO_0(9)  <= audio_dac_low(5);   -- B3
   GPIO_0(8)  <= audio_dac_low(4);   -- B4
   GPIO_0(7)  <= audio_dac_low(3);   -- B5
   GPIO_0(6)  <= audio_dac_low(2);   -- B6
   GPIO_0(5)  <= audio_dac_low(1);   -- B7
   GPIO_0(4)  <= audio_dac_low(0);   -- B8 (LSB)

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
   Hex_Buffer_Low : Hex_To_Seven_Segment
      port map (hex_value      => sd_buffer_byte(3 downto 0),
                seven_segments => HEX0);

   Hex_Buffer_High : Hex_To_Seven_Segment
      port map (hex_value      => sd_buffer_byte(7 downto 4),
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