library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Track_Generator is
   port (clock, vertical_sync         : in  std_logic;
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
         cat_view_position            : in  std_logic_vector(7 downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Track_Generator;

architecture track_generator_behaviour of Track_Generator is

   component Perspective_ROM is
      port (clock              : in  std_logic;
            track_row          : in  std_logic_vector(9 downto 0);
            perspective_output : out std_logic_vector(9 downto 0));
   end component Perspective_ROM;

   constant HORIZON_ROW    : std_logic_vector(9 downto 0) := conv_std_logic_vector(320, 10);
   constant TRACK_CENTRE_X : std_logic_vector(9 downto 0) := conv_std_logic_vector(320, 10);

   signal depth      : std_logic_vector(9 downto 0);
   signal spread_rom : std_logic_vector(9 downto 0);

   -- Per-row combinational signals
   signal cat_view_int_comb      : integer range -64 to 64;
   signal cat_view_abs_comb      : integer range 0 to 64;
   signal cat_view_abs_slv_comb  : std_logic_vector(7 downto 0);
   signal view_is_right_comb     : std_logic;

   signal lane_offset_product_comb : std_logic_vector(13 downto 0);
   signal lane_offset_comb         : std_logic_vector(9 downto 0);
   signal view_shift_product_comb  : std_logic_vector(17 downto 0);
   signal view_shift_pixels_comb   : std_logic_vector(9 downto 0);
   signal effective_centre_comb    : std_logic_vector(9 downto 0);
   signal track_left_edge_comb     : std_logic_vector(9 downto 0);
   signal track_right_edge_comb    : std_logic_vector(9 downto 0);

   -- Registered outputs
   signal track_left_edge_reg  : std_logic_vector(9 downto 0);
   signal track_right_edge_reg : std_logic_vector(9 downto 0);

   signal track_on : std_logic;

begin

   Perspective_Lookup : Perspective_ROM
      port map (clock              => clock,
                track_row          => depth,
                perspective_output => spread_rom);

   depth <= (pixel_row - HORIZON_ROW) when (pixel_row >= HORIZON_ROW) else (others => '0');

   -- Per-row combinational (whole chain settles before the register captures it)
   cat_view_int_comb     <= conv_integer(signed(cat_view_position));
   cat_view_abs_comb     <= cat_view_int_comb when cat_view_int_comb >= 0 else -cat_view_int_comb;
   cat_view_abs_slv_comb <= conv_std_logic_vector(cat_view_abs_comb, 8);
   view_is_right_comb    <= '1' when cat_view_int_comb > 0 else '0';

   lane_offset_product_comb <= conv_std_logic_vector(11, 4) * spread_rom;
   lane_offset_comb         <= lane_offset_product_comb(13 downto 4);

   view_shift_product_comb <= cat_view_abs_slv_comb * lane_offset_comb;
   view_shift_pixels_comb  <= view_shift_product_comb(15 downto 6);

   effective_centre_comb <= TRACK_CENTRE_X - view_shift_pixels_comb when view_is_right_comb = '1' else
                            TRACK_CENTRE_X + view_shift_pixels_comb;

   track_left_edge_comb  <= effective_centre_comb - spread_rom
                               when effective_centre_comb >= spread_rom else (others => '0');
   track_right_edge_comb <= effective_centre_comb + spread_rom;

   -- Pipeline register: edge coords lock in once per row
   Pipeline_Process : process(clock)
   begin
      if rising_edge(clock) then
         track_left_edge_reg  <= track_left_edge_comb;
         track_right_edge_reg <= track_right_edge_comb;
      end if;
   end process Pipeline_Process;

   -- Per-pixel: comparisons only
   track_on <= '1' when (pixel_row    >= HORIZON_ROW           and
                         pixel_column >= track_left_edge_reg   and
                         pixel_column <= track_right_edge_reg)
               else '0';

   red_out   <= "1111" when (track_on = '1') else "0000";
   green_out <= "1111" when (track_on = '1') else "0000";
   blue_out  <= "1111" when (track_on = '1') else "0000";

end architecture track_generator_behaviour;