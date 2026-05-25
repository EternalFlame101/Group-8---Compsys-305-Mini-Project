library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity HUD_Overlay is
	port(video_clock				 		: in std_logic;
		  reset					 			: in std_logic;
		  pixel_row, pixel_column     : in std_logic_vector(9 downto 0);
		  score					 			: in std_logic_vector(7 downto 0);
		  HUD_enable				 		: in std_logic;
		  HUD_active				 		: out std_logic; 
		  health_digit						: in std_logic_vector(1 downto 0);
		  score_h, score_t, score_o 	: out std_logic_vector(3 downto 0);
		  red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity HUD_Overlay;

architecture beh of HUD_Overlay is

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

	-- Per-digit RGB outputs
	signal d_hun_r, d_hun_g, d_hun_b : std_logic_vector(3 downto 0);
	signal d_ten_r, d_ten_g, d_ten_b : std_logic_vector(3 downto 0);
	signal d_one_r, d_one_g, d_one_b : std_logic_vector(3 downto 0);
	signal health_red, health_green, health_blue : std_logic_vector(3 downto 0);

	-- Decoded digit values
	signal score_hundreds : std_logic_vector(3 downto 0);
	signal score_tens     : std_logic_vector(3 downto 0);
	signal score_ones     : std_logic_vector(3 downto 0);

	-- Character codes fed to each digit instance
	-- Space = "100000", digit N = "11" & N
	signal char_hundreds : std_logic_vector(5 downto 0);
	signal char_tens     : std_logic_vector(5 downto 0);
	signal char_ones     : std_logic_vector(5 downto 0);

	-- Centred positions (char width = 8px * scale 4 = 32px per digit)
	-- 1 digit  centred at 320: ones   x=304
	-- 2 digits centred at 320: tens   x=288, ones x=320
	-- 3 digits centred at 320: hunds  x=272, tens x=304, ones x=336
	signal x_hundreds : std_logic_vector(9 downto 0);
	signal x_tens     : std_logic_vector(9 downto 0);
	signal x_ones     : std_logic_vector(9 downto 0);
	

	constant SCORE_Y  : integer := 50;
	constant HEALTH_X : integer := 50;
	constant HEALTH_Y : integer := 50;

begin

	-- ----------------------------------------------------------------
	-- Three separate 1-char Word_Display instances, one per digit.
	-- Each is always instantiated; we control visibility by feeding
	-- a space character when that digit position is suppressed.
	-- ----------------------------------------------------------------
	Digit_Hundreds : Word_Display
		generic map(STRING_LENGTH => 1,
					SCALE         => 4,
					TEXT_RED      => "1111",
					TEXT_GREEN    => "1111",
					TEXT_BLUE     => "1111")
		port map (clock         => video_clock,
				  characters    => char_hundreds,
				  x_position    => x_hundreds,
				  y_position    => conv_std_logic_vector(SCORE_Y, 10),
				  pixel_row     => pixel_row,
				  pixel_column  => pixel_column,
				  red_out       => d_hun_r,
				  green_out     => d_hun_g,
				  blue_out      => d_hun_b);

	Digit_Tens : Word_Display
		generic map(STRING_LENGTH => 1,
					SCALE         => 4,
					TEXT_RED      => "1111",
					TEXT_GREEN    => "1111",
					TEXT_BLUE     => "1111")
		port map (clock         => video_clock,
				  characters    => char_tens,
				  x_position    => x_tens,
				  y_position    => conv_std_logic_vector(SCORE_Y, 10),
				  pixel_row     => pixel_row,
				  pixel_column  => pixel_column,
				  red_out       => d_ten_r,
				  green_out     => d_ten_g,
				  blue_out      => d_ten_b);

	Digit_Ones : Word_Display
		generic map(STRING_LENGTH => 1,
					SCALE         => 4,
					TEXT_RED      => "1111",
					TEXT_GREEN    => "1111",
					TEXT_BLUE     => "1111")
		port map (clock         => video_clock,
				  characters    => char_ones,
				  x_position    => x_ones,
				  y_position    => conv_std_logic_vector(SCORE_Y, 10),
				  pixel_row     => pixel_row,
				  pixel_column  => pixel_column,
				  red_out       => d_one_r,
				  green_out     => d_one_g,
				  blue_out      => d_one_b);

	Lives : Word_Display
		generic map(STRING_LENGTH => 1,
					SCALE         => 4,
					TEXT_RED      => "1111",
					TEXT_GREEN    => "1111",
					TEXT_BLUE     => "1111")
		port map (clock         => video_clock,
				  characters    => "11" & "00" & health_digit,
				  x_position    => conv_std_logic_vector(HEALTH_X, 10),
				  y_position    => conv_std_logic_vector(HEALTH_Y, 10),
				  pixel_row     => pixel_row,
				  pixel_column  => pixel_column,
				  red_out       => health_red,
				  green_out     => health_green,
				  blue_out      => health_blue);

	-- ----------------------------------------------------------------
	-- Decode score into hundreds / tens / ones
	-- ----------------------------------------------------------------
	process(score)
		variable s         : integer range 0 to 255;
		variable h         : integer range 0 to 2;
		variable remainder : integer range 0 to 99;
		variable t         : integer range 0 to 9;
		variable o         : integer range 0 to 9;
	begin
		s := conv_integer(score);
		if    s >= 200 then h := 2; remainder := s - 200;
		elsif s >= 100 then h := 1; remainder := s - 100;
		else                h := 0; remainder := s;
		end if;
		if    remainder >= 90 then t := 9; o := remainder - 90;
		elsif remainder >= 80 then t := 8; o := remainder - 80;
		elsif remainder >= 70 then t := 7; o := remainder - 70;
		elsif remainder >= 60 then t := 6; o := remainder - 60;
		elsif remainder >= 50 then t := 5; o := remainder - 50;
		elsif remainder >= 40 then t := 4; o := remainder - 40;
		elsif remainder >= 30 then t := 3; o := remainder - 30;
		elsif remainder >= 20 then t := 2; o := remainder - 20;
		elsif remainder >= 10 then t := 1; o := remainder - 10;
		else                       t := 0; o := remainder;
		end if;
		score_hundreds <= conv_std_logic_vector(h, 4);
		score_tens     <= conv_std_logic_vector(t, 4);
		score_ones     <= conv_std_logic_vector(o, 4);
	end process;

	-- ----------------------------------------------------------------
	-- Character codes: space ("100000") when digit is suppressed,
	-- otherwise "11" & digit_value  ('0'="110000", '1'="110001", ...)
	-- ----------------------------------------------------------------
	char_hundreds <= "11" & score_hundreds when conv_integer(score) >= 100 else "100000";
	char_tens     <= "11" & score_tens     when conv_integer(score) >= 10  else "100000";
	char_ones     <= "11" & score_ones;

	-- ----------------------------------------------------------------
	-- X positions shift so the visible digits stay centred at 320.
	-- Each char is 32px wide (8px font * scale 4).
	--   score 0-9:   1 digit  -> ones   at 304
	--   score 10-99: 2 digits -> tens   at 288, ones at 320
	--   score 100+:  3 digits -> hunds  at 272, tens at 304, ones at 336
	-- ----------------------------------------------------------------
	x_hundreds <= conv_std_logic_vector(272, 10);  -- only drawn when score>=100
	x_tens     <= conv_std_logic_vector(288, 10) when conv_integer(score) < 100
					  else conv_std_logic_vector(304, 10);
	x_ones     <= conv_std_logic_vector(304, 10) when conv_integer(score) < 10
					  else conv_std_logic_vector(320, 10) when conv_integer(score) < 100
					  else conv_std_logic_vector(336, 10);

					  
	score_h <= score_hundreds;
	score_t <= score_tens;
	score_o <= score_ones;
	
	-- ----------------------------------------------------------------
	-- Output mux: score digits take priority, then health, then blank
	-- ----------------------------------------------------------------
	process(HUD_enable, d_hun_r, d_hun_g, d_hun_b,
						 d_ten_r, d_ten_g, d_ten_b,
						 d_one_r, d_one_g, d_one_b,
						 health_red, health_green, health_blue)
		variable score_r, score_g, score_b : std_logic_vector(3 downto 0);
	begin
		-- Merge the three digit outputs (at most one is non-zero per pixel)
		score_r := d_hun_r or d_ten_r or d_one_r;
		score_g := d_hun_g or d_ten_g or d_one_g;
		score_b := d_hun_b or d_ten_b or d_one_b;

		if HUD_enable = '1' then
			if (score_r or score_g or score_b) /= "0000" then
				red_out    <= score_r;
				green_out  <= score_g;
				blue_out   <= score_b;
				HUD_active <= '1';
			elsif (health_red or health_green or health_blue) /= "0000" then
				red_out    <= health_red;
				green_out  <= health_green;
				blue_out   <= health_blue;
				HUD_active <= '1';
			else
				red_out    <= "0000";
				green_out  <= "0000";
				blue_out   <= "0000";
				HUD_active <= '0';
			end if;
		else
			red_out    <= "0000";
			green_out  <= "0000";
			blue_out   <= "0000";
			HUD_active <= '0';
		end if;
	end process;

end architecture beh;