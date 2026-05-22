library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Player is
   generic (SCREEN_WIDTH           : positive := 640;
            SCREEN_HEIGHT          : positive := 480;
            SPRITE_SIZE            : positive := 64;
            SPRITE_SCALE           : positive := 2;
            WALK_FRAME_DURATION    : positive := 8;
            JUMP_TOTAL_FRAMES      : positive := 120;
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
end entity Player;

architecture player_behaviour of Player is

   component Sprites_Display is
      generic (SPRITE_WIDTH  : positive := 64;
               SPRITE_HEIGHT : positive := 64;
               ADDR_BITS     : positive := 12;
               SCALE         : positive := 2;
               MIF_FILE      : string   := "Images_To_mif/mif/jasper.mif");
      port (clock                        : in  std_logic;
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            sprite_x,  sprite_y          : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Sprites_Display;

   constant SCALED_SPRITE_SIZE : positive := SPRITE_SIZE * SPRITE_SCALE;
   constant LANE_1_CENTRE_X    : positive := SCREEN_WIDTH / 2;
   constant BASE_SPRITE_Y      : positive := SCREEN_HEIGHT - SCALED_SPRITE_SIZE;
   constant LANE_RESOLUTION    : integer  := 64;
   constant ROLL_FRAME_STEP    : integer  := 8;
   constant TRANSITION_SPEED   : integer  := 2;

   -- Dive animation:
   --   6 frames (squish1, squish2, squish3, squish2, squish1, neutral),
   --   each held for DIVE_FRAME_DURATION vsyncs.
   --   Total = 6 * 6 = 36 vsyncs ~ 0.6 s at 60 Hz (close to the requested 0.5 s
   --   while keeping divisible integer math).
   --
   -- Fast-drop on dive-while-airborne:
   --   When dive is triggered mid-jump, jump_frame_count is snapped to
   --   (JUMP_TOTAL_FRAMES - FAST_DROP_TAIL_FRAMES) so the parabola plays its
   --   final tail rapidly. With FAST_DROP_TAIL_FRAMES = 10, the cat lands in
   --   10 vsyncs (~166 ms) regardless of how high it was.
   constant DIVE_TOTAL_FRAMES     : integer  := 36;
   constant DIVE_FRAME_DURATION   : integer  := 6;
   constant FAST_DROP_TAIL_FRAMES : integer  := 10;

   -- Logical state
   signal current_lane_int : integer range 0 to 2 := 1;
   signal current_state    : std_logic            := '0';
   signal walk_frame_index : std_logic_vector(2 downto 0)             := "000";
   signal walk_vsync_count : integer range 0 to WALK_FRAME_DURATION   := 0;
   signal jump_frame_count : integer range 0 to JUMP_TOTAL_FRAMES     := 0;

   -- Dive state. dive_active mirrors current_state for the jump: '1' while the
   -- 36-frame squish animation is playing, '0' otherwise. dive_frame_count
   -- counts vsyncs from 0..35 during a dive.
   signal dive_active           : std_logic := '0';
   signal dive_frame_count      : integer range 0 to DIVE_TOTAL_FRAMES := 0;
   signal dive_input_previous   : std_logic := '0';

   -- Jump-height math (now pipelined)
   signal jump_distance_from_apex    : integer range 0 to JUMP_TOTAL_FRAMES                       := 0;
   signal jump_distance_squared_comb : integer range 0 to JUMP_TOTAL_FRAMES * JUMP_TOTAL_FRAMES   := 0;
   signal jump_distance_squared_reg  : integer range 0 to JUMP_TOTAL_FRAMES * JUMP_TOTAL_FRAMES   := 0;
   signal jump_pixel_offset          : integer range 0 to JUMP_TOTAL_FRAMES                       := 0;
   signal sprite_y_position_comb     : std_logic_vector(9 downto 0);
   signal sprite_y_position_reg      : std_logic_vector(9 downto 0) := (others => '0');

   -- View transition
   signal view_pos_int      : integer range -LANE_RESOLUTION to LANE_RESOLUTION := 0;
   signal view_pos_target   : integer range -LANE_RESOLUTION to LANE_RESOLUTION := 0;
   signal transition_active : std_logic := '0';
   signal transition_step   : integer range -TRANSITION_SPEED to TRANSITION_SPEED := 0;
	
   -- '0' = left roll (negative direction), '1' = right roll (positive direction).
   -- Latched at transition start so the playback direction stays consistent even
   -- when view_pos_int crosses zero on a lane-2 -> lane-0 style move.
   signal roll_direction    : std_logic := '0';

   -- Roll frame index 0..7 selects which of the 8 rotated sprites is shown.
   -- For a LEFT roll  the order is -45, -90, -135, -180, -225, -270, -315, 0
   -- For a RIGHT roll the order is -315, -270, -225, -180, -135, -90, -45, 0
   -- (right roll is just the left-roll list reversed, since the artist drew
   -- the rotations counter-clockwise).
   signal roll_frame_index  : integer range 0 to 7 := 0;

   signal vsync_previous       : std_logic := '0';
   signal click_previous       : std_logic := '0';
   signal right_click_previous : std_logic := '0';
   signal jump_input_previous  : std_logic := '0';

   signal sprite_x_position : std_logic_vector(9 downto 0);

   -- Walk-cycle frame outputs (5 distinct frames; neutral_set2 is reused as
   -- both the standing pose and the 0-degree roll frame).
   signal neutral_frame_red,  neutral_frame_green,  neutral_frame_blue  : std_logic_vector(3 downto 0);
   signal left_1_frame_red,   left_1_frame_green,   left_1_frame_blue   : std_logic_vector(3 downto 0);
   signal left_2_frame_red,   left_2_frame_green,   left_2_frame_blue   : std_logic_vector(3 downto 0);
   signal right_1_frame_red,  right_1_frame_green,  right_1_frame_blue  : std_logic_vector(3 downto 0);
   signal right_2_frame_red,  right_2_frame_green,  right_2_frame_blue  : std_logic_vector(3 downto 0);

   -- Roll-frame outputs (7 rotated sprites; the 8th "0 degrees" slot reuses
   -- the neutral frame above).
   signal roll_045_frame_red, roll_045_frame_green, roll_045_frame_blue : std_logic_vector(3 downto 0);
   signal roll_090_frame_red, roll_090_frame_green, roll_090_frame_blue : std_logic_vector(3 downto 0);
   signal roll_135_frame_red, roll_135_frame_green, roll_135_frame_blue : std_logic_vector(3 downto 0);
   signal roll_180_frame_red, roll_180_frame_green, roll_180_frame_blue : std_logic_vector(3 downto 0);
   signal roll_225_frame_red, roll_225_frame_green, roll_225_frame_blue : std_logic_vector(3 downto 0);
   signal roll_270_frame_red, roll_270_frame_green, roll_270_frame_blue : std_logic_vector(3 downto 0);
   signal roll_315_frame_red, roll_315_frame_green, roll_315_frame_blue : std_logic_vector(3 downto 0);

   -- Dive (squish) frame outputs. The animation plays
   --   squish1 -> squish2 -> squish3 -> squish2 -> squish1 -> neutral
   -- so we only need three new ROMs (squish1, squish2, squish3); squish2 and
   -- squish1 are read twice each from the same ROMs, and the final neutral
   -- frame reuses the existing neutral_frame_* outputs.
   signal squish_1_frame_red, squish_1_frame_green, squish_1_frame_blue : std_logic_vector(3 downto 0);
   signal squish_2_frame_red, squish_2_frame_green, squish_2_frame_blue : std_logic_vector(3 downto 0);
   signal squish_3_frame_red, squish_3_frame_green, squish_3_frame_blue : std_logic_vector(3 downto 0);

begin

   -- ---------------------------------------------------------------------------
   -- Sprite x is a compile-time constant (cat is permanently centred).
   -- Sprite y goes through a 2-stage pipeline so the long chain
   --   jump_frame_count -> parabola math -> Sprites_Display ROM address
   -- splits into short hops. jump_frame_count only updates once per vsync, so
   -- the 2 cycles of added latency are invisible.
   -- ---------------------------------------------------------------------------
   sprite_x_position <= conv_std_logic_vector(LANE_1_CENTRE_X - (SCALED_SPRITE_SIZE / 2), 10);

   -- Stage 1 combinational: distance-from-apex and its square
   jump_distance_from_apex    <= abs(JUMP_TOTAL_FRAMES - 2 * jump_frame_count);
   jump_distance_squared_comb <= jump_distance_from_apex * jump_distance_from_apex;

   -- Stage 1 register
   Jump_Pipeline_Stage_1 : process(clock)
   begin
      if rising_edge(clock) then
         jump_distance_squared_reg <= jump_distance_squared_comb;
      end if;
   end process Jump_Pipeline_Stage_1;

   -- Stage 2 combinational: parabolic offset and final y-position
   jump_pixel_offset <= 0 when current_state = '0' else
                        JUMP_PEAK_HEIGHT
                        - (JUMP_PEAK_HEIGHT * jump_distance_squared_reg)
                          / (JUMP_TOTAL_FRAMES * JUMP_TOTAL_FRAMES);

   sprite_y_position_comb <= conv_std_logic_vector(BASE_SPRITE_Y - jump_pixel_offset, 10);

   -- Stage 2 register
   Sprite_Y_Pipeline : process(clock)
   begin
      if rising_edge(clock) then
         sprite_y_position_reg <= sprite_y_position_comb;
      end if;
   end process Sprite_Y_Pipeline;

   -- ---------------------------------------------------------------------------
   -- Walk-cycle sprite ROMs
   -- ---------------------------------------------------------------------------
   Neutral_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/neutral.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => neutral_frame_red,
                green_out    => neutral_frame_green,
                blue_out     => neutral_frame_blue);

   Left_1_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/left_1.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => left_1_frame_red,
                green_out    => left_1_frame_green,
                blue_out     => left_1_frame_blue);

   Left_2_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/left_2.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => left_2_frame_red,
                green_out    => left_2_frame_green,
                blue_out     => left_2_frame_blue);

   Right_1_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/right_1.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => right_1_frame_red,
                green_out    => right_1_frame_green,
                blue_out     => right_1_frame_blue);

   Right_2_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/right_2.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => right_2_frame_red,
                green_out    => right_2_frame_green,
                blue_out     => right_2_frame_blue);

   -- ---------------------------------------------------------------------------
   -- Roll-frame sprite ROMs (7 rotated sprites; 0-degree slot reuses neutral)
   -- ---------------------------------------------------------------------------
   Roll_045_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/-45.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => roll_045_frame_red,
                green_out    => roll_045_frame_green,
                blue_out     => roll_045_frame_blue);

   Roll_090_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/-90.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => roll_090_frame_red,
                green_out    => roll_090_frame_green,
                blue_out     => roll_090_frame_blue);

   Roll_135_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/-135.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => roll_135_frame_red,
                green_out    => roll_135_frame_green,
                blue_out     => roll_135_frame_blue);

   Roll_180_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/-180.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => roll_180_frame_red,
                green_out    => roll_180_frame_green,
                blue_out     => roll_180_frame_blue);

   Roll_225_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/-225.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => roll_225_frame_red,
                green_out    => roll_225_frame_green,
                blue_out     => roll_225_frame_blue);

   Roll_270_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/-270.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => roll_270_frame_red,
                green_out    => roll_270_frame_green,
                blue_out     => roll_270_frame_blue);

   Roll_315_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/-315.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => roll_315_frame_red,
                green_out    => roll_315_frame_green,
                blue_out     => roll_315_frame_blue);

   -- ---------------------------------------------------------------------------
   -- Dive (squish) sprite ROMs
   -- ---------------------------------------------------------------------------
   Squish_1_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/squish1.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => squish_1_frame_red,
                green_out    => squish_1_frame_green,
                blue_out     => squish_1_frame_blue);

   Squish_2_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/squish2.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => squish_2_frame_red,
                green_out    => squish_2_frame_green,
                blue_out     => squish_2_frame_blue);

   Squish_3_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "Images_To_mif/mif/squish3.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position_reg,
                red_out      => squish_3_frame_red,
                green_out    => squish_3_frame_green,
                blue_out     => squish_3_frame_blue);

   -- ---------------------------------------------------------------------------
   -- State machine
   -- ---------------------------------------------------------------------------
   Animation_Process : process(clock, reset)
      variable distance_travelled : integer range 0 to LANE_RESOLUTION;
   begin
      if reset = '1' then
         current_state        <= '0';
         walk_frame_index     <= "000";
         walk_vsync_count     <= 0;
         jump_frame_count     <= 0;
         dive_active          <= '0';
         dive_frame_count     <= 0;
         dive_input_previous  <= '0';
         vsync_previous       <= '0';
         click_previous       <= '0';
         right_click_previous <= '0';
         jump_input_previous  <= '0';
         view_pos_int         <= 0;
         view_pos_target      <= 0;
         transition_active    <= '0';
         transition_step      <= 0;
         roll_direction       <= '0';
         roll_frame_index     <= 0;
      elsif rising_edge(clock) then
         vsync_previous <= vertical_sync;

         if (vertical_sync = '1') and (vsync_previous = '0') then

            -- Walk cycle: only advances when not transitioning AND not jumping
            -- AND not diving. The cat is rolling/jumping/squishing during those
            -- states, not walking. Frame is held at neutral ("000") on the
            -- first vsync after a transition completes via the reset just below.
            if transition_active = '0' then
               if current_state = '0' and dive_active = '0' then
                  if walk_vsync_count = WALK_FRAME_DURATION - 1 then
                     walk_vsync_count <= 0;
                     walk_frame_index <= walk_frame_index + 1;
                  else
                     walk_vsync_count <= walk_vsync_count + 1;
                  end if;
               end if;
            else
               walk_vsync_count <= 0;
               walk_frame_index <= "000";
            end if;

            -- =============================================================
            -- Jump and dive state machines (mutually-overriding)
            -- =============================================================
            -- Override rules:
            --   * Jump and dive can each be triggered while the other is
            --     active. Dive-on-jump triggers a fast-drop (jump_frame_count
            --     snaps to the parabola tail) and starts the squish animation
            --     in parallel. Jump-on-dive cancels the squish and starts a
            --     fresh jump.
            --   * Roll (lane transition) does NOT cancel jump or dive, and
            --     jump/dive do NOT cancel an active roll -- they run in
            --     parallel (cat can roll while airborne or while squishing).
            --   * A second jump press while already jumping is ignored
            --     (no double-jump). Same for dive.
            -- These are evaluated independently so both edges arriving on the
            -- same vsync end up cleanly: dive-edge wins for state transition,
            -- but jump-edge can override it on the very next vsync.
            -- -------------------------------------------------------------

            -- Edge-detected inputs for this vsync.
            -- jump_edge = jump_input  rising edge
            -- dive_edge = dive_input  rising edge
            -- (Computed in-line below via the *_previous registers.)

            if (dive_input = '1') and (dive_input_previous = '0') and (dive_active = '0') then
               -- Dive edge AND not already diving: start dive. Cancel jump
               -- and snap to the parabola tail so the cat falls fast if
               -- airborne. Pressing dive while already diving does nothing
               -- (no re-dive / dive cancel).
               dive_active      <= '1';
               dive_frame_count <= 0;
               if current_state = '1' then
                  -- Airborne: snap jump_frame_count toward landing so the
                  -- remaining parabola arc plays out over FAST_DROP_TAIL_FRAMES
                  -- vsyncs. current_state stays '1' so jump_pixel_offset
                  -- continues to be derived from the parabola until the tail
                  -- completes normally below.
                  jump_frame_count <= JUMP_TOTAL_FRAMES - FAST_DROP_TAIL_FRAMES;
               end if;
            elsif (jump_input = '1') and (jump_input_previous = '0') and (current_state = '0') then
               -- Jump edge AND not already jumping: start jump. Cancel any
               -- active dive. Pressing jump while already jumping does
               -- nothing (no double-jump).
               current_state    <= '1';
               jump_frame_count <= 0;
               dive_active      <= '0';
               dive_frame_count <= 0;
            else
               -- No new input: advance whichever animations are running.

               -- Jump frame counter advance / completion.
               if current_state = '1' then
                  if jump_frame_count = JUMP_TOTAL_FRAMES - 1 then
                     current_state    <= '0';
                     jump_frame_count <= 0;
                  else
                     jump_frame_count <= jump_frame_count + 1;
                  end if;
               end if;

               -- Dive frame counter advance / completion.
               if dive_active = '1' then
                  if dive_frame_count = DIVE_TOTAL_FRAMES - 1 then
                     dive_active      <= '0';
                     dive_frame_count <= 0;
                  else
                     dive_frame_count <= dive_frame_count + 1;
                  end if;
               end if;
            end if;

            -- Lane transition + roll-frame index update
            if transition_active = '1' then
               if view_pos_int = view_pos_target then
                  transition_active <= '0';
                  roll_frame_index  <= 0;
                  -- current_lane_int is now derived combinationally from
                  -- view_pos_int (see assignment below), so it has already
                  -- switched when the cat passed the halfway point.
               else
                  view_pos_int <= view_pos_int + transition_step;

                  -- How many steps of the 64-step transition have we completed?
                  -- Used to pick which of the 8 roll frames to display.
                  -- distance_travelled = LANE_RESOLUTION - |view_pos_target - (view_pos_int + step)|
                  distance_travelled := LANE_RESOLUTION - abs(view_pos_target - (view_pos_int + transition_step));

                  -- Map 1..63 -> 0..6, and 64 (final step) -> 7 (the 0-degree
                  -- frame, which is just neutral). distance_travelled / 8
                  -- gives 0 at steps 1..7, 1 at 8..15, ..., 7 at 56..63, and 8
                  -- at 64; clamp the 64 case down to 7.
                  if distance_travelled / ROLL_FRAME_STEP >= 7 then
                     roll_frame_index <= 7;
                  else
                     roll_frame_index <= distance_travelled / ROLL_FRAME_STEP;
                  end if;
               end if;
            else
               if (shift_right_input = '1') and (right_click_previous = '0') then
                  if current_lane_int = 0 then
                     view_pos_target   <= 0;
                     transition_step   <= TRANSITION_SPEED;
                     transition_active <= '1';
                     roll_direction    <= '1';
                     roll_frame_index  <= 0;
                  elsif current_lane_int = 1 then
                     view_pos_target   <= LANE_RESOLUTION;
                     transition_step   <= TRANSITION_SPEED;
                     transition_active <= '1';
                     roll_direction    <= '1';
                     roll_frame_index  <= 0;
                  end if;
               elsif (shift_left_input = '1') and (click_previous = '0') then
                  if current_lane_int = 2 then
                     view_pos_target   <= 0;
                     transition_step   <= -TRANSITION_SPEED;
                     transition_active <= '1';
                     roll_direction    <= '0';
                     roll_frame_index  <= 0;
                  elsif current_lane_int = 1 then
                     view_pos_target   <= -LANE_RESOLUTION;
                     transition_step   <= -TRANSITION_SPEED;
                     transition_active <= '1';
                     roll_direction    <= '0';
                     roll_frame_index  <= 0;
                  end if;
               end if;
            end if;

            click_previous       <= shift_left_input;
            right_click_previous <= shift_right_input;
            jump_input_previous  <= jump_input;
            dive_input_previous  <= dive_input;
         end if;
      end if;
   end process Animation_Process;

   -- ---------------------------------------------------------------------------
   -- Frame mux.
   -- Priority: rolling (lane transition) > dive (squish) > walking.
   -- Jumping does NOT enter the mux -- it only shifts the sprite up vertically
   -- via jump_pixel_offset; the underlying frame (walk or roll) keeps playing.
   -- Dive DOES enter the mux because the cat changes shape (squish frames).
   -- ---------------------------------------------------------------------------
   Frame_Selector : process(transition_active, roll_direction, roll_frame_index,
                            dive_active, dive_frame_count,
                            current_state, walk_frame_index,
                            neutral_frame_red,  neutral_frame_green,  neutral_frame_blue,
                            left_1_frame_red,   left_1_frame_green,   left_1_frame_blue,
                            left_2_frame_red,   left_2_frame_green,   left_2_frame_blue,
                            right_1_frame_red,  right_1_frame_green,  right_1_frame_blue,
                            right_2_frame_red,  right_2_frame_green,  right_2_frame_blue,
                            roll_045_frame_red, roll_045_frame_green, roll_045_frame_blue,
                            roll_090_frame_red, roll_090_frame_green, roll_090_frame_blue,
                            roll_135_frame_red, roll_135_frame_green, roll_135_frame_blue,
                            roll_180_frame_red, roll_180_frame_green, roll_180_frame_blue,
                            roll_225_frame_red, roll_225_frame_green, roll_225_frame_blue,
                            roll_270_frame_red, roll_270_frame_green, roll_270_frame_blue,
                            roll_315_frame_red, roll_315_frame_green, roll_315_frame_blue,
                            squish_1_frame_red, squish_1_frame_green, squish_1_frame_blue,
                            squish_2_frame_red, squish_2_frame_green, squish_2_frame_blue,
                            squish_3_frame_red, squish_3_frame_green, squish_3_frame_blue)
      variable dive_step : integer range 0 to 5;
   begin
      if transition_active = '1' then
         -- Rolling. Left roll plays  -45, -90, -135, -180, -225, -270, -315, 0.
         -- Right roll plays the reverse: -315, -270, -225, -180, -135, -90, -45, 0.
         if roll_direction = '0' then
            case roll_frame_index is
               when 0 =>
                  player_red <= roll_045_frame_red; player_green <= roll_045_frame_green; player_blue <= roll_045_frame_blue;
               when 1 =>
                  player_red <= roll_090_frame_red; player_green <= roll_090_frame_green; player_blue <= roll_090_frame_blue;
               when 2 =>
                  player_red <= roll_135_frame_red; player_green <= roll_135_frame_green; player_blue <= roll_135_frame_blue;
               when 3 =>
                  player_red <= roll_180_frame_red; player_green <= roll_180_frame_green; player_blue <= roll_180_frame_blue;
               when 4 =>
                  player_red <= roll_225_frame_red; player_green <= roll_225_frame_green; player_blue <= roll_225_frame_blue;
               when 5 =>
                  player_red <= roll_270_frame_red; player_green <= roll_270_frame_green; player_blue <= roll_270_frame_blue;
               when 6 =>
                  player_red <= roll_315_frame_red; player_green <= roll_315_frame_green; player_blue <= roll_315_frame_blue;
               when others =>
                  player_red <= neutral_frame_red;  player_green <= neutral_frame_green;  player_blue <= neutral_frame_blue;
            end case;
         else
            case roll_frame_index is
               when 0 =>
                  player_red <= roll_315_frame_red; player_green <= roll_315_frame_green; player_blue <= roll_315_frame_blue;
               when 1 =>
                  player_red <= roll_270_frame_red; player_green <= roll_270_frame_green; player_blue <= roll_270_frame_blue;
               when 2 =>
                  player_red <= roll_225_frame_red; player_green <= roll_225_frame_green; player_blue <= roll_225_frame_blue;
               when 3 =>
                  player_red <= roll_180_frame_red; player_green <= roll_180_frame_green; player_blue <= roll_180_frame_blue;
               when 4 =>
                  player_red <= roll_135_frame_red; player_green <= roll_135_frame_green; player_blue <= roll_135_frame_blue;
               when 5 =>
                  player_red <= roll_090_frame_red; player_green <= roll_090_frame_green; player_blue <= roll_090_frame_blue;
               when 6 =>
                  player_red <= roll_045_frame_red; player_green <= roll_045_frame_green; player_blue <= roll_045_frame_blue;
               when others =>
                  player_red <= neutral_frame_red;  player_green <= neutral_frame_green;  player_blue <= neutral_frame_blue;
            end case;
         end if;
      elsif dive_active = '1' then
         -- Dive. 6-step squish animation, DIVE_FRAME_DURATION (=6) vsyncs per
         -- step, total 36 vsyncs. Step sequence:
         --   0 -> squish1   1 -> squish2   2 -> squish3
         --   3 -> squish2   4 -> squish1   5 -> neutral
         dive_step := dive_frame_count / DIVE_FRAME_DURATION;
         case dive_step is
            when 0 =>
               player_red <= squish_1_frame_red; player_green <= squish_1_frame_green; player_blue <= squish_1_frame_blue;
            when 1 =>
               player_red <= squish_2_frame_red; player_green <= squish_2_frame_green; player_blue <= squish_2_frame_blue;
            when 2 =>
               player_red <= squish_3_frame_red; player_green <= squish_3_frame_green; player_blue <= squish_3_frame_blue;
            when 3 =>
               player_red <= squish_2_frame_red; player_green <= squish_2_frame_green; player_blue <= squish_2_frame_blue;
            when 4 =>
               player_red <= squish_1_frame_red; player_green <= squish_1_frame_green; player_blue <= squish_1_frame_blue;
            when others =>
               player_red <= neutral_frame_red;  player_green <= neutral_frame_green;  player_blue <= neutral_frame_blue;
         end case;
      else
         -- Walking. 8-frame cycle:
         --   000 neutral, 001 right_1, 010 right_2, 011 right_1,
         --   100 neutral, 101 left_1,  110 left_2,  111 left_1
         case walk_frame_index is
            when "000" =>
               player_red <= neutral_frame_red;  player_green <= neutral_frame_green;  player_blue <= neutral_frame_blue;
            when "001" =>
               player_red <= right_1_frame_red;  player_green <= right_1_frame_green;  player_blue <= right_1_frame_blue;
            when "010" =>
               player_red <= right_2_frame_red;  player_green <= right_2_frame_green;  player_blue <= right_2_frame_blue;
            when "011" =>
               player_red <= right_1_frame_red;  player_green <= right_1_frame_green;  player_blue <= right_1_frame_blue;
            when "100" =>
               player_red <= neutral_frame_red;  player_green <= neutral_frame_green;  player_blue <= neutral_frame_blue;
            when "101" =>
               player_red <= left_1_frame_red;   player_green <= left_1_frame_green;   player_blue <= left_1_frame_blue;
            when "110" =>
               player_red <= left_2_frame_red;   player_green <= left_2_frame_green;   player_blue <= left_2_frame_blue;
            when others =>
               player_red <= left_1_frame_red;   player_green <= left_1_frame_green;   player_blue <= left_1_frame_blue;
         end case;
      end if;
   end process Frame_Selector;

   -- Derive the current lane combinationally from view_pos_int. The cat is
   -- considered "in" a lane once its view position has crossed the midpoint
   -- (half of LANE_RESOLUTION = 32) between two lanes, so collision detection
   -- and Object_Manager priority track the cat's visual position rather than
   -- waiting for the full 64-frame transition to complete.
   current_lane_int <= 0 when view_pos_int < -(LANE_RESOLUTION / 2) else
                       2 when view_pos_int >  (LANE_RESOLUTION / 2) else
                       1;

   player_lane       <= conv_std_logic_vector(current_lane_int, 2);
   player_state      <= current_state;
   cat_view_position <= conv_std_logic_vector(view_pos_int, 8);

end architecture player_behaviour;