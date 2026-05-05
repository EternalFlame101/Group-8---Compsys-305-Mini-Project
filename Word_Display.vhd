library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Word_Display is
	generic (STR_LEN : positive := 16;
				SCALE : positive := 1);

	port (clock, v_sync : in std_logic;
			characters : in std_logic_vector((STR_LEN * 6 - 1) downto 0);
			pixel_row, pixel_column		  : in std_logic_vector(9 downto 0);
			-- x and y will be bottom left most pixel
			x_pos, y_pos					  : in std_logic_vector(9 downto 0);
			red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Word_Display;

architecture rtl of Word_Display is
	-- components
	component ROM_Display is
		generic(SCALE : positive := 1);
		
		port (clock, v_sync 			  		  : in std_logic;
				pixel_row, pixel_column		  : in std_logic_vector(9 downto 0);
				-- x and y will be bottom left most pixel
				x_pos, y_pos					  : in std_logic_vector(9 downto 0);
				-- what character it is from the 512
				character 			  			  : in std_logic_vector(5 downto 0);
				red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
	end component ROM_Display;
	
	-- custom type defines
	type colour_array_t is array (0 to STR_LEN - 1) of std_logic_vector(3 downto 0);
	
	-- signals
	signal array_red, array_green, array_blue : colour_array_t;
begin
	-- for generator loop
	generate_line : for i in 0 to STR_LEN - 1 generate
		disp_char : ROM_Display generic map (SCALE => SCALE)
										port map (clock => clock, v_sync => v_sync,
													 pixel_row => pixel_row,
													 pixel_column => pixel_column,
													 x_pos => x_pos + conv_std_logic_vector(i * 8 * SCALE, 10),
													 y_pos => y_pos,
													 character => characters((STR_LEN - i) * 6 - 1 downto (STR_LEN - i - 1) * 6),
													 red_out => array_red(i), 
													 green_out => array_green(i), 
													 blue_out => array_blue(i));
	end generate generate_line;
	
	-- combines all pixels to be displayed
	process(array_red, array_green, array_blue)
        variable r, g, b : std_logic_vector(3 downto 0);
    begin
        r := "0000";
        g := "0000";
        b := "0000";
        for i in 0 to STR_LEN - 1 loop
            r := r or array_red(i);
            g := g or array_green(i);
            b := b or array_blue(i);
        end loop;
        red_out   <= r;
        green_out <= g;
        blue_out  <= b;
    end process;
end architecture rtl;