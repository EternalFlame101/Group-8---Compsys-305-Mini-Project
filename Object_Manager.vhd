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
   generic (SPRITE_0_LANE : integer range 0 to 2 := 1;
            SPRITE_1_LANE : integer range 0 to 2 := 0;
				SPRITE_2_LANE : integer range 0 to 2 := 2);
   port (sprite_0_red, sprite_0_green, sprite_0_blue : in  std_logic_vector(3 downto 0);
         sprite_1_red, sprite_1_green, sprite_1_blue : in  std_logic_vector(3 downto 0);
			sprite_2_red, sprite_2_green, sprite_2_blue : in  std_logic_vector(3 downto 0);
         cat_lane                                    : in  std_logic_vector(1 downto 0);
         red_out,      green_out,      blue_out      : out std_logic_vector(3 downto 0));
end entity Object_Manager;

architecture object_manager_behaviour of Object_Manager is

	signal sprite_0_active : std_logic;
   signal sprite_1_active : std_logic;
   signal sprite_2_active : std_logic;

   signal cat_lane_int  : integer range 0 to 2;
	signal sprite_0_dist : integer range 0 to 2;
   signal sprite_1_dist : integer range 0 to 2;
   signal sprite_2_dist : integer range 0 to 2;
	
   signal sprite_wins : std_logic_vector(1 downto 0);

   -- top middle bottom routing for the priority mux.
	signal mid_sel, bot_sel : std_logic_vector(1 downto 0);
	
   signal top_red,  top_green,  top_blue  				: std_logic_vector(3 downto 0);
   signal top_active                            		: std_logic;
   signal middle_red,   middle_green,   middle_blue   : std_logic_vector(3 downto 0);
   signal middle_active                             	: std_logic;
	signal bottom_red,  bottom_green,  bottom_blue   	: std_logic_vector(3 downto 0);
   signal bottom_active                             	: std_logic;

begin

   -- A sprite is active if any of its colour channels is non-zero.
   sprite_0_active <= '1' when (sprite_0_red or sprite_0_green or sprite_0_blue) /= "0000" else '0';
   sprite_1_active <= '1' when (sprite_1_red or sprite_1_green or sprite_1_blue) /= "0000" else '0';
	sprite_2_active <= '1' when (sprite_2_red or sprite_2_green or sprite_2_blue) /= "0000" else '0';

   -- Lane-distance from the cat. Sprite wins ties so behaviour matches the
   -- old fixed-priority compositor when both sprites are equidistant.
   cat_lane_int  <= conv_integer(cat_lane);
   sprite_0_dist <= abs(SPRITE_0_LANE - cat_lane_int);
   sprite_1_dist <= abs(SPRITE_1_LANE - cat_lane_int);
	sprite_2_dist <= abs(SPRITE_2_LANE - cat_lane_int);
	
   sprite_wins <= "00" when (sprite_0_dist <= sprite_1_dist and sprite_0_dist <= sprite_2_dist) else
						"01" when (sprite_1_dist <= sprite_0_dist and sprite_1_dist <= sprite_2_dist) else
						"10" when (sprite_2_dist <= sprite_0_dist and sprite_2_dist <= sprite_1_dist) else
						"11";


   -- Route top middle bottom through a pair of muxes; output picks winner if active,
   -- loser otherwise, black if neither.
	mid_sel <= "01" when (sprite_wins="00" and sprite_1_dist >= sprite_2_dist) else
				  "10" when (sprite_wins="00" and sprite_2_dist >  sprite_1_dist) else
				  "00" when (sprite_wins="01" and sprite_0_dist >= sprite_2_dist) else
				  "10" when (sprite_wins="01" and sprite_2_dist >  sprite_0_dist) else
				  "00" when (sprite_wins="10" and sprite_0_dist >= sprite_1_dist) else
				  "01" when (sprite_wins="10" and sprite_1_dist >  sprite_0_dist) else
				  "11";
				  
	bot_sel <= "10" when (sprite_wins="00" and mid_sel="01") else
				  "01" when (sprite_wins="00" and mid_sel="10") else
				  "10" when (sprite_wins="01" and mid_sel="00") else
				  "00" when (sprite_wins="01" and mid_sel="10") else
				  "01" when (sprite_wins="10" and mid_sel="00") else
				  "00" when (sprite_wins="10" and mid_sel="01") else
				  "11";
	-- top
	top_red <= sprite_0_red when (sprite_wins = "00") else
				  sprite_1_red when (sprite_wins = "01") else
				  sprite_2_red when (sprite_wins = "10") else
				  "0000";
	top_green <= sprite_0_green when (sprite_wins = "00") else
				  sprite_1_green when (sprite_wins = "01") else
				  sprite_2_green when (sprite_wins = "10") else
				  "0000";
	top_blue <= sprite_0_blue when (sprite_wins = "00") else
				  sprite_1_blue when (sprite_wins = "01") else
				  sprite_2_blue when (sprite_wins = "10") else
				  "0000";
				  
	-- middle		  
	middle_red <= sprite_0_red when (mid_sel = "00") else
					  sprite_1_red when (mid_sel = "01") else
					  sprite_2_red when (mid_sel = "10") else
					  "0000";
					  
	middle_green <= sprite_0_green when (mid_sel = "00") else
						 sprite_1_green when (mid_sel = "01") else
						 sprite_2_green when (mid_sel = "10") else
						 "0000";
						 
	middle_blue <= sprite_0_blue when (mid_sel = "00") else
					   sprite_1_blue when (mid_sel = "01") else
					   sprite_2_blue when (mid_sel = "10") else
					   "0000";
	
	-- bottom		  
	bottom_red <= sprite_0_red when (bot_sel = "00") else
					  sprite_1_red when (bot_sel = "01") else
					  sprite_2_red when (bot_sel = "10") else
					  "0000";
					  
	bottom_green <= sprite_0_green when (bot_sel = "00") else
						 sprite_1_green when (bot_sel = "01") else
						 sprite_2_green when (bot_sel = "10") else
						 "0000";
						 
	bottom_blue <= sprite_0_blue when (bot_sel = "00") else
					   sprite_1_blue when (bot_sel = "01") else
					   sprite_2_blue when (bot_sel = "10") else
					   "0000";

	top_active <= '1' when (top_red or top_green or top_blue) /= "0000" else '0';
	middle_active <= '1' when (middle_red or middle_green or middle_blue) /= "0000" else '0';
	bottom_active <= '1' when (bottom_red or bottom_green or bottom_blue) /= "0000" else '0';

   red_out   <= top_red   		when top_active = '1' else
                middle_red    when middle_active  = '1' else
					 bottom_red    when bottom_active  = '1' else
                "0000";
   green_out   <= top_green   when top_active = '1' else
                middle_green  when middle_active  = '1' else
					 bottom_green  when bottom_active  = '1' else
                "0000";
	blue_out   <= top_blue   	when top_active = '1' else
                middle_blue   when middle_active  = '1' else
					 bottom_blue   when bottom_active  = '1' else
                "0000";

end architecture object_manager_behaviour;