library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity VGA_Sync is
    port (
        clock                           : in  std_logic;  -- 50MHz
        enable_pulse                    : in  std_logic;  -- 25MHz enable
        red, green, blue                : in  std_logic_vector(3 downto 0);
        red_out, green_out, blue_out    : out std_logic_vector(3 downto 0);
        horizontal_sync_out             : out std_logic;
        vertical_sync_out               : out std_logic;
        video_on                        : out std_logic;
        pixel_row, pixel_column         : out std_logic_vector(9 downto 0)
    );
end entity VGA_Sync;

architecture rtl of VGA_Sync is

    signal h_count  : std_logic_vector(9 downto 0) := (others => '0');
    signal v_count  : std_logic_vector(9 downto 0) := (others => '0');
    signal h_active : std_logic;
    signal v_active : std_logic;
    signal vid_on   : std_logic;

begin

    -- Generate Horizontal and Vertical Timing Signals for Video Signal

    -- horizontal_count counts pixels (640 + extra time for sync signals)
    --
    -- horizontal_sync  ------------------------------------__________--------
    -- horizontal_count    0                640             659       755    799

    -- vertical_count counts rows of pixels (480 + extra time for sync signals)
    --
    -- vertical_sync  -----------------------------------------------_______------------
    -- vertical_count  0                                      480    493-494          524

    process(clock)
    begin
        if rising_edge(clock) then
            if enable_pulse = '1' then
                if h_count = 799 then
                    h_count <= (others => '0');
                    if v_count = 524 then
                        v_count <= (others => '0');
                    else
                        v_count <= v_count + 1;
                    end if;
                else
                    h_count <= h_count + 1;
                end if;
            end if;
        end if;
    end process;

    -- Everything below is combinational — no clock involved

    -- Sync pulses
    horizontal_sync_out <= '0' when (h_count >= 659 and h_count <= 755) else '1';
    vertical_sync_out   <= '0' when (v_count >= 493 and v_count <= 494) else '1';

    -- Video on
    h_active <= '1' when h_count < 640 else '0';
    v_active <= '1' when v_count < 480 else '0';
    vid_on   <= h_active and v_active;
    video_on <= vid_on;

    -- Pixel coordinates
    pixel_column <= h_count when h_active = '1' else (others => '0');
    pixel_row    <= v_count when v_active = '1' else (others => '0');

    -- RGB gated by video_on
    red_out   <= red   when vid_on = '1' else (others => '0');
    green_out <= green when vid_on = '1' else (others => '0');
    blue_out  <= blue  when vid_on = '1' else (others => '0');

end architecture rtl;