library IEEE;
use IEEE.std_logic_1164.all;

-- Composites the player sprite on top of the existing obstacle (object) layer.
-- Player has priority: any non-transparent player pixel overrides the object
-- layer. Transparency is encoded as all-zero RGB, matching the convention used
-- by Object_Manager and Graphics_Manager elsewhere in the project.

entity Player_And_Objects_Manager is
   port (player_red,  player_green,  player_blue  : in  std_logic_vector(3 downto 0);
         objects_red, objects_green, objects_blue : in  std_logic_vector(3 downto 0);
         red_out,     green_out,     blue_out     : out std_logic_vector(3 downto 0));
end entity Player_And_Objects_Manager;

architecture player_and_objects_manager_behaviour of Player_And_Objects_Manager is
   signal player_pixel_visible : std_logic;
begin

   player_pixel_visible <= '1' when ((player_red   /= "0000") or
                                     (player_green /= "0000") or
                                     (player_blue  /= "0000"))
                               else '0';

   red_out   <= player_red   when player_pixel_visible = '1' else objects_red;
   green_out <= player_green when player_pixel_visible = '1' else objects_green;
   blue_out  <= player_blue  when player_pixel_visible = '1' else objects_blue;

end architecture player_and_objects_manager_behaviour;