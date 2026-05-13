library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Object_Manager is
	port (sprite_1_red,   sprite_1_green,   sprite_1_blue 		: in  std_logic_vector(3 downto 0);
			sprite_2_red,   sprite_2_green,   sprite_2_blue 		: in  std_logic_vector(3 downto 0);
			red_out,          green_out,          blue_out        : out std_logic_vector(3 downto 0));
end entity Object_Manager;

architecture object_manager_behaviour of Object_Manager is
    -- Active signals — true if that layer has anything to draw
    signal sprite_1_active : std_logic;
	 signal sprite_2_active : std_logic;
begin
    -- A layer is active if any channel is non zero
    sprite_1_active <= '1' when (sprite_1_red or sprite_1_green or sprite_1_blue) /= "0000" else '0';
	 
	 sprite_2_active <= '1' when (sprite_2_red or sprite_2_green or sprite_2_blue) /= "0000" else '0';

    -- Priority mux — highest priority first, background always last
    red_out   <= 	sprite_1_red when (sprite_1_active = '1') else
						sprite_2_red when (sprite_2_active = '1') else
						"0000";

    green_out <= sprite_1_green when (sprite_1_active = '1') else
						sprite_2_green when (sprite_2_active = '1') else
						"0000";

    blue_out  <= sprite_1_blue when (sprite_1_active = '1') else
						sprite_2_blue when (sprite_2_active = '1') else
						"0000";
end architecture object_manager_behaviour;