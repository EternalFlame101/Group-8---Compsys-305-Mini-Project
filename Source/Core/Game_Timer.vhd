library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ============================================================
-- Game_Timer
-- Counts upward in MM:SS format (00:00 -> 99:59).
-- Driven by the system clock; a clock-enable tick is generated
-- internally to produce exactly one "second" increment per
-- second based on CLOCK_HZ.
--
-- Outputs:
--   min_tens, min_ones  -- tens and ones digit of minutes (0-9)
--   sec_tens, sec_ones  -- tens and ones digit of seconds (0-5 / 0-9)
-- ============================================================
entity Game_Timer is
	generic (
		CLOCK_HZ : positive := 50_000_000  -- set to your system clock frequency
	);
	port (
		clock      : in  std_logic;
		reset      : in  std_logic;   -- synchronous reset, returns to 00:00
		enable     : in  std_logic;   -- pause/resume the timer
		min_tens   : out std_logic_vector(3 downto 0);
		min_ones   : out std_logic_vector(3 downto 0);
		sec_tens   : out std_logic_vector(3 downto 0);
		sec_ones   : out std_logic_vector(3 downto 0)
	);
end entity Game_Timer;

architecture beh of Game_Timer is

	-- Internal BCD counters
	signal r_sec_ones : integer range 0 to 9  := 0;
	signal r_sec_tens : integer range 0 to 5  := 0;  -- 0-5 (max 59 seconds)
	signal r_min_ones : integer range 0 to 9  := 0;
	signal r_min_tens : integer range 0 to 9  := 0;

	-- Prescaler to divide system clock down to 1 Hz
	signal prescale   : integer range 0 to CLOCK_HZ - 1 := 0;
	signal tick_1hz   : std_logic := '0';

begin

	-- ----------------------------------------------------------------
	-- 1 Hz tick generator
	-- ----------------------------------------------------------------
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				prescale <= 0;
				tick_1hz <= '0';
			elsif enable = '1' then
				if prescale = CLOCK_HZ - 1 then
					prescale <= 0;
					tick_1hz <= '1';
				else
					prescale <= prescale + 1;
					tick_1hz <= '0';
				end if;
			else
				tick_1hz <= '0';
			end if;
		end if;
	end process;

	-- ----------------------------------------------------------------
	-- BCD counter: increments on each 1 Hz tick
	-- ----------------------------------------------------------------
	process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				r_sec_ones <= 0;
				r_sec_tens <= 0;
				r_min_ones <= 0;
				r_min_tens <= 0;
			elsif tick_1hz = '1' then
				-- Seconds ones
				if r_sec_ones = 9 then
					r_sec_ones <= 0;
					-- Seconds tens
					if r_sec_tens = 5 then
						r_sec_tens <= 0;
						-- Minutes ones
						if r_min_ones = 9 then
							r_min_ones <= 0;
							-- Minutes tens (cap at 99:59)
							if r_min_tens = 9 then
								r_min_tens <= 0;
							else
								r_min_tens <= r_min_tens + 1;
							end if;
						else
							r_min_ones <= r_min_ones + 1;
						end if;
					else
						r_sec_tens <= r_sec_tens + 1;
					end if;
				else
					r_sec_ones <= r_sec_ones + 1;
				end if;
			end if;
		end if;
	end process;

	-- ----------------------------------------------------------------
	-- Drive outputs
	-- ----------------------------------------------------------------
	min_tens <= conv_std_logic_vector(r_min_tens, 4);
	min_ones <= conv_std_logic_vector(r_min_ones, 4);
	sec_tens <= conv_std_logic_vector(r_sec_tens, 4);
	sec_ones <= conv_std_logic_vector(r_sec_ones, 4);

end architecture beh;