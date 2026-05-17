library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ------------------------------------------------------------------------------
-- Track_Generator
--   Renders a perspective racetrack using the Perspective_ROM lookup. The
--   ROM maps a distance-from-horizon ("depth") value to a half-width
--   ("spread") that the track occupies at that row. The track is centred
--   on column 320 and widens as depth increases, giving the visual
--   appearance of a road receding into the distance.
--
--   The Perspective_ROM is clocked, so this block must run on the same
--   clock domain as the VGA pixel generator (i.e. video_clock).
-- ------------------------------------------------------------------------------
entity Track_Generator is
   port (clock, vertical_sync         : in  std_logic;
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
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

   signal track_on : std_logic;
   signal depth    : std_logic_vector(9 downto 0);
   signal spread   : std_logic_vector(9 downto 0);

begin

   -- Look up the half-width of the track at the current row.
   Perspective_Lookup : Perspective_ROM
      port map (clock              => clock,
                track_row          => depth,
                perspective_output => spread);

   -- Depth = how far below the horizon we are. Above the horizon, depth is
   -- pinned to 0 so the ROM lookup is well-defined (the track simply won't
   -- draw there because of the pixel_row >= HORIZON_ROW guard below).
   depth <= (pixel_row - HORIZON_ROW)
            when (pixel_row >= HORIZON_ROW)
            else (others => '0');

   track_on <= '1' when (pixel_row    >= HORIZON_ROW                  and
                         pixel_column >= TRACK_CENTRE_X - spread      and
                         pixel_column <= TRACK_CENTRE_X + spread)
               else '0';

   red_out   <= "1111" when (track_on = '1') else "0000";
   green_out <= "1111" when (track_on = '1') else "0000";
   blue_out  <= "1111" when (track_on = '1') else "0000";

end architecture track_generator_behaviour;