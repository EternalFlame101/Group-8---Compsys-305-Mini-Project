-- ------------------------------------------------------------------------------
-- SD_Init
--   SD-card controller: brings the card up in SPI mode (CMD0/CMD8/CMD55/ACMD41),
--   then continuously streams a track by reading 512-byte sectors (CMD17) into a
--   double buffer that Audio_Playback drains. Drives chip-select and orchestrates
--   SPI_Master for every byte.
--
--   NOTE: on every (re-)init a drain phase clocks 520 bytes with CS LOW first. A
--   re-init triggered mid-song can catch the card partway through a block read;
--   CS-high dummy clocks do not abort it (the card only shifts data while CS is
--   low), so without the drain the card ignores CMD0 and returns 0xFF. The drain
--   lets the interrupted block finish so re-init succeeds first try.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity SD_Init is
   port (clock              : in  std_logic;
         reset              : in  std_logic;
         start_init         : in  std_logic;
         start_sector       : in  std_logic_vector(31 downto 0);
         track_length       : in  std_logic_vector(31 downto 0);
         byte_address       : in  std_logic_vector(9 downto 0);   -- 10 bits: bit 9 = buffer select
         spi_clock_out      : out std_logic;
         spi_mosi_out       : out std_logic;
         spi_miso_in        : in  std_logic;
         spi_chip_select_n  : out std_logic;
         init_done          : out std_logic;
         audio_ready        : out std_logic;
         init_failed        : out std_logic;
         state_indicator    : out std_logic_vector(3 downto 0);
         last_response_byte : out std_logic_vector(7 downto 0);
         read_byte          : out std_logic_vector(7 downto 0));
end entity SD_Init;

architecture behavioural of SD_Init is

   component SPI_Master is
      port (clock          : in  std_logic;
            reset          : in  std_logic;
            use_fast_clock : in  std_logic;
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
      s_drain_request,           s_drain_wait,
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
      s_streaming_idle,
      s_init_failed);
   signal current_state      : init_state_type;
   signal next_command_state : init_state_type;

   constant POWER_UP_WAIT_CYCLES : integer := 100000;
   -- 160 dummy-clock bytes = 1280 SPI clocks with CS HIGH at ~390 kHz.
   -- Cold boot only needs the SD-spec minimum of 74 (10 bytes). This is
   -- deliberately much larger so a RE-init triggered mid-song (audio_sd_reset
   -- flipped while the card was mid CMD17 block read) reliably flushes the
   -- card's interrupted read and lets it return to idle before CMD0 is sent.
   -- Without this, CMD0 receives garbage (card still driving the aborted
   -- read) and init freezes at the CMD0 state code -- the intermittent
   -- LEDR=0011 failure. 1280 clocks >> one 512-byte block, so any partial
   -- read is guaranteed to complete/abort.
   constant DUMMY_CLOCK_BYTES    : integer := 160;
   -- Drain phase: clock this many bytes with CS LOW before the normal power-up /
   -- dummy-clock sequence. Diagnostics proved the real failure: when re-init is
   -- triggered mid-song the card is often partway through a CMD17 512-byte block
   -- read. Deasserting CS and sending dummy clocks with CS HIGH does NOT abort
   -- that read -- the card only shifts data out while CS is LOW, so it stays
   -- stuck and returns 0xFF to CMD0/CMD8 (the "HEX=FF, stage=CMD8/CMD0" result).
   -- Draining 520 bytes with CS LOW lets the interrupted block (512 data + 2 CRC,
   -- rounded up) finish so the card releases the bus and returns to idle. Only
   -- then do the standard CS-HIGH dummy clocks + CMD0 land cleanly.
   constant DRAIN_BYTES          : integer := 520;
   constant POLL_TIMEOUT_BYTES   : integer := 16;
   constant ACMD41_MAX_RETRIES   : integer := 1000;
   constant DATA_TOKEN_TIMEOUT   : integer := 50000;

   signal power_up_counter    : integer range 0 to POWER_UP_WAIT_CYCLES;
   signal byte_counter        : integer range 0 to DUMMY_CLOCK_BYTES;
   signal poll_counter        : integer range 0 to POLL_TIMEOUT_BYTES;
   signal acmd41_retry_count  : integer range 0 to ACMD41_MAX_RETRIES;
   signal data_token_counter  : integer range 0 to DATA_TOKEN_TIMEOUT;
   signal byte_write_index    : integer range 0 to 512;
   signal drain_counter       : integer range 0 to DRAIN_BYTES;
   signal sector_addr         : std_logic_vector(31 downto 0);
   signal fills_count         : integer range 0 to 3;

   signal spi_start_transfer  : std_logic;
   signal spi_transmit_byte   : std_logic_vector(7 downto 0);
   signal spi_received_byte   : std_logic_vector(7 downto 0);
   signal spi_transfer_done   : std_logic;
   signal spi_busy_signal     : std_logic;
   signal spi_use_fast        : std_logic;
   signal cs_internal         : std_logic;

   signal init_complete_register : std_logic;
   signal audio_ready_register   : std_logic;
   signal fill_buffer_target     : std_logic;
   signal previous_byte_high     : std_logic;
   signal byte_write_enable      : std_logic;
   signal read_byte_internal     : std_logic_vector(7 downto 0);

   signal current_state_code  : std_logic_vector(3 downto 0);
   signal frozen_state_code   : std_logic_vector(3 downto 0);

   type sector_buffer_type is array (0 to 511) of std_logic_vector(7 downto 0);
   signal sector_buffer_a : sector_buffer_type;
   signal sector_buffer_b : sector_buffer_type;

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

begin

   spi_master_instance : SPI_Master
      port map (clock          => clock,
                reset          => reset,
                use_fast_clock => spi_use_fast,
                start_transfer => spi_start_transfer,
                transmit_byte  => spi_transmit_byte,
                received_byte  => spi_received_byte,
                transfer_done  => spi_transfer_done,
                busy           => spi_busy_signal,
                spi_clock_out  => spi_clock_out,
                spi_mosi_out   => spi_mosi_out,
                spi_miso_in    => spi_miso_in);

   spi_chip_select_n  <= cs_internal;
   spi_use_fast       <= init_complete_register;
   last_response_byte <= spi_received_byte;
   read_byte          <= read_byte_internal;
   init_done          <= init_complete_register;
   audio_ready        <= audio_ready_register;
   init_failed        <= '1' when current_state = s_init_failed else '0';

   byte_write_enable <= '1' when (current_state = s_data_byte_wait and spi_transfer_done = '1') else '0';

   current_state_code <= "0000" when current_state = s_idle
                    else "1101" when current_state = s_drain_request          or current_state = s_drain_wait
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
                    else "1100" when current_state = s_streaming_idle
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

   sector_buffer_process : process(clock)
   begin
      if rising_edge(clock) then
         if byte_write_enable = '1' then
            if fill_buffer_target = '0' then
               sector_buffer_a(byte_write_index) <= spi_received_byte;
            else
               sector_buffer_b(byte_write_index) <= spi_received_byte;
            end if;
         end if;
         if byte_address(9) = '0' then
            read_byte_internal <= sector_buffer_a(conv_integer(byte_address(8 downto 0)));
         else
            read_byte_internal <= sector_buffer_b(conv_integer(byte_address(8 downto 0)));
         end if;
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
         drain_counter          <= 0;
         sector_addr            <= start_sector;
         fills_count            <= 0;
         init_complete_register <= '0';
         audio_ready_register   <= '0';
         fill_buffer_target     <= '0';
         previous_byte_high     <= '0';

      elsif rising_edge(clock) then
         spi_start_transfer <= '0';

         case current_state is

            when s_idle =>
               cs_internal      <= '1';
               power_up_counter <= 0;
               byte_counter     <= 0;
               poll_counter     <= 0;
               drain_counter    <= 0;
               if start_init = '1' then
                  current_state <= s_drain_request;
               end if;

            -- ===== DRAIN PHASE (CS LOW) =====
            -- Clock DRAIN_BYTES with CS asserted LOW so any CMD17 block read that
            -- was interrupted by this (re-)init completes and the card releases
            -- the bus. Without this the card ignores CMD0/CMD8 (returns 0xFF).
            -- On a cold boot the card isn't mid-read, so this just clocks
            -- harmless 0xFF bytes -- no downside.
            when s_drain_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  spi_transmit_byte  <= x"FF";
                  spi_start_transfer <= '1';
                  current_state      <= s_drain_wait;
               end if;

            when s_drain_wait =>
               cs_internal <= '0';
               if spi_transfer_done = '1' then
                  if drain_counter = DRAIN_BYTES - 1 then
                     drain_counter <= 0;
                     current_state <= s_power_up_wait;
                  else
                     drain_counter <= drain_counter + 1;
                     current_state <= s_drain_request;
                  end if;
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
                     init_complete_register <= '1';
                     fill_buffer_target     <= '0';
                     sector_addr            <= start_sector;
                     fills_count            <= 0;
                     next_command_state     <= s_cmd17_request;
                     byte_counter           <= 0;
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

            when s_cmd17_request =>
               cs_internal <= '0';
               if spi_busy_signal = '0' then
                  case byte_counter is
                     when 0 => spi_transmit_byte <= x"51";
                     when 1 => spi_transmit_byte <= sector_addr(31 downto 24);
                     when 2 => spi_transmit_byte <= sector_addr(23 downto 16);
                     when 3 => spi_transmit_byte <= sector_addr(15 downto 8);
                     when 4 => spi_transmit_byte <= sector_addr(7 downto 0);
                     when 5 => spi_transmit_byte <= x"FF";
                     when others => spi_transmit_byte <= x"FF";
                  end case;
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
                     -- A sector finished. Decide what next.
                     if sector_addr = start_sector + track_length - 1 then
                        sector_addr <= start_sector;
                     else
                        sector_addr <= sector_addr + 1;
                     end if;
                     if fills_count = 0 then
                        -- Just filled buffer A. Now fill buffer B with sector 1.
                        fills_count        <= 1;
                        fill_buffer_target <= '1';
                        next_command_state <= s_cmd17_request;
                        byte_counter       <= 0;
                        current_state      <= s_inter_command_request;
                     elsif fills_count = 1 then
                        -- Just filled buffer B. Both buffers ready. Start audio.
                        fills_count          <= 2;
                        audio_ready_register <= '1';
                        previous_byte_high   <= '0';
                        current_state        <= s_streaming_idle;
                     else
                        -- Streaming refill done. Back to idle.
                        current_state <= s_streaming_idle;
                     end if;
                  else
                     byte_counter  <= byte_counter + 1;
                     current_state <= s_data_crc_request;
                  end if;
               end if;

            when s_streaming_idle =>
               cs_internal <= '0';
               if byte_address(9) /= previous_byte_high then
                  -- Playback just moved to the other buffer. Refill the one it left.
                  fill_buffer_target <= previous_byte_high;
                  previous_byte_high <= byte_address(9);
                  next_command_state <= s_cmd17_request;
                  byte_counter       <= 0;
                  current_state      <= s_inter_command_request;
               end if;

            when s_init_failed =>
               cs_internal <= '1';

         end case;
      end if;
   end process init_process;

end architecture behavioural;