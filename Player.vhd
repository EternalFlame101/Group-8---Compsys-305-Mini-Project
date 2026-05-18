library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Player is
   generic (SCREEN_WIDTH        : positive := 640;
            SCREEN_HEIGHT       : positive := 480;
            SPRITE_SIZE         : positive := 32;
            SPRITE_SCALE        : positive := 4;
            WALK_FRAME_DURATION : positive := 5;     -- vsyncs per walking frame (~12 fps)
            JUMP_TOTAL_FRAMES   : positive := 120;   -- vsyncs for full jump (2 s at 60 Hz)
            JUMP_PEAK_HEIGHT    : positive := 60);   -- pixels above ground at apex
   port (clock, reset, vertical_sync             : in  std_logic;
         pixel_row, pixel_column                 : in  std_logic_vector(9 downto 0);
         mouse_left_click                        : in  std_logic;
         player_red, player_green, player_blue   : out std_logic_vector(3 downto 0);
         player_lane                             : out std_logic_vector(1 downto 0);
         player_state                            : out std_logic);
end entity Player;

architecture player_behaviour of Player is

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

   -- Pixel-space constants derived from generics.
   constant SCALED_SPRITE_SIZE : positive := SPRITE_SIZE * SPRITE_SCALE;
   constant LANE_1_CENTRE_X    : positive := SCREEN_WIDTH / 2;
   constant BASE_SPRITE_Y      : positive := SCREEN_HEIGHT - SCALED_SPRITE_SIZE;
   constant JUMP_HALFWAY       : positive := JUMP_TOTAL_FRAMES / 2;

   -- Lane is fixed to middle for now; will be muxed when lane switching is added.
   signal current_lane     : std_logic_vector(1 downto 0) := "01";
   signal current_state    : std_logic                    := '0';

   -- Walking animation: 2-bit index cycles "00" -> "01" -> "10" -> "11" -> "00".
   --   "00", "10" -> neutral
   --   "01"       -> neutralleft
   --   "11"       -> neutralright
   -- Giving the loop: neutral, neutralleft, neutral, neutralright.
   signal walk_frame_index : std_logic_vector(1 downto 0)             := "00";
   signal walk_vsync_count : integer range 0 to WALK_FRAME_DURATION   := 0;

   -- Jump animation counter (0 = on ground, JUMP_HALFWAY = apex, back to 0 to land).
   signal jump_frame_count  			: integer range 0 to JUMP_TOTAL_FRAMES := 0;
   signal jump_pixel_offset     		: integer range 0 to JUMP_TOTAL_FRAMES := 0;
	
	-- |T - 2t| - frame distance from the apex (peak when 0, edges when JUMP_TOTAL_FRAMES).
   signal jump_distance_from_apex 	: integer range 0 to JUMP_TOTAL_FRAMES := 0;

   -- Edge-detect registers for vsync and mouse click.
   signal vsync_previous : std_logic := '0';
   signal click_previous : std_logic := '0';

   -- Sprite top-left position on screen.
   signal sprite_x_position : std_logic_vector(9 downto 0);
   signal sprite_y_position : std_logic_vector(9 downto 0);

   -- RGB outputs from each per-frame ROM.
   signal neutral_frame_red, neutral_frame_green, neutral_frame_blue : std_logic_vector(3 downto 0);
   signal left_frame_red,    left_frame_green,    left_frame_blue    : std_logic_vector(3 downto 0);
   signal right_frame_red,   right_frame_green,   right_frame_blue   : std_logic_vector(3 downto 0);

begin

   -- ---------------------------------------------------------------------------
   -- Sprite positioning
   -- ---------------------------------------------------------------------------
   -- Middle lane, dead-centre horizontally (lane 0 and lane 2 X-coords TBD when
   -- lane switching is added).
   sprite_x_position <= conv_std_logic_vector(LANE_1_CENTRE_X - (SCALED_SPRITE_SIZE / 2), 10);

   -- Vertical = bottom of screen minus current jump offset.
   sprite_y_position <= conv_std_logic_vector(BASE_SPRITE_Y - jump_pixel_offset, 10);

	-- Parabolic jump arc:
   --   distance_from_apex = |T - 2t|   ranges 0 (apex) to T (start/end of jump)
   --   height = peak - peak * distance^2 / T^2
   -- Easy to swap for a LUT later if a non-ballistic feel is wanted.
   jump_distance_from_apex <= abs(JUMP_TOTAL_FRAMES - 2 * jump_frame_count);

   jump_pixel_offset <= 0 when current_state = '0' else
                        JUMP_PEAK_HEIGHT
                        - (JUMP_PEAK_HEIGHT * jump_distance_from_apex * jump_distance_from_apex)
                          / (JUMP_TOTAL_FRAMES * JUMP_TOTAL_FRAMES);

   -- ---------------------------------------------------------------------------
   -- Per-frame sprite ROMs
   -- ---------------------------------------------------------------------------
   Neutral_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "py_files/img_to_mif/mif/neutral.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position,
                red_out      => neutral_frame_red,
                green_out    => neutral_frame_green,
                blue_out     => neutral_frame_blue);

   Left_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "py_files/img_to_mif/mif/neutralleft.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position,
                red_out      => left_frame_red,
                green_out    => left_frame_green,
                blue_out     => left_frame_blue);

   Right_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "py_files/img_to_mif/mif/neutralright.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position,
                red_out      => right_frame_red,
                green_out    => right_frame_green,
                blue_out     => right_frame_blue);

   -- ---------------------------------------------------------------------------
   -- Animation state machine: advances once per vertical-sync rising edge (60 Hz)
   -- ---------------------------------------------------------------------------
	Animation_Process : process(clock, reset)
   begin
      if reset = '1' then
         current_state    <= '0';
         walk_frame_index <= "00";
         walk_vsync_count <= 0;
         jump_frame_count <= 0;
         vsync_previous   <= '0';
         click_previous   <= '0';
      elsif rising_edge(clock) then
         vsync_previous <= vertical_sync;

         if (vertical_sync = '1') and (vsync_previous = '0') then

            if current_state = '0' then
               -- Grounded: cycle walking frames.
               if walk_vsync_count = WALK_FRAME_DURATION - 1 then
                  walk_vsync_count <= 0;
                  walk_frame_index <= walk_frame_index + 1;
               else
                  walk_vsync_count <= walk_vsync_count + 1;
               end if;

               -- Rising edge of left-click between this and the previous vsync.
               if (mouse_left_click = '1') and (click_previous = '0') then
                  current_state    <= '1';
                  jump_frame_count <= 0;
               end if;

            else
               -- Jumping: advance counter; return to grounded after full arc.
               if jump_frame_count = JUMP_TOTAL_FRAMES - 1 then
                  current_state    <= '0';
                  jump_frame_count <= 0;
               else
                  jump_frame_count <= jump_frame_count + 1;
               end if;
            end if;

            -- Sample click state once per vsync for next frame's edge detection.
            click_previous <= mouse_left_click;

         end if;
      end if;
   end process Animation_Process;

   -- ---------------------------------------------------------------------------
   -- Frame mux: jumping always shows neutral; walking cycles per walk_frame_index.
   -- ---------------------------------------------------------------------------
   Frame_Selector : process(current_state, walk_frame_index,
                            neutral_frame_red, neutral_frame_green, neutral_frame_blue,
                            left_frame_red,    left_frame_green,    left_frame_blue,
                            right_frame_red,   right_frame_green,   right_frame_blue)
   begin
      if current_state = '1' then
         player_red   <= neutral_frame_red;
         player_green <= neutral_frame_green;
         player_blue  <= neutral_frame_blue;
      else
         case walk_frame_index is
            when "00" =>
               player_red   <= neutral_frame_red;
               player_green <= neutral_frame_green;
               player_blue  <= neutral_frame_blue;
            when "01" =>
               player_red   <= left_frame_red;
               player_green <= left_frame_green;
               player_blue  <= left_frame_blue;
            when "10" =>
               player_red   <= neutral_frame_red;
               player_green <= neutral_frame_green;
               player_blue  <= neutral_frame_blue;
            when others =>
               player_red   <= right_frame_red;
               player_green <= right_frame_green;
               player_blue  <= right_frame_blue;
         end case;
      end if;
   end process Frame_Selector;

   player_lane  <= current_lane;
   player_state <= current_state;

end architecture player_behaviour;