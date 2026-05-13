library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity SPI_Master is
   generic (CLOCK_DIVIDER : positive := 128);  -- 50 MHz / 128 = ~390 kHz, safe for SD init
   port (clock          : in  std_logic;
         reset          : in  std_logic;
         start_transfer : in  std_logic;
         transmit_byte  : in  std_logic_vector(7 downto 0);
         received_byte  : out std_logic_vector(7 downto 0);
         transfer_done  : out std_logic;
         busy           : out std_logic;
         spi_clock_out  : out std_logic;
         spi_mosi_out   : out std_logic;
         spi_miso_in    : in  std_logic);
end entity SPI_Master;

architecture behavioural of SPI_Master is

   type spi_state_type is (state_idle, state_transferring, state_completed);
   signal current_state : spi_state_type;

   constant HALF_PERIOD_MAX : integer := CLOCK_DIVIDER / 2 - 1;

   signal divider_counter   : integer range 0 to CLOCK_DIVIDER;
   signal bit_counter       : integer range 0 to 8;
   signal sclk_internal     : std_logic;
   signal transmit_register : std_logic_vector(7 downto 0);
   signal receive_register  : std_logic_vector(7 downto 0);

begin

   spi_clock_out <= sclk_internal;
   spi_mosi_out  <= transmit_register(7) when current_state = state_transferring else '1';
   received_byte <= receive_register;

   spi_process : process(clock, reset)
   begin
      if reset = '1' then
         current_state     <= state_idle;
         divider_counter   <= 0;
         sclk_internal     <= '0';
         bit_counter       <= 0;
         transmit_register <= (others => '1');
         receive_register  <= (others => '0');
         transfer_done     <= '0';
         busy              <= '0';

      elsif rising_edge(clock) then
         transfer_done <= '0';

         case current_state is

            when state_idle =>
               busy            <= '0';
               sclk_internal   <= '0';
               divider_counter <= 0;
               bit_counter     <= 0;
               if start_transfer = '1' then
                  transmit_register <= transmit_byte;
                  busy              <= '1';
                  current_state     <= state_transferring;
               end if;

            when state_transferring =>
               busy <= '1';

               if divider_counter = HALF_PERIOD_MAX then
                  divider_counter <= 0;

                  if sclk_internal = '0' then
                     -- Rising edge of SCLK: sample MISO
                     sclk_internal    <= '1';
                     receive_register <= receive_register(6 downto 0) & spi_miso_in;
                  else
                     -- Falling edge of SCLK: shift MOSI to next bit, check completion
                     sclk_internal <= '0';
                     if bit_counter = 7 then
                        current_state <= state_completed;
                     else
                        transmit_register <= transmit_register(6 downto 0) & '0';
                        bit_counter       <= bit_counter + 1;
                     end if;
                  end if;

               else
                  divider_counter <= divider_counter + 1;
               end if;

            when state_completed =>
               sclk_internal <= '0';
               busy          <= '0';
               transfer_done <= '1';
               current_state <= state_idle;

         end case;
      end if;
   end process spi_process;

end architecture behavioural;