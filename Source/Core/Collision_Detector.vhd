-- ------------------------------------------------------------------------------
-- Collision_Detector
--   Purely combinational collision logic. For each of the three lanes it decides
--   whether the player has hit an obstacle or collected a gift, based on the
--   object type, the object's on-track row, the player's lane, and whether the
--   player is jumping or diving.
--
--   Object encodings: "100" = air box (pass by diving), "010" = small ground box
--   (pass by jumping), "011" = large ground box (must change lane). A collision
--   only registers once the object has descended past row 140 (near the player).
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Collision_Detector is
   port (lane_0_row, lane_1_row, lane_2_row  : in std_logic_vector(9 downto 0);
         lane_0_obj_type, lane_1_obj_type, lane_2_obj_type  : in std_logic_vector(2 downto 0);
         lane_0_active, lane_1_active, lane_2_active : in std_logic;
         player_lane                         : in std_logic_vector(1 downto 0);
         player_state                        : in std_logic; -- 0 grounded, 1 jumping
         player_dive                         : in std_logic; -- 1 while dive/squish animation active
         lane_0_object_collision             : out std_logic;
         lane_1_object_collision             : out std_logic;
         lane_2_object_collision             : out std_logic;
         lane_0_gift_collision               : out std_logic;
         lane_1_gift_collision               : out std_logic;
         lane_2_gift_collision               : out std_logic);
end entity Collision_Detector;

architecture collision_detector_behaviour of Collision_Detector is
begin
   -- "100" = floating air box: pass by diving; collides when NOT diving.
   -- "010" = small ground box: pass by jumping; collides when grounded.
   -- "011" = large ground box: too tall to jump; always collides (must switch lanes).
   lane_0_object_collision <= '1' when ((lane_0_active = '1' and player_lane = "00") and
                                        (lane_0_row >= conv_std_logic_vector(140, 10)) and
                                       ((lane_0_obj_type = "100" and player_dive = '0') or
                                        (lane_0_obj_type = "010" and player_state = '0') or
                                        (lane_0_obj_type = "011")))
                                     else '0';

   lane_1_object_collision <= '1' when ((lane_1_active = '1' and player_lane = "01") and
                                        (lane_1_row >= conv_std_logic_vector(140, 10)) and
                                       ((lane_1_obj_type = "100" and player_dive = '0') or
                                        (lane_1_obj_type = "010" and player_state = '0') or
                                        (lane_1_obj_type = "011")))
                                     else '0';

   lane_2_object_collision <= '1' when ((lane_2_active = '1' and player_lane = "10") and
                                        (lane_2_row >= conv_std_logic_vector(140, 10)) and
                                       ((lane_2_obj_type = "100" and player_dive = '0') or
                                        (lane_2_obj_type = "010" and player_state = '0') or
                                        (lane_2_obj_type = "011")))
                                     else '0';

   -- gift collision
   lane_0_gift_collision <= '1' when ((lane_0_active = '1' and player_lane = "00") and
                                      (lane_0_row >= conv_std_logic_vector(140, 10)) and
                                      (lane_0_obj_type = "001" and player_state = '0'))
                                else '0';

   lane_1_gift_collision <= '1' when ((lane_1_active = '1' and player_lane = "01") and
                                      (lane_1_row >= conv_std_logic_vector(140, 10)) and
                                      (lane_1_obj_type = "001" and player_state = '0'))
                                else '0';

   lane_2_gift_collision <= '1' when ((lane_2_active = '1' and player_lane = "10") and
                                      (lane_2_row >= conv_std_logic_vector(140, 10)) and
                                      (lane_2_obj_type = "001" and player_state = '0'))
                                else '0';
end architecture collision_detector_behaviour;
