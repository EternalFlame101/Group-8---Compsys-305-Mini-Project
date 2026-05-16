library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ------------------------------------------------------------------------------
-- Object_Manager
--   Combines two Moving_Object outputs into a single sprite-plane output.
--   Sprite 1 takes priority over sprite 2 where both are active. Where
--   neither sprite is active, the output is black, allowing whatever sits
--   underneath in the final compositor to show through.
-- ------------------------------------------------------------------------------
entity Object_Manager is
   port (sprite_0_red, sprite_0_green, sprite_0_blue : in  std_logic_vector(3 downto 0);
			sprite_1_red, sprite_1_green, sprite_1_blue : in  std_logic_vector(3 downto 0);
         sprite_2_red, sprite_2_green, sprite_2_blue : in  std_logic_vector(3 downto 0);
         red_out,      green_out,      blue_out      : out std_logic_vector(3 downto 0));
end entity Object_Manager;

architecture object_manager_behaviour of Object_Manager is

   -- Active signals: true if that sprite has anything to draw on this pixel.
	signal sprite_0_active : std_logic;
   signal sprite_1_active : std_logic;
   signal sprite_2_active : std_logic;

begin

   -- A sprite is active if any of its colour channels is non-zero.
	sprite_0_active <= '1' when (sprite_0_red or sprite_0_green or sprite_0_blue) /= "0000" else '0';
   sprite_1_active <= '1' when (sprite_1_red or sprite_1_green or sprite_1_blue) /= "0000" else '0';
   sprite_2_active <= '1' when (sprite_2_red or sprite_2_green or sprite_2_blue) /= "0000" else '0';

   -- Priority mux: sprite 1 on top, sprite 2 below, transparent (black) otherwise.
   red_out   <= sprite_0_red	 when (sprite_0_active = '1') else
					 sprite_1_red   when (sprite_1_active = '1') else
                sprite_2_red   when (sprite_2_active = '1') else
                "0000";
   green_out <= sprite_0_green when (sprite_0_active = '1') else
					 sprite_1_green when (sprite_1_active = '1') else
                sprite_2_green when (sprite_2_active = '1') else
                "0000";
   blue_out  <= sprite_0_green when (sprite_0_active = '1') else
					 sprite_1_blue  when (sprite_1_active = '1') else
                sprite_2_blue  when (sprite_2_active = '1') else
                "0000";

end architecture object_manager_behaviour;