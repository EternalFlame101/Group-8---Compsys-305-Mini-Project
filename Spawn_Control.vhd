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

    signal lfsr_address   : std_logic_vector(7 downto 0);
    signal rom_lane_0     : std_logic_vector(1 downto 0);
    signal rom_lane_1     : std_logic_vector(1 downto 0);
    signal rom_lane_2     : std_logic_vector(1 downto 0);
    signal lfsr_enable    : std_logic := '0';

    -- Arrived edge detector: fire exactly one spawn per arrival pulse
    signal any_arrived       : std_logic;
    signal any_arrived_prev  : std_logic := '0';
    signal arrived_rising    : std_logic;

    -- Spawn FSM: drives one LFSR-advance + ROM-read + lane-latch sequence
    --   IDLE       -> waiting for an arrival (or initial startup)
    --   PULSE      -> lfsr_enable = '1' (LFSR will advance this cycle's edge)
    --   ROM_SETTLE -> wait one cycle for ROM internal addr register to update
    --   LATCH      -> ROM output now reflects the new LFSR value; latch into lanes
    type spawn_state_t is (IDLE, PULSE, ROM_SETTLE, LATCH);
    signal state : spawn_state_t := PULSE;  -- first cycle pulses LFSR to spawn wave 1

begin

    LFSR_Inst : lfsr_8bit
        generic map (SEED => "10110001")
        port map (
            clock  => clock,
            reset  => reset,
            enable => lfsr_enable,
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

    any_arrived    <= arrived_0 or arrived_1 or arrived_2;
    arrived_rising <= any_arrived and (not any_arrived_prev);

    -- Spawn FSM + lane register
    process(clock)
    begin
        if rising_edge(clock) then
            -- Edge detector latch
            any_arrived_prev <= any_arrived;

            -- Default: don't advance the LFSR
            lfsr_enable <= '0';

            if reset = '1' then
                state             <= PULSE;  -- spawn wave 1 fresh after reset
                any_arrived_prev  <= '0';
                lane_0_type       <= "00";
                lane_1_type       <= "00";
                lane_2_type       <= "00";
            else
                case state is
                    when IDLE =>
                        if arrived_rising = '1' then
                            state <= PULSE;
                        end if;

                    when PULSE =>
                        -- This cycle's edge: LFSR advances, ROM samples OLD addr
                        lfsr_enable <= '1';
                        state       <= ROM_SETTLE;

                    when ROM_SETTLE =>
                        -- This cycle's edge: ROM samples NEW addr, output settles
                        state <= LATCH;

                    when LATCH =>
                        -- ROM output now reflects the post-advance LFSR value.
                        -- Skip all-zero patterns (those entries exist in the MIF
                        -- but would leave every lane empty, so the player would
                        -- never see a wave and arrived would never re-fire -- the
                        -- FSM would stall forever in IDLE).
                        if rom_lane_0 = "00" and rom_lane_1 = "00" and rom_lane_2 = "00" then
                            state <= PULSE;
                        else
                            lane_0_type <= rom_lane_0;
                            lane_1_type <= rom_lane_1;
                            lane_2_type <= rom_lane_2;
                            state       <= IDLE;
                        end if;
                end case;

                -- Clear lanes the instant they report arrival, regardless of state.
                -- Placed AFTER the LATCH assignment so an arrival on the same cycle
                -- as a latch still wins and zeroes the lane (re-arms enable_seen_low
                -- in Moving_Object).
                if arrived_0 = '1' then lane_0_type <= "00"; end if;
                if arrived_1 = '1' then lane_1_type <= "00"; end if;
                if arrived_2 = '1' then lane_2_type <= "00"; end if;
            end if;
        end if;
    end process;

    debug_vsync_pulse <= lfsr_enable;
    debug_lfsr        <= lfsr_address;

end architecture beh;