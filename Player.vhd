library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Player is
   generic (SCREEN_WIDTH           : positive := 640;
            SCREEN_HEIGHT          : positive := 480;
            SPRITE_SIZE            : positive := 32;
            SPRITE_SCALE           : positive := 4;
            WALK_FRAME_DURATION    : positive := 5;
            JUMP_TOTAL_FRAMES      : positive := 120;
            JUMP_PEAK_HEIGHT       : positive := 60;
            LANE_TRANSITION_FRAMES : positive := 64);   -- ~1.07 s at 60 Hz
   port (clock, reset, vertical_sync             : in  std_logic;
         pixel_row, pixel_column                 : in  std_logic_vector(9 downto 0);
         mouse_left_click                        : in  std_logic;   -- shift LEFT
         mouse_right_click                       : in  std_logic;   -- shift RIGHT (new)
         jump_input                              : in  std_logic;   -- jump (new; KEY(1))
         player_red, player_green, player_blue   : out std_logic_vector(3 downto 0);
         player_lane                             : out std_logic_vector(1 downto 0);
         player_state                            : out std_logic;
         cat_view_position                       : out std_logic_vector(7 downto 0));
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

   constant SCALED_SPRITE_SIZE : positive := SPRITE_SIZE * SPRITE_SCALE;
   constant LANE_1_CENTRE_X    : positive := SCREEN_WIDTH / 2;
   constant BASE_SPRITE_Y      : positive := SCREEN_HEIGHT - SCALED_SPRITE_SIZE;
   constant LANE_RESOLUTION    : integer  := 64;   -- 1/64 lane per step; matches transition frames

   -- Logical lane (0 = left, 1 = middle, 2 = right). Only flips when transition completes.
   signal current_lane_int : integer range 0 to 2 := 1;
   signal current_state    : std_logic            := '0';

   -- Walking animation (unchanged).
   signal walk_frame_index : std_logic_vector(1 downto 0)             := "00";
   signal walk_vsync_count : integer range 0 to WALK_FRAME_DURATION   := 0;

   -- Jump animation (unchanged).
   signal jump_frame_count        : integer range 0 to JUMP_TOTAL_FRAMES := 0;
   signal jump_pixel_offset       : integer range 0 to JUMP_TOTAL_FRAMES := 0;
   signal jump_distance_from_apex : integer range 0 to JUMP_TOTAL_FRAMES := 0;

   -- Lane transition state. view_pos_int is the signed fractional viewpoint:
   --   -64 = looking from lane 0, 0 = lane 1, +64 = lane 2.
   signal view_pos_int      : integer range -LANE_RESOLUTION to LANE_RESOLUTION := 0;
   signal view_pos_target   : integer range -LANE_RESOLUTION to LANE_RESOLUTION := 0;
   signal transition_active : std_logic := '0';
   signal transition_step   : integer range -1 to 1 := 0;

   -- Edge-detect registers for vsync and all three inputs.
   signal vsync_previous       : std_logic := '0';
   signal click_previous       : std_logic := '0';
   signal right_click_previous : std_logic := '0';
   signal jump_input_previous  : std_logic := '0';

   signal sprite_x_position : std_logic_vector(9 downto 0);
   signal sprite_y_position : std_logic_vector(9 downto 0);

   signal neutral_frame_red, neutral_frame_green, neutral_frame_blue : std_logic_vector(3 downto 0);
   signal left_frame_red,    left_frame_green,    left_frame_blue    : std_logic_vector(3 downto 0);
   signal right_frame_red,   right_frame_green,   right_frame_blue   : std_logic_vector(3 downto 0);

begin

   -- ---------------------------------------------------------------------------
   -- Sprite positioning: cat is permanently centred horizontally; the world
   -- shifts around it via cat_view_position.
   -- ---------------------------------------------------------------------------
   sprite_x_position <= conv_std_logic_vector(LANE_1_CENTRE_X - (SCALED_SPRITE_SIZE / 2), 10);
   sprite_y_position <= conv_std_logic_vector(BASE_SPRITE_Y - jump_pixel_offset, 10);

   jump_distance_from_apex <= abs(JUMP_TOTAL_FRAMES - 2 * jump_frame_count);

   jump_pixel_offset <= 0 when current_state = '0' else
                        JUMP_PEAK_HEIGHT
                        - (JUMP_PEAK_HEIGHT * jump_distance_from_apex * jump_distance_from_apex)
                          / (JUMP_TOTAL_FRAMES * JUMP_TOTAL_FRAMES);

   -- ---------------------------------------------------------------------------
   -- Per-frame sprite ROMs (unchanged).
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
   -- State machine: walking/jumping plus lane-transition ramp. One vsync edge
   -- = one step (1/64 of a lane), so a full lane change takes 64 frames.
   -- ---------------------------------------------------------------------------
   Animation_Process : process(clock, reset)
   begin
      if reset = '1' then
         current_state        <= '0';
         walk_frame_index     <= "00";
         walk_vsync_count     <= 0;
         jump_frame_count     <= 0;
         vsync_previous       <= '0';
         click_previous       <= '0';
         right_click_previous <= '0';
         jump_input_previous  <= '0';
         current_lane_int     <= 1;
         view_pos_int         <= 0;
         view_pos_target      <= 0;
         transition_active    <= '0';
         transition_step      <= 0;
      elsif rising_edge(clock) then
         vsync_previous <= vertical_sync;

         if (vertical_sync = '1') and (vsync_previous = '0') then

            -- Walking / jumping animation (jump trigger remapped to jump_input).
            if current_state = '0' then
               if walk_vsync_count = WALK_FRAME_DURATION - 1 then
                  walk_vsync_count <= 0;
                  walk_frame_index <= walk_frame_index + 1;
               else
                  walk_vsync_count <= walk_vsync_count + 1;
               end if;

               if (jump_input = '1') and (jump_input_previous = '0') then
                  current_state    <= '1';
                  jump_frame_count <= 0;
               end if;
            else
               if jump_frame_count = JUMP_TOTAL_FRAMES - 1 then
                  current_state    <= '0';
                  jump_frame_count <= 0;
               else
                  jump_frame_count <= jump_frame_count + 1;
               end if;
            end if;

            -- Lane transition: ramp viewpoint then snap logical lane at the end.
            if transition_active = '1' then
               if view_pos_int = view_pos_target then
                  transition_active <= '0';
                  if view_pos_target = -LANE_RESOLUTION then
                     current_lane_int <= 0;
                  elsif view_pos_target = LANE_RESOLUTION then
                     current_lane_int <= 2;
                  else
                     current_lane_int <= 1;
                  end if;
               else
                  view_pos_int <= view_pos_int + transition_step;
               end if;
            else
               -- Right-click: shift one lane to the right (if not already in lane 2).
               if (mouse_right_click = '1') and (right_click_previous = '0') then
                  if current_lane_int = 0 then
                     view_pos_target   <= 0;
                     transition_step   <= 1;
                     transition_active <= '1';
                  elsif current_lane_int = 1 then
                     view_pos_target   <= LANE_RESOLUTION;
                     transition_step   <= 1;
                     transition_active <= '1';
                  end if;
               -- Left-click: shift one lane to the left (if not already in lane 0).
               elsif (mouse_left_click = '1') and (click_previous = '0') then
                  if current_lane_int = 2 then
                     view_pos_target   <= 0;
                     transition_step   <= -1;
                     transition_active <= '1';
                  elsif current_lane_int = 1 then
                     view_pos_target   <= -LANE_RESOLUTION;
                     transition_step   <= -1;
                     transition_active <= '1';
                  end if;
               end if;
            end if;

            click_previous       <= mouse_left_click;
            right_click_previous <= mouse_right_click;
            jump_input_previous  <= jump_input;
         end if;
      end if;
   end process Animation_Process;

   -- ---------------------------------------------------------------------------
   -- Frame mux (unchanged).
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

   player_lane       <= conv_std_logic_vector(current_lane_int, 2);
   player_state      <= current_state;
   cat_view_position <= conv_std_logic_vector(view_pos_int, 8);

end architecture player_behaviour;