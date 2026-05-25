library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Cursor is
	generic (SIZE_CONST : positive := 8);

		port (pixel_column, pixel_row	: in  std_logic_vector(9 downto 0);
				cursor_x, cursor_y 		: in  std_logic_vector(9 downto 0);
				red, green, blue 			: out std_logic_vector(3 downto 0));
end entity Cursor;

architecture cursor_behaviour of Cursor is
	signal cursor_on	: std_logic;
	signal size 		: std_logic_vector(9 downto 0);
begin
	size <= conv_std_logic_vector(SIZE_CONST, 10);

	cursor_on <= '1' when (('0' & cursor_x <= pixel_column + size)
						and ('0' & pixel_column <= cursor_x + size) -- x_position - size <= pixel_column <= x_position + size
						and ('0' & cursor_y <= pixel_row + size)
						and ('0' & pixel_row <= cursor_y + size)) -- y_position - size <= pixel_row <= y_position + size
						else '0';

	red 	<= "1111" when (cursor_on = '1') else "0000";
	green <= "1100" when (cursor_on = '1') else "0000";
	blue 	<= "1111" when (cursor_on = '1') else "0000";
end architecture cursor_behaviour;