library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_signed.all;

entity Orbiting_Ball is
    port (clock, vertical_sync    : in std_logic;
          pixel_row, pixel_column : in std_logic_vector(9 downto 0);
          radius                  : in std_logic_vector(6 downto 0);
          ball_x_out, ball_y_out  : out std_logic_vector(9 downto 0));
end entity Orbiting_Ball;

architecture orbiting_ball_behavior of Orbiting_Ball is
    signal ball_size              : std_logic_vector(9 downto 0);
    signal ball_x_position        : std_logic_vector(9 downto 0);
    signal ball_y_position        : std_logic_vector(9 downto 0);
    signal phase                  : integer range 0 to 63 := 0;
    signal offset_x               : integer range -128 to 127;
    signal offset_y               : integer range -128 to 127;
    signal radius_int             : integer range 0 to 100;
    signal vertical_sync_previous : std_logic;

    constant CENTER_X_POSITION : integer := 320;
    constant CENTER_Y_POSITION : integer := 240;

    type lut_type is array(0 to 15) of integer range 0 to 100;
    constant SIN_LUT : lut_type := (0, 10, 20, 29, 38, 47, 56, 63,
                                    71, 78, 83, 88, 92, 95, 98, 100);

    function sin64(phase_in : integer) return integer is
        variable quadrant : integer range 0 to 3;
        variable index    : integer range 0 to 15;
        variable sine     : integer range 0 to 100;
    begin
        quadrant := phase_in / 16;
        index    := phase_in mod 16;
        case quadrant is
            when 0 => sine := SIN_LUT(index);
            when 1 =>
                if index = 0 then sine := 100;
                else sine := SIN_LUT(16 - index); end if;
            when 2 => sine := SIN_LUT(index);
            when 3 =>
                if index = 0 then sine := 100;
                else sine := SIN_LUT(16 - index); end if;
            when others => sine := 0;
        end case;
        return sine;
    end function;

    function sin64_signed(phase_in : integer) return integer is
        variable magnitude : integer range 0 to 100;
    begin
        magnitude := sin64(phase_in);
        if phase_in >= 32 then
            return -magnitude;
        else
            return magnitude;
        end if;
    end function;

    function cos64_signed(phase_in : integer) return integer is
    begin
        return sin64_signed((phase_in + 16) mod 64);
    end function;
begin
    ball_size <= conv_std_logic_vector(8, 10);
    radius_int <= conv_integer(unsigned(radius));

    offset_x <= (sin64_signed(phase) * radius_int) / 100;
    offset_y <= (-cos64_signed(phase) * radius_int) / 100;

    ball_x_position <= conv_std_logic_vector(CENTER_X_POSITION + offset_x, 10);
    ball_y_position <= conv_std_logic_vector(CENTER_Y_POSITION + offset_y, 10);

    ball_x_out <= ball_x_position;
    ball_y_out <= ball_y_position;

    Move_Ball: process (clock)
    begin
        if rising_edge(clock) then
            vertical_sync_previous <= vertical_sync;
            -- Detect rising edge of vertical_sync (end of sync pulse = start of new frame)
            if (vertical_sync_previous = '0') and (vertical_sync = '1') then
                if phase = 63 then
                    phase <= 0;
                else
                    phase <= phase + 1;
                end if;
            end if;
        end if;
    end process Move_Ball;
end architecture orbiting_ball_behavior;