library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Track_Generator is
	port (clock, v_sync 					  : in std_logic;
			pixel_row, pixel_column 	  : in std_logic_vector(9 downto 0);
			red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Track_Generator;

architecture rtl of Track_Generator is
	-- components
	component Perspective_ROM is
		port (clock						  : in  std_logic;
				track_row              : in  std_logic_vector (9 downto 0);
				perspective_output     : out std_logic_vector (9 downto 0));
	end component Perspective_ROM;

	-- signals
	signal track_on : std_logic;
	signal depth    : std_logic_vector(9 downto 0);
	signal spread   : std_logic_vector(9 downto 0);
begin
	Get_Spread : Perspective_ROM
		port map (clock 				  => clock,
					 track_row 			  => depth,
					 perspective_output => spread);

	depth <= (pixel_row - conv_std_logic_vector(320, 10))
				when (pixel_row >= conv_std_logic_vector(320, 10))
				else (others => '0');

	track_on <= '1' when (pixel_row    >= conv_std_logic_vector(320, 10) and
								 pixel_column >= conv_std_logic_vector(320, 10) - spread and
								 pixel_column <= conv_std_logic_vector(320, 10) + spread)
								 else '0';

	red_out <= "1111" when (track_on = '1') else "0000";
	green_out <= "1111" when (track_on = '1') else "0000";
	blue_out <= "1111" when (track_on = '1') else "0000";
end architecture rtl;