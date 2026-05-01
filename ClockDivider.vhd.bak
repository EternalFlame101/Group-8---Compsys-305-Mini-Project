library IEEE;
use IEEE.std_logic_1164.all;

-- -------------------------------------
-- Written by : Team 8 (Jasper's Knee)
-- Date		  : 30/4/26
-- Purpose    : generic clock generator
-- -------------------------------------


entity ClockDivider is
	generic (input_clock_frequency  : positive := 50_000_000;
				output_clock_frequency : positive := 25_000_000);

	port (input_clock  : in std_logic;
		   enable_pulse : out std_logic);
end entity ClockDivider;

architecture clock_divider_behaviour of ClockDivider is
	constant input_clock_divisor : positive range 1 to input_clock_frequency 
										:= (input_clock_frequency / output_clock_frequency);
	signal counter : natural range 0 to input_clock_divisor := 0;
begin
	clk_dividing : process(input_clock)
	begin
		if (rising_edge(input_clock)) then
			if (counter = input_clock_divisor - 1) then
				counter <= 0;
			else
				counter <= counter + 1;
			end if;
		end if;
	end process clk_dividing;
	
	-- pulsed output for the clock_divider instead of generating a new, divided clock.
	enable_pulse <= '1' when (counter = input_clock_divisor - 1) else '0';
end architecture clock_divider_behaviour;