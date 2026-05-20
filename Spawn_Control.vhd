library IEEE;
use IEEE.std_logic_1164.all;

entity Spawn_Control is
    port(
        clock         : in  std_logic;
        reset         : in  std_logic;
        vertical_sync : in  std_logic;
        arrived_0     : in  std_logic;
        arrived_1     : in  std_logic;
        arrived_2     : in  std_logic;
        lane_0_type   : out std_logic_vector(1 downto 0);
        lane_1_type   : out std_logic_vector(1 downto 0);
        lane_2_type   : out std_logic_vector(1 downto 0);
        debug_vsync_pulse : out std_logic;
        debug_lfsr        : out std_logic_vector(7 downto 0)
    );
end entity;

architecture beh of Spawn_Control is

    component lfsr_8bit is
        generic(SEED : std_logic_vector(7 downto 0) := "10110001");
        port(
            clock  : in  std_logic;
            reset  : in  std_logic;
            enable : in  std_logic;
            output : out std_logic_vector(7 downto 0)
        );
    end component;

    component Wave_ROM is
        port(
            clock      : in  std_logic;
            address    : in  std_logic_vector(7 downto 0);
            lane_0_out : out std_logic_vector(1 downto 0);
            lane_1_out : out std_logic_vector(1 downto 0);
            lane_2_out : out std_logic_vector(1 downto 0)
        );
    end component;

    signal lfsr_address  : std_logic_vector(7 downto 0);
    signal rom_lane_0    : std_logic_vector(1 downto 0);
    signal rom_lane_1    : std_logic_vector(1 downto 0);
    signal rom_lane_2    : std_logic_vector(1 downto 0);
    signal vsync_pulse   : std_logic := '0';
    signal spawn_trigger : std_logic := '0';
    signal rom_valid     : std_logic := '0';
    signal active_0      : std_logic := '0';
    signal active_1      : std_logic := '0';
    signal active_2      : std_logic := '0';
    signal frame_counter : integer range 0 to 416666 := 0;

begin

    LFSR_Inst : lfsr_8bit
        generic map (SEED => "10110001")
        port map (
            clock  => clock,
            reset  => '0',
            enable => vsync_pulse,
            output => lfsr_address
        );

    Wave_ROM_Inst : Wave_ROM
        port map (
            clock      => clock,
            address    => lfsr_address,
            lane_0_out => rom_lane_0,
            lane_1_out => rom_lane_1,
            lane_2_out => rom_lane_2
        );

    process(clock)
    begin
        if rising_edge(clock) then
            vsync_pulse <= '0';

            if frame_counter = 416666 then
                frame_counter <= 0;
                vsync_pulse   <= '1';
            else
                frame_counter <= frame_counter + 1;
            end if;

            spawn_trigger <= vsync_pulse;
            rom_valid     <= spawn_trigger;
        end if;
    end process;

    process(clock)
    begin
        if rising_edge(clock) then
            if arrived_0 = '1' then
                active_0    <= '0';
                lane_0_type <= "00";
            end if;
            if arrived_1 = '1' then
                active_1    <= '0';
                lane_1_type <= "00";
            end if;
            if arrived_2 = '1' then
                active_2    <= '0';
                lane_2_type <= "00";
            end if;

            if rom_valid = '1' then
                if rom_lane_0 /= "00" and active_0 = '0' then
                    lane_0_type <= rom_lane_0;
                    active_0    <= '1';
                end if;
                if rom_lane_1 /= "00" and active_1 = '0' then
                    lane_1_type <= rom_lane_1;
                    active_1    <= '1';
                end if;
                if rom_lane_2 /= "00" and active_2 = '0' then
                    lane_2_type <= rom_lane_2;
                    active_2    <= '1';
                end if;
            end if;
        end if;
    end process;

    debug_vsync_pulse <= vsync_pulse;
    debug_lfsr        <= lfsr_address;

end architecture beh;