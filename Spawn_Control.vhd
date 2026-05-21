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
    signal active_0       : std_logic := '0';
    signal active_1       : std_logic := '0';
    signal active_2       : std_logic := '0';
    signal any_arrived    : std_logic := '0';
	 
	 signal wave_pending   : std_logic := '1';  -- initiate
	 signal wave_running   : std_logic := '0';
	 signal rom_valid      : std_logic := '0';

begin

    LFSR_Inst : lfsr_8bit
        generic map (SEED => "10110001")
        port map (
            clock  => clock,
            reset  => '0',
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

    -- Pipeline: advance LFSR on arrival, read ROM 2 cycles later
		process(clock)
		begin
			 if rising_edge(clock) then
				  lfsr_enable <= '0';
				  rom_valid   <= lfsr_enable;

				  if wave_pending = '1' and wave_running = '0' then
						lfsr_enable  <= '1';
						wave_pending <= '0';
						wave_running <= '1';
				  end if;

				  if rom_valid = '1' then
						wave_running <= '0';  -- now safe to accept new arrived
				  end if;
				  
				  if wave_running = '0' then
					  if arrived_0 = '1' or arrived_1 = '1' or arrived_2 = '1' then
							wave_pending <= '1';
					  end if;
				  end if;
			 end if;
		end process;

		process(clock)
		begin
			 if rising_edge(clock) then
				  if rom_valid = '1' then
						lane_0_type <= rom_lane_0;
						lane_1_type <= rom_lane_1;
						lane_2_type <= rom_lane_2;
				  end if;

				  if arrived_0 = '1' then lane_0_type <= "00"; end if;
				  if arrived_1 = '1' then lane_1_type <= "00"; end if;
				  if arrived_2 = '1' then lane_2_type <= "00"; end if;
			 end if;
		end process;

    debug_vsync_pulse <= lfsr_enable;
    debug_lfsr        <= lfsr_address;

end architecture beh;