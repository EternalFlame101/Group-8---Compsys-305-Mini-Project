library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Moving_Object is
   generic (REAL_HEIGHT : positive             := 60;
            REAL_WIDTH  : positive             := 80;
            LANE        : integer range 0 to 2 := 1);
   port (enable, clock, vertical_sync : in  std_logic;
         reset  							  : in  std_logic;
			obj_type                     : in  std_logic_vector(2 downto 0);
			arrived 			  				  : out std_logic;
         pixel_column, pixel_row      : in  std_logic_vector(9 downto 0);
         speed_select                  : in  std_logic_vector(1 downto 0);
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
   -- Registered obj_type flags. obj_type is a port driven by external registers;
   -- capturing it here places a register adjacent to the per-pixel pipeline so
   -- the color-mux comparisons see a short register-to-register hop instead of
   -- a long cross-chip routing path.
   signal obj_type_stage_2                         : std_logic_vector(2 downto 0);

   -- Per-vsync precomputed constants. These are stable for every pixel within
   -- a frame, so we compute them once in Frame_Stage_2 instead of redoing the
   -- 2-subtract chain on every pixel clock cycle. Removing those subtracts
   -- from Stage 1A's per-pixel comb is what brought pixel_clock above 100 MHz.
   --   top_face_top_y  = object_y - object_height - top_height
   --   side_face_top_y = object_y - object_height
   signal top_face_top_y_stage_2  : std_logic_vector(9 downto 0);
   signal side_face_top_y_stage_2 : std_logic_vector(9 downto 0);

   -- Distance update
   signal object_distance    : std_logic_vector(9 downto 0) := (others => '0');
   signal vertical_sync_previous : std_logic;

   -- Per-pixel pipeline is split into Stage 1A (row derivations) + Stage 1B
   -- (multiplier products) + Stage 1C (boundary calcs) + existing Stage 1 reg.
   -- Each non-suffixed signal below is the REGISTERED output of its stage; the
   -- corresponding `_combinational` signal is the comb input feeding the next
   -- pipeline register. Splitting the per-pixel chain in two halves was needed
   -- to clear the ~21 ns combinational path from object_height_stage_2 to
   -- top_right_overflow_pixel_stage_1 that was capping pixel_clock Fmax at
   -- ~45 MHz.

   -- Stage 1A combinational (driven by Stage 1A comb, captured by Stage 1A reg).
   -- rows_from_*_bottom were moved into Stage 1B comb so that the second
   -- subtract (top_height - rows_from_top_face_top) runs in parallel with the
   -- multiplies rather than chained inside Stage 1A. side_column_offset moved
   -- to Stage 1B too once we precomputed object_x +/- object_width here as
   -- left_side_x / right_side_x (vsync-stable, but recomputed per pixel under
   -- the live pixel_column was capping Fmax at ~78 MHz).
   signal rows_from_top_face_top_combinational  : std_logic_vector(9 downto 0);
   signal rows_from_side_face_top_combinational : std_logic_vector(9 downto 0);
   signal left_side_x_combinational             : std_logic_vector(9 downto 0);
   signal right_side_x_combinational            : std_logic_vector(9 downto 0);

   -- Stage 1A registered outputs (used by Stage 1B comb).
   signal rows_from_top_face_top  : std_logic_vector(9 downto 0);
   signal rows_from_side_face_top : std_logic_vector(9 downto 0);
   signal left_side_x             : std_logic_vector(9 downto 0);
   signal right_side_x            : std_logic_vector(9 downto 0);

   -- Pixel coord pass-throughs through each pipeline stage so that pixel_row /
   -- pixel_column reach the existing Stage 1 reg with the same 3-cycle latency
   -- as everything else (1A reg + 1B reg + existing Stage 1 reg).
   signal pixel_row_stage_1a    : std_logic_vector(9 downto 0);
   signal pixel_column_stage_1a : std_logic_vector(9 downto 0);
   signal pixel_row_stage_1b    : std_logic_vector(9 downto 0);
   signal pixel_column_stage_1b : std_logic_vector(9 downto 0);

   -- Stage 1B combinational signals for the bottom-row offsets. These feed
   -- straight into the per-pixel multiplies in the same Stage 1B comb section.
   signal rows_from_top_face_bottom_combinational  : std_logic_vector(9 downto 0);
   signal rows_from_side_face_bottom_combinational : std_logic_vector(9 downto 0);

   -- Stage 1B registered version of rows_from_side_face_bottom, needed by
   -- Side_Face_Boundary (Stage 1C comb) for its clamp condition.
   -- rows_from_top_face_bottom and side_column_offset are only consumed by
   -- the Stage 1B multiplies in the same comb stage, so neither needs to be
   -- registered -- the multiplies read the _combinational alias directly.
   signal rows_from_side_face_bottom       : std_logic_vector(9 downto 0);
   signal side_column_offset_combinational : std_logic_vector(9 downto 0);

   -- Stage 1B combinational versions of all 6 per-pixel multiplier products.
   -- top_max_extension_scaled_product used to stay pure combinational because
   -- both its inputs are vsync-stable, but it sat in Stage 1C's critical path
   -- (the multiply + bit-select feeds Side_Face_Boundary). Registering it adds
   -- 1 cycle of harmless latency (the value is constant per vsync anyway) but
   -- removes the multiply from the path that lands at side_face_right_overflow.
   signal width_difference_product_combinational         : std_logic_vector(19 downto 0);
   signal height_difference_product_combinational        : std_logic_vector(19 downto 0);
   signal top_skew_product_combinational                 : std_logic_vector(27 downto 0);
   signal side_shift_product_combinational               : std_logic_vector(27 downto 0);
   signal top_max_extension_scaled_product_combinational : std_logic_vector(17 downto 0);
   signal baseline_top_cave_in_product_combinational     : std_logic_vector(19 downto 0);

   -- Stage 1B registered outputs (used by Stage 1C comb / boundary processes)
   signal width_difference_product       : std_logic_vector(19 downto 0);
   signal height_difference_product      : std_logic_vector(19 downto 0);
   signal top_skew_product               : std_logic_vector(27 downto 0);
   signal side_shift_product             : std_logic_vector(27 downto 0);
   signal top_max_extension_scaled_product : std_logic_vector(17 downto 0);
   signal baseline_top_cave_in_product   : std_logic_vector(19 downto 0);

   signal back_width_at_row_combinational            : std_logic_vector(9 downto 0);
   signal side_top_boundary_combinational            : std_logic_vector(9 downto 0);
   signal top_skew_low_combinational                 : std_logic_vector(9 downto 0);
   signal top_skew_high_combinational                : std_logic_vector(9 downto 0);
   signal baseline_top_cave_in_combinational         : std_logic_vector(9 downto 0);
   signal side_shift_unclamped_scaled_combinational  : std_logic_vector(9 downto 0);
   signal top_max_extension_scaled_combinational     : std_logic_vector(9 downto 0);
   signal apply_baseline_cave_in_combinational       : std_logic;

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

	
	-- Lane detection
	signal object_arrived : std_logic;
	signal object_reset   : std_logic;
	signal object_active  : std_logic;
	

	signal effective_height : std_logic_vector(9 downto 0);
	signal effective_width	: std_logic_vector(9 downto 0);

	signal enable_latch : std_logic := '0';

	signal enable_seen_low : std_logic := '1';

	signal frame_div_counter : std_logic_vector(1 downto 0) := "00";

	-- frac_counter increments on every actual advance (not every vsync) to produce
	-- fractional average step sizes across 5 distance zones:
	--   zone 1 (  0- 31): step always 1    -> avg 1.00
	--   zone 2 ( 32- 63): step 2 once/4   -> avg 1.25
	--   zone 3 ( 64- 95): step alternates  -> avg 1.50
	--   zone 4 ( 96-127): step 1 once/4   -> avg 1.75
	--   zone 5 (128-159): step always 2    -> avg 2.00
	signal frac_counter : std_logic_vector(1 downto 0) := "00";
	signal dist_step    : std_logic_vector(9 downto 0);
begin

	dist_step <=
		conv_std_logic_vector(2, 10) when conv_integer(object_distance) >= 128 else
		conv_std_logic_vector(1, 10) when conv_integer(object_distance) >= 96 and frac_counter = "11" else
		conv_std_logic_vector(2, 10) when conv_integer(object_distance) >= 96 else
		conv_std_logic_vector(2, 10) when conv_integer(object_distance) >= 64 and frac_counter(0) = '0' else
		conv_std_logic_vector(1, 10) when conv_integer(object_distance) >= 64 else
		conv_std_logic_vector(2, 10) when conv_integer(object_distance) >= 32 and frac_counter = "00" else
		conv_std_logic_vector(1, 10);

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

   -- "011" large obstacle is 120 px tall; all others are 60 px.
   -- "001" gift is 30 px wide; all obstacles are 70 px wide.
   effective_height <= conv_std_logic_vector(120, 10) when obj_type = "011" else
                       conv_std_logic_vector(60, 10);
   effective_width  <= conv_std_logic_vector(30, 10) when obj_type = "001" else
                       conv_std_logic_vector(70, 10);
     
   Moving : process(clock)
	 begin
		 if rising_edge(clock) then
			  object_arrived     <= '0';
			  vertical_sync_previous <= vertical_sync;

			  if reset = '1' then
					object_distance   <= (others => '1');
					object_active     <= '0';
					enable_latch      <= '0';
					enable_seen_low   <= '1';
					frame_div_counter <= "00";
				frac_counter      <= "00";
			  else
					-- Update enable latch combinationally each cycle
					if enable = '0' then
						 enable_latch    <= '0';
						 enable_seen_low <= '1';
					elsif object_active = '0' and enable_seen_low = '1' then
						 enable_latch    <= enable;
						 enable_seen_low <= '0';
					end if;

					if (vertical_sync = '0') and (vertical_sync_previous = '1') then
						 -- Tick the frame divider on every vsync (free-running, used below)
						 frame_div_counter <= frame_div_counter + 1;

						 if enable_latch = '1' and object_active = '0' then
							  object_active   <= '1';
							  object_distance <= (others => '0');
							  frac_counter    <= "00";
						 end if;

						 if object_active = '1' then
							  -- Arrival threshold kept inside ROM depth (160 entries,
							  -- 8-bit address). See Object_ROM.vhd line 68.
							  if object_distance >= conv_std_logic_vector(159, 10) then
									object_arrived  <= '1';
									object_distance <= (others => '0');
									object_active   <= '0';
							  else
									-- speed_select: "00"=freeze
									--               "01"=easy   (1 step / 2 vsyncs, ~5.3 s/wave)
									--               "10"=medium (3 steps / 4 vsyncs, ~3.5 s/wave)
									--               "11"=hard   (1 step / vsync,     ~2.6 s/wave)
									-- dist_step adds perspective correction: step doubles past distance 80
									-- so the object visually accelerates toward the player.
									case speed_select is
										when "00" => null;
										when "01" =>
											if frame_div_counter(0) = '1' then
												object_distance <= object_distance + dist_step;
												frac_counter    <= frac_counter + 1;
											end if;
										when "10" =>
											if frame_div_counter /= "01" then
												object_distance <= object_distance + dist_step;
												frac_counter    <= frac_counter + 1;
											end if;
										when others =>
											object_distance <= object_distance + dist_step;
											frac_counter    <= frac_counter + 1;
									end case;
							  end if;
						 end if;
					end if;
			  end if;
		 end if;
	 end process;

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

   object_height_scaled_product_combinational      <= object_height_rom      * effective_height;
   object_width_scaled_product_combinational       <= object_width_rom       * effective_width;
   object_width_back_scaled_product_combinational  <= object_width_back_rom  * effective_width;
   object_height_back_scaled_product_combinational <= object_height_back_rom * effective_height;
   top_height_scaled_product_combinational         <= top_height_rom         * effective_height;

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
         -- Air box ("100"): shift up by one scaled box-height so it floats
         -- exactly above where a short box would sit on the ground.
         if obj_type = "100" then
            object_y_stage_1 <= object_y_rom - object_height_combinational;
         else
            object_y_stage_1 <= object_y_rom;
         end if;
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

         -- Per-vsync precomputed constants used by the per-pixel pipeline
         -- (Stage 1A reads these as plain registers, no chained subtracts).
         top_face_top_y_stage_2  <= object_y_stage_1 - object_height_stage_1 - top_height_stage_1;
         side_face_top_y_stage_2 <= object_y_stage_1 - object_height_stage_1;

         -- Capture obj_type into a register local to the pipeline so the
         -- per-pixel color mux sees a short register-to-register hop.
         obj_type_stage_2 <= obj_type;
      end if;
   end process Frame_Stage_2;

   -- ========================================================================
   -- Per-pixel Stage 1A combinational: row derivations
   -- Inputs: pixel_row, pixel_column (live), and Frame_Stage_2 precomputed
   -- constants top_face_top_y_stage_2 / side_face_top_y_stage_2. Stage 1A is
   -- now a single subtract + clamp per row signal -- the chained subtracts
   -- that used to live here moved into Frame_Stage_2 (the per-vsync subs) and
   -- Stage 1B comb (the rows_from_*_bottom subs).
   -- ========================================================================
   rows_from_top_face_top_combinational <= (pixel_row - top_face_top_y_stage_2)
                                              when (pixel_row >= top_face_top_y_stage_2)
                                              else (others => '0');

   rows_from_side_face_top_combinational <= (pixel_row - side_face_top_y_stage_2)
                                               when (pixel_row >= side_face_top_y_stage_2)
                                               else (others => '0');

   -- Precomputed side edges. Both inputs are vsync-stable so these are
   -- effectively constants between vsyncs; registering them in Stage 1A reg
   -- removes a chained subtract from the per-pixel side_column_offset path.
   left_side_x_combinational  <= object_x_stage_2 - object_width_stage_2;
   right_side_x_combinational <= object_x_stage_2 + object_width_stage_2;

   -- ========================================================================
   -- Per-pixel Stage 1A register: latches the row derivations and pixel coords
   -- ========================================================================
   Per_Pixel_Stage_1A : process(clock)
   begin
      if rising_edge(clock) then
         rows_from_top_face_top  <= rows_from_top_face_top_combinational;
         rows_from_side_face_top <= rows_from_side_face_top_combinational;
         left_side_x             <= left_side_x_combinational;
         right_side_x            <= right_side_x_combinational;
         pixel_row_stage_1a      <= pixel_row;
         pixel_column_stage_1a   <= pixel_column;
      end if;
   end process Per_Pixel_Stage_1A;

   -- ========================================================================
   -- Per-pixel Stage 1B combinational: bottom-row subtracts + multiplier
   -- products. Reads Stage 1A registered rows_from_*_top, computes the second
   -- subtract (rows_from_*_bottom) combinationally, and feeds the result into
   -- the big multiplies in the same comb stage. Quartus pushes the multiplies
   -- into DSP blocks; the subtract is a carry chain in front of the DSP and
   -- the combined depth (~5-6 ns) fits comfortably in one pipeline stage.
   -- All 6 products are registered into Stage 1B; the per-vsync-stable one
   -- (top_max_extension_scaled_product) was previously left as pure comb but
   -- moving it into the register removes its multiply from the Stage 1C path
   -- ending at side_face_right_overflow_pixel_stage_1.
   -- ========================================================================
   rows_from_top_face_bottom_combinational <= (top_height_stage_2 - rows_from_top_face_top)
                                                 when (top_height_stage_2 >= rows_from_top_face_top) else (others => '0');
   rows_from_side_face_bottom_combinational <= (object_height_stage_2 - rows_from_side_face_top)
                                                  when (object_height_stage_2 >= rows_from_side_face_top) else (others => '0');

   -- side_column_offset moved to Stage 1B comb (was Stage 1A reg). Inputs are
   -- the Stage 1A registered precomputes plus the Stage 1A registered pixel
   -- column, so the chain is two parallel compares + two parallel subtracts +
   -- a mux -- short enough to leave room for the multiply that consumes it.
   side_column_offset_combinational <= (left_side_x - pixel_column_stage_1a)
                                          when (box_side_of_cat_stage_2 = '1' and
                                                pixel_column_stage_1a <= left_side_x) else
                                       (pixel_column_stage_1a - right_side_x)
                                          when (box_side_of_cat_stage_2 = '0' and
                                                box_is_off_centre_stage_2 = '1' and
                                                pixel_column_stage_1a >= right_side_x) else
                                       (others => '0');

   width_difference_product_combinational         <= width_difference_stage_2  * rows_from_top_face_top;
   height_difference_product_combinational        <= height_difference_stage_2 * side_column_offset_combinational;
   top_skew_product_combinational                 <= top_combined_taper_stage_2  * rows_from_top_face_bottom_combinational;
   side_shift_product_combinational               <= side_combined_taper_stage_2 * rows_from_side_face_bottom_combinational;
   top_max_extension_scaled_product_combinational <= top_max_extension_stage_2 * cat_distance_from_box_centre_slv_stage_2;
   baseline_top_cave_in_product_combinational     <= top_taper_stage_2 * rows_from_top_face_bottom_combinational;

   -- ========================================================================
   -- Per-pixel Stage 1B register: latches the per-pixel products and pass-
   -- throughs needed by Stage 1C boundary calculations.
   -- ========================================================================
   Per_Pixel_Stage_1B : process(clock)
   begin
      if rising_edge(clock) then
         width_difference_product         <= width_difference_product_combinational;
         height_difference_product        <= height_difference_product_combinational;
         top_skew_product                 <= top_skew_product_combinational;
         side_shift_product               <= side_shift_product_combinational;
         top_max_extension_scaled_product <= top_max_extension_scaled_product_combinational;
         baseline_top_cave_in_product     <= baseline_top_cave_in_product_combinational;
         rows_from_side_face_bottom       <= rows_from_side_face_bottom_combinational;
         pixel_row_stage_1b               <= pixel_row_stage_1a;
         pixel_column_stage_1b            <= pixel_column_stage_1a;
      end if;
   end process Per_Pixel_Stage_1B;

   back_width_at_row_combinational            <= object_width_stage_2 - width_difference_product(17 downto 8);
   side_top_boundary_combinational            <= height_difference_product(18 downto 9);
   top_skew_low_combinational                 <= top_skew_product(23 downto 14);
   top_skew_high_combinational                <= top_skew_low_combinational(8 downto 0) & '0';
   baseline_top_cave_in_combinational         <= baseline_top_cave_in_product(18 downto 9);
   side_shift_unclamped_scaled_combinational  <= side_shift_product(23 downto 14);
   top_max_extension_scaled_combinational     <= top_max_extension_scaled_product(15 downto 6);

   -- Frustum cave-in on the top face only displays when the cat is exactly
   -- centred on this box (i.e. fully settled in this box's lane). Other times,
   -- the cave-in is zero and the top edges follow File-2's off-axis skew math.
   apply_baseline_cave_in_combinational <= '1' when box_is_off_centre_stage_2 = '0' else '0';

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
   --
   -- Math: when the cat is dead-on (apply_baseline_cave_in = '1'), both edges
   -- cave inward symmetrically using baseline_top_cave_in (this makes the
   -- in-lane box look like a proper frustum). Otherwise we use File-2's
   -- off-axis skew math uniformly across all lanes (no LANE=1 special case):
   --   box on left of cat (box_side_of_cat = '0'):
   --       top_left  = object_x - back_w + top_skew_high   (far edge, more cave-in)
   --       top_right = object_x + back_w + top_skew_low    (near edge, flares outward)
   --   box on right of cat (box_side_of_cat = '1'):
   --       top_left  = object_x - back_w - top_skew_low    (near edge, flares outward)
   --       top_right = object_x + back_w - top_skew_high   (far edge, more cave-in)
   Top_Edges_Boundary : process(object_x_stage_2, back_width_at_row_combinational,
                                top_skew_low_combinational, top_skew_high_combinational,
                                baseline_top_cave_in_combinational,
                                apply_baseline_cave_in_combinational,
                                box_side_of_cat_stage_2)
      variable left_extended       : std_logic_vector(11 downto 0);
      variable right_extended      : std_logic_vector(11 downto 0);
      variable object_x_extended   : std_logic_vector(11 downto 0);
      variable back_w_extended     : std_logic_vector(11 downto 0);
      variable skew_low_extended   : std_logic_vector(11 downto 0);
      variable skew_high_extended  : std_logic_vector(11 downto 0);
      variable baseline_extended   : std_logic_vector(11 downto 0);
   begin
      object_x_extended  := "00" & object_x_stage_2;
      back_w_extended    := "00" & back_width_at_row_combinational;
      skew_low_extended  := "00" & top_skew_low_combinational;
      skew_high_extended := "00" & top_skew_high_combinational;
      baseline_extended  := "00" & baseline_top_cave_in_combinational;

      if apply_baseline_cave_in_combinational = '1' then
         -- Dead-on case: symmetric frustum cave-in on both edges
         left_extended  := object_x_extended - back_w_extended + baseline_extended;
         right_extended := object_x_extended + back_w_extended - baseline_extended;
      elsif box_side_of_cat_stage_2 = '0' then
         -- Box on left of cat (we view from its right side)
         left_extended  := object_x_extended - back_w_extended + skew_high_extended;
         right_extended := object_x_extended + back_w_extended + skew_low_extended;
      else
         -- Box on right of cat (we view from its left side)
         left_extended  := object_x_extended - back_w_extended - skew_low_extended;
         right_extended := object_x_extended + back_w_extended - skew_high_extended;
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
         pixel_row_pixel_stage_1                    <= pixel_row_stage_1b;
         pixel_column_pixel_stage_1                 <= pixel_column_stage_1b;

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
   -- Use the Frame_Stage_2 precomputed constants (top_face_top_y_stage_2,
   -- side_face_top_y_stage_2) instead of recomputing the two-subtract chain
   -- inline. Both are algebraically identical to their respective
   -- object_y_stage_2 - object_height_stage_2 [- top_height_stage_2] forms,
   -- but read from a single register rather than requiring two adders in the
   -- per-pixel critical path (saves ~10 ns at 25 MHz).
   object_front_on <= '1' when (box_off_screen_pixel_stage_1 = '0' and
                                (pixel_row_pixel_stage_1    >= side_face_top_y_stage_2) and
                                (pixel_row_pixel_stage_1    <= object_y_stage_2)        and
                                (front_face_left_underflow_pixel_stage_1 = '1' or
                                 pixel_column_pixel_stage_1 >= front_face_left_boundary_pixel_stage_1)  and
                                (front_face_right_overflow_pixel_stage_1 = '1' or
                                 pixel_column_pixel_stage_1 <= front_face_right_boundary_pixel_stage_1))
                      else '0';

   object_top_on <= '1' when (box_off_screen_pixel_stage_1 = '0' and
                              (pixel_row_pixel_stage_1    >= top_face_top_y_stage_2)    and
                              (pixel_row_pixel_stage_1    <= side_face_top_y_stage_2)   and
                              (top_left_underflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 >= top_left_pixel_stage_1)   and
                              (top_right_overflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 <= top_right_pixel_stage_1))
                    else '0';

   left_side_on  <= '1' when (box_off_screen_pixel_stage_1 = '0' and
                              (pixel_row_pixel_stage_1    >= top_face_top_y_stage_2)                 and
                              (pixel_row_pixel_stage_1    <= object_y_stage_2 - side_top_boundary_pixel_stage_1) and
                              (side_face_left_underflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 >= side_face_left_boundary_pixel_stage_1) and
                              (front_face_left_underflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 <= front_face_left_boundary_pixel_stage_1))
                    else '0';

   right_side_on <= '1' when (box_off_screen_pixel_stage_1 = '0' and
                              (pixel_row_pixel_stage_1    >= top_face_top_y_stage_2)                  and
                              (pixel_row_pixel_stage_1    <= object_y_stage_2 - side_top_boundary_pixel_stage_1) and
                              (side_face_right_overflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 <= side_face_right_boundary_pixel_stage_1) and
                              (front_face_right_overflow_pixel_stage_1 = '1' or
                               pixel_column_pixel_stage_1 >= front_face_right_boundary_pixel_stage_1))
                    else '0';

   object_side_on <= left_side_on  when (box_side_of_cat_stage_2 = '1')   else
                     right_side_on when (box_is_off_centre_stage_2 = '1') else
                     '0';

   -- Priority mux: front > top > side
   -- "001" gift:    yellow  (R+G high, no B)
   -- "010" small:   green   (G high, R/B low)
   -- "011" large:   blue    (B high, no R/G) -- tall ground box, must switch lanes
   -- "100" air box: red     (R high, G/B low) -- floating, must dive
   -- obj_type_stage_2 is a Frame_Stage_2 register of the obj_type port; using
   -- it here keeps obj_type out of the per-pixel critical path.
   red_combinational   <= "0111" when (object_front_on = '1' and obj_type_stage_2 = "001") else
                          "0111" when (object_front_on = '1' and obj_type_stage_2 = "100") else
                          "0000" when (object_front_on = '1' and obj_type_stage_2 = "011") else
                          "0001" when (object_front_on = '1') else
                          "1111" when (object_top_on   = '1' and obj_type_stage_2 = "001") else
                          "1111" when (object_top_on   = '1' and obj_type_stage_2 = "100") else
                          "0000" when (object_top_on   = '1' and obj_type_stage_2 = "011") else
                          "0001" when (object_top_on   = '1') else
                          "0111" when (object_side_on  = '1' and obj_type_stage_2 = "001") else
                          "0011" when (object_side_on  = '1' and obj_type_stage_2 = "100") else
                          "0000" when (object_side_on  = '1' and obj_type_stage_2 = "011") else
                          "0001" when (object_side_on  = '1') else
                          "0000";
   green_combinational <= "0111" when (object_front_on = '1' and obj_type_stage_2 = "001") else
                          "0001" when (object_front_on = '1' and obj_type_stage_2 = "100") else
                          "0000" when (object_front_on = '1' and obj_type_stage_2 = "011") else
                          "0111" when (object_front_on = '1') else
                          "1111" when (object_top_on   = '1' and obj_type_stage_2 = "001") else
                          "0001" when (object_top_on   = '1' and obj_type_stage_2 = "100") else
                          "0001" when (object_top_on   = '1' and obj_type_stage_2 = "011") else
                          "1111" when (object_top_on   = '1') else
                          "0111" when (object_side_on  = '1' and obj_type_stage_2 = "001") else
                          "0001" when (object_side_on  = '1' and obj_type_stage_2 = "100") else
                          "0000" when (object_side_on  = '1' and obj_type_stage_2 = "011") else
                          "0011" when (object_side_on  = '1') else
                          "0000";
   blue_combinational  <= "0000" when (object_front_on = '1' and obj_type_stage_2 = "001") else
                          "0000" when (object_front_on = '1' and obj_type_stage_2 = "100") else
                          "0111" when (object_front_on = '1' and obj_type_stage_2 = "011") else
                          "0001" when (object_front_on = '1') else
                          "0000" when (object_top_on   = '1' and obj_type_stage_2 = "001") else
                          "0000" when (object_top_on   = '1' and obj_type_stage_2 = "100") else
                          "1111" when (object_top_on   = '1' and obj_type_stage_2 = "011") else
                          "0001" when (object_top_on   = '1') else
                          "0000" when (object_side_on  = '1' and obj_type_stage_2 = "001") else
                          "0000" when (object_side_on  = '1' and obj_type_stage_2 = "100") else
                          "0011" when (object_side_on  = '1' and obj_type_stage_2 = "011") else
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

	arrived 	 <= object_arrived;
	row_out <= object_distance when object_active = '1' else (others => '0');

end architecture moving_object_behaviour;