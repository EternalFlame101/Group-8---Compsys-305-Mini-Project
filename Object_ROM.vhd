library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library altera_mf;
use altera_mf.all;

entity Object_ROM is
	port (clock				  : in  std_logic;
			track_row        : in  std_logic_vector (9 downto 0);
			obj_sd_output	  : out std_logic_vector (9 downto 0);
		   obj_y_output     : out std_logic_vector (9 downto 0);
			obj_h_output     : out std_logic_vector (9 downto 0);
			obj_w_output     : out std_logic_vector (9 downto 0);
			obj_wb_output	  : out std_logic_vector (9 downto 0);
			top_h_output     : out std_logic_vector (9 downto 0);
			top_taper     	  : out std_logic_vector (9 downto 0);
			side_taper       : out std_logic_vector (9 downto 0));
end entity Object_ROM;

architecture object_rom_behaviour of Object_ROM is
	signal rom_address : std_logic_vector(7 downto 0);
	signal rom_data    : std_logic_vector(79 downto 0);

	component altsyncram
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
				q_a		 : out std_logic_vector (79 downto 0));
	end component;
begin
	Altsyncram_Component : altsyncram 
		generic map (address_aclr_a         => "none",
						 clock_enable_input_a   => "bypass",
						 clock_enable_output_a  => "bypass",
						 init_file              => "Images_To_mif/mif/object_data.mif",
						 intended_device_family => "cyclone V",
						 lpm_hint               => "enable_runtime_mod=no",
						 lpm_type               => "altsyncram",
						 numwords_a             => 160,
						 operation_mode         => "rom",
						 outdata_aclr_a         => "none",
						 outdata_reg_a          => "unregistered",
						 widthad_a              => 8,
						 width_a                => 80,
						 width_byteena_a        => 1)
										  
			port map (clock0    => clock,
						 address_a => rom_address,
						 q_a       => rom_data);

	-- getting the perspective scaler
	rom_address <= track_row(7 downto 0);
	
	obj_sd_output<= rom_data(79 downto 70);
	obj_y_output <= rom_data(69 downto 60);
	obj_h_output <= rom_data(59 downto 50);
	obj_w_output <= rom_data(49 downto 40);
	obj_wb_output<= rom_data(39 downto 30);
	top_h_output <= rom_data(29 downto 20);
	top_taper 	 <= rom_data(19 downto 10);
	side_taper	 <= rom_data(9 downto 0);
end architecture object_rom_behaviour;