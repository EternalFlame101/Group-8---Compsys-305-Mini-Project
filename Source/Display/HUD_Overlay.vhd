library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ============================================================
-- HUD_Overlay
-- Character codes verified against tcgrom.mif (octal addresses,
-- index = address / 8):
--   Space = 32  = "100000"
--   E     =  5  = "000101"    I =  9 = "001001"
--   L     = 12  = "001100"    M = 13 = "001101"
--   O     = 15  = "001111"    R = 18 = "010010"
--   S     = 19  = "010011"    T = 20 = "010100"
--   U     = 21  = "010101"    V = 22 = "010110"
--   C     =  3  = "000011"
--   colon = 29  = "011101"
--   digits 0-9  = "11" & digit_value  (index 48-57, confirmed)
--
-- Layout (640x480):
--   Top-left  : "LIVES" label + lives digit  (green)
--   Top-centre: "SCORE" label + score digits (yellow)
--   Top-right : "TIME"  label + MM:SS digits (cyan)
-- ============================================================

entity HUD_Overlay is
	port (video_clock                   : in  std_logic;
			reset                         : in  std_logic;
			pixel_row, pixel_column       : in  std_logic_vector(9 downto 0);
			score                         : in  std_logic_vector(9 downto 0);
			HUD_enable                    : in  std_logic;
			HUD_active                    : out std_logic;
			health_digit                  : in  std_logic_vector(1 downto 0);  -- raw hit counter from Game_Master
			game_mode                     : in  std_logic;                     -- '0'=training(max 3), '1'=normal(max 1)
			min_tens, min_ones            : in  std_logic_vector(3 downto 0);
			sec_tens, sec_ones            : in  std_logic_vector(3 downto 0);
			score_h, score_t, score_o     : out std_logic_vector(3 downto 0);
			red_out, green_out, blue_out  : out std_logic_vector(3 downto 0));
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

	-- RGB outputs per element
	signal d_hun_r, d_hun_g, d_hun_b     : std_logic_vector(3 downto 0);
	signal d_ten_r, d_ten_g, d_ten_b     : std_logic_vector(3 downto 0);
	signal d_one_r, d_one_g, d_one_b     : std_logic_vector(3 downto 0);
	signal slbl_r,  slbl_g,  slbl_b      : std_logic_vector(3 downto 0);
	signal hlth_r,  hlth_g,  hlth_b      : std_logic_vector(3 downto 0);
	signal llbl_r,  llbl_g,  llbl_b      : std_logic_vector(3 downto 0);
	signal tmmt_r,  tmmt_g,  tmmt_b      : std_logic_vector(3 downto 0);
	signal tmmo_r,  tmmo_g,  tmmo_b      : std_logic_vector(3 downto 0);
	signal tmco_r,  tmco_g,  tmco_b      : std_logic_vector(3 downto 0);
	signal tmst_r,  tmst_g,  tmst_b      : std_logic_vector(3 downto 0);
	signal tmso_r,  tmso_g,  tmso_b      : std_logic_vector(3 downto 0);
	signal tlbl_r,  tlbl_g,  tlbl_b      : std_logic_vector(3 downto 0);

	-- Score decode
	signal score_hundreds  : std_logic_vector(3 downto 0);
	signal score_tens      : std_logic_vector(3 downto 0);
	signal score_ones      : std_logic_vector(3 downto 0);
	signal char_hundreds   : std_logic_vector(5 downto 0);
	signal char_tens       : std_logic_vector(5 downto 0);
	signal char_ones       : std_logic_vector(5 downto 0);
	signal x_hundreds      : std_logic_vector(9 downto 0);
	signal x_tens          : std_logic_vector(9 downto 0);
	signal x_ones          : std_logic_vector(9 downto 0);

	signal remaining_lives : std_logic_vector(3 downto 0);

	-- Layout constants
	constant LABEL_Y     : integer := 8;
	constant VALUE_Y     : integer := 28;

	constant LIVES_X     : integer := 10;
	-- "SCORE" = 5 chars x 16px = 80px wide, centred at 320 -> start at 280
	constant SCORE_LBL_X : integer := 280;
	-- Score digits centred at 320, each 32px wide
	-- TIME: 5 chars (MM:SS) x 32px = 160px, right-aligned to x=630 -> start at 470
	constant TIME_VAL_X  : integer := 470;
	-- "TIME" = 4 chars x 16px = 64px, centred over MM:SS block centre (470+80=550) -> start at 518
	constant TIME_LBL_X  : integer := 518;

	-- Verified colon code: index 29 = "011101"
	constant CHAR_COLON  : std_logic_vector(5 downto 0) := "011101";
	-- Space: index 32 = "100000"
	constant CHAR_SPACE  : std_logic_vector(5 downto 0) := "100000";

begin

	-- ==========================================================
	-- LIVES LABEL  "LIVES"  (scale 2, green)
	-- L=001100  I=001001  V=010110  E=000101  S=010011
	-- ==========================================================
	Lives_Label : Word_Display
		generic map (STRING_LENGTH => 5, SCALE => 2,
					   TEXT_RED => "0000", TEXT_GREEN => "1111", TEXT_BLUE => "0000")
		port map (clock        => video_clock,
				    characters  => "001100" & "001001" & "010110" & "000101" & "010011",
				    x_position  => conv_std_logic_vector(LIVES_X, 10),
				    y_position  => conv_std_logic_vector(LABEL_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => llbl_r, green_out => llbl_g, blue_out => llbl_b);

	-- ==========================================================
	-- Remaining lives compute
	-- ==========================================================
	process(game_mode, health_digit)
	begin
		if health_digit = "11" then
			-- Title screen or game over state
			remaining_lives <= "0000"; 
		elsif game_mode = '1' then
			-- SINGLE PLAYER MODE (Normal)
			if health_digit = "10" then
				remaining_lives <= "0001"; -- 1 Life remaining at start
			else
				remaining_lives <= "0000";
			end if;
		else
			-- TRAINING MODE
			case health_digit is
				when "00"   => remaining_lives <= "0011"; -- 3 Lives remaining at start
				when "01"   => remaining_lives <= "0010"; -- 2 Lives remaining
				when "10"   => remaining_lives <= "0001"; -- 1 Life remaining
				when others => remaining_lives <= "0000";
			end case;
		end if;
	end process;

	-- ==========================================================
	-- LIVES VALUE  (scale 4, green)
	-- digit N = "11" & N  (confirmed: '0'=48=oct600, '1'=49=oct610)
	-- ==========================================================
	Lives_Value : Word_Display
		generic map (STRING_LENGTH => 1, SCALE => 4,
					   TEXT_RED => "0000", TEXT_GREEN => "1111", TEXT_BLUE => "0000")
		port map (clock        => video_clock,
				    characters  => "11" & remaining_lives,
				    x_position  => conv_std_logic_vector(LIVES_X, 10),
				    y_position  => conv_std_logic_vector(VALUE_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => hlth_r, green_out => hlth_g, blue_out => hlth_b);

	-- ==========================================================
	-- SCORE LABEL  "SCORE"  (scale 2, yellow)
	-- S=010011  C=000011  O=001111  R=010010  E=000101
	-- ==========================================================
	Score_Label : Word_Display
		generic map (STRING_LENGTH => 5, SCALE => 2,
					   TEXT_RED => "1111", TEXT_GREEN => "1111", TEXT_BLUE => "0000")
		port map (clock        => video_clock,
				    characters  => "010011" & "000011" & "001111" & "010010" & "000101",
				    x_position  => conv_std_logic_vector(SCORE_LBL_X, 10),
				    y_position  => conv_std_logic_vector(LABEL_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => slbl_r, green_out => slbl_g, blue_out => slbl_b);

	-- ==========================================================
	-- SCORE DIGITS  (scale 4, white)
	-- ==========================================================
	Digit_Hundreds : Word_Display
		generic map (STRING_LENGTH => 1, SCALE => 4,
					   TEXT_RED => "1111", TEXT_GREEN => "1111", TEXT_BLUE => "1111")
		port map (clock        => video_clock,
				    characters  => char_hundreds,
				    x_position  => x_hundreds,
				    y_position  => conv_std_logic_vector(VALUE_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => d_hun_r, green_out => d_hun_g, blue_out => d_hun_b);

	Digit_Tens : Word_Display
		generic map (STRING_LENGTH => 1, SCALE => 4,
					   TEXT_RED => "1111", TEXT_GREEN => "1111", TEXT_BLUE => "1111")
		port map (clock        => video_clock,
				    characters  => char_tens,
				    x_position  => x_tens,
				    y_position  => conv_std_logic_vector(VALUE_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => d_ten_r, green_out => d_ten_g, blue_out => d_ten_b);

	Digit_Ones : Word_Display
		generic map (STRING_LENGTH => 1, SCALE => 4,
					   TEXT_RED => "1111", TEXT_GREEN => "1111", TEXT_BLUE => "1111")
		port map (clock        => video_clock,
				    characters  => char_ones,
				    x_position  => x_ones,
				    y_position  => conv_std_logic_vector(VALUE_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => d_one_r, green_out => d_one_g, blue_out => d_one_b);

	-- ==========================================================
	-- TIME LABEL  "TIME"  (scale 2, cyan)
	-- T=010100  I=001001  M=001101  E=000101
	-- ==========================================================
	Time_Label : Word_Display
		generic map (STRING_LENGTH => 4, SCALE => 2,
					   TEXT_RED => "0000", TEXT_GREEN => "1111", TEXT_BLUE => "1111")
		port map (clock        => video_clock,
				    characters  => "010100" & "001001" & "001101" & "000101",
				    x_position  => conv_std_logic_vector(TIME_LBL_X, 10),
				    y_position  => conv_std_logic_vector(LABEL_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => tlbl_r, green_out => tlbl_g, blue_out => tlbl_b);

	-- ==========================================================
	-- TIME DIGITS  MM:SS  (scale 4, cyan)
	-- Each char 32px wide:
	--   min_tens : TIME_VAL_X +   0 = 470
	--   min_ones : TIME_VAL_X +  32 = 502
	--   colon    : TIME_VAL_X +  64 = 534
	--   sec_tens : TIME_VAL_X +  96 = 566
	--   sec_ones : TIME_VAL_X + 128 = 598
	-- ==========================================================
	Time_MinTens : Word_Display
		generic map (STRING_LENGTH => 1, SCALE => 4,
					   TEXT_RED => "0000", TEXT_GREEN => "1111", TEXT_BLUE => "1111")
		port map (clock        => video_clock,
				    characters  => "11" & min_tens,
				    x_position  => conv_std_logic_vector(TIME_VAL_X, 10),
				    y_position  => conv_std_logic_vector(VALUE_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => tmmt_r, green_out => tmmt_g, blue_out => tmmt_b);

	Time_MinOnes : Word_Display
		generic map (STRING_LENGTH => 1, SCALE => 4,
					   TEXT_RED => "0000", TEXT_GREEN => "1111", TEXT_BLUE => "1111")
		port map (clock        => video_clock,
				    characters  => "11" & min_ones,
				    x_position  => conv_std_logic_vector(TIME_VAL_X + 32, 10),
				    y_position  => conv_std_logic_vector(VALUE_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => tmmo_r, green_out => tmmo_g, blue_out => tmmo_b);

	Time_Colon : Word_Display
		generic map (STRING_LENGTH => 1, SCALE => 4,
					   TEXT_RED => "0000", TEXT_GREEN => "1111", TEXT_BLUE => "1111")
		port map (clock        => video_clock,
				    characters  => CHAR_COLON,
				    x_position  => conv_std_logic_vector(TIME_VAL_X + 64, 10),
				    y_position  => conv_std_logic_vector(VALUE_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => tmco_r, green_out => tmco_g, blue_out => tmco_b);

	Time_SecTens : Word_Display
		generic map (STRING_LENGTH => 1, SCALE => 4,
					   TEXT_RED => "0000", TEXT_GREEN => "1111", TEXT_BLUE => "1111")
		port map (clock        => video_clock,
				    characters  => "11" & sec_tens,
				    x_position  => conv_std_logic_vector(TIME_VAL_X + 96, 10),
				    y_position  => conv_std_logic_vector(VALUE_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => tmst_r, green_out => tmst_g, blue_out => tmst_b);

	Time_SecOnes : Word_Display
		generic map (STRING_LENGTH => 1, SCALE => 4,
					   TEXT_RED => "0000", TEXT_GREEN => "1111", TEXT_BLUE => "1111")
		port map (clock        => video_clock,
				    characters  => "11" & sec_ones,
				    x_position  => conv_std_logic_vector(TIME_VAL_X + 128, 10),
				    y_position  => conv_std_logic_vector(VALUE_Y, 10),
				    pixel_row   => pixel_row, pixel_column => pixel_column,
				    red_out     => tmso_r, green_out => tmso_g, blue_out => tmso_b);

	-- ==========================================================
	-- Score BCD decode
	-- ==========================================================
	process(score)
		variable s, h, remainder, t, o : integer;
	begin
		s := conv_integer(score);
		if    s >= 900 then h := 9; remainder := s - 900;
		elsif s >= 800 then h := 8; remainder := s - 800;
		elsif s >= 700 then h := 7; remainder := s - 700;
		elsif s >= 600 then h := 6; remainder := s - 600;
		elsif s >= 500 then h := 5; remainder := s - 500;
		elsif s >= 400 then h := 4; remainder := s - 400;
		elsif s >= 300 then h := 3; remainder := s - 300;
		elsif s >= 200 then h := 2; remainder := s - 200;
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

	char_hundreds <= "11" & score_hundreds when conv_integer(score) >= 100 else CHAR_SPACE;
	char_tens     <= "11" & score_tens     when conv_integer(score) >= 10  else CHAR_SPACE;
	char_ones     <= "11" & score_ones;

	-- Score digit X positions (centred at 320, each 32px wide)
	x_hundreds <= conv_std_logic_vector(272, 10);
	x_tens     <= conv_std_logic_vector(288, 10) when conv_integer(score) < 100
	              else conv_std_logic_vector(304, 10);
	x_ones     <= conv_std_logic_vector(304, 10) when conv_integer(score) < 10
	              else conv_std_logic_vector(320, 10) when conv_integer(score) < 100
	              else conv_std_logic_vector(336, 10);

	score_h <= score_hundreds;
	score_t <= score_tens;
	score_o <= score_ones;

	-- ==========================================================
	-- Output mux: OR all layers together
	-- ==========================================================
	process(HUD_enable,
			  d_hun_r, d_hun_g, d_hun_b,
			  d_ten_r, d_ten_g, d_ten_b,
			  d_one_r, d_one_g, d_one_b,
			  slbl_r, slbl_g, slbl_b,
			  hlth_r, hlth_g, hlth_b,
			  llbl_r, llbl_g, llbl_b,
			  tmmt_r, tmmt_g, tmmt_b,
			  tmmo_r, tmmo_g, tmmo_b,
			  tmco_r, tmco_g, tmco_b,
			  tmst_r, tmst_g, tmst_b,
			  tmso_r, tmso_g, tmso_b,
			  tlbl_r, tlbl_g, tlbl_b)
		variable r, g, b : std_logic_vector(3 downto 0);
	begin
		r := d_hun_r or d_ten_r or d_one_r or slbl_r
		          or hlth_r or llbl_r
		          or tmmt_r or tmmo_r or tmco_r or tmst_r or tmso_r or tlbl_r;
		g := d_hun_g or d_ten_g or d_one_g or slbl_g
		          or hlth_g or llbl_g
		          or tmmt_g or tmmo_g or tmco_g or tmst_g or tmso_g or tlbl_g;
		b := d_hun_b or d_ten_b or d_one_b or slbl_b
		          or hlth_b or llbl_b
		          or tmmt_b or tmmo_b or tmco_b or tmst_b or tmso_b or tlbl_b;

		if HUD_enable = '1' then
			red_out   <= r;
			green_out <= g;
			blue_out  <= b;
			if (r or g or b) /= "0000" then
				HUD_active <= '1';
			else
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