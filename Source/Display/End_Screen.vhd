-- ------------------------------------------------------------------------------
-- End_Screen
--   Renders the win/lose end screen. end_screen_outcome selects which message is
--   shown (0 = lose, 1 = win); end_screen_active gates it on. Pulses end_screen
--   when the player dismisses it (any key / click) so Game_Master can return to
--   the start screen.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity End_Screen is
   port (video_clock                  : in  std_logic;
         reset                        : in  std_logic;
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
         mouse_row, mouse_column      : in  std_logic_vector(9 downto 0);
         any_key_pressed              : in  std_logic;
         end_screen_outcome           : in  std_logic;
         end_screen_active            : in  std_logic;
         end_screen                   : out std_logic;
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity End_Screen;

architecture end_screen_behaviour of End_Screen is

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

   -- ---------------------------------------------------------------------------
   -- State
   -- ---------------------------------------------------------------------------
   signal screen_active : std_logic := '1';

   -- ---------------------------------------------------------------------------
   -- Text pixel outputs
   -- ---------------------------------------------------------------------------
   signal you_red,  you_green,  you_blue  : std_logic_vector(3 downto 0);
   signal win_red,  win_green,  win_blue  : std_logic_vector(3 downto 0);
   signal lose_red, lose_green, lose_blue : std_logic_vector(3 downto 0);
   signal cont_red, cont_green, cont_blue : std_logic_vector(3 downto 0);
   -- Registered subtitle outputs: the 54-char OR tree from pixel_column_r to
   -- cont_* is ~6 ns; registering it here keeps the Output_Compositor path
   -- (cont_r + you/win/lose OR) short enough for the 80 MHz target.
   signal cont_red_r, cont_green_r, cont_blue_r : std_logic_vector(3 downto 0) := (others => '0');
   signal pixel_row_r, pixel_column_r    : std_logic_vector(9 downto 0) := (others => '0');
   signal red_comb, green_comb, blue_comb : std_logic_vector(3 downto 0);

   -- ---------------------------------------------------------------------------
   -- Layout
   -- "YOU" - 3 chars SCALE 3 (24px each = 72px wide), centred x = (640-72)/2 = 284
   -- "WIN" - 3 chars SCALE 3, centred x = 284
   -- "LOSE"- 4 chars SCALE 3 (24*4=96px), centred x = (640-96)/2 = 272
   -- "CLICK ANYWHERE TO CONTINUE" - 26 chars SCALE 1 (8px each = 208px)
   --   centred x = (640-208)/2 = 216
   -- ---------------------------------------------------------------------------
   constant YOU_X  : integer := 284;
   constant YOU_Y  : integer := 180;
   constant WIN_X  : integer := 284;
   constant WIN_Y  : integer := 240;
   constant LOSE_X : integer := 272;
   constant LOSE_Y : integer := 240;
   constant CONT_X : integer := 104;
   constant CONT_Y : integer := 320;

begin

   -- ---------------------------------------------------------------------------
   -- Screen active latch: goes low on click or key press
   -- ---------------------------------------------------------------------------
   Pixel_Coord_Pipe : process(video_clock)
   begin
      if rising_edge(video_clock) then
         pixel_row_r    <= pixel_row;
         pixel_column_r <= pixel_column;
         cont_red_r     <= cont_red;
         cont_green_r   <= cont_green;
         cont_blue_r    <= cont_blue;
      end if;
   end process Pixel_Coord_Pipe;

   Screen_Latch : process(video_clock, reset)
   begin
      if reset = '1' then
         screen_active <= '1';
      elsif rising_edge(video_clock) then
         if (any_key_pressed = '1' and end_screen_active = '1') then
            screen_active <= '0';
         end if;
      end if;
   end process Screen_Latch;

   end_screen <= screen_active;

   -- ---------------------------------------------------------------------------
   -- "YOU" - always shown (SCALE 3, purple)
   -- ---------------------------------------------------------------------------
   You_Text : Word_Display
      generic map (STRING_LENGTH => 3,
                   SCALE         => 3,
                   TEXT_RED      => "1001",
                   TEXT_GREEN    => "0111",
                   TEXT_BLUE     => "1100")
      port map (clock          => video_clock,
                characters     => "011001" &  -- Y
                                  "001111" &  -- O
                                  "010101",   -- U
                x_position     => conv_std_logic_vector(YOU_X,  10),
                y_position     => conv_std_logic_vector(YOU_Y,  10),
                pixel_row      => pixel_row_r,
                pixel_column   => pixel_column_r,
                red_out        => you_red,
                green_out      => you_green,
                blue_out       => you_blue);

   -- ---------------------------------------------------------------------------
   -- "WIN" - shown when end_screen_outcome = '1' (green)
   -- ---------------------------------------------------------------------------
   Win_Text : Word_Display
      generic map (STRING_LENGTH => 3,
                   SCALE         => 3,
                   TEXT_RED      => "0000",
                   TEXT_GREEN    => "1111",
                   TEXT_BLUE     => "0000")
      port map (clock          => video_clock,
                characters     => "010111" &  -- W
                                  "001001" &  -- I
                                  "001110",   -- N
                x_position     => conv_std_logic_vector(WIN_X,  10),
                y_position     => conv_std_logic_vector(WIN_Y,  10),
                pixel_row      => pixel_row_r,
                pixel_column   => pixel_column_r,
                red_out        => win_red,
                green_out      => win_green,
                blue_out       => win_blue);

   -- ---------------------------------------------------------------------------
   -- "LOSE" - shown when end_screen_outcome = '0' (red)
   -- ---------------------------------------------------------------------------
   Lose_Text : Word_Display
      generic map (STRING_LENGTH => 4,
                   SCALE         => 3,
                   TEXT_RED      => "1111",
                   TEXT_GREEN    => "0000",
                   TEXT_BLUE     => "0000")
      port map (clock          => video_clock,
                characters     => "001100" &  -- L
                                  "001111" &  -- O
                                  "010011" &  -- S
                                  "000101",   -- E
                x_position     => conv_std_logic_vector(LOSE_X, 10),
                y_position     => conv_std_logic_vector(LOSE_Y, 10),
                pixel_row      => pixel_row_r,
                pixel_column   => pixel_column_r,
                red_out        => lose_red,
                green_out      => lose_green,
                blue_out       => lose_blue);

   -- --------------------------------------------------------------------------------
   -- "CLICK ANYWHERE ON THE SCREEN/PRESS ANY KEY TO CONTINUE" (SCALE 1, muted purple)
   -- --------------------------------------------------------------------------------
   Subtitle : Word_Display
      generic map (STRING_LENGTH => 54,
                   SCALE         => 1,
                   TEXT_RED      => "0110",
                   TEXT_GREEN    => "0101",
                   TEXT_BLUE     => "1000")
      port map (clock          => video_clock,
                characters     => "000011" &  -- C
                                  "001100" &  -- L
                                  "001001" &  -- I
                                  "000011" &  -- C
                                  "001011" &  -- K
                                  "100000" &  -- sp
                                  "000001" &  -- A
                                  "001110" &  -- N
                                  "011001" &  -- Y
                                  "010111" &  -- W
                                  "001000" &  -- H
                                  "000101" &  -- E
                                  "010010" &  -- R
                                  "000101" &  -- E
                                  "100000" &  -- sp
                                  "001111" &  -- O
                                  "001110" &  -- N
                                  "100000" &  -- sp
                                  "010100" &  -- T
                                  "001000" &  -- H
                                  "000101" &  -- E
                                  "100000" &  -- sp
                                  "010011" &  -- S
                                  "000011" &  -- C
                                  "010010" &  -- R
                                  "000101" &  -- E
                                  "000101" &  -- E
                                  "001110" &  -- N
                                  "101111" &  -- /  = 47
                                  "010000" &  -- P
                                  "010010" &  -- R
                                  "000101" &  -- E
                                  "010011" &  -- S
                                  "010011" &  -- S
                                  "100000" &  -- sp
                                  "000001" &  -- A
                                  "001110" &  -- N
                                  "011001" &  -- Y
                                  "100000" &  -- sp
                                  "001011" &  -- K
                                  "000101" &  -- E
                                  "011001" &  -- Y
                                  "100000" &  -- sp
                                  "010100" &  -- T
                                  "001111" &  -- O
                                  "100000" &  -- sp
                                  "000011" &  -- C
                                  "001111" &  -- O
                                  "001110" &  -- N
                                  "010100" &  -- T
                                  "001001" &  -- I
                                  "001110" &  -- N
                                  "010101" &  -- U
                                  "000101",   -- E
                x_position     => conv_std_logic_vector(CONT_X, 10),
                y_position     => conv_std_logic_vector(CONT_Y, 10),
                pixel_row      => pixel_row_r,
                pixel_column   => pixel_column_r,
                red_out        => cont_red,
                green_out      => cont_green,
                blue_out       => cont_blue);

   -- ---------------------------------------------------------------------------
   -- Output compositor
   -- WIN:  YOU + WIN  + continue prompt
   -- LOSE: YOU + LOSE + continue prompt
   -- ---------------------------------------------------------------------------
   Output_Compositor : process(end_screen_outcome,
                               you_red,  you_green,  you_blue,
                               win_red,  win_green,  win_blue,
                               lose_red, lose_green, lose_blue,
                               cont_red_r, cont_green_r, cont_blue_r)
   begin
      if end_screen_outcome = '1' then
         red_comb   <= you_red   or win_red   or cont_red_r;
         green_comb <= you_green or win_green or cont_green_r;
         blue_comb  <= you_blue  or win_blue  or cont_blue_r;
      else
         red_comb   <= you_red   or lose_red   or cont_red_r;
         green_comb <= you_green or lose_green or cont_green_r;
         blue_comb  <= you_blue  or lose_blue  or cont_blue_r;
      end if;
   end process Output_Compositor;

   Output_Reg : process(video_clock)
   begin
      if rising_edge(video_clock) then
         red_out   <= red_comb;
         green_out <= green_comb;
         blue_out  <= blue_comb;
      end if;
   end process Output_Reg;

end architecture end_screen_behaviour;