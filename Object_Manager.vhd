library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ------------------------------------------------------------------------------
-- Object_Manager
--   Combines two Moving_Object outputs into a single sprite-plane output, with
--   priority decided dynamically by how close each sprite's home lane is to
--   the cat's current lane. The closer sprite renders on top; ties go to
--   sprite_1. Where neither sprite is active, the output is black so the
--   compositor below can show through.
-- ------------------------------------------------------------------------------
entity Object_Manager is
   generic (SPRITE_1_LANE : integer range 0 to 2 := 1;
            SPRITE_2_LANE : integer range 0 to 2 := 0);
   port (sprite_1_red, sprite_1_green, sprite_1_blue : in  std_logic_vector(3 downto 0);
         sprite_2_red, sprite_2_green, sprite_2_blue : in  std_logic_vector(3 downto 0);
         cat_lane                                    : in  std_logic_vector(1 downto 0);
         red_out,      green_out,      blue_out      : out std_logic_vector(3 downto 0));
end entity Object_Manager;

architecture object_manager_behaviour of Object_Manager is

   signal sprite_1_active : std_logic;
   signal sprite_2_active : std_logic;

   signal cat_lane_int  : integer range 0 to 2;
   signal sprite_1_dist : integer range 0 to 2;
   signal sprite_2_dist : integer range 0 to 2;
   signal sprite_1_wins : std_logic;

   -- Winner/loser routing for the priority mux.
   signal winner_red,  winner_green,  winner_blue  : std_logic_vector(3 downto 0);
   signal winner_active                            : std_logic;
   signal loser_red,   loser_green,   loser_blue   : std_logic_vector(3 downto 0);
   signal loser_active                             : std_logic;

begin

   -- A sprite is active if any of its colour channels is non-zero.
   sprite_1_active <= '1' when (sprite_1_red or sprite_1_green or sprite_1_blue) /= "0000" else '0';
   sprite_2_active <= '1' when (sprite_2_red or sprite_2_green or sprite_2_blue) /= "0000" else '0';

   -- Lane-distance from the cat. Sprite_1 wins ties so behaviour matches the
   -- old fixed-priority compositor when both sprites are equidistant.
   cat_lane_int  <= conv_integer(cat_lane);
   sprite_1_dist <= abs(SPRITE_1_LANE - cat_lane_int);
   sprite_2_dist <= abs(SPRITE_2_LANE - cat_lane_int);
   sprite_1_wins <= '1' when sprite_1_dist <= sprite_2_dist else '0';

   -- Route winner/loser through a pair of muxes; output picks winner if active,
   -- loser otherwise, black if neither.
   winner_red    <= sprite_1_red    when sprite_1_wins = '1' else sprite_2_red;
   winner_green  <= sprite_1_green  when sprite_1_wins = '1' else sprite_2_green;
   winner_blue   <= sprite_1_blue   when sprite_1_wins = '1' else sprite_2_blue;
   winner_active <= sprite_1_active when sprite_1_wins = '1' else sprite_2_active;

   loser_red    <= sprite_2_red    when sprite_1_wins = '1' else sprite_1_red;
   loser_green  <= sprite_2_green  when sprite_1_wins = '1' else sprite_1_green;
   loser_blue   <= sprite_2_blue   when sprite_1_wins = '1' else sprite_1_blue;
   loser_active <= sprite_2_active when sprite_1_wins = '1' else sprite_1_active;

   red_out   <= winner_red   when winner_active = '1' else
                loser_red    when loser_active  = '1' else
                "0000";
   green_out <= winner_green when winner_active = '1' else
                loser_green  when loser_active  = '1' else
                "0000";
   blue_out  <= winner_blue  when winner_active = '1' else
                loser_blue   when loser_active  = '1' else
                "0000";

end architecture object_manager_behaviour;