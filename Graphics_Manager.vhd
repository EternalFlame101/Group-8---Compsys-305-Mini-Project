library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Graphics_Manager is
	port (sprites_red,   	sprites_green,   		sprites_blue 	: in std_logic_vector(3 downto 0);
			background_red,	background_green,	 	background_blue: in std_logic_vector(3 downto 0);
			red_out, 			green_out,				blue_out 		: out std_logic_vector(3 downto 0));
end entity Graphics_Manager;

architecture graphics_manager_behaviour of Graphics_Manager is
    -- Active signals — true if that layer has anything to draw
    signal sprites_active     : std_logic;
	 signal background_active	: std_logic;
begin
    -- A layer is active if any channel is non zero
    sprites_active <= '1' when (sprites_red or sprites_green or sprites_blue) /= "0000" else '0';
	 background_active <= '1' when (background_red or background_green or background_blue) /= "0000" else '0';

    -- Priority mux — highest priority first, background always last
    red_out   <= sprites_red       when sprites_active = '1' else
                 background_red;

    green_out <= sprites_green     when sprites_active = '1' else
                 background_green;

    blue_out  <= sprites_blue      when sprites_active = '1' else
                 background_blue;
end architecture graphics_manager_behaviour;