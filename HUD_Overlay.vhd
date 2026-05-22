	library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.std_logic_arith.all;
	use IEEE.std_logic_unsigned.all;

	entity HUD_Overlay is
		port(video_clock						 : in std_logic;
			  reset								 : in std_logic;
			  pixel_row, pixel_column      : in std_logic_vector(9 downto 0);
			  score								 : in std_logic_vector(5 downto 0);
			  HUD_enable						 : in std_logic; -- in running or nah (in game master)
			  HUD_active						 : out std_logic; 
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

		signal score_red, score_green, score_blue : std_logic_vector(3 downto 0);
		signal health_red, health_green, health_blue : std_logic_vector(3 downto 0);

		signal score_tens : std_logic_vector(3 downto 0);
		signal score_ones : std_logic_vector(3 downto 0);
		signal score_tens_char : std_logic_vector(5 downto 0);
		signal score_ones_char : std_logic_vector(5 downto 0);
		signal score_chars     : std_logic_vector(11 downto 0);

		-- Score 
		constant SCORE_X : integer := 288;
		constant SCORE_Y : integer := 50;
		
		constant HEALTH_X : integer := 50;
		constant HEALTH_Y : integer := 50;
	begin 

		
		Points : Word_Display
			generic map(STRING_LENGTH => 2,
							SCALE			  => 4, 
							TEXT_RED		  => "1111",
							TEXT_GREEN 	  => "1111",
							TEXT_BLUE 	  => "1111")
			port map (clock          => video_clock,
						 characters     => score_chars,
						 x_position     => conv_std_logic_vector(SCORE_X, 10),
						 y_position     => conv_std_logic_vector(SCORE_Y, 10),
						 pixel_row      => pixel_row,
						 pixel_column   => pixel_column,
						 red_out        => score_red,
						 green_out      => score_green,
						 blue_out       => score_blue);
		
		Lives : Word_Display
			generic map(STRING_LENGTH => 1,
							SCALE			  => 4,
							TEXT_RED		  => "1111",
							TEXT_GREEN 	  => "1111",
							TEXT_BLUE 	  => "1111")
			port map (clock          => video_clock,
						 characters     => "110000",   -- VARIABLE SCORE -- 0 for now 
						 x_position     => conv_std_logic_vector(HEALTH_X, 10),
						 y_position     => conv_std_logic_vector(HEALTH_Y, 10),
						 pixel_row      => pixel_row,
						 pixel_column   => pixel_column,
						 red_out        => health_red,
						 green_out      => health_green,
						 blue_out       => health_blue);
		
		process(HUD_enable, score_red, score_green, score_blue,
				  health_red, health_green, health_blue)
		begin
			  if HUD_enable = '1' then
					-- Score layer takes priority, then health, then transparent
					if (score_red or score_green or score_blue) /= "0000" then
						 red_out   <= score_red;
						 green_out <= score_green;
						 blue_out  <= score_blue;
						 HUD_active <= '1';
					elsif (health_red or health_green or health_blue) /= "0000" then
						 red_out   <= health_red;
						 green_out <= health_green;
						 blue_out  <= health_blue;
						 HUD_active <= '1';
					else
						 red_out   <= "0000";
						 green_out <= "0000";
						 blue_out  <= "0000";
						 HUD_active <= '0';
					end if;
			  else
					red_out   <= "0000";
					green_out <= "0000";
					blue_out  <= "0000";
					HUD_active <= '0';
			  end if;
		end process;
		
		process(score)
			 variable s : integer range 0 to 63;
		begin
			 s := conv_integer(score);
			 if    s >= 60 then score_tens <= "0110"; score_ones <= conv_std_logic_vector(s - 60, 4);
			 elsif s >= 50 then score_tens <= "0101"; score_ones <= conv_std_logic_vector(s - 50, 4);
			 elsif s >= 40 then score_tens <= "0100"; score_ones <= conv_std_logic_vector(s - 40, 4);
			 elsif s >= 30 then score_tens <= "0011"; score_ones <= conv_std_logic_vector(s - 30, 4);
			 elsif s >= 20 then score_tens <= "0010"; score_ones <= conv_std_logic_vector(s - 20, 4);
			 elsif s >= 10 then score_tens <= "0001"; score_ones <= conv_std_logic_vector(s - 10, 4);
			 else               score_tens <= "0000"; score_ones <= conv_std_logic_vector(s,      4);
			 end if;
		end process;
		
		score_tens_char <= "11" & score_tens;
		score_ones_char <= "11" & score_ones;
		score_chars     <= score_tens_char & score_ones_char;

	end architecture beh;
