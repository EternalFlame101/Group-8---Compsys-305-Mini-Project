library IEEE; 
use IEEE.std_logic_1164.all;

-- Used in Spawn_Control
entity lfsr_8bit is
	generic(
		SEED : std_logic_vector(7 downto 0) := "10110001" -- default
	);
	port(
		clock 	:	in std_logic;
		reset		:	in std_logic;
		enable 	:	in std_logic;
		output	: 	out std_logic_vector(7 downto 0)
	);
end entity;

architecture beh of lfsr_8bit is
	signal reg : std_logic_vector(7 downto 0) := SEED;

begin 

	process(Clock)
		variable fb : std_logic;
	begin 
		if rising_edge(Clock) then 
			if reset = '1' then
				reg <= SEED;
			elsif enable = '1' then
				-- Galois LFSR, primitive polynomial x^8 + x^6 + x^5 + x^4 + 1
				-- (period 255 from any non-zero seed; single-XOR depth keeps Fmax high)
				fb := reg(7);
				reg(7) <= reg(6);
				reg(6) <= reg(5) xor fb;
				reg(5) <= reg(4) xor fb;
				reg(4) <= reg(3) xor fb;
				reg(3) <= reg(2);
				reg(2) <= reg(1);
				reg(1) <= reg(0);
				reg(0) <= fb;
			end if;
		end if; 
	end process;
	
	output <= reg;

end architecture beh;