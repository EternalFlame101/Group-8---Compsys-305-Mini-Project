library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Audio_Test_Generator is
   generic (CLOCK_FREQUENCY      : positive := 50_000_000;
            SAMPLE_RATE          : positive := 44_100);
   port (clock    : in  std_logic;
         reset    : in  std_logic;
         dac_data : out std_logic_vector(7 downto 0));
end entity Audio_Test_Generator;

architecture behavioural of Audio_Test_Generator is

   constant SAMPLE_PERIOD_CYCLES : integer := CLOCK_FREQUENCY / SAMPLE_RATE;

   signal divider_counter : integer range 0 to SAMPLE_PERIOD_CYCLES;
   signal sawtooth_value  : std_logic_vector(7 downto 0);

begin

   dac_data <= sawtooth_value;

   waveform_process : process(clock, reset)
   begin
      if reset = '1' then
         divider_counter <= 0;
         sawtooth_value  <= (others => '0');

      elsif rising_edge(clock) then
         if divider_counter = SAMPLE_PERIOD_CYCLES - 1 then
            divider_counter <= 0;
            sawtooth_value  <= sawtooth_value + 1;
         else
            divider_counter <= divider_counter + 1;
         end if;
      end if;
   end process waveform_process;

end architecture behavioural;