library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Graphics_Manager is
    port (
        text_large_r, text_large_g, text_large_b : in  std_logic_vector(3 downto 0);
        text_small_r, text_small_g, text_small_b : in  std_logic_vector(3 downto 0);
        background_r, background_g, background_b : in  std_logic_vector(3 downto 0);
        sprite_r, sprite_g, sprite_b             : in  std_logic_vector(3 downto 0);
        mouse_r, mouse_g, mouse_b                : in  std_logic_vector(3 downto 0);
        red_out, green_out, blue_out             : out std_logic_vector(3 downto 0)
    );
end entity Graphics_Manager;

architecture rtl of Graphics_Manager is

    -- Active signals — true if that layer has anything to draw
    signal text_large_active : std_logic;
    signal text_small_active : std_logic;
    signal sprite_active     : std_logic;
    signal mouse_active      : std_logic;

begin

    -- A layer is active if any channel is non zero
    text_large_active <= '1' when (text_large_r or text_large_g or text_large_b) /= "0000" else '0';
    text_small_active <= '1' when (text_small_r or text_small_g or text_small_b) /= "0000" else '0';
    sprite_active     <= '1' when (sprite_r     or sprite_g     or sprite_b)     /= "0000" else '0';
    mouse_active      <= '1' when (mouse_r      or mouse_g      or mouse_b)      /= "0000" else '0';

    -- Priority mux — highest priority first, background always last
    red_out   <= text_large_r when text_large_active = '1' else
                 text_small_r when text_small_active = '1' else
                 mouse_r      when mouse_active      = '1' else
                 sprite_r     when sprite_active     = '1' else
                 background_r;

    green_out <= text_large_g when text_large_active = '1' else
                 text_small_g when text_small_active = '1' else
                 mouse_g      when mouse_active      = '1' else
                 sprite_g     when sprite_active     = '1' else
                 background_g;

    blue_out  <= text_large_b when text_large_active = '1' else
                 text_small_b when text_small_active = '1' else
                 mouse_b      when mouse_active      = '1' else
                 sprite_b     when sprite_active     = '1' else
                 background_b;

end architecture rtl;