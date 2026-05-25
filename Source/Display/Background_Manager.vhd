library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- ------------------------------------------------------------------------------
-- Background_Manager
--   Combines the background layer (sky/ground) and the track layer into a
--   single background-plane output. The track takes priority where it is
--   active; everywhere else, the background shows through.
--
--   In the current Background_Generator implementation, the background
--   layer is non-zero across the entire frame, so the priority mux is
--   effectively just "track when active, background otherwise".
-- ------------------------------------------------------------------------------
entity Background_Manager is
   port (clock : in std_logic;
			background_red, background_green, background_blue : in  std_logic_vector(3 downto 0);
         track_red,      track_green,      track_blue      : in  std_logic_vector(3 downto 0);
         red_out,        green_out,        blue_out        : out std_logic_vector(3 downto 0));
end entity Background_Manager;

architecture background_manager_behaviour of Background_Manager is

   -- Active signals: true if that layer has anything to draw on this pixel.
   signal background_active : std_logic;
   signal track_active      : std_logic;
	
	signal red_reg 	: std_logic_vector(3 downto 0);
	signal green_reg 	: std_logic_vector(3 downto 0);
	signal blue_reg	: std_logic_vector(3 downto 0);

begin

   -- A layer is active if any of its colour channels is non-zero.
   background_active <= '1' when (background_red or background_green or background_blue) /= "0000" else '0';
   track_active      <= '1' when (track_red      or track_green      or track_blue)      /= "0000" else '0';

   -- Priority mux: track on top, background underneath.
   red_reg   <= track_red   when (track_active = '1') else background_red;
   green_reg <= track_green when (track_active = '1') else background_green;
   blue_reg  <= track_blue  when (track_active = '1') else background_blue;
	
	register_output : process(clock)
	begin
		if rising_edge(clock) then
			red_out <= red_reg;
			green_out <= green_reg;
			blue_out <= blue_reg;
		end if;
	end process register_output;

end architecture background_manager_behaviour;