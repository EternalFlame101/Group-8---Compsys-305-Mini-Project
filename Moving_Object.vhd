library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Moving_Object is
   generic (REAL_HEIGHT : positive             := 60;
            REAL_WIDTH  : positive             := 80;
            LANE        : integer range 0 to 2 := 1);
   port (enable, clock, vertical_sync : in  std_logic;
         pixel_column, pixel_row      : in  std_logic_vector(9 downto 0);
         speed                        : in  std_logic_vector(3 downto 0);
         cat_view_position            : in  std_logic_vector(7 downto 0);
         row_out                      : out std_logic_vector(9 downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Moving_Object;

architecture moving_object_behaviour of Moving_Object is

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

   constant TRACK_CENTRE_X      : std_logic_vector(9 downto 0) := conv_std_logic_vector(320, 10);
   constant LANE_HOME_POSITION  : integer := (LANE - 1) * 64;

   -- ROM outputs
   signal lane_spread_rom            : std_logic_vector(9 downto 0);
   signal object_y_rom               : std_logic_vector(9 downto 0);
   signal object_height_rom          : std_logic_vector(9 downto 0);
   signal object_width_rom           : std_logic_vector(9 downto 0);
   signal object_width_back_rom      : std_logic_vector(9 downto 0);
   signal object_height_back_rom     : std_logic_vector(9 downto 0);
   signal top_height_rom             : std_logic_vector(9 downto 0);
   signal top_taper_rom              : std_logic_vector(9 downto 0);
   signal side_taper_rom             : std_logic_vector(9 downto 0);

   -- Frame Stage 1 combinational
   signal cat_view_position_integer            : integer range -64 to 64;
   signal box_position_relative_to_cat_combinational : integer range -128 to 128;
   signal cat_distance_from_box_centre_combinational : integer range 0 to 128;
   signal cat_distance_from_box_centre_slv_combinational : std_logic_vector(7 downto 0);
   signal box_side_of_cat_combinational         : std_logic;
   signal box_is_off_centre_combinational       : std_logic;

   signal object_height_scaled_product_combinational      : std_logic_vector(19 downto 0);
   signal object_width_scaled_product_combinational       : std_logic_vector(19 downto 0);
   signal object_width_back_scaled_product_combinational  : std_logic_vector(19 downto 0);
   signal object_height_back_scaled_product_combinational : std_logic_vector(19 downto 0);
   signal top_height_scaled_product_combinational         : std_logic_vector(19 downto 0);
   signal object_height_combinational             : std_logic_vector(9 downto 0);
   signal object_width_combinational              : std_logic_vector(9 downto 0);
   signal object_width_back_combinational         : std_logic_vector(9 downto 0);
   signal object_height_back_combinational        : std_logic_vector(9 downto 0);
   signal top_height_combinational                : std_logic_vector(9 downto 0);
   signal lane_offset_product_combinational       : std_logic_vector(13 downto 0);
   signal lane_offset_combinational               : std_logic_vector(9 downto 0);

   -- Frame Stage 1 registers
   signal cat_distance_from_box_centre_slv_stage_1 : std_logic_vector(7 downto 0);
   signal box_side_of_cat_stage_1                  : std_logic;
   signal box_is_off_centre_stage_1                : std_logic;
   signal object_height_stage_1                    : std_logic_vector(9 downto 0);
   signal object_width_stage_1                     : std_logic_vector(9 downto 0);
   signal object_height_back_stage_1               : std_logic_vector(9 downto 0);
   signal object_width_back_stage_1                : std_logic_vector(9 downto 0);
   signal top_height_stage_1                       : std_logic_vector(9 downto 0);
   signal lane_offset_stage_1                      : std_logic_vector(9 downto 0);
   signal top_taper_stage_1                        : std_logic_vector(9 downto 0);
   signal side_taper_stage_1                       : std_logic_vector(9 downto 0);
   signal object_y_stage_1                         : std_logic_vector(9 downto 0);

   -- Frame Stage 2 combinational
   signal width_difference_combinational             : std_logic_vector(9 downto 0);
   signal height_difference_combinational            : std_logic_vector(9 downto 0);
   signal object_x_shift_product_combinational       : std_logic_vector(17 downto 0);
   signal object_x_shift_combinational               : std_logic_vector(9 downto 0);
   signal object_x_shift_true_combinational          : std_logic_vector(10 downto 0);
   signal object_x_combinational                     : std_logic_vector(9 downto 0);
   signal box_off_screen_combinational               : std_logic;
   signal top_combined_taper_combinational           : std_logic_vector(17 downto 0);
   signal side_combined_taper_combinational          : std_logic_vector(17 downto 0);
   signal top_max_extension_product_combinational    : std_logic_vector(19 downto 0);
   signal top_max_extension_combinational            : std_logic_vector(9 downto 0);

   -- Frame Stage 2 registers (used by per-pixel logic)
   signal cat_distance_from_box_centre_slv_stage_2 : std_logic_vector(7 downto 0);
   signal box_side_of_cat_stage_2                  : std_logic;
   signal box_is_off_centre_stage_2                : std_logic;
   signal object_height_stage_2                    : std_logic_vector(9 downto 0);
   signal object_width_stage_2                     : std_logic_vector(9 downto 0);
   signal top_height_stage_2                       : std_logic_vector(9 downto 0);
   signal width_difference_stage_2                 : std_logic_vector(9 downto 0);
   signal height_difference_stage_2                : std_logic_vector(9 downto 0);
   signal object_x_stage_2                         : std_logic_vector(9 downto 0);
   signal object_y_stage_2                         : std_logic_vector(9 downto 0);
   signal top_combined_taper_stage_2               : std_logic_vector(17 downto 0);
   signal side_combined_taper_stage_2              : std_logic_vector(17 downto 0);
   signal top_max_extension_stage_2                : std_logic_vector(9 downto 0);
   signal top_taper_stage_2                        : std_logic_vector(9 downto 0);
   signal box_off_screen_stage_2                   : std_logic;

   -- Distance update
   signal object_distance    : std_logic_vector(9 downto 0) := (others => '1');
   signal vertical_sync_previous : std_logic;

   -- Per-pixel Stage 1 combinational (after frame Stage 2 registers)
   signal rows_from_top_face_top              : std_logic_vector(9 downto 0);
   signal rows_from_top_face_bottom           : std_logic_vector(9 downto 0);
   signal rows_from_side_face_top             : std_logic_vector(9 downto 0);
   signal rows_from_side_face_bottom          : std_logic_vector(9 downto 0);
   signal side_column_offset                  : std_logic_vector(9 downto 0);

   signal width_difference_product       : std_logic_vector(19 downto 0);
   signal height_difference_product      : std_logic_vector(19 downto 0);
   signal top_skew_product               : std_logic_vector(27 downto 0);
   signal side_shift_product             : std_logic_vector(27 downto 0);
   signal top_max_extension_scaled_product : std_logic_vector(17 downto 0);
   signal baseline_top_cave_in_product   : std_logic_vector(19 downto 0);

   signal back_width_at_row_combinational            : std_logic_vector(9 downto 0);
   signal side_top_boundary_combinational            : std_logic_vector(9 downto 0);
   signal off_axis_top_skew_combinational            : std_logic_vector(9 downto 0);
   signal baseline_top_cave_in_combinational         : std_logic_vector(9 downto 0);
   signal side_shift_unclamped_scaled_combinational  : std_logic_vector(9 downto 0);
   signal top_max_extension_scaled_combinational     : std_logic_vector(9 downto 0);
   signal far_edge_cave_in_combinational             : std_logic_vector(9 downto 0);
   signal near_edge_magnitude_combinational          : std_logic_vector(9 downto 0);
   signal near_edge_is_outward_combinational         : std_logic;

   -- Per-pixel Stage 1 registers
   signal side_top_boundary_pixel_stage_1            : std_logic_vector(9 downto 0);
   signal pixel_row_pixel_stage_1                    : std_logic_vector(9 downto 0);
   signal pixel_column_pixel_stage_1                 : std_logic_vector(9 downto 0);

   -- Boundary values + underflow/overflow flags computed in Pixel Stage 1.
   -- These exist to handle the case where a box partially extends off-screen
   -- left (causing unsigned subtraction to underflow) or off-screen right
   -- (causing 10-bit unsigned addition to overflow). Each comparison in Stage 2
   -- ORs the flag into the comparison result so an off-screen boundary forces
   -- the comparison to pass.
   signal front_face_left_boundary_combinational     : std_logic_vector(9 downto 0);
   signal front_face_left_underflow_combinational    : std_logic;
   signal front_face_right_boundary_combinational    : std_logic_vector(9 downto 0);
   signal front_face_right_overflow_combinational    : std_logic;
   signal side_face_left_boundary_combinational      : std_logic_vector(9 downto 0);
   signal side_face_left_underflow_combinational     : std_logic;
   signal side_face_right_boundary_combinational     : std_logic_vector(9 downto 0);
   signal side_face_right_overflow_combinational     : std_logic;
   signal top_left_combinational                     : std_logic_vector(9 downto 0);
   signal top_left_underflow_combinational           : std_logic;
   signal top_right_combinational                    : std_logic_vector(9 downto 0);
   signal top_right_overflow_combinational           : std_logic;

   -- Pixel Stage 1 registered versions
   signal front_face_left_boundary_pixel_stage_1     : std_logic_vector(9 downto 0);
   signal front_face_left_underflow_pixel_stage_1    : std_logic;
   signal front_face_right_boundary_pixel_stage_1    : std_logic_vector(9 downto 0);
   signal front_face_right_overflow_pixel_stage_1    : std_logic;
   signal side_face_left_boundary_pixel_stage_1      : std_logic_vector(9 downto 0);
   signal side_face_left_underflow_pixel_stage_1     : std_logic;
   signal side_face_right_boundary_pixel_stage_1     : std_logic_vector(9 downto 0);
   signal side_face_right_overflow_pixel_stage_1     : std_logic;
   signal top_left_pixel_stage_1                     : std_logic_vector(9 downto 0);
   signal top_left_underflow_pixel_stage_1           : std_logic;
   signal top_right_pixel_stage_1                    : std_logic_vector(9 downto 0);
   signal top_right_overflow_pixel_stage_1           : std_logic;
   signal box_off_screen_pixel_stage_1               : std_logic;

   -- Per-pixel Stage 2 combinational
   signal object_front_on          : std_logic;
   signal object_top_on            : std_logic;
   signal left_side_on             : std_logic;
   signal right_side_on            : std_logic;
   signal object_side_on           : std_logic;
   signal red_combinational, green_combinational, blue_combinational : std_logic_vector(3 downto 0);

   -- Output registers
   signal red_out_register, green_out_register, blue_out_register : std_logic_vector(3 downto 0);

begin

   -- ROM lookups
   Object_Geometry_Lookup : Object_ROM
      port map (clock         => clock,
                track_row     => object_distance,
                obj_sd_output => object_height_back_rom,
                obj_y_output  => object_y_rom,
                obj_h_output  => object_height_rom,
                obj_w_output  => object_width_rom,
                obj_wb_output => object_width_back_rom,
                top_h_output  => top_height_rom,
                top_taper     => top_taper_rom,
                side_taper    => side_taper_rom);

   Track_Perspective_Lookup : Perspective_ROM
      port map (clock              => clock,
                track_row          => object_distance,
                perspective_output => lane_spread_rom);

   -- ========================================================================
   -- Frame Stage 1 combinational
   -- ========================================================================
   cat_view_position_integer                         <= conv_integer(signed(cat_view_position));
   box_position_relative_to_cat_combinational        <= LANE_HOME_POSITION - cat_view_position_integer;
   cat_distance_from_box_centre_combinational        <= box_position_relative_to_cat_combinational
                                                          when box_position_relative_to_cat_combinational >= 0
                                                          else -box_position_relative_to_cat_combinational;
   cat_distance_from_box_centre_slv_combinational    <= conv_std_logic_vector(cat_distance_from_box_centre_combinational, 8);
   box_side_of_cat_combinational                     <= '1' when box_position_relative_to_cat_combinational >  0 else '0';
   box_is_off_centre_combinational                   <= '1' when box_position_relative_to_cat_combinational /= 0 else '0';

   object_height_scaled_product_combinational      <= object_height_rom      * conv_std_logic_vector(REAL_HEIGHT, 10);
   object_width_scaled_product_combinational       <= object_width_rom       * conv_std_logic_vector(REAL_WIDTH,  10);
   object_width_back_scaled_product_combinational  <= object_width_back_rom  * conv_std_logic_vector(REAL_WIDTH,  10);
   object_height_back_scaled_product_combinational <= object_height_back_rom * conv_std_logic_vector(REAL_HEIGHT, 10);
   top_height_scaled_product_combinational         <= top_height_rom         * conv_std_logic_vector(REAL_HEIGHT, 10);

   object_height_combinational      <= object_height_scaled_product_combinational(16 downto 7);
   object_width_combinational       <= object_width_scaled_product_combinational(15 downto 6);
   object_width_back_combinational  <= object_width_back_scaled_product_combinational(15 downto 6);
   object_height_back_combinational <= object_height_back_scaled_product_combinational(16 downto 7);
   top_height_combinational         <= top_height_scaled_product_combinational(16 downto 7);

   lane_offset_product_combinational <= conv_std_logic_vector(11, 4) * lane_spread_rom;
   lane_offset_combinational         <= lane_offset_product_combinational(13 downto 4);

   Frame_Stage_1 : process(clock)
   begin
      if rising_edge(clock) then
         cat_distance_from_box_centre_slv_stage_1 <= cat_distance_from_box_centre_slv_combinational;
         box_side_of_cat_stage_1                  <= box_side_of_cat_combinational;
         box_is_off_centre_stage_1                <= box_is_off_centre_combinational;
         object_height_stage_1                    <= object_height_combinational;
         object_width_stage_1                     <= object_width_combinational;
         object_height_back_stage_1               <= object_height_back_combinational;
         object_width_back_stage_1                <= object_width_back_combinational;
         top_height_stage_1                       <= top_height_combinational;
         lane_offset_stage_1                      <= lane_offset_combinational;
         top_taper_stage_1                        <= top_taper_rom;
         side_taper_stage_1                       <= side_taper_rom;
         object_y_stage_1                         <= object_y_rom;
      end if;
   end process Frame_Stage_1;

   -- ========================================================================
   -- Frame Stage 2 combinational
   -- ========================================================================
   width_difference_combinational  <= (object_width_stage_1  - object_width_back_stage_1)
                                         when object_width_stage_1  >= object_width_back_stage_1
                                         else (others => '0');
   height_difference_combinational <= (object_height_stage_1 - object_height_back_stage_1)
                                         when object_height_stage_1 >= object_height_back_stage_1
                                         else (others => '0');

   object_x_shift_product_combinational <= cat_distance_from_box_centre_slv_stage_1 * lane_offset_stage_1;
   -- True 11-bit value of the shift (uncapped). Used to detect when the box
   -- would render entirely off-screen and should be gated off.
   object_x_shift_true_combinational    <= object_x_shift_product_combinational(16 downto 6);
   -- Original 10-bit shift used in object_x. This wraps when the true value is
   -- >= 1024, but that's OK because in that case box_off_screen_combinational
   -- will fire and gate the rendering anyway.
   object_x_shift_combinational         <= object_x_shift_product_combinational(15 downto 6);
   object_x_combinational               <= TRACK_CENTRE_X + object_x_shift_combinational
                                              when box_side_of_cat_stage_1 = '1'
                                              else TRACK_CENTRE_X - object_x_shift_combinational;
   -- "Box fully off-screen" detection. The critical threshold is where object_x
   -- itself wraps: object_x = TRACK_CENTRE_X - shift wraps when shift > 320.
   -- Once object_x wraps, all downstream comparisons go haywire (the wrapped
   -- value lands in the 'overflow' range and falsely triggers the overflow
   -- flag, causing faces to render across the whole screen). So we must gate
   -- the module off the moment object_x would wrap, even though this means
   -- the box pops off-screen instead of fading at the edge. The mirror case
   -- (object_x = TRACK_CENTRE_X + shift) wraps at shift = 1024 - 320 = 704,
   -- but both share the same shift signal so we use the smaller threshold for
   -- safety on both sides.
   box_off_screen_combinational <= '1' when object_x_shift_true_combinational > conv_std_logic_vector(320, 11) else '0';

   top_combined_taper_combinational      <= top_taper_stage_1  * cat_distance_from_box_centre_slv_stage_1;
   side_combined_taper_combinational     <= side_taper_stage_1 * cat_distance_from_box_centre_slv_stage_1;
   top_max_extension_product_combinational <= top_taper_stage_1 * top_height_stage_1;
   top_max_extension_combinational         <= top_max_extension_product_combinational(17 downto 8);

   Frame_Stage_2 : process(clock)
   begin
      if rising_edge(clock) then
         cat_distance_from_box_centre_slv_stage_2 <= cat_distance_from_box_centre_slv_stage_1;
         box_side_of_cat_stage_2                  <= box_side_of_cat_stage_1;
         box_is_off_centre_stage_2                <= box_is_off_centre_stage_1;
         object_height_stage_2                    <= object_height_stage_1;
         object_width_stage_2                     <= object_width_stage_1;
         top_height_stage_2                       <= top_height_stage_1;
         width_difference_stage_2                 <= width_difference_combinational;
         height_difference_stage_2                <= height_difference_combinational;
         object_x_stage_2                         <= object_x_combinational;
         object_y_stage_2                         <= object_y_stage_1;
         top_combined_taper_stage_2               <= top_combined_taper_combinational;
         side_combined_taper_stage_2              <= side_combined_taper_combinational;
         top_max_extension_stage_2                <= top_max_extension_combinational;
         top_taper_stage_2                        <= top_taper_stage_1;
         box_off_screen_stage_2                   <= box_off_screen_combinational;
      end if;
   end process Frame_Stage_2;

   -- ========================================================================
   -- Distance update (per-frame)
   -- ========================================================================
   Moving : process(clock)
   begin
      if rising_edge(clock) then
         vertical_sync_previous <= vertical_sync;
         if ((vertical_sync = '0') and (vertical_sync_previous = '1')) then
            if (enable = '1') then
               if (object_distance = "0000000000") then
                  null;
               else
                  object_distance <= object_distance + ("000000" & speed);
               end if;
            end if;
         end if;
      end if;
   end process Moving;

   -- ========================================================================
   -- Per-pixel Stage 1 combinational: row derivations + all multiplies
   -- ========================================================================
   rows_from_top_face_top <= (pixel_row - (object_y_stage_2 - object_height_stage_2 - top_height_stage_2))
                                when (pixel_row >= (object_y_stage_2 - object_height_stage_2 - top_height_stage_2))
                                else (others => '0');
   rows_from_top_face_bottom <= (top_height_stage_2 - rows_from_top_face_top)
                                   when (top_height_stage_2 >= rows_from_top_face_top) else (others => '0');

   rows_from_side_face_top <= (pixel_row - (object_y_stage_2 - object_height_stage_2))
                                 when (pixel_row >= (object_y_stage_2 - object_height_stage_2))
                                 else (others => '0');
   rows_from_side_face_bottom <= (object_height_stage_2 - rows_from_side_face_top)
                                    when (object_height_stage_2 >= rows_from_side_face_top) else (others => '0');

   side_column_offset <= ((object_x_stage_2 - object_width_stage_2) - pixel_column)
                            when (box_side_of_cat_stage_2 = '1' and
                                  pixel_column <= object_x_stage_2 - object_width_stage_2) else
                         (pixel_column - (object_x_stage_2 + object_width_stage_2))
                            when (box_side_of_cat_stage_2 = '0' and
                                  box_is_off_centre_stage_2 = '1' and
                                  pixel_column >= object_x_stage_2 + object_width_stage_2) else
                         (others => '0');

   width_difference_product         <= width_difference_stage_2  * rows_from_top_face_top;
   height_difference_product        <= height_difference_stage_2 * side_column_offset;
   top_skew_product                 <= top_combined_taper_stage_2  * rows_from_top_face_bottom;
   side_shift_product               <= side_combined_taper_stage_2 * rows_from_side_face_bottom;
   top_max_extension_scaled_product <= top_max_extension_stage_2 * cat_distance_from_box_centre_slv_stage_2;
   baseline_top_cave_in_product     <= top_taper_stage_2 * rows_from_top_face_bottom;

   back_width_at_row_combinational            <= object_width_stage_2 - width_difference_product(17 downto 8);
   side_top_boundary_combinational            <= height_difference_product(18 downto 9);
   off_axis_top_skew_combinational            <= top_skew_product(23 downto 14);
   baseline_top_cave_in_combinational         <= baseline_top_cave_in_product(18 downto 9);
   side_shift_unclamped_scaled_combinational  <= side_shift_product(23 downto 14);
   top_max_extension_scaled_combinational     <= top_max_extension_scaled_product(15 downto 6);

   -- Combine baseline and off-axis amounts here in Stage 1 (registered) so
   -- Stage 2 is just a 2-way mux. far_edge_cave_in is always positive; the
   -- near edge is signed, so we encode it as (magnitude, is_outward).
   far_edge_cave_in_combinational     <= baseline_top_cave_in_combinational + off_axis_top_skew_combinational;
   near_edge_magnitude_combinational  <= (baseline_top_cave_in_combinational - off_axis_top_skew_combinational)
                                            when baseline_top_cave_in_combinational >= off_axis_top_skew_combinational
                                            else (off_axis_top_skew_combinational - baseline_top_cave_in_combinational);
   near_edge_is_outward_combinational <= '1' when off_axis_top_skew_combinational > baseline_top_cave_in_combinational
                                             else '0';

   -- ========================================================================
   -- Boundary values + underflow/overflow flags (Pixel Stage 1 combinational)
   -- ========================================================================
   -- Front face boundaries. Computed in 12-bit to cleanly detect underflow
   -- (bit 11 = '1') and overflow into [1024, 2047] (bit 11 = '0' AND bit 10 = '1').
   Front_Face_Boundary : process(object_x_stage_2, object_width_stage_2)
      variable left_extended  : std_logic_vector(11 downto 0);
      variable right_extended : std_logic_vector(11 downto 0);
   begin
      left_extended  := ("00" & object_x_stage_2) - ("00" & object_width_stage_2);
      right_extended := ("00" & object_x_stage_2) + ("00" & object_width_stage_2);
      front_face_left_boundary_combinational  <= left_extended(9 downto 0);
      front_face_left_underflow_combinational <= left_extended(11);
      front_face_right_boundary_combinational <= right_extended(9 downto 0);
      if right_extended(11) = '0' and right_extended(10) = '1' then
         front_face_right_overflow_combinational <= '1';
      else
         front_face_right_overflow_combinational <= '0';
      end if;
   end process Front_Face_Boundary;

   -- Top face edges. Computed in 12-bit space so that natural large values
   -- (up to ~2046) don't collide with the underflow sign bit. Bit 11 = '1' on
   -- the result means the true value is negative (underflowed); bits 10..0
   -- carry the magnitude. The boundary value stored is the low 10 bits, which
   -- are valid when the flag is '0'.
   Top_Edges_Boundary : process(object_x_stage_2, back_width_at_row_combinational,
                                far_edge_cave_in_combinational,
                                near_edge_magnitude_combinational,
                                near_edge_is_outward_combinational,
                                box_side_of_cat_stage_2, box_is_off_centre_stage_2)
      variable left_extended  : std_logic_vector(11 downto 0);
      variable right_extended : std_logic_vector(11 downto 0);
      variable object_x_extended  : std_logic_vector(11 downto 0);
      variable back_w_extended    : std_logic_vector(11 downto 0);
      variable far_edge_extended  : std_logic_vector(11 downto 0);
      variable near_edge_extended : std_logic_vector(11 downto 0);
   begin
      object_x_extended  := "00" & object_x_stage_2;
      back_w_extended    := "00" & back_width_at_row_combinational;
      far_edge_extended  := "00" & far_edge_cave_in_combinational;
      near_edge_extended := "00" & near_edge_magnitude_combinational;

      -- Top-left: object_x - back_w + (far_edge | +near | -near)
      if box_side_of_cat_stage_2 = '0' and box_is_off_centre_stage_2 = '1' then
         left_extended := object_x_extended - back_w_extended + far_edge_extended;
      elsif near_edge_is_outward_combinational = '1' then
         left_extended := object_x_extended - back_w_extended - near_edge_extended;
      else
         left_extended := object_x_extended - back_w_extended + near_edge_extended;
      end if;

      -- Top-right: object_x + back_w + (-far_edge | +near | -near)
      if box_side_of_cat_stage_2 = '1' then
         right_extended := object_x_extended + back_w_extended - far_edge_extended;
      elsif near_edge_is_outward_combinational = '1' then
         right_extended := object_x_extended + back_w_extended + near_edge_extended;
      else
         right_extended := object_x_extended + back_w_extended - near_edge_extended;
      end if;

      top_left_combinational            <= left_extended(9 downto 0);
      top_left_underflow_combinational  <= left_extended(11);
      top_right_combinational           <= right_extended(9 downto 0);
      if right_extended(11) = '0' and right_extended(10) = '1' then
         top_right_overflow_combinational <= '1';
      else
         top_right_overflow_combinational <= '0';
      end if;
   end process Top_Edges_Boundary;

   -- Side face boundaries: object_x ± object_width ± actual_side_shift_scaled.
   -- We need actual_side_shift_scaled combinationally here so we compute the
   -- side-clamp inline (same logic as the Stage 2 version below). 12-bit
   -- arithmetic so we can cleanly detect both underflow (bit 11 = '1') and
   -- overflow into [1024, 2047] (bit 11 = '0' AND bit 10 = '1').
   Side_Face_Boundary : process(object_x_stage_2, object_width_stage_2,
                                top_max_extension_scaled_combinational,
                                side_shift_unclamped_scaled_combinational,
                                rows_from_side_face_bottom)
      variable side_shift_clamped : std_logic_vector(9 downto 0);
      variable left_extended      : std_logic_vector(11 downto 0);
      variable right_extended     : std_logic_vector(11 downto 0);
   begin
      if side_shift_unclamped_scaled_combinational >= top_max_extension_scaled_combinational then
         side_shift_clamped := top_max_extension_scaled_combinational;
      elsif rows_from_side_face_bottom = "0000000000" then
         side_shift_clamped := (others => '0');
      else
         side_shift_clamped := side_shift_unclamped_scaled_combinational;
      end if;

      left_extended  := ("00" & object_x_stage_2) - ("00" & object_width_stage_2) - ("00" & side_shift_clamped);
      right_extended := ("00" & object_x_stage_2) + ("00" & object_width_stage_2) + ("00" & side_shift_clamped);

      side_face_left_boundary_combinational  <= left_extended(9 downto 0);
      side_face_left_underflow_combinational <= left_extended(11);
      side_face_right_boundary_combinational <= right_extended(9 downto 0);
      if right_extended(11) = '0' and right_extended(10) = '1' then
         side_face_right_overflow_combinational <= '1';
      else
         side_face_right_overflow_combinational <= '0';
      end if;
   end process Side_Face_Boundary;

   -- ========================================================================
   -- Per-pixel Stage 1 register
   -- ========================================================================
   Per_Pixel_Stage_1 : process(clock)
   begin
      if rising_edge(clock) then
         side_top_boundary_pixel_stage_1            <= side_top_boundary_combinational;
         pixel_row_pixel_stage_1                    <= pixel_row;
         pixel_column_pixel_stage_1                 <= pixel_column;

         -- New boundary values and underflow/overflow flags
         front_face_left_boundary_pixel_stage_1     <= front_face_left_boundary_combinational;
         front_face_left_underflow_pixel_stage_1    <= front_face_left_underflow_combinational;
         front_face_right_boundary_pixel_stage_1    <= front_face_right_boundary_combinational;
         front_face_right_overflow_pixel_stage_1    <= front_face_right_overflow_combinational;
         side_face_left_boundary_pixel_stage_1      <= side_face_left_boundary_combinational;
         side_face_left_underflow_pixel_stage_1     <= side_face_left_underflow_combinational;
         side_face_right_boundary_pixel_stage_1     <= side_face_right_boundary_combinational;
         side_face_right_overflow_pixel_stage_1     <= side_face_right_overflow_combinational;
         top_left_pixel_stage_1                     <= top_left_combinational;
         top_left_underflow_pixel_stage_1           <= top_left_underflow_combinational;
         top_right_pixel_stage_1                    <= top_right_combinational;
         top_right_overflow_pixel_stage_1           <= top_right_overflow_combinational;
         box_off_screen_pixel_stage_1               <= box_off_screen_stage_2;
      end if;
   end process Per_Pixel_Stage_1;

   -- ========================================================================
   -- Per-pixel Stage 2 combinational: comparisons + priority mux
   -- ========================================================================

   -- On signals: each comparison ORs the underflow/overflow flag in. When the
   -- flag is set, the corresponding boundary is off-screen, so the comparison
   -- is forced true (i.e. every visible pixel is "inside" relative to that
   -- boundary). This fixes the unsigned-wraparound bug that caused faces to
   -- vanish when the box was partially off-screen.
   object_front_on <= '1' when (box_off_screen_pixel_stage_1 = '0' and
                                (pixel_row_pixel_stage_1    >= object_y_stage_2 - object_height_stage_2) and
                                (pixel_row_pixel_stage_1    <= object_y_stage_2)                         and
                                (front_face_left_underflow_pixel_stage_1 = '1' or
                                 pixel_column_pixel_stage_1 >= front_face_left_boundary_pixel_stage_1)  and
                                (front_face_right_overflow_pixel_stage_1 = '1' or
                                 pixel_column_pixel_stage_1 <= front_face_right_boundary_pixel_stage_1))
                      else '0';

   object_top_on <= '1' when (box_off_screen_pixel_stage_1 = '0' and
                              (pixel_row_pixel_stage_1    >= object_y_stage_2 - object_height_stage_2 - top_height_stage_2) and
                              (pixel_row_pixel_stage_1    <= object_y_stage_2 - object_height_stage_2)                      and
                              (top_left_underflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 >= top_left_pixel_stage_1)                                        and
                              (top_right_overflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 <= top_right_pixel_stage_1))
                    else '0';

   left_side_on  <= '1' when (box_off_screen_pixel_stage_1 = '0' and
                              (pixel_row_pixel_stage_1    >= object_y_stage_2 - object_height_stage_2 - top_height_stage_2) and
                              (pixel_row_pixel_stage_1    <= object_y_stage_2 - side_top_boundary_pixel_stage_1)            and
                              (side_face_left_underflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 >= side_face_left_boundary_pixel_stage_1)                         and
                              (front_face_left_underflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 <= front_face_left_boundary_pixel_stage_1))
                    else '0';

   right_side_on <= '1' when (box_off_screen_pixel_stage_1 = '0' and
                              (pixel_row_pixel_stage_1    >= object_y_stage_2 - object_height_stage_2 - top_height_stage_2) and
                              (pixel_row_pixel_stage_1    <= object_y_stage_2 - side_top_boundary_pixel_stage_1)            and
                              (side_face_right_overflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 <= side_face_right_boundary_pixel_stage_1)                        and
                              (front_face_right_overflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 >= front_face_right_boundary_pixel_stage_1))
                    else '0';

   object_side_on <= left_side_on  when (box_side_of_cat_stage_2 = '1')   else
                     right_side_on when (box_is_off_centre_stage_2 = '1') else
                     '0';

   -- Priority mux: front > top > side
   red_combinational   <= "0001" when (object_front_on = '1') else
                          "0001" when (object_top_on   = '1') else
                          "0001" when (object_side_on  = '1') else
                          "0000";
   green_combinational <= "0111" when (object_front_on = '1') else
                          "1111" when (object_top_on   = '1') else
                          "0011" when (object_side_on  = '1') else
                          "0000";
   blue_combinational  <= "0001" when (object_front_on = '1') else
                          "0001" when (object_top_on   = '1') else
                          "0001" when (object_side_on  = '1') else
                          "0000";

   -- ========================================================================
   -- Output register
   -- ========================================================================
   Output_Register : process(clock)
   begin
      if rising_edge(clock) then
         red_out_register   <= red_combinational;
         green_out_register <= green_combinational;
         blue_out_register  <= blue_combinational;
      end if;
   end process Output_Register;

   red_out   <= red_out_register;
   green_out <= green_out_register;
   blue_out  <= blue_out_register;

   row_out <= object_distance;

end architecture moving_object_behaviour;