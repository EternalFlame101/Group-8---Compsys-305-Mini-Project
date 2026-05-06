library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Top_Level is
    port (
        CLOCK_50                        : in    std_logic;
        SW                              : in    std_logic_vector(9 downto 0);
        KEY                             : in    std_logic_vector(3 downto 0);
        RESET_N                         : in    std_logic;
        PS2_DAT                         : inout std_logic;
        PS2_CLK                         : inout std_logic;
        HEX0, HEX1, HEX2, HEX3, HEX5  : out   std_logic_vector(6 downto 0);
        VGA_R, VGA_G, VGA_B            : out   std_logic_vector(3 downto 0);
        VGA_HS, VGA_VS                 : out   std_logic
    );
end entity Top_Level;

architecture game_behaviour of Top_Level is

    component Clock_Divider is
        generic (
            input_clock_frequency  : positive := 50_000_000;
            output_clock_frequency : positive := 25_000_000
        );
        port (
            input_clock  : in  std_logic;
            enable_pulse : out std_logic
        );
    end component Clock_Divider;

    component Graphics_Manager is
        port (
            text_large_r, text_large_g, text_large_b : in  std_logic_vector(3 downto 0);
            text_small_r, text_small_g, text_small_b : in  std_logic_vector(3 downto 0);
            background_r, background_g, background_b : in  std_logic_vector(3 downto 0);
            sprite_r, sprite_g, sprite_b             : in  std_logic_vector(3 downto 0);
            mouse_r, mouse_g, mouse_b                : in  std_logic_vector(3 downto 0);
            red_out, green_out, blue_out             : out std_logic_vector(3 downto 0)
        );
    end component Graphics_Manager;

    component VGA_Sync is
        port (
            clock                        : in  std_logic;
            enable_pulse                 : in  std_logic;
            red, green, blue             : in  std_logic_vector(3 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0);
            horizontal_sync_out          : out std_logic;
            vertical_sync_out            : out std_logic;
            video_on                     : out std_logic;
            pixel_row, pixel_column      : out std_logic_vector(9 downto 0)
        );
    end component VGA_Sync;

    component Word_Display is
        generic (
            STR_LEN : positive := 16;
            SCALE   : positive := 1
        );
        port (
            clock, v_sync            : in  std_logic;
            characters               : in  std_logic_vector((STR_LEN * 6 - 1) downto 0);
            pixel_row, pixel_column  : in  std_logic_vector(9 downto 0);
            x_pos, y_pos             : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0)
        );
    end component Word_Display;

    component Mouse is
        port (
            clock_25Mhz, enable_pulse, reset : in    std_logic;
            mouse_data                       : inout std_logic;
            mouse_clk                        : inout std_logic;
            left_button, right_button        : out   std_logic;
            mouse_cursor_row                 : out   std_logic_vector(9 downto 0);
            mouse_cursor_column              : out   std_logic_vector(9 downto 0)
        );
    end component Mouse;

    component Orbiting_Ball is
        port (
            clock, vertical_sync    : in  std_logic;
            pixel_row, pixel_column : in  std_logic_vector(9 downto 0);
            radius                  : in  std_logic_vector(6 downto 0);
            dip_switch_9            : in  std_logic;
            ball_x_out, ball_y_out  : out std_logic_vector(9 downto 0)
        );
    end component Orbiting_Ball;

    component Ball is
        generic (SIZE_CONST : positive := 8);
        port (
            clock, enable_pulse      : in  std_logic;
            pixel_row, pixel_column  : in  std_logic_vector(9 downto 0);
            ball_x, ball_y           : in  std_logic_vector(9 downto 0);
            red, green, blue         : out std_logic_vector(3 downto 0)
        );
    end component Ball;

    component Colour_Changer is
        port (
            clock, vertical_sync                                          : in  std_logic;
            dip_switch_0, dip_switch_1, dip_switch_2, dip_switch_3       : in  std_logic;
            push_button_0, push_button_1, push_button_2, push_button_3   : in  std_logic;
            seven_segment_display_digit_0, seven_segment_display_digit_1,
            seven_segment_display_digit_2, seven_segment_display_digit_3,
            seven_segment_display_digit_5                                 : out std_logic_vector(6 downto 0);
            red_out, green_out, blue_out                                  : out std_logic_vector(3 downto 0)
        );
    end component Colour_Changer;

    signal enable_pulse                    : std_logic;
    signal vertical_sync, horizontal_sync  : std_logic;
    signal video_on                        : std_logic;
    signal left_btn, right_btn             : std_logic;
    signal mouse_row, mouse_col            : std_logic_vector(9 downto 0);

    signal red, green, blue                : std_logic_vector(3 downto 0);
    signal red1, green1, blue1             : std_logic_vector(3 downto 0);
    signal red2, green2, blue2             : std_logic_vector(3 downto 0);
    signal red3, green3, blue3             : std_logic_vector(3 downto 0);
    signal red4, green4, blue4             : std_logic_vector(3 downto 0);
    signal red5, green5, blue5             : std_logic_vector(3 downto 0);
    signal red_out, green_out, blue_out    : std_logic_vector(3 downto 0);
    signal pixel_row, pixel_column         : std_logic_vector(9 downto 0);
    signal ball_x_out, ball_y_out          : std_logic_vector(9 downto 0);

begin

    u_divider : Clock_Divider
        port map (input_clock => CLOCK_50, enable_pulse => enable_pulse);

    u_vga : VGA_Sync
        port map (
            clock               => CLOCK_50,
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
            pixel_column        => pixel_column
        );

    u_ball_coords : Orbiting_Ball
        port map (
            clock          => CLOCK_50,
            vertical_sync  => vertical_sync,
            pixel_row      => pixel_row,
            pixel_column   => pixel_column,
            radius         => conv_std_logic_vector(100, 7),
            dip_switch_9   => left_btn,
            ball_x_out     => ball_x_out,
            ball_y_out     => ball_y_out
        );

    u_spin : Ball
        generic map (SIZE_CONST => 20)
        port map (
            clock          => CLOCK_50,
            enable_pulse   => enable_pulse,
            pixel_row      => pixel_row,
            pixel_column   => pixel_column,
            ball_x         => ball_x_out,
            ball_y         => ball_y_out,
            red            => red1,
            green          => green1,
            blue           => blue1
        );

    u_mouse : Mouse
        port map (
            clock_25Mhz        => CLOCK_50,
            enable_pulse       => enable_pulse,
            reset              => not RESET_N,
            mouse_data         => PS2_DAT,
            mouse_clk          => PS2_CLK,
            left_button        => left_btn,
            right_button       => right_btn,
            mouse_cursor_row   => mouse_row,
            mouse_cursor_column => mouse_col
        );

    u_mouse_ball : Ball
        generic map (SIZE_CONST => 8)
        port map (
            clock          => CLOCK_50,
            enable_pulse   => enable_pulse,
            pixel_row      => pixel_row,
            pixel_column   => pixel_column,
            ball_x         => mouse_col,
            ball_y         => mouse_row,
            red            => red2,
            green          => green2,
            blue           => blue2
        );

    u_colour : Colour_Changer
        port map (
            clock                         => CLOCK_50,
            vertical_sync                 => vertical_sync,
            dip_switch_0                  => SW(0),
            dip_switch_1                  => SW(1),
            dip_switch_2                  => SW(2),
            dip_switch_3                  => SW(3),
            push_button_0                 => KEY(0),
            push_button_1                 => KEY(1),
            push_button_2                 => KEY(2),
            push_button_3                 => KEY(3),
            seven_segment_display_digit_0 => HEX0,
            seven_segment_display_digit_1 => HEX1,
            seven_segment_display_digit_2 => HEX2,
            seven_segment_display_digit_3 => HEX3,
            seven_segment_display_digit_5 => HEX5,
            red_out                       => red5,
            green_out                     => green5,
            blue_out                      => blue5
        );

    -- Hello World scale 1 — small text
    u_word3 : Word_Display
        generic map (STR_LEN => 11, SCALE => 1)
        port map (
            clock          => CLOCK_50,
            v_sync         => vertical_sync,
            characters     => "001000" &  -- H = 8
                              "000101" &  -- E = 5
                              "001100" &  -- L = 12
                              "001100" &  -- L = 12
                              "001111" &  -- O = 15
                              "100001" &  -- space = 33
                              "010111" &  -- W = 23
                              "001111" &  -- O = 15
                              "010010" &  -- R = 18
                              "001100" &  -- L = 12
                              "000100",   -- D = 4
            pixel_row      => pixel_row,
            pixel_column   => pixel_column,
            x_pos          => conv_std_logic_vector(276, 10),
            y_pos          => conv_std_logic_vector(236, 10),
            red_out        => red3,
            green_out      => green3,
            blue_out       => blue3
        );

    -- CHUD scale 2 — large text
    u_word4 : Word_Display
        generic map (STR_LEN => 4, SCALE => 2)
        port map (
            clock          => CLOCK_50,
            v_sync         => vertical_sync,
            characters     => "000011" &  -- C = 3
                              "001000" &  -- H = 8
                              "010101" &  -- U = 21
                              "000100",   -- D = 4
            pixel_row      => pixel_row,
            pixel_column   => pixel_column,
            x_pos          => conv_std_logic_vector(288, 10),
            y_pos          => conv_std_logic_vector(236, 10),
            red_out        => red4,
            green_out      => green4,
            blue_out       => blue4
        );

    u_graphics : Graphics_Manager
        port map (
            text_large_r => red4,    -- CHUD scale 2 is large
            text_large_g => green4,
            text_large_b => blue4,
            text_small_r => red3,    -- Hello World scale 1 is small
            text_small_g => green3,
            text_small_b => blue3,
            background_r => red5,
            background_g => green5,
            background_b => blue5,
            sprite_r     => red1,
            sprite_g     => green1,
            sprite_b     => blue1,
            mouse_r      => red2,
            mouse_g      => green2,
            mouse_b      => blue2,
            red_out      => red,
            green_out    => green,
            blue_out     => blue
        );

    VGA_R  <= red_out;
    VGA_G  <= green_out;
    VGA_B  <= blue_out;
    VGA_HS <= horizontal_sync;
    VGA_VS <= vertical_sync;

end architecture game_behaviour;