-- ------------------------------------------------------------------------------
-- Audio_Playback
--   Streams 16-bit PCM samples out to the dual R-2R DACs at a fixed sample rate.
--   A clock divider generates one sample_tick every SAMPLE_PERIOD_CYCLES; on each
--   tick the FSM reads two bytes (low then high) from the SD sector buffer and
--   latches them to the high/low DAC output registers.
--
--   The incoming samples are signed 2's-complement; bit 7 of the high byte is
--   inverted to convert to the unsigned offset-binary the R-2R ladder expects.
--   Outputs default to x"80" (midpoint = silence) on reset.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Audio_Playback is
   generic (CLOCK_FREQUENCY : positive := 50_000_000;
            SAMPLE_RATE     : positive := 44_100);
   port (clock        : in  std_logic;
         reset        : in  std_logic;
         audio_ready  : in  std_logic;
         buffer_byte  : in  std_logic_vector(7 downto 0);
         byte_address : out std_logic_vector(9 downto 0);
         dac_high     : out std_logic_vector(7 downto 0);
         dac_low      : out std_logic_vector(7 downto 0));
end entity Audio_Playback;

architecture behavioural of Audio_Playback is

   constant SAMPLE_PERIOD_CYCLES : integer := CLOCK_FREQUENCY / SAMPLE_RATE;

   type playback_state_type is (s_idle, s_low_wait_1, s_low_wait_2, s_high_wait_1, s_high_wait_2);
   signal current_state : playback_state_type;

   signal divider_counter : integer range 0 to SAMPLE_PERIOD_CYCLES;
   signal sample_tick     : std_logic;
   signal byte_index      : std_logic_vector(9 downto 0);
   signal low_byte        : std_logic_vector(7 downto 0);
   signal address_reg     : std_logic_vector(9 downto 0);
   signal dac_high_reg    : std_logic_vector(7 downto 0);
   signal dac_low_reg     : std_logic_vector(7 downto 0);

begin

   byte_address <= address_reg;
   dac_high     <= dac_high_reg;
   dac_low      <= dac_low_reg;

   tick_process : process(clock, reset)
   begin
      if reset = '1' then
         divider_counter <= 0;
         sample_tick     <= '0';
      elsif rising_edge(clock) then
         if divider_counter = SAMPLE_PERIOD_CYCLES - 1 then
            divider_counter <= 0;
            sample_tick     <= '1';
         else
            divider_counter <= divider_counter + 1;
            sample_tick     <= '0';
         end if;
      end if;
   end process tick_process;

   playback_process : process(clock, reset)
   begin
      if reset = '1' then
         current_state <= s_idle;
         byte_index    <= (others => '0');
         address_reg   <= (others => '0');
         dac_high_reg  <= x"80";   -- midpoint = silence
         dac_low_reg   <= x"00";
         low_byte      <= (others => '0');

      elsif rising_edge(clock) then
         case current_state is

            when s_idle =>
               if sample_tick = '1' and audio_ready = '1' then
                  address_reg   <= byte_index;
                  current_state <= s_low_wait_1;
               end if;

            when s_low_wait_1 =>
               current_state <= s_low_wait_2;

            when s_low_wait_2 =>
               low_byte      <= buffer_byte;
               address_reg   <= byte_index + 1;
               current_state <= s_high_wait_1;

            when s_high_wait_1 =>
               current_state <= s_high_wait_2;

            when s_high_wait_2 =>
               -- buffer_byte is the MSB (high byte) of the 16-bit sample.
               -- Inverting bit 7 converts signed 2's-complement to unsigned offset-binary for the DAC.
               dac_low_reg  <= not(buffer_byte(7)) & buffer_byte(6 downto 0);
               dac_high_reg <= low_byte;

               byte_index   <= byte_index + 2;
               current_state <= s_idle;

         end case;
      end if;
   end process playback_process;

end architecture behavioural;