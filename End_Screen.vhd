library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity End_Screen is
   port (video_clock                  : in  std_logic;
         reset                        : in  std_logic;
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
         mouse_row, mouse_column      : in  std_logic_vector(9 downto 0);
         mouse_left_click             : in  std_logic;
         any_key_pressed              : in  std_logic;
         end_screen_outcome           : in  std_logic;
			end_screen_active				  : in  std_logic;
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

   -- Input sync + edge detect
   signal mouse_left_click_sync_1, mouse_left_click_sync_2 : std_logic;
   signal any_key_pressed_sync_1,  any_key_pressed_sync_2  : std_logic;
   signal mouse_left_click_previous                        : std_logic;
   signal any_key_pressed_previous                         : std_logic;
   signal mouse_left_click_edge                            : std_logic;
   signal any_key_pressed_edge                             : std_logic;

   -- ---------------------------------------------------------------------------
   -- Text pixel outputs
   -- ---------------------------------------------------------------------------
   signal you_red,  you_green,  you_blue  : std_logic_vector(3 downto 0);
   signal win_red,  win_green,  win_blue  : std_logic_vector(3 downto 0);
   signal lose_red, lose_green, lose_blue : std_logic_vector(3 downto 0);
   signal cont_red, cont_green, cont_blue : std_logic_vector(3 downto 0);

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
   constant CONT_X : integer := 216;
   constant CONT_Y : integer := 360;

begin

   -- ---------------------------------------------------------------------------
   -- Sync + edge detect
   -- ---------------------------------------------------------------------------
   Sync_Inputs : process(video_clock, reset)
   begin
      if reset = '1' then
         mouse_left_click_sync_1   <= '0';
         mouse_left_click_sync_2   <= '0';
         mouse_left_click_previous <= '0';
         any_key_pressed_sync_1    <= '0';
         any_key_pressed_sync_2    <= '0';
         any_key_pressed_previous  <= '0';
      elsif rising_edge(video_clock) then
         mouse_left_click_sync_1   <= mouse_left_click;
         mouse_left_click_sync_2   <= mouse_left_click_sync_1;
         mouse_left_click_previous <= mouse_left_click_sync_2;
         any_key_pressed_sync_1    <= any_key_pressed;
         any_key_pressed_sync_2    <= any_key_pressed_sync_1;
         any_key_pressed_previous  <= any_key_pressed_sync_2;
      end if;
   end process Sync_Inputs;

   mouse_left_click_edge <= mouse_left_click_sync_2 and not mouse_left_click_previous;
   any_key_pressed_edge  <= any_key_pressed_sync_2  and not any_key_pressed_previous;

   -- ---------------------------------------------------------------------------
   -- Screen active latch: goes low on click or key press
   -- ---------------------------------------------------------------------------
   Screen_Latch : process(video_clock, reset)
   begin
      if reset = '1' then
         screen_active <= '1';
      elsif rising_edge(video_clock) then
         if (((mouse_left_click_edge = '1') or (any_key_pressed_edge = '1')) and end_screen_active = '1') then
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
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
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
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
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
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                red_out        => lose_red,
                green_out      => lose_green,
                blue_out       => lose_blue);

   -- ---------------------------------------------------------------------------
   -- "CLICK ANYWHERE TO CONTINUE" (SCALE 1, muted purple)
   -- ---------------------------------------------------------------------------
   Continue_Text : Word_Display
      generic map (STRING_LENGTH => 26,
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
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
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
                               cont_red, cont_green, cont_blue)
   begin
      if end_screen_outcome = '1' then
         red_out   <= you_red   or win_red   or cont_red;
         green_out <= you_green or win_green or cont_green;
         blue_out  <= you_blue  or win_blue  or cont_blue;
      else
         red_out   <= you_red   or lose_red   or cont_red;
         green_out <= you_green or lose_green or cont_green;
         blue_out  <= you_blue  or lose_blue  or cont_blue;
      end if;
   end process Output_Compositor;

end architecture end_screen_behaviour;