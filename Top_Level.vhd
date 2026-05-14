library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Top_Level is
   port (CLOCK_50            : in    std_logic;
         RESET_N             : in    std_logic;
         KEY                 : in    std_logic_vector(3 downto 0);
			SW                  : in    std_logic_vector(9 downto 0);
         VGA_HS, VGA_VS      : out   std_logic;
         VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
         HEX0, HEX1, HEX2,
         HEX3, HEX4, HEX5    : out   std_logic_vector(6 downto 0);
         LEDR                : out   std_logic_vector(9 downto 0);
         PS2_DAT             : inout std_logic;
         PS2_CLK             : inout std_logic;

         -- SD card (DE0-CV onboard slot, native pin names)
         SD_CLK              : out   std_logic;
         SD_CMD              : out   std_logic;
			SD_DATA    			  : inout std_logic_vector(3 downto 0);
			
			GPIO_0 				  : out std_logic_vector(35 downto 0));
end entity Top_Level;

architecture game_behaviour of Top_Level is

   -- ---------------------------------------------------------------------------
   -- Components
   -- ---------------------------------------------------------------------------
   component Ball is
      generic (SIZE_CONST : positive := 8);
      port (pixel_column, pixel_row : in  std_logic_vector(9 downto 0);
            ball_x, ball_y          : in  std_logic_vector(9 downto 0);
            red, green, blue        : out std_logic_vector(3 downto 0));
   end component Ball;

   component Clock_Divider is
      generic (input_clock_frequency  : positive := 50_000_000;
               output_clock_frequency : positive := 25_000_000);
      port (input_clock  : in  std_logic;
            enable_pulse : out std_logic);
   end component Clock_Divider;

   component Graphics_Manager is
      port (text_large_red,   text_large_green,   text_large_blue : in  std_logic_vector(3 downto 0);
            text_small_red,   text_small_green,   text_small_blue : in  std_logic_vector(3 downto 0);
            background_red,   background_green,   background_blue : in  std_logic_vector(3 downto 0);
            sprite_red,       sprite_green,       sprite_blue     : in  std_logic_vector(3 downto 0);
            mouse_red,        mouse_green,        mouse_blue      : in  std_logic_vector(3 downto 0);
            red_out,          green_out,          blue_out        : out std_logic_vector(3 downto 0));
   end component Graphics_Manager;

   component Mouse is
      port (clock, reset              : in    std_logic;
            left_button, right_button : out   std_logic;
            mouse_cursor_row          : out   std_logic_vector(9 downto 0);
            mouse_cursor_column       : out   std_logic_vector(9 downto 0);
            mouse_data                : inout std_logic;
            mouse_clock               : inout std_logic);
   end component Mouse;

   component Orbiting_Ball is
      port (clock, vertical_sync    : in  std_logic;
            pixel_row, pixel_column : in  std_logic_vector(9 downto 0);
            radius                  : in  std_logic_vector(6 downto 0);
            left_click              : in  std_logic;
            ball_x_out, ball_y_out  : out std_logic_vector(9 downto 0));
   end component Orbiting_Ball;

   component VGA_Sync is
      port (clock, enable_pulse                    : in  std_logic;
            red, green, blue                       : in  std_logic_vector(3 downto 0);
            video_on                               : out std_logic;
            horizontal_sync_out, vertical_sync_out : out std_logic;
            red_out, green_out, blue_out           : out std_logic_vector(3 downto 0);
            pixel_row, pixel_column                : out std_logic_vector(9 downto 0));
   end component VGA_Sync;

   component Word_Display is
      generic (STRING_LENGTH : positive := 16;
               SCALE         : positive := 1);
      port (clock                        : in  std_logic;
            x_position, y_position       : in  std_logic_vector(9 downto 0);
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            characters                   : in  std_logic_vector((STRING_LENGTH * 6 - 1) downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Word_Display;
	
	component SD_Init is
      port (clock              : in  std_logic;
            reset              : in  std_logic;
            start_init         : in  std_logic;
            byte_address       : in  std_logic_vector(8 downto 0);
            spi_clock_out      : out std_logic;
            spi_mosi_out       : out std_logic;
            spi_miso_in        : in  std_logic;
            spi_chip_select_n  : out std_logic;
            init_done          : out std_logic;
            read_done          : out std_logic;
            init_failed        : out std_logic;
            state_indicator    : out std_logic_vector(3 downto 0);
            last_response_byte : out std_logic_vector(7 downto 0);
            read_byte          : out std_logic_vector(7 downto 0));
   end component SD_Init;
	
	component Hex_To_Seven_Segment is
      port (hex_value      : in  std_logic_vector(3 downto 0);
            seven_segments : out std_logic_vector(6 downto 0));
   end component Hex_To_Seven_Segment;
	
	component Audio_Test_Generator is
      generic (CLOCK_FREQUENCY      : positive := 50_000_000;
               SAMPLE_RATE          : positive := 44_100);
      port (clock    : in  std_logic;
            reset    : in  std_logic;
            dac_data : out std_logic_vector(7 downto 0));
   end component Audio_Test_Generator;

   -- ---------------------------------------------------------------------------
   -- Signals
   -- ---------------------------------------------------------------------------
   signal enable_pulse                   : std_logic;
   signal vertical_sync, horizontal_sync : std_logic;
   signal video_on                       : std_logic;
   signal left_click, right_click        : std_logic;
   signal mouse_column, mouse_row        : std_logic_vector(9 downto 0);

   signal red, green, blue               : std_logic_vector(3 downto 0);
   signal red1, green1, blue1            : std_logic_vector(3 downto 0);
   signal red2, green2, blue2            : std_logic_vector(3 downto 0);
   signal red3, green3, blue3            : std_logic_vector(3 downto 0);
   signal red4, green4, blue4            : std_logic_vector(3 downto 0);
   signal red_out, green_out, blue_out   : std_logic_vector(3 downto 0);
   signal pixel_row, pixel_column        : std_logic_vector(9 downto 0);
   signal ball_x_out, ball_y_out         : std_logic_vector(9 downto 0);

	signal init_done_signal       		  : std_logic;
   signal init_failed_signal             : std_logic;
   signal init_state_indicator           : std_logic_vector(3 downto 0);
   signal last_response_byte_sig         : std_logic_vector(7 downto 0);
	
	signal sd_serial_clock					  : std_logic;
	signal sd_command 						  : std_logic;
	signal sd_chip_select  					  : std_logic;
	signal sd_data_in                     : std_logic;
	
	signal read_done_signal   				  : std_logic;
   signal read_byte_signal   				  : std_logic_vector(7 downto 0);
	
	signal audio_dac_data : std_logic_vector(7 downto 0);

begin

   -- ---------------------------------------------------------------------------
   -- Clock Divider
   -- ---------------------------------------------------------------------------
   Divider : Clock_Divider
      port map (input_clock  => CLOCK_50,
                enable_pulse => enable_pulse);

   -- ---------------------------------------------------------------------------
   -- VGA sync
   -- ---------------------------------------------------------------------------
   VGA : VGA_Sync
      port map (clock               => CLOCK_50,
                enable_pulse        => enable_pulse,
                red                 => red,
                green               => green,
                blue                => blue,
                red_out             => red_out,
                green_out           => green_out,
                blue_out            => blue_out,
                horizontal_sync_out => horizontal_sync,
                vertical_sync_out   => vertical_sync,
                video_on            => video_on,
                pixel_row           => pixel_row,
                pixel_column        => pixel_column);

   -- ---------------------------------------------------------------------------
   -- Orbiting ball position
   -- ---------------------------------------------------------------------------
   Orbiting : Orbiting_Ball
      port map (clock         => CLOCK_50,
                vertical_sync => vertical_sync,
                pixel_row     => pixel_row,
                pixel_column  => pixel_column,
                radius        => conv_std_logic_vector(100, 7),
                left_click    => left_click,
                ball_x_out    => ball_x_out,
                ball_y_out    => ball_y_out);

   -- ---------------------------------------------------------------------------
   -- Orbiting ball sprite
   -- ---------------------------------------------------------------------------
   Sprite : Ball
      generic map (SIZE_CONST => 20)
      port map (pixel_column => pixel_column,
                pixel_row    => pixel_row,
                ball_x       => ball_x_out,
                ball_y       => ball_y_out,
                red          => red1,
                green        => green1,
                blue         => blue1);

   -- ---------------------------------------------------------------------------
   -- Mouse controller
   -- ---------------------------------------------------------------------------
   Mouse_Controller : Mouse
      port map (clock               => CLOCK_50,
                reset               => not RESET_N,
                mouse_data          => PS2_DAT,
                mouse_clock         => PS2_CLK,
                left_button         => left_click,
                right_button        => right_click,
                mouse_cursor_row    => mouse_row,
                mouse_cursor_column => mouse_column);

   -- ---------------------------------------------------------------------------
   -- Mouse cursor sprite
   -- ---------------------------------------------------------------------------
   Mouse_Sprite : Ball
      generic map (SIZE_CONST => 8)
      port map (pixel_column => pixel_column,
                pixel_row    => pixel_row,
                ball_x       => mouse_column,
                ball_y       => mouse_row,
                red          => red2,
                green        => green2,
                blue         => blue2);

   -- ---------------------------------------------------------------------------
   -- Hello World small text
   -- ---------------------------------------------------------------------------
   Hello_World : Word_Display
      generic map (STRING_LENGTH => 11,
                   SCALE         => 1)
      port map (clock          => CLOCK_50,
                characters     => "001000" &  -- H = 8
                                  "000101" &  -- E = 5
                                  "001100" &  -- L = 12
                                  "001100" &  -- L = 12
                                  "001111" &  -- O = 15
                                  "100000" &  -- space = 32
                                  "010111" &  -- W = 23
                                  "001111" &  -- O = 15
                                  "010010" &  -- R = 18
                                  "001100" &  -- L = 12
                                  "000100",   -- D = 4
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                x_position     => conv_std_logic_vector(276, 10),
                y_position     => conv_std_logic_vector(220, 10),
                red_out        => red3,
                green_out      => green3,
                blue_out       => blue3);

   -- ---------------------------------------------------------------------------
   -- OINK large text
   -- ---------------------------------------------------------------------------
   CHUD : Word_Display
      generic map (STRING_LENGTH => 4,
                   SCALE         => 2)
      port map (clock          => CLOCK_50,
                characters     => "001111" &  -- O = 16
                                  "001001" &  -- I = 9
                                  "001110" &  -- N = 14
                                  "001011",   -- K = 11
                pixel_row      => pixel_row,
                pixel_column   => pixel_column,
                x_position     => conv_std_logic_vector(288, 10),
                y_position     => conv_std_logic_vector(250, 10),
                red_out        => red4,
                green_out      => green4,
                blue_out       => blue4);

   -- ---------------------------------------------------------------------------
   -- Graphics layer compositor
   -- Background is black (all zeros) now that Background_Colour is removed
   -- ---------------------------------------------------------------------------
   Graphics : Graphics_Manager
      port map (text_large_red   => red4,
                text_large_green => green4,
                text_large_blue  => blue4,
                text_small_red   => red3,
                text_small_green => green3,
                text_small_blue  => blue3,
                background_red   => "0000",
                background_green => "0000",
                background_blue  => "0000",
                sprite_red       => red1,
                sprite_green     => green1,
                sprite_blue      => blue1,
                mouse_red        => red2,
                mouse_green      => green2,
                mouse_blue       => blue2,
                red_out          => red,
                green_out        => green,
                blue_out         => blue);

	-- ---------------------------------------------------------------------------
   -- SD card SPI initialiser
   -- KEY(0) is active-low, so invert before passing in as start trigger
   -- ---------------------------------------------------------------------------
	SD_Initialiser : SD_Init
      port map (clock              => CLOCK_50,
                reset              => not RESET_N,
                start_init         => not KEY(0),
                byte_address       => SW(8 downto 0),
                spi_clock_out      => sd_serial_clock,
                spi_mosi_out       => sd_command,
                spi_miso_in        => sd_data_in,
                spi_chip_select_n  => sd_chip_select,
                init_done          => init_done_signal,
                read_done          => read_done_signal,
                init_failed        => init_failed_signal,
                state_indicator    => init_state_indicator,
                last_response_byte => last_response_byte_sig,
                read_byte          => read_byte_signal);
					 
	Audio_Generator : Audio_Test_Generator
      port map (clock    => CLOCK_50,
                reset    => not RESET_N,
                dac_data => audio_dac_data);
					 
   -- ---------------------------------------------------------------------------
   -- LED assignments
   -- ---------------------------------------------------------------------------
   LEDR(3 downto 0) <= init_state_indicator;
   LEDR(4)          <= init_done_signal;
   LEDR(7 downto 5) <= (others => '0');
   LEDR(8)          <= init_failed_signal;
   LEDR(9)          <= read_done_signal;
	
	-- Debug mirror to GPIO_0 header for oscilloscope probing
	GPIO_0(0)           <= sd_serial_clock;   -- CLK
	GPIO_0(1)           <= sd_chip_select;    -- CS (HIGH = deasserted, LOW = active)
	GPIO_0(2) 			  <= sd_command;        -- MOSI
	GPIO_0(3) 			  <= sd_data_in;        -- MISO
	
	-- DAC0800 data lines (B1 = MSB = audio_dac_data(7), B8 = LSB = audio_dac_data(0))
   GPIO_0(11) <= audio_dac_data(7);   -- B1 (MSB)
   GPIO_0(10) <= audio_dac_data(6);   -- B2
   GPIO_0(9)  <= audio_dac_data(5);   -- B3
   GPIO_0(8)  <= audio_dac_data(4);   -- B4
   GPIO_0(7)  <= audio_dac_data(3);   -- B5
   GPIO_0(6)  <= audio_dac_data(2);   -- B6
   GPIO_0(5)  <= audio_dac_data(1);   -- B7
   GPIO_0(4)  <= audio_dac_data(0);   -- B8 (LSB)
	
	GPIO_0(35 downto 12) <= (others => '0');

	-- HEX0/HEX1 show the byte at SW(8:0) of the read sector buffer
   Hex_Buffer_Low    : Hex_To_Seven_Segment
      port map (hex_value      => read_byte_signal(3 downto 0),
                seven_segments => HEX0);

   Hex_Buffer_High   : Hex_To_Seven_Segment
      port map (hex_value      => read_byte_signal(7 downto 4),
                seven_segments => HEX1);

   -- HEX4/HEX5 show the last raw SPI response byte (for debugging failures)
   Hex_Response_Low  : Hex_To_Seven_Segment
      port map (hex_value      => last_response_byte_sig(3 downto 0),
                seven_segments => HEX4);

   Hex_Response_High : Hex_To_Seven_Segment
      port map (hex_value      => last_response_byte_sig(7 downto 4),
                seven_segments => HEX5);

   HEX2 <= "1111111";
   HEX3 <= "1111111";
	
	-- Physical SD pin connections
   SD_CLK     <= sd_serial_clock;
   SD_CMD     <= sd_command;
   SD_DATA(3) <= sd_chip_select;
   SD_DATA(2) <= '1';
   SD_DATA(1) <= '1';
   SD_DATA(0) <= 'Z';
   sd_data_in <= SD_DATA(0);

   -- ---------------------------------------------------------------------------
   -- VGA output
   -- ---------------------------------------------------------------------------
   VGA_R  <= red_out;
   VGA_G  <= green_out;
   VGA_B  <= blue_out;
   VGA_HS <= horizontal_sync;
   VGA_VS <= vertical_sync;

end architecture game_behaviour;