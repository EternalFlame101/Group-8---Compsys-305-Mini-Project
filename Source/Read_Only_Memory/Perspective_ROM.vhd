-- ------------------------------------------------------------------------------
-- Perspective_ROM
--   altsyncram-backed table mapping each track row to its perspective width
--   (how far the track edges spread at that row). Track_Generator reads this to
--   draw the receding three-lane road.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library altera_mf;
use altera_mf.all;

entity Perspective_ROM is
   port (clock                  : in  std_logic;
         track_row              : in  std_logic_vector (9 downto 0);
         perspective_output     : out std_logic_vector (9 downto 0));
end entity Perspective_ROM;

architecture perspective_rom_behaviour of Perspective_ROM is
   signal rom_address : std_logic_vector(7 downto 0);
   signal rom_data    : std_logic_vector(9 downto 0);

   component altsyncram
      generic (address_aclr_a         : string;
               clock_enable_input_a   : string;
               clock_enable_output_a  : string;
               init_file              : string;
               intended_device_family : string;
               lpm_hint               : string;
               lpm_type               : string;
               numwords_a             : natural;
               operation_mode         : string;
               outdata_aclr_a         : string;
               outdata_reg_a          : string;
               widthad_a              : natural;
               width_a                : natural;
               width_byteena_a        : natural);

      port (clock0    : in  std_logic;
            address_a : in  std_logic_vector (7 downto 0);
            q_a       : out std_logic_vector (9 downto 0));
   end component;
begin
   Altsyncram_Component : altsyncram
      generic map (address_aclr_a         => "none",
                   clock_enable_input_a   => "bypass",
                   clock_enable_output_a  => "bypass",
                   init_file              => "Assets/Memory_Initialization_Files/perspective.mif",
                   intended_device_family => "cyclone V",
                   lpm_hint               => "enable_runtime_mod=no",
                   lpm_type               => "altsyncram",
                   numwords_a             => 160,
                   operation_mode         => "rom",
                   outdata_aclr_a         => "none",
                   outdata_reg_a          => "unregistered",
                   widthad_a              => 8,
                   width_a                => 10,
                   width_byteena_a        => 1)

         port map (clock0    => clock,
                   address_a => rom_address,
                   q_a       => rom_data);

   -- getting the perspective scaler
   rom_address <= track_row(7 downto 0);

   perspective_output <= rom_data;
end perspective_rom_behaviour;