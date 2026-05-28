library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library altera_mf;
use altera_mf.all;

entity Sprites_ROM is
    generic (
        DEPTH     : positive := 1024;
        ADDR_BITS : positive := 12;
        MIF_FILE  : string   := "placeholder.mif"
    );
    port (
        clock   : in  std_logic;
        address : in  std_logic_vector(11 downto 0);
        red     : out std_logic_vector(3 downto 0);
        green   : out std_logic_vector(3 downto 0);
        blue    : out std_logic_vector(3 downto 0)
    );
end entity Sprites_ROM;

architecture rom_behaviour of Sprites_ROM is
   signal rom_data    : std_logic_vector(11 downto 0);
   signal rom_address : std_logic_vector(ADDR_BITS - 1 downto 0);

   component altsyncram
      generic (address_aclr_a        : string;
               clock_enable_input_a  : string;
               clock_enable_output_a : string;
               init_file             : string;
               intended_device_family: string;
               lpm_hint              : string;
               lpm_type              : string;
               numwords_a            : natural;
               operation_mode        : string;
               outdata_aclr_a        : string;
               outdata_reg_a         : string;
               widthad_a             : natural;
               width_a               : natural;
               width_byteena_a       : natural);

      port (clock0    : in  std_logic;
            address_a : in  std_logic_vector(ADDR_BITS - 1 downto 0);
            q_a       : out std_logic_vector(11 downto 0));
   end component;
begin
   Altsyncram_Component : altsyncram
      generic map (address_aclr_a         => "none",
                   clock_enable_input_a   => "bypass",
                   clock_enable_output_a  => "bypass",
                   init_file              => MIF_FILE,
                   intended_device_family => "cyclone v",
                   lpm_hint               => "enable_runtime_mod=no",
                   lpm_type               => "altsyncram",
                   numwords_a             => DEPTH,
                   operation_mode         => "rom",
                   outdata_aclr_a         => "none",
                   outdata_reg_a          => "unregistered",
                   widthad_a              => ADDR_BITS,
                   width_a                => 12,
                   width_byteena_a        => 1)

         port map (clock0    => clock,
                   address_a => rom_address,
                   q_a       => rom_data);

   -- Slice the incoming 12-bit address down to whatever the ROM actually needs.
   -- For 32x32 sprites (1024 words, ADDR_BITS=10) this takes the low 10 bits.
   -- For 64x64 sprites (4096 words, ADDR_BITS=12) this takes all 12 bits.
   rom_address <= address(ADDR_BITS - 1 downto 0);

   red   <= rom_data(11 downto 8);
   green <= rom_data(7 downto 4);
   blue  <= rom_data(3 downto 0);

end architecture rom_behaviour;