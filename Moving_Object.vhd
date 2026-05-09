library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Moving_Object is
	generic (REAL_HEIGHT : positive := 8;
				REAL_WIDTH : positive := 8;
				LANE : integer range 0 to 2 := 1);
	port (enable, clock, v_sync 		  	: in std_logic;
			pixel_column, pixel_row		  	: in  std_logic_vector(9 downto 0);
			speed								  	: in std_logic_vector(3 downto 0);
			red_out, green_out, blue_out 	: out std_logic_vector(3 downto 0));
end entity Moving_Object;

architecture rtl of Moving_Object is
	-- components
	component Object_ROM is
		port (clock				  : in  std_logic;
				track_row        : in  std_logic_vector (9 downto 0);
				obj_y_output     : out std_logic_vector (9 downto 0);
				obj_h_output     : out std_logic_vector (9 downto 0);
				obj_w_output     : out std_logic_vector (9 downto 0));
	end component Object_ROM;
	
	component Perspective_ROM is
		port (clock						  : in  std_logic;
				track_row              : in  std_logic_vector (9 downto 0);
				perspective_output     : out std_logic_vector (9 downto 0));
	end component Perspective_ROM;

	-- signals
	signal obj_on			: std_logic;
	signal side_on			: std_logic;
	signal left_side_on	: std_logic;
	signal right_side_on	: std_logic;
	signal top_on			: std_logic;
	signal v_sync_prev 	: std_logic; 
	
	-- object attributes
	signal obj_distance  : std_logic_vector(9 downto 0) 
								:= (others => '1');
	
	signal side_width		: std_logic_vector(9 downto 0);
	signal side_scaler	: std_logic_vector(9 downto 0);
	signal side_red,
			 side_green,
			 side_blue		: std_logic_vector(3 downto 0);
	
	signal top_height		: std_logic_vector(9 downto 0);
	signal top_left		: std_logic_vector(9 downto 0);
	signal top_right		: std_logic_vector(9 downto 0);
	signal top_red,
			 top_green,
			 top_blue		: std_logic_vector(3 downto 0);
	
	signal obj_height 	: std_logic_vector(9 downto 0);
	signal obj_width		: std_logic_vector(9 downto 0);
	signal obj_red,
			 obj_green,
			 obj_blue		: std_logic_vector(3 downto 0);

	signal side_local_row				: std_logic_vector(9 downto 0);
	signal inverted_local				: std_logic_vector(9 downto 0);
	signal side_shift    				: std_logic_vector(9 downto 0);
	signal actual_side_shift 			: std_logic_vector(9 downto 0);
	signal actual_side_shift_clamped : std_logic_vector(9 downto 0);
	signal side_product  				: std_logic_vector(19 downto 0);
	signal side_product2 				: std_logic_vector(19 downto 0);
	
	signal top_local_row : std_logic_vector(9 downto 0);
	signal top_shift     : std_logic_vector(9 downto 0);
	signal top_product   : std_logic_vector(19 downto 0);
	
	signal obj_x			: std_logic_vector(9 downto 0);
	signal obj_y			: std_logic_vector(9 downto 0);
	
	-- track attributes
	signal spread			: std_logic_vector(9 downto 0);
	
	-- spread max is 310, multiplying by 11 then bit shift 4 is approx 2/3
	-- making sure enough bits in product to not overflow
	signal product			: std_logic_vector(13 downto 0);
	signal shift			: std_logic_vector(9 downto 0);
begin
	-- port maps
	Object_internal_control : Object_ROM
		port map (clock 			=> clock,
					 track_row 		=> obj_distance,
					 obj_y_output 	=> obj_y,
					 obj_h_output 	=> obj_height,
					 obj_w_output 	=> obj_width);

	Track_information : Perspective_ROM
		port map (clock					=> clock,
					 track_row 				=> obj_distance,
					 perspective_output 	=> spread);
					 
	-- given track finding x position
	product <= conv_std_logic_vector(11, 4) * spread;
	shift <= product(13 downto 4);
	
	obj_x <= (conv_std_logic_vector(320, 10) + shift(9 downto 0)) 	when (LANE = 2) else
				(conv_std_logic_vector(320, 10)) 							when (LANE = 1) else
				(conv_std_logic_vector(320, 10) - shift(9 downto 0));

	-- movement of the object is dictated by itself internally
	-- affected by game state though, e.g. external speed input
	Moving : process(clock)
	begin
		if rising_edge(clock) then
			v_sync_prev <= v_sync;
			if ((v_sync = '0') and (v_sync_prev = '1')) then
				if (enable = '1') then
					if (obj_distance = "0000000000") then
						null;
					else
						obj_distance <= obj_distance + ("000000" & speed);
					end if;
				end if;
			end if;
		end if;
	end process Moving;
	
	-- object drawing front
	obj_on <= '1' when ((pixel_row >= obj_y - obj_height)
						and (pixel_row <= obj_y) 
						and (pixel_column >= obj_x - obj_width) 
						and (pixel_column <= obj_x + obj_width)) else '0';
						
	obj_red		<=	"0001" when (obj_on = '1') else "0000";
	obj_green	<= "0111" when (obj_on = '1') else "0000";
	obj_blue		<= "0001" when (obj_on = '1') else "0000";
						
	-- object drawing side based on the front and top
	side_width <= ("0" & obj_width(9 downto 1)) when (unsigned(obj_distance) >= 140) else
					  ("0"  & obj_width(9 downto 2) & "0") when (unsigned(obj_distance) >= 100) else
					  ("00" & obj_width(9 downto 2));
	side_local_row <= pixel_row - (obj_y - obj_height);
	
	side_product <= shift * (side_local_row + side_local_row(9 downto 0));
	
	inverted_local <= obj_height - side_local_row;
	side_product2  <= shift * inverted_local;
	actual_side_shift <= side_product2(14 downto 5);
	
	-- Hard clamp as safety net
	actual_side_shift_clamped <= (side_width) 	when (actual_side_shift >= side_width) else
										  (others => '0') when inverted_local = "0000000000" else
										  actual_side_shift;
	
	left_side_on <= '1' when ((pixel_row >= obj_y - obj_height - top_height) 
								 and (pixel_row <= obj_y) 
								 and (pixel_column >= obj_x - obj_width - actual_side_shift_clamped) 
								 and (pixel_column <= obj_x - obj_width)) else '0';
								 
	right_side_on <= '1' when ((pixel_row >= obj_y - obj_height - top_height) 
								  and (pixel_row <= obj_y) 
								  and (pixel_column <= obj_x + obj_width + actual_side_shift_clamped) 
								  and (pixel_column >= obj_x + obj_width)) else '0';
	
	side_on <= 	left_side_on 	when (LANE = 2) else 
					right_side_on 	when (LANE = 0) else '0';
	
	side_red		<=	"0001" when (side_on = '1') else "0000";
	side_green	<= "0011" when (side_on = '1') else "0000";
	side_blue	<= "0001" when (side_on = '1') else "0000";

	-- object drawing top
	top_local_row <= (obj_y - obj_height) - pixel_row;
	
	top_product <= shift * (top_local_row + (top_local_row(9 downto 0)));

	top_shift <= top_product(15 downto 6);
	
	top_height <= "0000" & obj_height(9 downto 4);
	
	top_left  <= (obj_x - obj_width - top_shift)  when LANE = 2 else
					 (obj_x - obj_width)              when LANE = 1 else
					 (obj_x - obj_width + top_shift);

	top_right <= (obj_x + obj_width - top_shift)  when LANE = 2 else
					 (obj_x + obj_width)              when LANE = 1 else
					 (obj_x + obj_width + top_shift);


	top_on <= '1' when ((pixel_row >= obj_y - obj_height - top_height) 
						 and (pixel_row <= obj_y - obj_height) 
						 and (pixel_column >= top_left) 
						 and (pixel_column <= top_right)) else '0';
	
	top_red		<=	"0001" when (top_on = '1') else "0000";
	top_green	<= "1111" when (top_on = '1') else "0000";
	top_blue		<= "0001" when (top_on = '1') else "0000";
	
	-- priority output for layering the top side and front together
	red_out 		<= top_red when (top_on = '1') else
						obj_red when (obj_on = '1') else
						side_red;
						
	green_out 	<= top_green when (top_on = '1') else
						obj_green when (obj_on = '1') else
						side_green;
						
	blue_out 	<= top_blue when (top_on = '1') else
						obj_blue when (obj_on = '1') else
						side_blue;
						
end architecture rtl;