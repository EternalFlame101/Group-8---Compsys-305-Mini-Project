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
			row_out							  : out std_logic_vector(9 downto 0); -- WORK IN PROGRESS
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

   constant TRACK_CENTRE_X : std_logic_vector(9 downto 0) := conv_std_logic_vector(320, 10);
   constant HOME_POS       : integer := (LANE - 1) * 64;

   -- ROM outputs
   signal spread_rom                 : std_logic_vector(9 downto 0);
   signal object_y_rom               : std_logic_vector(9 downto 0);
   signal object_height_raw_rom      : std_logic_vector(9 downto 0);
   signal object_width_raw_rom       : std_logic_vector(9 downto 0);
   signal object_width_back_raw_rom  : std_logic_vector(9 downto 0);
   signal object_height_back_raw_rom : std_logic_vector(9 downto 0);
   signal top_height_raw_rom         : std_logic_vector(9 downto 0);
   signal top_taper_rom              : std_logic_vector(9 downto 0);
   signal side_taper_rom             : std_logic_vector(9 downto 0);

   -- Stage 1 combinational (from ROMs + cat_view_position)
   signal cat_view_int_comb        : integer range -64 to 64;
   signal relative_pos_signed_comb : integer range -128 to 128;
   signal abs_relative_comb        : integer range 0 to 128;
   signal abs_relative_slv_comb    : std_logic_vector(7 downto 0);
   signal relative_is_right_comb   : std_logic;
   signal relative_is_nonzero_comb : std_logic;

   signal scale_height_product_comb      : std_logic_vector(19 downto 0);
   signal scale_width_product_comb       : std_logic_vector(19 downto 0);
   signal scale_width_back_product_comb  : std_logic_vector(19 downto 0);
   signal scale_height_back_product_comb : std_logic_vector(19 downto 0);
   signal scale_top_height_product_comb  : std_logic_vector(19 downto 0);
   signal object_height_comb             : std_logic_vector(9 downto 0);
   signal object_width_comb              : std_logic_vector(9 downto 0);
   signal object_width_back_comb         : std_logic_vector(9 downto 0);
   signal object_height_back_comb        : std_logic_vector(9 downto 0);
   signal top_height_comb                : std_logic_vector(9 downto 0);

   signal lane_offset_product_comb : std_logic_vector(13 downto 0);
   signal lane_offset_comb         : std_logic_vector(9 downto 0);

   -- Stage 1 registers
   signal abs_relative_slv_s1    : std_logic_vector(7 downto 0);
   signal relative_is_right_s1   : std_logic;
   signal relative_is_nonzero_s1 : std_logic;
   signal object_height_s1       : std_logic_vector(9 downto 0);
   signal object_width_s1        : std_logic_vector(9 downto 0);
   signal object_height_back_s1  : std_logic_vector(9 downto 0);
   signal object_width_back_s1   : std_logic_vector(9 downto 0);
   signal top_height_s1          : std_logic_vector(9 downto 0);
   signal lane_offset_s1         : std_logic_vector(9 downto 0);
   signal top_taper_s1           : std_logic_vector(9 downto 0);
   signal side_taper_s1          : std_logic_vector(9 downto 0);
   signal object_y_s1            : std_logic_vector(9 downto 0);

   -- Stage 2 combinational (from Stage 1 registers)
   signal width_diff_comb             : std_logic_vector(9 downto 0);
   signal height_diff_comb            : std_logic_vector(9 downto 0);
   signal object_x_shift_product_comb : std_logic_vector(17 downto 0);
   signal object_x_shift_comb         : std_logic_vector(9 downto 0);
   signal object_x_comb               : std_logic_vector(9 downto 0);
   signal top_combined_taper_comb     : std_logic_vector(17 downto 0);
   signal side_combined_taper_comb    : std_logic_vector(17 downto 0);
   signal top_max_product_comb        : std_logic_vector(19 downto 0);
   signal top_max_extension_comb      : std_logic_vector(9 downto 0);

   -- Stage 2 registers (used by per-pixel logic)
   signal abs_relative_slv_reg    : std_logic_vector(7 downto 0);
   signal relative_is_right_reg   : std_logic;
   signal relative_is_nonzero_reg : std_logic;
   signal object_height_reg       : std_logic_vector(9 downto 0);
   signal object_width_reg        : std_logic_vector(9 downto 0);
   signal top_height_reg          : std_logic_vector(9 downto 0);
   signal width_diff_reg          : std_logic_vector(9 downto 0);
   signal height_diff_reg         : std_logic_vector(9 downto 0);
   signal object_x_reg            : std_logic_vector(9 downto 0);
   signal object_y_reg            : std_logic_vector(9 downto 0);
   signal top_combined_taper_reg  : std_logic_vector(17 downto 0);
   signal side_combined_taper_reg : std_logic_vector(17 downto 0);
   signal top_max_extension_reg   : std_logic_vector(9 downto 0);

   -- Per-pixel signals
   signal object_distance    : std_logic_vector(9 downto 0) := (others => '1');
   signal vertical_sync_prev : std_logic;

   signal object_front_on : std_logic;
   signal object_side_on  : std_logic;
   signal left_side_on    : std_logic;
   signal right_side_on   : std_logic;
   signal object_top_on   : std_logic;

   signal top_local_row, top_inverted_local : std_logic_vector(9 downto 0);
   signal side_local_row, inverted_local    : std_logic_vector(9 downto 0);

   signal top_skew_product : std_logic_vector(27 downto 0);
   signal top_skew_low     : std_logic_vector(9 downto 0);
   signal top_skew_high    : std_logic_vector(9 downto 0);

   signal side_shift_product          : std_logic_vector(27 downto 0);
   signal side_shift_unclamped_scaled : std_logic_vector(9 downto 0);
   signal top_max_scaled_product      : std_logic_vector(17 downto 0);
   signal top_max_extension_scaled    : std_logic_vector(9 downto 0);
   signal actual_side_shift_scaled    : std_logic_vector(9 downto 0);

   signal width_diff_product  : std_logic_vector(19 downto 0);
   signal back_w_at_row       : std_logic_vector(9 downto 0);
   signal side_column_offset  : std_logic_vector(9 downto 0);
   signal height_diff_product : std_logic_vector(19 downto 0);
   signal side_top_boundary   : std_logic_vector(9 downto 0);

   signal top_left, top_right : std_logic_vector(9 downto 0);

   signal side_red,   side_green,   side_blue   : std_logic_vector(3 downto 0);
   signal top_red,    top_green,    top_blue    : std_logic_vector(3 downto 0);
   signal object_red, object_green, object_blue : std_logic_vector(3 downto 0);

begin

   -- ROM lookups
   Object_Geometry_Lookup : Object_ROM
      port map (clock         => clock,
                track_row     => object_distance,
                obj_sd_output => object_height_back_raw_rom,
                obj_y_output  => object_y_rom,
                obj_h_output  => object_height_raw_rom,
                obj_w_output  => object_width_raw_rom,
                obj_wb_output => object_width_back_raw_rom,
                top_h_output  => top_height_raw_rom,
                top_taper     => top_taper_rom,
                side_taper    => side_taper_rom);

   Track_Perspective_Lookup : Perspective_ROM
      port map (clock              => clock,
                track_row          => object_distance,
                perspective_output => spread_rom);

   -- ========================================================================
   -- Stage 1 combinational: all "raw x scale" multiplies in parallel
   -- ========================================================================
   cat_view_int_comb        <= conv_integer(signed(cat_view_position));
   relative_pos_signed_comb <= HOME_POS - cat_view_int_comb;
   abs_relative_comb        <= relative_pos_signed_comb when relative_pos_signed_comb >= 0
                                                        else -relative_pos_signed_comb;
   abs_relative_slv_comb    <= conv_std_logic_vector(abs_relative_comb, 8);
   relative_is_right_comb   <= '1' when relative_pos_signed_comb >  0 else '0';
   relative_is_nonzero_comb <= '1' when relative_pos_signed_comb /= 0 else '0';

   scale_height_product_comb      <= object_height_raw_rom * conv_std_logic_vector(REAL_HEIGHT, 10);
   scale_width_product_comb       <= object_width_raw_rom  * conv_std_logic_vector(REAL_WIDTH,  10);
   scale_width_back_product_comb  <= object_width_back_raw_rom  * conv_std_logic_vector(REAL_WIDTH,  10);
   scale_height_back_product_comb <= object_height_back_raw_rom * conv_std_logic_vector(REAL_HEIGHT, 10);
   scale_top_height_product_comb  <= top_height_raw_rom * conv_std_logic_vector(REAL_HEIGHT, 10);

   object_height_comb      <= scale_height_product_comb(16 downto 7);
   object_width_comb       <= scale_width_product_comb(15 downto 6);
   object_width_back_comb  <= scale_width_back_product_comb(15 downto 6);
   object_height_back_comb <= scale_height_back_product_comb(16 downto 7);
   top_height_comb         <= scale_top_height_product_comb(16 downto 7);

   lane_offset_product_comb <= conv_std_logic_vector(11, 4) * spread_rom;
   lane_offset_comb         <= lane_offset_product_comb(13 downto 4);

   -- ========================================================================
   -- Stage 1 register
   -- ========================================================================
   Pipeline_Stage_1 : process(clock)
   begin
      if rising_edge(clock) then
         abs_relative_slv_s1    <= abs_relative_slv_comb;
         relative_is_right_s1   <= relative_is_right_comb;
         relative_is_nonzero_s1 <= relative_is_nonzero_comb;
         object_height_s1       <= object_height_comb;
         object_width_s1        <= object_width_comb;
         object_height_back_s1  <= object_height_back_comb;
         object_width_back_s1   <= object_width_back_comb;
         top_height_s1          <= top_height_comb;
         lane_offset_s1         <= lane_offset_comb;
         top_taper_s1           <= top_taper_rom;
         side_taper_s1          <= side_taper_rom;
         object_y_s1            <= object_y_rom;
      end if;
   end process Pipeline_Stage_1;

   -- ========================================================================
   -- Stage 2 combinational: all "second-tier" multiplies in parallel
   -- ========================================================================
   width_diff_comb  <= (object_width_s1  - object_width_back_s1)
                          when object_width_s1  >= object_width_back_s1  else (others => '0');
   height_diff_comb <= (object_height_s1 - object_height_back_s1)
                          when object_height_s1 >= object_height_back_s1 else (others => '0');

   object_x_shift_product_comb <= abs_relative_slv_s1 * lane_offset_s1;
   object_x_shift_comb         <= object_x_shift_product_comb(15 downto 6);
   object_x_comb <= TRACK_CENTRE_X + object_x_shift_comb when relative_is_right_s1 = '1' else
                    TRACK_CENTRE_X - object_x_shift_comb;

   top_combined_taper_comb  <= top_taper_s1 * abs_relative_slv_s1;
   side_combined_taper_comb <= side_taper_s1 * abs_relative_slv_s1;
   top_max_product_comb     <= top_taper_s1 * top_height_s1;
   top_max_extension_comb   <= top_max_product_comb(17 downto 8);

   -- ========================================================================
   -- Stage 2 register
   -- ========================================================================
   Pipeline_Stage_2 : process(clock)
   begin
      if rising_edge(clock) then
         abs_relative_slv_reg    <= abs_relative_slv_s1;
         relative_is_right_reg   <= relative_is_right_s1;
         relative_is_nonzero_reg <= relative_is_nonzero_s1;
         object_height_reg       <= object_height_s1;
         object_width_reg        <= object_width_s1;
         top_height_reg          <= top_height_s1;
         width_diff_reg          <= width_diff_comb;
         height_diff_reg         <= height_diff_comb;
         object_x_reg            <= object_x_comb;
         object_y_reg            <= object_y_s1;
         top_combined_taper_reg  <= top_combined_taper_comb;
         side_combined_taper_reg <= side_combined_taper_comb;
         top_max_extension_reg   <= top_max_extension_comb;
      end if;
   end process Pipeline_Stage_2;

   -- ========================================================================
   -- Per-frame distance update
   -- ========================================================================
   Moving : process(clock)
   begin
      if rising_edge(clock) then
         vertical_sync_prev <= vertical_sync;
         if ((vertical_sync = '0') and (vertical_sync_prev = '1')) then
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
   -- Per-pixel rendering (combinational, reads only Stage 2 registered values)
   -- ========================================================================

   -- Front face
   object_front_on <= '1' when ((pixel_row    >= object_y_reg - object_height_reg) and
                                (pixel_row    <= object_y_reg)                     and
                                (pixel_column >= object_x_reg - object_width_reg)  and
                                (pixel_column <= object_x_reg + object_width_reg))
                      else '0';

   object_red   <= "0001" when (object_front_on = '1') else "0000";
   object_green <= "0111" when (object_front_on = '1') else "0000";
   object_blue  <= "0001" when (object_front_on = '1') else "0000";

   -- Per-pixel row derivations
   top_local_row <= (pixel_row - (object_y_reg - object_height_reg - top_height_reg))
                       when (pixel_row >= (object_y_reg - object_height_reg - top_height_reg))
                       else (others => '0');
   top_inverted_local <= (top_height_reg - top_local_row)
                            when (top_height_reg >= top_local_row) else (others => '0');

   side_local_row <= (pixel_row - (object_y_reg - object_height_reg))
                        when (pixel_row >= (object_y_reg - object_height_reg))
                        else (others => '0');
   inverted_local <= (object_height_reg - side_local_row)
                        when (object_height_reg >= side_local_row) else (others => '0');

   -- Back-width interpolation
   width_diff_product <= width_diff_reg * top_local_row;
   back_w_at_row      <= object_width_reg - width_diff_product(17 downto 8);

   -- Back-height interpolation
   side_column_offset <= ((object_x_reg - object_width_reg) - pixel_column)
                            when (relative_is_right_reg = '1' and
                                  pixel_column <= object_x_reg - object_width_reg) else
                         (pixel_column - (object_x_reg + object_width_reg))
                            when (relative_is_right_reg = '0' and
                                  relative_is_nonzero_reg = '1' and
                                  pixel_column >= object_x_reg + object_width_reg) else
                         (others => '0');
   height_diff_product <= height_diff_reg * side_column_offset;
   side_top_boundary   <= height_diff_product(18 downto 9);

   -- Top face
   top_skew_product <= top_combined_taper_reg * top_inverted_local;
   top_skew_low     <= top_skew_product(23 downto 14);
   top_skew_high    <= top_skew_low(8 downto 0) & '0';

	-- WORK IN PROGRESS JASPER
   top_left  <= (object_x_reg - back_w_at_row + top_skew_high) when (relative_is_right_reg = '0' and LANE /= 1) else
					 (object_x_reg - back_w_at_row - top_skew_low)  when (relative_is_right_reg = '1' and LANE /= 1) else
					 (object_x_reg - back_w_at_row + top_skew_low)  when (relative_is_right_reg = '0' and LANE = 1)  else
					 (object_x_reg - back_w_at_row - top_skew_low);
					 
   top_right <= (object_x_reg + back_w_at_row + top_skew_low)  when (relative_is_right_reg = '0' and LANE /= 1) else
					 (object_x_reg + back_w_at_row - top_skew_high) when (relative_is_right_reg = '1' and LANE /= 1) else
					 (object_x_reg + back_w_at_row + top_skew_low)  when (relative_is_right_reg = '0' and LANE = 1)  else
					 (object_x_reg + back_w_at_row - top_skew_low);

   object_top_on <= '1' when ((pixel_row    >= object_y_reg - object_height_reg - top_height_reg) and
                              (pixel_row    <= object_y_reg - object_height_reg)                  and
                              (pixel_column >= top_left)                                          and
                              (pixel_column <= top_right))
                    else '0';

   top_red   <= "0001" when (object_top_on = '1') else "0000";
   top_green <= "1111" when (object_top_on = '1') else "0000";
   top_blue  <= "0001" when (object_top_on = '1') else "0000";

   -- Side face
   side_shift_product          <= side_combined_taper_reg * inverted_local;
   side_shift_unclamped_scaled <= side_shift_product(23 downto 14);

   top_max_scaled_product   <= top_max_extension_reg * abs_relative_slv_reg;
   top_max_extension_scaled <= top_max_scaled_product(15 downto 6);

   actual_side_shift_scaled <= top_max_extension_scaled
                                  when (side_shift_unclamped_scaled >= top_max_extension_scaled) else
                               (others => '0')
                                  when (inverted_local = "0000000000") else
                               side_shift_unclamped_scaled;

   left_side_on  <= '1' when ((pixel_row    >= object_y_reg - object_height_reg - top_height_reg) and
                              (pixel_row    <= object_y_reg - side_top_boundary)                  and
                              (pixel_column >= object_x_reg - object_width_reg - actual_side_shift_scaled) and
                              (pixel_column <= object_x_reg - object_width_reg))
                    else '0';

   right_side_on <= '1' when ((pixel_row    >= object_y_reg - object_height_reg - top_height_reg) and
                              (pixel_row    <= object_y_reg - side_top_boundary)                  and
                              (pixel_column <= object_x_reg + object_width_reg + actual_side_shift_scaled) and
                              (pixel_column >= object_x_reg + object_width_reg))
                    else '0';

   object_side_on <= left_side_on  when (relative_is_right_reg = '1')   else
                     right_side_on when (relative_is_nonzero_reg = '1') else
                     '0';

   side_red   <= "0001" when (object_side_on = '1') else "0000";
   side_green <= "0011" when (object_side_on = '1') else "0000";
   side_blue  <= "0001" when (object_side_on = '1') else "0000";

   -- Priority mux: front > top > side
   red_out   <= object_red   when (object_front_on = '1') else
                top_red      when (object_top_on   = '1') else
                side_red;
   green_out <= object_green when (object_front_on = '1') else
                top_green    when (object_top_on   = '1') else
                side_green;
   blue_out  <= object_blue  when (object_front_on = '1') else
                top_blue     when (object_top_on   = '1') else
                side_blue;
	row_out <= object_distance;

end architecture moving_object_behaviour;