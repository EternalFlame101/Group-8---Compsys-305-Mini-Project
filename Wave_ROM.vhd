library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library altera_mf;
use altera_mf.all;

entity Wave_ROM is
	port (
        clock   	: in  std_logic;
        address 	: in  std_logic_vector(7 downto 0); -- HEX
		  lane_0_out: out std_logic_vector(2 downto 0);
		  lane_1_out: out std_logic_vector(2 downto 0);
		  lane_2_out: out std_logic_vector(2 downto 0)
    );
end entity Wave_ROM;

architecture Wave_ROM_behaviour of Wave_ROM is

	signal rom_address : std_logic_vector (7 downto 0);
	signal rom_data	 : std_logic_vector (8 downto 0);

	component altsyncram is
		generic (address_aclr_a			  : string;
					clock_enable_input_a	  : string;
					clock_enable_output_a  : string;
					init_file				  : string;
					intended_device_family : string;
					lpm_hint					  : string;
					lpm_type					  : string;
					numwords_a				  : natural;
					operation_mode			  : string;
					outdata_aclr_a			  : string;
					outdata_reg_a			  : string;
					widthad_a				  : natural;
					width_a					  : natural;
					width_byteena_a		  : natural);
					
		port (clock0	 : in  std_logic;
				address_a : in  std_logic_vector (7 downto 0);
				q_a		 : out std_logic_vector (8 downto 0));
	
	end component altsyncram;
				
begin

	Altsyncram_Component : altsyncram 
		generic map (address_aclr_a         => "none",
						 clock_enable_input_a   => "bypass",
						 clock_enable_output_a  => "bypass",
						 init_file              => "Images_To_mif/mif/spawn_patterns.mif",
						 intended_device_family => "cyclone v",
						 lpm_hint               => "enable_runtime_mod=no",
						 lpm_type               => "altsyncram",
						 numwords_a             => 256,
						 operation_mode         => "rom",
						 outdata_aclr_a         => "none",
						 outdata_reg_a          => "unregistered",
						 widthad_a              => 8,
						 width_a                => 9,
						 width_byteena_a        => 1)
										  
			port map (clock0    => clock,
						 address_a => address,
						 q_a       => rom_data);

	
	lane_0_out <= rom_data(2 downto 0);
	lane_1_out <= rom_data(5 downto 3);
	lane_2_out <= rom_data(8 downto 6);
	
end architecture;