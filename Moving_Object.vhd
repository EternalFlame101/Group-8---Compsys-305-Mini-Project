library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ------------------------------------------------------------------------------
-- Moving_Object
--   Draws a perspective-correct 3D-ish object travelling along one of three
--   lanes of the racetrack. The object is composed of three faces: a front,
--   a top, and a side (left side when in lane 2, right side when in lane 0,
--   no side when centred in lane 1).
--
--   Geometry data (raw dimensions per distance step) comes from Object_ROM.
--   Track perspective data (spread per distance step) comes from
--   Perspective_ROM via the same shared module used by Track_Generator.
--
--   The object's distance from the camera is tracked in obj_distance and
--   advances once per VGA frame (detected on the falling edge of
--   vertical_sync). The 'speed' input controls how many distance steps
--   are advanced per frame.
--
--   Generic parameters:
--     REAL_HEIGHT - maximum modelled object height (max useful value: 120)
--     REAL_WIDTH  - maximum modelled object width  (max useful value: 80)
--     LANE        - which track lane the object travels in: 0, 1, or 2
--
--   All clocked sub-components (the two ROMs and the Moving process) share
--   the same clock, which should be the VGA pixel clock (video_clock).
-- ------------------------------------------------------------------------------
entity Moving_Object is
   generic (REAL_HEIGHT : positive            := 60;
            REAL_WIDTH  : positive            := 80;
            LANE        : integer range 0 to 2 := 1);
   port (enable, clock, vertical_sync : in  std_logic;
			reset, obj_reset, arrived 	  : in  std_logic;
         pixel_column, pixel_row      : in  std_logic_vector(9 downto 0);
         speed                        : in  std_logic_vector(3 downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Moving_Object;

architecture moving_object_behaviour of Moving_Object is

   -- ---------------------------------------------------------------------------
   -- Components
   -- ---------------------------------------------------------------------------
   component Object_ROM is
      port (clock         : in  std_logic;
            track_row     : in  std_logic_vector(9 downto 0);
            obj_sd_output : out std_logic_vector(9 downto 0);
            obj_y_output  : out std_logic_vector(9 downto 0);
            obj_h_output  : out std_logic_vector(9 downto 0);
            obj_w_output  : out std_logic_vector(9 downto 0);
            obj_wb_output : out std_logic_vector(9 downto 0);
            top_h_output  : out std_logic_vector(9 downto 0);
            top_taper     : out std_logic_vector(9 downto 0);
            side_taper    : out std_logic_vector(9 downto 0));
   end component Object_ROM;

   component Perspective_ROM is
      port (clock              : in  std_logic;
            track_row          : in  std_logic_vector(9 downto 0);
            perspective_output : out std_logic_vector(9 downto 0));
   end component Perspective_ROM;

   -- ---------------------------------------------------------------------------
   -- Constants
   -- ---------------------------------------------------------------------------
   constant TRACK_CENTRE_X : std_logic_vector(9 downto 0) := conv_std_logic_vector(320, 10);

   -- ---------------------------------------------------------------------------
   -- Drawing-enable flags for each face of the object
   -- ---------------------------------------------------------------------------
   signal object_front_on : std_logic;
   signal object_side_on  : std_logic;
   signal left_side_on    : std_logic;
   signal right_side_on   : std_logic;
   signal object_top_on   : std_logic;

   -- One-cycle delayed copy of vertical_sync, used to detect the falling
   -- edge that triggers a per-frame distance update.
   signal vertical_sync_prev : std_logic;

   -- ---------------------------------------------------------------------------
   -- Object scaling: raw ROM values multiplied by generic REAL_HEIGHT/REAL_WIDTH
   -- and then divided down (via bit-slicing) to get final pixel dimensions.
   -- ---------------------------------------------------------------------------
   signal object_height_raw     : std_logic_vector(9 downto 0);
   signal object_width_raw      : std_logic_vector(9 downto 0);
   signal object_height         : std_logic_vector(9 downto 0);
   signal object_width          : std_logic_vector(9 downto 0);
   signal scale_height_product  : std_logic_vector(19 downto 0);
   signal scale_width_product   : std_logic_vector(19 downto 0);

   signal object_width_back_raw   : std_logic_vector(9 downto 0);
   signal object_height_back_raw  : std_logic_vector(9 downto 0);
   signal scale_width_back_product  : std_logic_vector(19 downto 0);
   signal scale_height_back_product : std_logic_vector(19 downto 0);

   signal top_height_raw        : std_logic_vector(9 downto 0);
   signal scale_top_height_product : std_logic_vector(19 downto 0);

   -- ---------------------------------------------------------------------------
   -- Object distance from camera (0 = at camera, larger = further away).
   -- Initialised to maximum so the object spawns from the horizon.
   -- TODO: drive this from a real reset signal instead of relying on
   -- signal-initialisation semantics.
   -- ---------------------------------------------------------------------------
   signal object_distance : std_logic_vector(9 downto 0) := (others => '1');

   -- ---------------------------------------------------------------------------
   -- Per-face colours
   -- ---------------------------------------------------------------------------
   signal side_red,  side_green,  side_blue  : std_logic_vector(3 downto 0);
   signal top_red,   top_green,   top_blue   : std_logic_vector(3 downto 0);
   signal object_red, object_green, object_blue : std_logic_vector(3 downto 0);

   -- ---------------------------------------------------------------------------
   -- Side-face geometry signals (left side for lane 2, right side for lane 0)
   -- ---------------------------------------------------------------------------
   signal side_local_row             : std_logic_vector(9 downto 0);
   signal inverted_local             : std_logic_vector(9 downto 0);
   signal actual_side_shift          : std_logic_vector(9 downto 0);
   signal actual_side_shift_clamped  : std_logic_vector(9 downto 0);
   signal side_product               : std_logic_vector(19 downto 0);
   signal side_taper_signal          : std_logic_vector(9 downto 0);

   -- ---------------------------------------------------------------------------
   -- Top-face geometry signals
   -- ---------------------------------------------------------------------------
   signal top_height                 : std_logic_vector(9 downto 0);
   signal top_left                   : std_logic_vector(9 downto 0);
   signal top_right                  : std_logic_vector(9 downto 0);
   signal top_taper_signal           : std_logic_vector(9 downto 0);
   signal top_local_row              : std_logic_vector(9 downto 0);
   signal top_inverted_local         : std_logic_vector(9 downto 0);
   signal top_product                : std_logic_vector(19 downto 0);
   signal top_edge_shift             : std_logic_vector(9 downto 0);

   signal top_max_extension          : std_logic_vector(9 downto 0);
   signal top_max_product            : std_logic_vector(19 downto 0);

   -- ---------------------------------------------------------------------------
   -- Back-width tapering: the back of the object is narrower than the front,
   -- and we interpolate between them as we move up the top face.
   -- ---------------------------------------------------------------------------
   signal object_width_back     : std_logic_vector(9 downto 0);
   signal back_w_at_row         : std_logic_vector(9 downto 0);
   signal width_diff            : std_logic_vector(9 downto 0);
   signal width_diff_product    : std_logic_vector(19 downto 0);

   -- ---------------------------------------------------------------------------
   -- Back-height tapering: similar to back-width but for the side face
   -- ---------------------------------------------------------------------------
   signal object_height_back    : std_logic_vector(9 downto 0);
   signal height_diff           : std_logic_vector(9 downto 0);
   signal side_column_offset    : std_logic_vector(9 downto 0);
   signal side_top_boundary     : std_logic_vector(9 downto 0);
   signal height_diff_product   : std_logic_vector(19 downto 0);

   -- ---------------------------------------------------------------------------
   -- Object screen position (centre coordinates)
   -- ---------------------------------------------------------------------------
   signal object_x : std_logic_vector(9 downto 0);
   signal object_y : std_logic_vector(9 downto 0);

   -- ---------------------------------------------------------------------------
   -- Track perspective signals
   -- ---------------------------------------------------------------------------
   signal spread : std_logic_vector(9 downto 0);

   -- spread max is around 310. Multiplying by 11 and bit-shifting right by 4
   -- approximates a factor of 2/3 while keeping enough bits to avoid overflow.
   signal lane_offset_product : std_logic_vector(13 downto 0);
   signal lane_offset         : std_logic_vector(9 downto 0);

	
	-- Lane detection
	signal arrived : std_logic;
	signal obj_reset : std_logic;
begin

   -- ---------------------------------------------------------------------------
   -- ROM lookups (clocked: must be on the same clock as the pixel pipeline)
   -- ---------------------------------------------------------------------------
   Object_Geometry_Lookup : Object_ROM
      port map (clock         => clock,
                track_row     => object_distance,
                obj_sd_output => object_height_back_raw,
                obj_y_output  => object_y,
                obj_h_output  => object_height_raw,
                obj_w_output  => object_width_raw,
                obj_wb_output => object_width_back_raw,
                top_h_output  => top_height_raw,
                top_taper     => top_taper_signal,
                side_taper    => side_taper_signal);

   Track_Perspective_Lookup : Perspective_ROM
      port map (clock              => clock,
                track_row          => object_distance,
                perspective_output => spread);

   -- ---------------------------------------------------------------------------
   -- Lane positioning: given the track spread at this distance, place the
   -- object centre-X at the appropriate lane position.
   -- ---------------------------------------------------------------------------
   lane_offset_product <= conv_std_logic_vector(11, 4) * spread;
   lane_offset         <= lane_offset_product(13 downto 4);

   object_x <= (TRACK_CENTRE_X + lane_offset) when (LANE = 2) else
               (TRACK_CENTRE_X)               when (LANE = 1) else
               (TRACK_CENTRE_X - lane_offset);

   -- ---------------------------------------------------------------------------
   -- Object dimension scaling: raw ROM data * generic size, divided by the
   -- model's max (120 height, 80 width) via bit-slicing. Constants come from
   -- the Python-side data generation scripts.
   -- ---------------------------------------------------------------------------
   scale_height_product <= object_height_raw * conv_std_logic_vector(REAL_HEIGHT, 10);
   scale_width_product  <= object_width_raw  * conv_std_logic_vector(REAL_WIDTH,  10);
   object_height <= scale_height_product(16 downto 7);
   object_width  <= scale_width_product(15 downto 6);

   scale_width_back_product  <= object_width_back_raw  * conv_std_logic_vector(REAL_WIDTH,  10);
   scale_height_back_product <= object_height_back_raw * conv_std_logic_vector(REAL_HEIGHT, 10);
   object_width_back  <= scale_width_back_product(15 downto 6);
   object_height_back <= scale_height_back_product(16 downto 7);

   scale_top_height_product <= top_height_raw * conv_std_logic_vector(REAL_HEIGHT, 10);
   top_height               <= scale_top_height_product(16 downto 7);

   -- ---------------------------------------------------------------------------
   -- Per-frame distance update: advance object_distance by 'speed' on the
   -- falling edge of vertical_sync (i.e. once per frame), unless we've
   -- reached zero (object has arrived at the camera).
   -- ---------------------------------------------------------------------------
   Moving : process(clock)
   begin
      if rising_edge(clock) then
			arrived <= '0';
         vertical_sync_prev <= vertical_sync;
			
			if obj_reset = '1' then
				object_distance <= (others => '1');
			
         elsif ((vertical_sync = '0') and (vertical_sync_prev = '1')) then
            if (enable = '1') then
               if (object_distance = "0000000000") then
                  arrived <= '1';
               else
                  object_distance <= object_distance + ("000000" & speed);
               end if;
            end if;
         end if;
      end if;
   end process Moving;

   -- ---------------------------------------------------------------------------
   -- Front face: a filled rectangle centred on (object_x, object_y).
   -- ---------------------------------------------------------------------------
   object_front_on <= '1' when ((pixel_row    >= object_y - object_height) and
                                (pixel_row    <= object_y)                 and
                                (pixel_column >= object_x - object_width)  and
                                (pixel_column <= object_x + object_width))
                      else '0';

   object_red   <= "0001" when (object_front_on = '1') else "0000";
   object_green <= "0111" when (object_front_on = '1') else "0000";
   object_blue  <= "0001" when (object_front_on = '1') else "0000";

   -- ---------------------------------------------------------------------------
   -- Back-edge interpolation: width and height at the back of the object are
   -- smaller than at the front, and we lerp between them along the top face
   -- and side face respectively.
   -- ---------------------------------------------------------------------------
   width_diff <= (object_width - object_width_back) when (object_width >= object_width_back)
                                                    else (others => '0');
   width_diff_product <= width_diff * top_local_row;
   back_w_at_row      <= object_width - width_diff_product(17 downto 8);

   height_diff <= (object_height - object_height_back) when (object_height >= object_height_back)
                                                       else (others => '0');

   side_column_offset <= ((object_x - object_width) - pixel_column)
                            when (LANE = 2 and pixel_column <= object_x - object_width) else
                         (pixel_column - (object_x + object_width))
                            when (LANE = 0) else
                         (others => '0');
   height_diff_product <= height_diff * side_column_offset;
   side_top_boundary   <= height_diff_product(18 downto 9);

   -- ---------------------------------------------------------------------------
   -- Side face: extends out from the front face in the direction away from
   -- centre lane. Taper grows linearly with row distance from the top of
   -- the front face, clamped so it can never extend beyond the top face.
   -- ---------------------------------------------------------------------------
   side_local_row <= (pixel_row - (object_y - object_height)) when (pixel_row >= (object_y - object_height))
                                                              else (others => '0');

   inverted_local    <= object_height - side_local_row;
   side_product      <= side_taper_signal * inverted_local;
   actual_side_shift <= side_product(17 downto 8);

   -- Clamp: side extension can't exceed the top face's extension, and is
   -- forced to zero when we're at the very bottom of the side face.
   actual_side_shift_clamped <= top_max_extension  when (actual_side_shift >= top_max_extension) else
                                (others => '0')    when (inverted_local = "0000000000")         else
                                actual_side_shift;

   left_side_on  <= '1' when ((pixel_row    >= object_y - object_height - top_height)         and
                              (pixel_row    <= object_y - side_top_boundary)                  and
                              (pixel_column >= object_x - object_width - actual_side_shift_clamped) and
                              (pixel_column <= object_x - object_width))
                    else '0';

   right_side_on <= '1' when ((pixel_row    >= object_y - object_height - top_height)         and
                              (pixel_row    <= object_y - side_top_boundary)                  and
                              (pixel_column <= object_x + object_width + actual_side_shift_clamped) and
                              (pixel_column >= object_x + object_width))
                    else '0';

   object_side_on <= left_side_on  when (LANE = 2) else
                     right_side_on when (LANE = 0) else
                     '0';

   side_red   <= "0001" when (object_side_on = '1') else "0000";
   side_green <= "0011" when (object_side_on = '1') else "0000";
   side_blue  <= "0001" when (object_side_on = '1') else "0000";

   -- ---------------------------------------------------------------------------
   -- Top face: a quadrilateral that tapers inward toward the back of the
   -- object. Its left and right edges shift inward as we move from front
   -- (bottom of top face) to back (top of top face).
   -- ---------------------------------------------------------------------------
   top_local_row <= (pixel_row - (object_y - object_height - top_height))
                       when (pixel_row >= (object_y - object_height - top_height))
                       else (others => '0');

   top_inverted_local <= (top_height - top_local_row) when (top_height >= top_local_row)
                                                      else (others => '0');

   top_product    <= top_taper_signal * top_inverted_local;
   top_edge_shift <= top_product(17 downto 8);

   top_max_product   <= top_taper_signal * top_height;
   top_max_extension <= top_max_product(17 downto 8);

   -- Left/right edges of the top face. The shifts are doubled (& '0') on the
   -- "outside" of the lane to give the proper perspective skew.
   top_left  <= (object_x - back_w_at_row - top_edge_shift)               when LANE = 2 else
                (object_x - back_w_at_row + top_edge_shift(9 downto 0))   when LANE = 1 else
                (object_x - back_w_at_row + (top_edge_shift(8 downto 0) & '0'));

   top_right <= (object_x + back_w_at_row - (top_edge_shift(8 downto 0) & '0')) when LANE = 2 else
                (object_x + back_w_at_row - top_edge_shift(9 downto 0))         when LANE = 1 else
                (object_x + back_w_at_row + top_edge_shift);

   object_top_on <= '1' when ((pixel_row    >= object_y - object_height - top_height) and
                              (pixel_row    <= object_y - object_height)              and
                              (pixel_column >= top_left)                              and
                              (pixel_column <= top_right))
                    else '0';

   top_red   <= "0001" when (object_top_on = '1') else "0000";
   top_green <= "1111" when (object_top_on = '1') else "0000";
   top_blue  <= "0001" when (object_top_on = '1') else "0000";

   -- ---------------------------------------------------------------------------
   -- Final per-pixel priority mux: front > top > side
   -- ---------------------------------------------------------------------------
   red_out   <= object_red   when (object_front_on = '1') else
                top_red      when (object_top_on   = '1') else
                side_red;

   green_out <= object_green when (object_front_on = '1') else
                top_green    when (object_top_on   = '1') else
                side_green;

   blue_out  <= object_blue  when (object_front_on = '1') else
                top_blue     when (object_top_on   = '1') else
                side_blue;

end architecture moving_object_behaviour;