library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ------------------------------------------------------------------------------
-- Start_Screen
--   Self-contained start screen for Pusheen's Ploy.
--
--   State machine:
--     title_screen -> mode_select : on mouse left click rising edge OR any KEY rising edge
--     mode_select  -> game_running: on mouse left click rising edge while a button is hovered
--     game_running -> (stays)     : selected_mode is latched, start_screen_active goes low
--
--   While in title_screen or mode_select, start_screen_active = '1' so Top_Level
--   can overlay the start screen on top of the game pipeline.
--
--   Two mode outputs are exposed:
--     selected_mode - live, reflects whichever button is currently in flight
--     latched_mode  - frozen at the instant we entered game_running; safe for
--                     downstream gameplay modules that must not change mode
--                     mid-game.
--
--   Hover effect: each game mode button has a small (SCALE 2) resting version and
--   a large (SCALE 3) hovered version. They share an x centre but the large one
--   sits above the small one (small Y unchanged, large Y shifted up ~18 px). This
--   gives a "lift on hover" look and, critically, keeps the large versions away
--   from row positions that triggered simultaneous-switching-noise glitches on
--   the VGA sync output when many ROM_Display character_on signals toggled at
--   the same scanline.
-- ------------------------------------------------------------------------------

entity Start_Screen is
   port (video_clock                  : in  std_logic;
         reset                        : in  std_logic;
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
         mouse_row, mouse_column      : in  std_logic_vector(9 downto 0);
         mouse_left_click             : in  std_logic;
         any_key_pressed              : in  std_logic;
         start_screen_active          : out std_logic;
			start_screen_fsm				  : in  std_logic;
         selected_mode                : out std_logic;
         latched_mode                 : out std_logic;
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Start_Screen;

architecture start_screen_behaviour of Start_Screen is

   component Word_Display is
      generic (STRING_LENGTH : positive                     := 16;
               SCALE         : positive                     := 1;
               TEXT_RED      : std_logic_vector(3 downto 0) := "1111";
               TEXT_GREEN    : std_logic_vector(3 downto 0) := "1111";
               TEXT_BLUE     : std_logic_vector(3 downto 0) := "1111");
      port (clock                        : in  std_logic;
            x_position, y_position       : in  std_logic_vector(9 downto 0);
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            characters                   : in  std_logic_vector((STRING_LENGTH * 6 - 1) downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Word_Display;

   -- ---------------------------------------------------------------------------
   -- State machine
   -- ---------------------------------------------------------------------------
   type screen_state_type is (title_screen, mode_select, game_running);
   signal screen_state           : screen_state_type := title_screen;

   -- Internal copy of selected_mode so we can both drive an output port and
   -- feed the mode-latch process from it.
   signal selected_mode_internal : std_logic := '0';
   signal latched_mode_internal  : std_logic := '0';

   -- ---------------------------------------------------------------------------
   -- Input synchronisers and rising-edge detection
   -- ---------------------------------------------------------------------------
   signal mouse_left_click_sync_1, mouse_left_click_sync_2 : std_logic;
   signal any_key_pressed_sync_1,  any_key_pressed_sync_2  : std_logic;
   signal mouse_left_click_previous                        : std_logic;
   signal any_key_pressed_previous                         : std_logic;
   signal mouse_left_click_edge                            : std_logic;
   signal any_key_pressed_edge                             : std_logic;

   -- ---------------------------------------------------------------------------
   -- Hover signals
   -- ---------------------------------------------------------------------------
   signal training_hovered      : std_logic;
   signal single_player_hovered : std_logic;
   signal two_player_hovered    : std_logic;

   -- ---------------------------------------------------------------------------
   -- Per-text-element pixel outputs
   -- ---------------------------------------------------------------------------
   signal title_red,    title_green,    title_blue    : std_logic_vector(3 downto 0);
   signal credits_one_red, credits_one_green, credits_one_blue : std_logic_vector(3 downto 0);
   signal credits_two_red, credits_two_green, credits_two_blue : std_logic_vector(3 downto 0);
   signal subtitle_red, subtitle_green, subtitle_blue : std_logic_vector(3 downto 0);
   signal header_red,   header_green,   header_blue   : std_logic_vector(3 downto 0);

   signal training_small_red,      training_small_green,      training_small_blue      : std_logic_vector(3 downto 0);
   signal training_large_red,      training_large_green,      training_large_blue      : std_logic_vector(3 downto 0);
   signal single_player_small_red, single_player_small_green, single_player_small_blue : std_logic_vector(3 downto 0);
   signal single_player_large_red, single_player_large_green, single_player_large_blue : std_logic_vector(3 downto 0);

   signal training_red,      training_green,      training_blue      : std_logic_vector(3 downto 0);
   signal single_player_red, single_player_green, single_player_blue : std_logic_vector(3 downto 0);

   -- ---------------------------------------------------------------------------
   -- Layout constants
   -- All horizontally centred on x = 320 (screen width 640).
   -- Each character is 8 pixels wide/tall before SCALE is applied.
   -- ---------------------------------------------------------------------------

   -- Title: "PUSHEEN'S PLOY" - 14 chars at SCALE 3 (24 px per char)
   --   width = 14 * 24 = 336 px, x = (640 - 336) / 2 = 152
   constant TITLE_X : integer := 152;
   constant TITLE_Y : integer := 120;

   -- Credits line 1: "GROUP 8 - JASPER'S KNEE" - 23 chars at SCALE 1 (8 px per char)
   --   width = 23 * 8 = 184 px, x = (640 - 184) / 2 = 228
   --   y = TITLE_Y + 50 = 170 (24 px tall title + 26 px breathing room)
   constant CREDITS_ONE_X : integer := 228;
   constant CREDITS_ONE_Y : integer := 170;

   -- Credits line 2: "FREDERICK, JASPER & JOHNNY" - 26 chars at SCALE 1
   --   width = 26 * 8 = 208 px, x = (640 - 208) / 2 = 216
   --   y = CREDITS_ONE_Y + 15 = 185 (8 px tall line + 7 px gap, tight pair)
   constant CREDITS_TWO_X : integer := 216;
   constant CREDITS_TWO_Y : integer := 185;

   -- Subtitle: 54 chars at SCALE 1 (8 px per char)
   --   width = 54 * 8 = 432 px, x = (640 - 432) / 2 = 104
   --   Pushed down to y=320 (was 300) so the credits block breathes properly.
   constant SUBTITLE_X : integer := 104;
   constant SUBTITLE_Y : integer := 320;

   -- Header: "SELECT YOUR GAME MODE:" - 22 chars at SCALE 2 (16 px per char)
   --   width = 22 * 16 = 352 px, x = (640 - 352) / 2 = 144
   constant HEADER_X : integer := 144;
   constant HEADER_Y : integer := 100;

   -- Buttons: small (SCALE 2) is resting, large (SCALE 3) is hovered.
   -- Large versions sit ~18 px above their small counterparts (lift-on-hover).
   -- Hit box uses the small bounding box, which stays at the original spacing.
   --
   -- TRAINING: 8 chars
   --   small: 8 * 16 = 128 wide, 16 tall, top-left (256, 192)
   --   large: 8 * 24 = 192 wide, 24 tall, top-left (224, 170)
   constant TRAINING_SMALL_X    : integer := 256;
   constant TRAINING_SMALL_Y    : integer := 192;
   constant TRAINING_LARGE_X    : integer := 224;
   constant TRAINING_LARGE_Y    : integer := 170;
   constant TRAINING_HIT_X_MAX  : integer := 384;
   constant TRAINING_HIT_Y_MAX  : integer := 208;

   -- SINGLE PLAYER: 13 chars
   --   small: 13 * 16 = 208 wide, 16 tall, top-left (216, 272)
   --   large: 13 * 24 = 312 wide, 24 tall, top-left (164, 250)
   constant SINGLE_PLAYER_SMALL_X   : integer := 216;
   constant SINGLE_PLAYER_SMALL_Y   : integer := 272;
   constant SINGLE_PLAYER_LARGE_X   : integer := 164;
   constant SINGLE_PLAYER_LARGE_Y   : integer := 250;
   constant SINGLE_PLAYER_HIT_X_MAX : integer := 424;
   constant SINGLE_PLAYER_HIT_Y_MAX : integer := 288;

begin

   -- ---------------------------------------------------------------------------
   -- Synchronise inputs into video_clock domain and detect rising edges
   -- ---------------------------------------------------------------------------
   Synchronise_Inputs : process(video_clock, reset)
   begin
      if reset = '1' then
         mouse_left_click_sync_1   <= '0';
         mouse_left_click_sync_2   <= '0';
         mouse_left_click_previous <= '0';
         any_key_pressed_sync_1    <= '0';
         any_key_pressed_sync_2    <= '0';
         any_key_pressed_previous  <= '0';
      elsif rising_edge(video_clock) then
         mouse_left_click_sync_1   <= mouse_left_click;
         mouse_left_click_sync_2   <= mouse_left_click_sync_1;
         mouse_left_click_previous <= mouse_left_click_sync_2;
         any_key_pressed_sync_1    <= any_key_pressed;
         any_key_pressed_sync_2    <= any_key_pressed_sync_1;
         any_key_pressed_previous  <= any_key_pressed_sync_2;
      end if;
   end process Synchronise_Inputs;

   mouse_left_click_edge <= mouse_left_click_sync_2 and not mouse_left_click_previous;
   any_key_pressed_edge  <= any_key_pressed_sync_2  and not any_key_pressed_previous;

   -- ---------------------------------------------------------------------------
   -- Hover detection (mouse cursor inside button hit box - uses small bounding box)
   -- ---------------------------------------------------------------------------
   training_hovered      <= '1' when (mouse_column >= conv_std_logic_vector(TRAINING_SMALL_X,    10) and
                                      mouse_column <  conv_std_logic_vector(TRAINING_HIT_X_MAX,  10) and
                                      mouse_row    >= conv_std_logic_vector(TRAINING_SMALL_Y,    10) and
                                      mouse_row    <  conv_std_logic_vector(TRAINING_HIT_Y_MAX,  10))
                                else '0';

   single_player_hovered <= '1' when (mouse_column >= conv_std_logic_vector(SINGLE_PLAYER_SMALL_X,   10) and
                                      mouse_column <  conv_std_logic_vector(SINGLE_PLAYER_HIT_X_MAX, 10) and
                                      mouse_row    >= conv_std_logic_vector(SINGLE_PLAYER_SMALL_Y,   10) and
                                      mouse_row    <  conv_std_logic_vector(SINGLE_PLAYER_HIT_Y_MAX, 10))
                                else '0';

   -- ---------------------------------------------------------------------------
   -- State machine
   -- ---------------------------------------------------------------------------
   -- latched_mode_internal is set in the same cycle as the screen_state
   -- transition into game_running so it is valid the moment
   -- start_screen_active falls. Doing it in a separate process delayed the
   -- latch by one cycle and caused Game_Master to sample the stale value.
   State_Machine : process(video_clock, reset)
   begin
      if reset = '1' then
         screen_state           <= title_screen;
         selected_mode_internal <= '0';
         latched_mode_internal  <= '0';
      elsif rising_edge(video_clock) then
         case screen_state is
            when title_screen =>
               if any_key_pressed_edge = '1' then
                  screen_state <= mode_select;
               end if;

            when mode_select =>
               if mouse_left_click_edge = '1' then
                  if training_hovered = '1' then
                     selected_mode_internal <= '0';
                     latched_mode_internal  <= '0';
                     screen_state           <= game_running;
                  elsif single_player_hovered = '1' then
                     selected_mode_internal <= '1';
                     latched_mode_internal  <= '1';
                     screen_state           <= game_running;
                  end if;
               end if;

            when game_running =>
               null;
         end case;
      end if;
   end process State_Machine;
	
   start_screen_active <= '0' when (screen_state = game_running) else '1';
   selected_mode       <= selected_mode_internal;
   latched_mode        <= latched_mode_internal;
	
   -- ---------------------------------------------------------------------------
   -- Title: "PUSHEEN'S PLOY" (SCALE 3)
   -- ---------------------------------------------------------------------------
   Title : Word_Display
      generic map (STRING_LENGTH => 14,
                   SCALE         => 3,
                   TEXT_RED      => "1001",
                   TEXT_GREEN    => "0111",
                   TEXT_BLUE     => "1100")
      port map (clock          => video_clock,
                characters     => "010000" &  -- P  = 16
                                  "010101" &  -- U  = 21
                                  "010011" &  -- S  = 19
                                  "001000" &  -- H  =  8
                                  "000101" &  -- E  =  5
                                  "000101" &  -- E  =  5
                                  "001110" &  -- N  = 14
                                  "100111" &  -- '  = 39
                                  "010011" &  -- S  = 19
                                  "100000" &  -- sp = 32
                                  "010000" &  -- P  = 16
                                  "001100" &  -- L  = 12
                                  "001111" &  -- O  = 15
                                  "011001",   -- Y  = 25
                x_position     => conv_std_logic_vector(TITLE_X, 10),
                y_position     => conv_std_logic_vector(TITLE_Y, 10),
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => title_red,
                green_out      => title_green,
                blue_out       => title_blue);

   -- ---------------------------------------------------------------------------
   -- Credits line 1: "GROUP 8 - JASPER'S KNEE" (SCALE 1)
   -- Muted purple (darker than title) so it sits visually under the title.
   -- '-' is index 45 = 101101, '8' is index 56 = 111000 (assuming standard
   -- numeric encoding where '0' starts at 48).
   -- ---------------------------------------------------------------------------
   Credits_One : Word_Display
      generic map (STRING_LENGTH => 23,
                   SCALE         => 1,
                   TEXT_RED      => "0110",
                   TEXT_GREEN    => "0101",
                   TEXT_BLUE     => "1000")
      port map (clock          => video_clock,
                characters     => "000111" &  -- G
                                  "010010" &  -- R
                                  "001111" &  -- O
                                  "010101" &  -- U
                                  "010000" &  -- P
                                  "100000" &  -- sp
                                  "111000" &  -- 8  = 56
                                  "100000" &  -- sp
                                  "101101" &  -- -  = 45
                                  "100000" &  -- sp
                                  "001010" &  -- J  = 10
                                  "000001" &  -- A
                                  "010011" &  -- S
                                  "010000" &  -- P
                                  "000101" &  -- E
                                  "010010" &  -- R
                                  "100111" &  -- '  = 39
                                  "010011" &  -- S
                                  "100000" &  -- sp
                                  "001011" &  -- K
                                  "001110" &  -- N
                                  "000101" &  -- E
                                  "000101",   -- E
                x_position     => conv_std_logic_vector(CREDITS_ONE_X, 10),
                y_position     => conv_std_logic_vector(CREDITS_ONE_Y, 10),
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => credits_one_red,
                green_out      => credits_one_green,
                blue_out       => credits_one_blue);

   -- ---------------------------------------------------------------------------
   -- Credits line 2: "FREDERICK, JASPER & JOHNNY" (SCALE 1)
   -- ',' is index 44 = 101100, '&' is index 38 = 100110.
   -- ---------------------------------------------------------------------------
   Credits_Two : Word_Display
      generic map (STRING_LENGTH => 26,
                   SCALE         => 1,
                   TEXT_RED      => "0110",
                   TEXT_GREEN    => "0101",
                   TEXT_BLUE     => "1000")
      port map (clock          => video_clock,
                characters     => "000110" &  -- F  =  6
                                  "010010" &  -- R
                                  "000101" &  -- E
                                  "000100" &  -- D
                                  "000101" &  -- E
                                  "010010" &  -- R
                                  "001001" &  -- I
                                  "000011" &  -- C
                                  "001011" &  -- K
                                  "101100" &  -- ,  = 44
                                  "100000" &  -- sp
                                  "001010" &  -- J
                                  "000001" &  -- A
                                  "010011" &  -- S
                                  "010000" &  -- P
                                  "000101" &  -- E
                                  "010010" &  -- R
                                  "100000" &  -- sp
                                  "100110" &  -- &  = 38
                                  "100000" &  -- sp
                                  "001010" &  -- J
                                  "001111" &  -- O
                                  "001000" &  -- H
                                  "001110" &  -- N
                                  "001110" &  -- N
                                  "011001",   -- Y
                x_position     => conv_std_logic_vector(CREDITS_TWO_X, 10),
                y_position     => conv_std_logic_vector(CREDITS_TWO_Y, 10),
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => credits_two_red,
                green_out      => credits_two_green,
                blue_out       => credits_two_blue);

   -- ---------------------------------------------------------------------------
   -- Subtitle: "CLICK ANYWHERE ON THE SCREEN/PRESS ANY KEY TO CONTINUE" (SCALE 1)
   -- ---------------------------------------------------------------------------
   Subtitle : Word_Display
      generic map (STRING_LENGTH => 54,
                   SCALE         => 1,
                   TEXT_RED      => "1001",
                   TEXT_GREEN    => "0111",
                   TEXT_BLUE     => "1100")
      port map (clock          => video_clock,
                characters     => "000011" &  -- C
                                  "001100" &  -- L
                                  "001001" &  -- I
                                  "000011" &  -- C
                                  "001011" &  -- K
                                  "100000" &  -- sp
                                  "000001" &  -- A
                                  "001110" &  -- N
                                  "011001" &  -- Y
                                  "010111" &  -- W
                                  "001000" &  -- H
                                  "000101" &  -- E
                                  "010010" &  -- R
                                  "000101" &  -- E
                                  "100000" &  -- sp
                                  "001111" &  -- O
                                  "001110" &  -- N
                                  "100000" &  -- sp
                                  "010100" &  -- T
                                  "001000" &  -- H
                                  "000101" &  -- E
                                  "100000" &  -- sp
                                  "010011" &  -- S
                                  "000011" &  -- C
                                  "010010" &  -- R
                                  "000101" &  -- E
                                  "000101" &  -- E
                                  "001110" &  -- N
                                  "101111" &  -- /  = 47
                                  "010000" &  -- P
                                  "010010" &  -- R
                                  "000101" &  -- E
                                  "010011" &  -- S
                                  "010011" &  -- S
                                  "100000" &  -- sp
                                  "000001" &  -- A
                                  "001110" &  -- N
                                  "011001" &  -- Y
                                  "100000" &  -- sp
                                  "001011" &  -- K
                                  "000101" &  -- E
                                  "011001" &  -- Y
                                  "100000" &  -- sp
                                  "010100" &  -- T
                                  "001111" &  -- O
                                  "100000" &  -- sp
                                  "000011" &  -- C
                                  "001111" &  -- O
                                  "001110" &  -- N
                                  "010100" &  -- T
                                  "001001" &  -- I
                                  "001110" &  -- N
                                  "010101" &  -- U
                                  "000101",   -- E
                x_position     => conv_std_logic_vector(SUBTITLE_X, 10),
                y_position     => conv_std_logic_vector(SUBTITLE_Y, 10),
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => subtitle_red,
                green_out      => subtitle_green,
                blue_out       => subtitle_blue);

   -- ---------------------------------------------------------------------------
   -- Header: "SELECT YOUR GAME MODE:" (SCALE 2)
   -- Note: your MIF has ':' at index 29 (binary 011101) per your customisation.
   -- ---------------------------------------------------------------------------
   Header : Word_Display
      generic map (STRING_LENGTH => 22,
                   SCALE         => 2,
                   TEXT_RED      => "1001",
                   TEXT_GREEN    => "0111",
                   TEXT_BLUE     => "1100")
      port map (clock          => video_clock,
                characters     => "010011" &  -- S
                                  "000101" &  -- E
                                  "001100" &  -- L
                                  "000101" &  -- E
                                  "000011" &  -- C
                                  "010100" &  -- T
                                  "100000" &  -- sp
                                  "011001" &  -- Y
                                  "001111" &  -- O
                                  "010101" &  -- U
                                  "010010" &  -- R
                                  "100000" &  -- sp
                                  "000111" &  -- G
                                  "000001" &  -- A
                                  "001101" &  -- M
                                  "000101" &  -- E
                                  "100000" &  -- sp
                                  "001101" &  -- M
                                  "001111" &  -- O
                                  "000100" &  -- D
                                  "000101" &  -- E
                                  "011101",   -- :
                x_position     => conv_std_logic_vector(HEADER_X, 10),
                y_position     => conv_std_logic_vector(HEADER_Y, 10),
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => header_red,
                green_out      => header_green,
                blue_out       => header_blue);

   -- ---------------------------------------------------------------------------
   -- TRAINING button: small (resting) + large (hovered)
   -- ---------------------------------------------------------------------------
   Training_Small : Word_Display
      generic map (STRING_LENGTH => 8,
                   SCALE         => 2,
                   TEXT_RED      => "1001",
                   TEXT_GREEN    => "0111",
                   TEXT_BLUE     => "1100")
      port map (clock          => video_clock,
                characters     => "010100" &  -- T
                                  "010010" &  -- R
                                  "000001" &  -- A
                                  "001001" &  -- I
                                  "001110" &  -- N
                                  "001001" &  -- I
                                  "001110" &  -- N
                                  "000111",   -- G
                x_position     => conv_std_logic_vector(TRAINING_SMALL_X, 10),
                y_position     => conv_std_logic_vector(TRAINING_SMALL_Y, 10),
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => training_small_red,
                green_out      => training_small_green,
                blue_out       => training_small_blue);

   Training_Large : Word_Display
      generic map (STRING_LENGTH => 8,
                   SCALE         => 3,
                   TEXT_RED      => "1001",
                   TEXT_GREEN    => "0111",
                   TEXT_BLUE     => "1100")
      port map (clock          => video_clock,
                characters     => "010100" &  -- T
                                  "010010" &  -- R
                                  "000001" &  -- A
                                  "001001" &  -- I
                                  "001110" &  -- N
                                  "001001" &  -- I
                                  "001110" &  -- N
                                  "000111",   -- G
                x_position     => conv_std_logic_vector(TRAINING_LARGE_X, 10),
                y_position     => conv_std_logic_vector(TRAINING_LARGE_Y, 10),
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => training_large_red,
                green_out      => training_large_green,
                blue_out       => training_large_blue);

   -- ---------------------------------------------------------------------------
   -- SINGLE PLAYER button: small + large
   -- ---------------------------------------------------------------------------
   Single_Player_Small : Word_Display
      generic map (STRING_LENGTH => 13,
                   SCALE         => 2,
                   TEXT_RED      => "1001",
                   TEXT_GREEN    => "0111",
                   TEXT_BLUE     => "1100")
      port map (clock          => video_clock,
                characters     => "010011" &  -- S
                                  "001001" &  -- I
                                  "001110" &  -- N
                                  "000111" &  -- G
                                  "001100" &  -- L
                                  "000101" &  -- E
                                  "100000" &  -- sp
                                  "010000" &  -- P
                                  "001100" &  -- L
                                  "000001" &  -- A
                                  "011001" &  -- Y
                                  "000101" &  -- E
                                  "010010",   -- R
                x_position     => conv_std_logic_vector(SINGLE_PLAYER_SMALL_X, 10),
                y_position     => conv_std_logic_vector(SINGLE_PLAYER_SMALL_Y, 10),
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => single_player_small_red,
                green_out      => single_player_small_green,
                blue_out       => single_player_small_blue);

   Single_Player_Large : Word_Display
      generic map (STRING_LENGTH => 13,
                   SCALE         => 3,
                   TEXT_RED      => "1001",
                   TEXT_GREEN    => "0111",
                   TEXT_BLUE     => "1100")
      port map (clock          => video_clock,
                characters     => "010011" &  -- S
                                  "001001" &  -- I
                                  "001110" &  -- N
                                  "000111" &  -- G
                                  "001100" &  -- L
                                  "000101" &  -- E
                                  "100000" &  -- sp
                                  "010000" &  -- P
                                  "001100" &  -- L
                                  "000001" &  -- A
                                  "011001" &  -- Y
                                  "000101" &  -- E
                                  "010010",   -- R
                x_position     => conv_std_logic_vector(SINGLE_PLAYER_LARGE_X, 10),
                y_position     => conv_std_logic_vector(SINGLE_PLAYER_LARGE_Y, 10),
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => single_player_large_red,
                green_out      => single_player_large_green,
                blue_out       => single_player_large_blue);

   
   -- ---------------------------------------------------------------------------
   -- Hover mux per button: large pixels when hovered, small pixels otherwise.
   -- ---------------------------------------------------------------------------
   training_red   <= training_large_red   when training_hovered = '1' else training_small_red;
   training_green <= training_large_green when training_hovered = '1' else training_small_green;
   training_blue  <= training_large_blue  when training_hovered = '1' else training_small_blue;

   single_player_red   <= single_player_large_red   when single_player_hovered = '1' else single_player_small_red;
   single_player_green <= single_player_large_green when single_player_hovered = '1' else single_player_small_green;
   single_player_blue  <= single_player_large_blue  when single_player_hovered = '1' else single_player_small_blue;

   -- ---------------------------------------------------------------------------
   -- Output compositor: only the layers belonging to the current state are visible.
   -- ---------------------------------------------------------------------------
   Output_Compositor : process(screen_state,
                               title_red,         title_green,         title_blue,
                               credits_one_red,   credits_one_green,   credits_one_blue,
                               credits_two_red,   credits_two_green,   credits_two_blue,
                               subtitle_red,      subtitle_green,      subtitle_blue,
                               header_red,        header_green,        header_blue,
                               training_red,      training_green,      training_blue,
                               single_player_red, single_player_green, single_player_blue)
   begin
      case screen_state is
         when title_screen =>
            red_out   <= title_red   or credits_one_red   or credits_two_red   or subtitle_red;
            green_out <= title_green or credits_one_green or credits_two_green or subtitle_green;
            blue_out  <= title_blue  or credits_one_blue  or credits_two_blue  or subtitle_blue;

         when mode_select =>
            red_out   <= header_red   or training_red   or single_player_red;
            green_out <= header_green or training_green or single_player_green;
            blue_out  <= header_blue  or training_blue  or single_player_blue;

         when game_running =>
            red_out   <= (others => '0');
            green_out <= (others => '0');
            blue_out  <= (others => '0');
      end case;
   end process Output_Compositor;

end architecture start_screen_behaviour;	