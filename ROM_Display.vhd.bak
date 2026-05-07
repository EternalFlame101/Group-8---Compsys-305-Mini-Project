library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity ROM_Display is
	-- multiplier
	generic (SCALE : positive := 1);

	port (clock, v_sync 			  		  : in std_logic;
			pixel_row, pixel_column		  : in std_logic_vector(9 downto 0);
			-- x and y will be bottom left most pixel
			x_pos, y_pos					  : in std_logic_vector(9 downto 0);
			-- what character it is from the 512
			character 			  			  : in std_logic_vector(5 downto 0);
			red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity ROM_Display;

architecture rtl of ROM_Display is
	-- components
	component char_rom is
		port(character_address	:	in std_logic_vector (5 downto 0);
			  font_row, font_col	:	in std_logic_vector (2 downto 0);
			  clock					: 	in std_logic ;
			  rom_mux_output		:	out std_logic);
	end component char_rom;
	
	-- functions
	-- Number of bits to shift right to divide by SCALE
	-- 2 power shift is scale, scale is only in powers of 2
	-- Add this function before the signals
	function log2(n : positive) return integer is
	begin
		 if    n <= 1 then return 0;
		 elsif n <= 2 then return 1;
		 elsif n <= 4 then return 2;
		 else              return 3;
		 end if;
	end function log2;
	
	-- constants
	constant CHAR_SIZE : integer := 8 * SCALE;
	
	constant SCALE_SHIFT : integer := log2(SCALE);
	
	-- signals
	signal disp_on : std_logic;
	signal char_on : std_logic;
	signal char_on_reg : std_logic;
	
	signal font_row : std_logic_vector(2 downto 0);
	signal font_column : std_logic_vector(2 downto 0);

begin
	-- char
	char_process : process(clock, pixel_row, pixel_column)
	begin
		if rising_edge(clock) then
			char_on_reg <= char_on;
		end if;
	end process char_process;
	
	-- getting fonts row and column
	font_row <= std_logic_vector(unsigned(pixel_row - y_pos))(SCALE_SHIFT + 2 downto SCALE_SHIFT);
	font_column <= std_logic_vector(unsigned(pixel_column - x_pos))(SCALE_SHIFT + 2 downto SCALE_SHIFT);
	
	-- making sure in bounding box of letter
	char_on <= '1' when ((pixel_row <= y_pos + conv_std_logic_vector(CHAR_SIZE - 1,10)) 
						 and (pixel_row >= y_pos)
						 and (pixel_column <= x_pos + conv_std_logic_vector(CHAR_SIZE - 1,10)) 
						 and (pixel_column >= x_pos)) else '0';
	
	-- getting character pixel state
	get_char_pixel : char_rom port map (character_address => character, 
													font_row => font_row,
													font_col => font_column,
													clock => clock,
													rom_mux_output => disp_on);


	-- output white text
	red_out <= "1111" when (char_on_reg ='1' and disp_on = '1') else "0000";
	green_out <= "1111" when (char_on_reg = '1' and disp_on = '1') else "0000";
	blue_out <= "1111" when (char_on_reg = '1' and disp_on = '1') else "0000";
end architecture rtl;