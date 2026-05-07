library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity ROM_Display is
	-- multiplier
	generic (SCALE : positive := 1);

	port (clock 		  					  : in std_logic;
			character_selection 			  : in std_logic_vector(5 downto 0); -- what character it is from the 512 characters in the MIF file
			x_position, y_position		  : in std_logic_vector(9 downto 0); -- x and y will be bottom left most pixel
			pixel_column, pixel_row		  : in std_logic_vector(9 downto 0);
			red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity ROM_Display;

architecture rom_display_behaviour of ROM_Display is
	-- components
	component Character_ROM is
		port(clock						 : in  std_logic;
			  character_address		 : in  std_logic_vector (5 downto 0);
			  font_row, font_column	 : in  std_logic_vector (2 downto 0);
			  rom_multiplexer_output : out std_logic);
	end component Character_ROM;
	
	-- functions
	-- Number of bits to shift right to divide by SCALE
	-- 2 power shift is scale, scale is only in powers of 2
	-- Add this function before the signals
	function log_base_2(n : positive) return integer is
	begin
		if (n <= 1) then 
			return 0;
		elsif (n <= 2) then 
			return 1;
		elsif (n <= 4) then 
			return 2;
		else 
			return 3;
		end if;
	end function log_base_2;
	
	-- constants
	constant CHAR_SIZE 	: integer := 8 * SCALE;
	constant SCALE_SHIFT : integer := log_base_2(SCALE);
	
	-- signals
	signal display_on 			  : std_logic;
	signal character_on 			  : std_logic;
	signal character_on_register : std_logic;
	
	signal font_row    : std_logic_vector(2 downto 0);
	signal font_column : std_logic_vector(2 downto 0);
begin
	-- character
	Character_Process : process (clock, pixel_row, pixel_column)
	begin
		if rising_edge(clock) then
			character_on_register <= character_on;
		end if;
	end process Character_Process;
	
	-- getting fonts row and column
	font_row 	<= std_logic_vector(unsigned(pixel_row - y_position))(SCALE_SHIFT + 2 downto SCALE_SHIFT);
	font_column <= std_logic_vector(unsigned(pixel_column - x_position))(SCALE_SHIFT + 2 downto SCALE_SHIFT);
	
	-- making sure in bounding box of letter
	character_on <= '1' when ((pixel_row <= y_position + conv_std_logic_vector(CHAR_SIZE - 1,10)) 
						     and (pixel_row >= y_position)
						     and (pixel_column <= x_position + conv_std_logic_vector(CHAR_SIZE - 1,10)) 
						     and (pixel_column >= x_position)) 
						     else '0';
	
	-- getting character pixel state
	Get_Character_Pixel : Character_ROM 
		port map (clock	 			      => clock,
					 character_address      => character_selection, 
					 font_row 			      => font_row, 
					 font_column            => font_column,
					 rom_multiplexer_output => display_on);

	-- output white text
	red_out   <= "1111" when (character_on_register = '1' and display_on = '1') else "0000";
	green_out <= "1111" when (character_on_register = '1' and display_on = '1') else "0000";
	blue_out  <= "1111" when (character_on_register = '1' and display_on = '1') else "0000";
end architecture rom_display_behaviour;