library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity SD_Init is
   port (clock              : in  std_logic;
         reset              : in  std_logic;
         start_init         : in  std_logic;
         byte_address       : in  std_logic_vector(8 downto 0);
         spi_clock_out      : out std_logic;
         spi_mosi_out       : out std_logic;
         spi_miso_in        : in  std_logic;
         spi_chip_select_n  : out std_logic;
         init_done          : out std_logic;
         read_done          : out std_logic;
         init_failed        : out std_logic;
         state_indicator    : out std_logic_vector(3 downto 0);
         last_response_byte : out std_logic_vector(7 downto 0);
         read_byte          : out std_logic_vector(7 downto 0));
end entity SD_Init;

architecture behavioural of SD_Init is

   component SPI_Master is
      generic (CLOCK_DIVIDER : positive := 128);
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
   end component SPI_Master;

   type init_state_type is (
      s_idle,
      s_power_up_wait,
      s_dummy_clocks_request,    s_dummy_clocks_wait,
      s_cmd0_request,            s_cmd0_wait,
      s_cmd0_poll_request,       s_cmd0_poll_wait,
      s_cmd8_request,            s_cmd8_wait,
      s_cmd8_poll_request,       s_cmd8_poll_wait,
      s_cmd8_extra_request,      s_cmd8_extra_wait,
      s_cmd55_request,           s_cmd55_wait,
      s_cmd55_poll_request,      s_cmd55_poll_wait,
      s_acmd41_request,          s_acmd41_wait,
      s_acmd41_poll_request,     s_acmd41_poll_wait,
      s_inter_command_request,   s_inter_command_wait,
      s_cmd17_request,           s_cmd17_wait,
      s_cmd17_poll_request,      s_cmd17_poll_wait,
      s_data_token_poll_request, s_data_token_poll_wait,
      s_data_byte_request,       s_data_byte_wait,
      s_data_crc_request,        s_data_crc_wait,
      s_read_complete,
      s_init_failed);
   signal current_state      : init_state_type;
   signal next_command_state : init_state_type;

   constant POWER_UP_WAIT_CYCLES   : integer := 100000;
   constant DUMMY_CLOCK_BYTES      : integer := 10;
   constant POLL_TIMEOUT_BYTES     : integer := 16;
   constant ACMD41_MAX_RETRIES     : integer := 1000;
   constant DATA_TOKEN_TIMEOUT     : integer := 50000;

   signal power_up_counter         : integer range 0 to POWER_UP_WAIT_CYCLES;
   signal byte_counter             : integer range 0 to 16;
   signal poll_counter             : integer range 0 to POLL_TIMEOUT_BYTES;
   signal acmd41_retry_count       : integer range 0 to ACMD41_MAX_RETRIES;
   signal data_token_counter       : integer range 0 to DATA_TOKEN_TIMEOUT;
   signal byte_write_index         : integer range 0 to 512;

   signal spi_start_transfer       : std_logic;
   signal spi_transmit_byte        : std_logic_vector(7 downto 0);
   signal spi_received_byte        : std_logic_vector(7 downto 0);
   signal spi_transfer_done        : std_logic;
   signal spi_busy_signal          : std_logic;
   signal cs_internal              : std_logic;

   signal init_complete_register   : std_logic;
   signal byte_write_enable        : std_logic;
   signal read_byte_internal       : std_logic_vector(7 downto 0);

   signal current_state_code       : std_logic_vector(3 downto 0);
   signal frozen_state_code        : std_logic_vector(3 downto 0);

   type sector_buffer_type is array (0 to 511) of std_logic_vector(7 downto 0);
   signal sector_buffer : sector_buffer_type;

   function get_cmd0_byte(index : integer) return std_logic_vector is
   begin
      case index is
         when 0      => return x"40";
         when 5      => return x"95";
         when others => return x"00";
      end case;
   end function;

   function get_cmd8_byte(index : integer) return std_logic_vector is
   begin
      case index is
         when 0      => return x"48";
         when 3      => return x"01";
         when 4      => return x"AA";
         when 5      => return x"87";
         when others => return x"00";
      end case;
   end function;

   function get_cmd55_byte(index : integer) return std_logic_vector is
   begin
      case index is
         when 0      => return x"77";
         when 5      => return x"FF";
         when others => return x"00";
      end case;
   end function;

   function get_acmd41_byte(index : integer) return std_logic_vector is
   begin
      case index is
         when 0      => return x"69";
         when 1      => return x"40";
         when 5      => return x"FF";
         when others => return x"00";
      end case;
   end function;

   -- CMD17 reads single block. Argument is sector number for SDHC cards.
   -- This reads sector 0.
   function get_cmd17_byte(index : integer) return std_logic_vector is
   begin
      case index is
         when 0      => return x"51";
         when 5      => return x"FF";
         when others => return x"00";
      end case;
   end function;

begin

   spi_master_instance : SPI_Master
      generic map (CLOCK_DIVIDER => 128)
      port map (clock          => clock,
                reset          => reset,
                start_transfer => spi_start_transfer,
                transmit_byte  => spi_transmit_byte,
                received_byte  => spi_received_byte,
                transfer_done  => spi_transfer_done,
                busy           => spi_busy_signal,
                spi_clock_out  => spi_clock_out,
                spi_mosi_out   => spi_mosi_out,
                spi_miso_in    => spi_miso_in);

   spi_chip_select_n  <= cs_internal;
   last_response_byte <= spi_received_byte;
   read_byte          <= read_byte_internal;
   init_done          <= init_complete_register;
   read_done          <= '1' when current_state = s_read_complete else '0';
   init_failed        <= '1' when current_state = s_init_failed   else '0';

   -- Combinational: write to buffer one cycle after each data byte transfer completes
   byte_write_enable <= '1' when (current_state = s_data_byte_wait and spi_transfer_done = '1') else '0';

   current_state_code <= "0000" when current_state = s_idle
                    else "0001" when current_state = s_power_up_wait
                    else "0010" when current_state = s_dummy_clocks_request    or current_state = s_dummy_clocks_wait
                    else "0011" when current_state = s_cmd0_request            or current_state = s_cmd0_wait
                                                                                or current_state = s_cmd0_poll_request       or current_state = s_cmd0_poll_wait
                    else "0100" when current_state = s_cmd8_request            or current_state = s_cmd8_wait
                                                                                or current_state = s_cmd8_poll_request       or current_state = s_cmd8_poll_wait
                                                                                or current_state = s_cmd8_extra_request      or current_state = s_cmd8_extra_wait
                    else "0101" when current_state = s_cmd55_request           or current_state = s_cmd55_wait
                                                                                or current_state = s_cmd55_poll_request      or current_state = s_cmd55_poll_wait
                    else "0110" when current_state = s_acmd41_request          or current_state = s_acmd41_wait
                                                                                or current_state = s_acmd41_poll_request     or current_state = s_acmd41_poll_wait
                    else "0111" when current_state = s_inter_command_request   or current_state = s_inter_command_wait
                    else "1000" when current_state = s_cmd17_request           or current_state = s_cmd17_wait
                                                                                or current_state = s_cmd17_poll_request      or current_state = s_cmd17_poll_wait
                    else "1001" when current_state = s_data_token_poll_request or current_state = s_data_token_poll_wait
                    else "1010" when current_state = s_data_byte_request       or current_state = s_data_byte_wait
                    else "1011" when current_state = s_data_crc_request        or current_state = s_data_crc_wait
                    else "1100" when current_state = s_read_complete
                    else "1110";

   failure_latch_process : process(clock, reset)
   begin
      if reset = '1' then
         frozen_state_code <= "0000";
      elsif rising_edge(clock) then
         if current_state /= s_init_failed then
            frozen_state_code <= current_state_code;
         end if;
      end if;
   end process failure_latch_process;

   state_indicator <= frozen_state_code;

   -- Sector buffer: synchronous write, registered read. Quartus infers block RAM.
   sector_buffer_process : process(clock)
   begin
      if rising_edge(clock) then
         if byte_write_enable = '1' then
            sector_buffer(byte_write_index) <= spi_received_byte;
         end if;
         read_byte_internal <= sector_buffer(conv_integer(byte_address));
      end if;
   end process sector_buffer_process;

   init_process : process(clock, reset)
   begin
      if reset = '1' then
         current_state          <= s_idle;
         next_command_state     <= s_idle;
         spi_start_transfer     <= '0';
         spi_transmit_byte      <= x"FF";
         cs_internal            <= '1';
         power_up_counter       <= 0;
         byte_counter           <= 0;
         poll_counter           <= 0;
         acmd41_retry_count     <= 0;
         data_token_counter     <= 0;
         byte_write_index       <= 0;
         init_complete_register <= '0';

      elsif rising_edge(clock) then
         spi_start_transfer <= '0';

         case current_state is

            when s_idle =>
               cs_internal      <= '1';
               power_up_counter <= 0;
               byte_counter     <= 0;
               poll_counter     <= 0;
               if start_init = '1' then
                  current_state <= s_power_up_wait;
               end if;

            when s_power_up_wait =>
               cs_internal <= '1';
               if power_up_counter = POWER_UP_WAIT_CYCLES then
                  current_state <= s_dummy_clocks_request;
                  byte_counter  <= 0;
               else
                  power_up_counter <= power_up_counter + 1;
               end if;

            when s_dummy_clocks_request =>
               cs_internal <= '1';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_dummy_clocks_wait;
               end if;

            when s_dummy_clocks_wait =>
               cs_internal <= '1';
               if spi_transfer_done = '1' then
                  if byte_counter = DUMMY_CLOCK_BYTES - 1 then
                     byte_counter  <= 0;
                     current_state <= s_cmd0_request;
                  else
                     byte_counter  <= byte_counter + 1;
                     current_state <= s_dummy_clocks_request;
                  end if;
               end if;

            when s_cmd0_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= get_cmd0_byte(byte_counter);
                  spi_start_transfer <= '1';
                  current_state      <= s_cmd0_wait;
               end if;

            when s_cmd0_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if byte_counter = 5 then
                     byte_counter  <= 0;
                     poll_counter  <= 0;
                     current_state <= s_cmd0_poll_request;
                  else
                     byte_counter  <= byte_counter + 1;
                     current_state <= s_cmd0_request;
                  end if;
               end if;

            when s_cmd0_poll_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_cmd0_poll_wait;
               end if;

            when s_cmd0_poll_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if spi_received_byte = x"01" then
                     next_command_state <= s_cmd8_request;
                     byte_counter       <= 0;
                     current_state      <= s_inter_command_request;
                  elsif poll_counter = POLL_TIMEOUT_BYTES - 1 then
                     current_state <= s_init_failed;
                  else
                     poll_counter  <= poll_counter + 1;
                     current_state <= s_cmd0_poll_request;
                  end if;
               end if;

            when s_cmd8_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= get_cmd8_byte(byte_counter);
                  spi_start_transfer <= '1';
                  current_state      <= s_cmd8_wait;
               end if;

            when s_cmd8_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if byte_counter = 5 then
                     byte_counter  <= 0;
                     poll_counter  <= 0;
                     current_state <= s_cmd8_poll_request;
                  else
                     byte_counter  <= byte_counter + 1;
                     current_state <= s_cmd8_request;
                  end if;
               end if;

            when s_cmd8_poll_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_cmd8_poll_wait;
               end if;

            when s_cmd8_poll_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if spi_received_byte = x"01" then
                     byte_counter  <= 0;
                     current_state <= s_cmd8_extra_request;
                  elsif poll_counter = POLL_TIMEOUT_BYTES - 1 then
                     current_state <= s_init_failed;
                  else
                     poll_counter  <= poll_counter + 1;
                     current_state <= s_cmd8_poll_request;
                  end if;
               end if;

            when s_cmd8_extra_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_cmd8_extra_wait;
               end if;

            when s_cmd8_extra_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if byte_counter = 3 then
                     byte_counter       <= 0;
                     acmd41_retry_count <= 0;
                     next_command_state <= s_cmd55_request;
                     current_state      <= s_inter_command_request;
                  else
                     byte_counter  <= byte_counter + 1;
                     current_state <= s_cmd8_extra_request;
                  end if;
               end if;

            when s_cmd55_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= get_cmd55_byte(byte_counter);
                  spi_start_transfer <= '1';
                  current_state      <= s_cmd55_wait;
               end if;

            when s_cmd55_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if byte_counter = 5 then
                     byte_counter  <= 0;
                     poll_counter  <= 0;
                     current_state <= s_cmd55_poll_request;
                  else
                     byte_counter  <= byte_counter + 1;
                     current_state <= s_cmd55_request;
                  end if;
               end if;

            when s_cmd55_poll_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_cmd55_poll_wait;
               end if;

            when s_cmd55_poll_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if spi_received_byte(7) = '0' then
                     next_command_state <= s_acmd41_request;
                     byte_counter       <= 0;
                     current_state      <= s_inter_command_request;
                  elsif poll_counter = POLL_TIMEOUT_BYTES - 1 then
                     current_state <= s_init_failed;
                  else
                     poll_counter  <= poll_counter + 1;
                     current_state <= s_cmd55_poll_request;
                  end if;
               end if;

            when s_acmd41_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= get_acmd41_byte(byte_counter);
                  spi_start_transfer <= '1';
                  current_state      <= s_acmd41_wait;
               end if;

            when s_acmd41_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if byte_counter = 5 then
                     byte_counter  <= 0;
                     poll_counter  <= 0;
                     current_state <= s_acmd41_poll_request;
                  else
                     byte_counter  <= byte_counter + 1;
                     current_state <= s_acmd41_request;
                  end if;
               end if;

            when s_acmd41_poll_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_acmd41_poll_wait;
               end if;

            when s_acmd41_poll_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if spi_received_byte = x"00" then
                     -- Init done! Latch the flag and proceed to read sector 0
                     init_complete_register <= '1';
                     next_command_state     <= s_cmd17_request;
                     byte_counter           <= 0;
                     data_token_counter     <= 0;
                     current_state          <= s_inter_command_request;
                  elsif spi_received_byte = x"01" then
                     if acmd41_retry_count = ACMD41_MAX_RETRIES - 1 then
                        current_state <= s_init_failed;
                     else
                        acmd41_retry_count <= acmd41_retry_count + 1;
                        byte_counter       <= 0;
                        next_command_state <= s_cmd55_request;
                        current_state      <= s_inter_command_request;
                     end if;
                  elsif poll_counter = POLL_TIMEOUT_BYTES - 1 then
                     current_state <= s_init_failed;
                  else
                     poll_counter  <= poll_counter + 1;
                     current_state <= s_acmd41_poll_request;
                  end if;
               end if;

            when s_inter_command_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_inter_command_wait;
               end if;

            when s_inter_command_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  current_state <= next_command_state;
               end if;

            -- CMD17 reads single block at the address in the argument (sector 0 here)
            when s_cmd17_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= get_cmd17_byte(byte_counter);
                  spi_start_transfer <= '1';
                  current_state      <= s_cmd17_wait;
               end if;

            when s_cmd17_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if byte_counter = 5 then
                     byte_counter  <= 0;
                     poll_counter  <= 0;
                     current_state <= s_cmd17_poll_request;
                  else
                     byte_counter  <= byte_counter + 1;
                     current_state <= s_cmd17_request;
                  end if;
               end if;

            when s_cmd17_poll_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_cmd17_poll_wait;
               end if;

            when s_cmd17_poll_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if spi_received_byte = x"00" then
                     data_token_counter <= 0;
                     current_state      <= s_data_token_poll_request;
                  elsif poll_counter = POLL_TIMEOUT_BYTES - 1 then
                     current_state <= s_init_failed;
                  else
                     poll_counter  <= poll_counter + 1;
                     current_state <= s_cmd17_poll_request;
                  end if;
               end if;

            -- Card prepares the data, then sends 0xFE to signal the data block is coming.
            -- Can take a while, so the timeout is much larger than other polls.
            when s_data_token_poll_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_data_token_poll_wait;
               end if;

            when s_data_token_poll_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if spi_received_byte = x"FE" then
                     byte_write_index <= 0;
                     current_state    <= s_data_byte_request;
                  elsif data_token_counter = DATA_TOKEN_TIMEOUT - 1 then
                     current_state <= s_init_failed;
                  else
                     data_token_counter <= data_token_counter + 1;
                     current_state      <= s_data_token_poll_request;
                  end if;
               end if;

            -- Read 512 data bytes into sector_buffer
            when s_data_byte_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_data_byte_wait;
               end if;

            when s_data_byte_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if byte_write_index = 511 then
                     byte_write_index <= 0;
                     byte_counter     <= 0;
                     current_state    <= s_data_crc_request;
                  else
                     byte_write_index <= byte_write_index + 1;
                     current_state    <= s_data_byte_request;
                  end if;
               end if;

            -- Read and discard the 2 CRC bytes that follow the data block
            when s_data_crc_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_data_crc_wait;
               end if;

            when s_data_crc_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if byte_counter = 1 then
                     current_state <= s_read_complete;
                  else
                     byte_counter  <= byte_counter + 1;
                     current_state <= s_data_crc_request;
                  end if;
               end if;

            when s_read_complete =>
               cs_internal <= '1';

            when s_init_failed =>
               cs_internal <= '1';

         end case;
      end if;
   end process init_process;

end architecture behavioural;