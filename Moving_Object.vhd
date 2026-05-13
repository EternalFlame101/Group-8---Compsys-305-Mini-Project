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
				obj_sd_output	  : out std_logic_vector (9 downto 0);
				obj_y_output     : out std_logic_vector (9 downto 0);
				obj_h_output     : out std_logic_vector (9 downto 0);
				obj_w_output     : out std_logic_vector (9 downto 0);
				obj_wb_output	  : out std_logic_vector (9 downto 0);
				top_h_output     : out std_logic_vector (9 downto 0);
				top_taper     	  : out std_logic_vector (9 downto 0);
				side_taper       : out std_logic_vector (9 downto 0));
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
	signal side_red,
			 side_green,
			 side_blue		: std_logic_vector(3 downto 0);
	
	signal top_red,
			 top_green,
			 top_blue		: std_logic_vector(3 downto 0);
	
	
	signal obj_red,
			 obj_green,
			 obj_blue		: std_logic_vector(3 downto 0);
			 
	signal obj_height 	: std_logic_vector(9 downto 0);
	signal obj_width		: std_logic_vector(9 downto 0);
	
	signal side_local_row				: std_logic_vector(9 downto 0);
	signal inverted_local				: std_logic_vector(9 downto 0);
	signal actual_side_shift 			: std_logic_vector(9 downto 0);
	signal actual_side_shift_clamped : std_logic_vector(9 downto 0);
	signal side_product  				: std_logic_vector(19 downto 0);
	signal side_taper						: std_logic_vector(9 downto 0);
	
	signal top_height		 : std_logic_vector(9 downto 0);
	signal top_left		 : std_logic_vector(9 downto 0);
	signal top_right		 : std_logic_vector(9 downto 0);
	signal top_taper      : std_logic_vector(9 downto 0);
	signal top_local_row  : std_logic_vector(9 downto 0);
	signal top_inv_local  : std_logic_vector(9 downto 0);
	signal top_product    : std_logic_vector(19 downto 0);
	signal top_edge_shift : std_logic_vector(9 downto 0);
	
	signal top_max_extension : std_logic_vector(9 downto 0);
	signal top_max_product   : std_logic_vector(19 downto 0);
	
	-- tapering to less than front width
	signal obj_w_back     : std_logic_vector(9 downto 0);
	signal back_product   : std_logic_vector(19 downto 0);
	signal back_w_at_row  : std_logic_vector(9 downto 0);
	signal front_w_at_row : std_logic_vector(9 downto 0);
	signal w_diff         : std_logic_vector(9 downto 0);
	signal w_diff_product : std_logic_vector(19 downto 0);
	
	-- taper to less than front height
	signal obj_h_back     : std_logic_vector(9 downto 0);
	signal h_diff         : std_logic_vector(9 downto 0);
	signal side_col_offset: std_logic_vector(9 downto 0);
	signal side_top_boundary : std_logic_vector(9 downto 0);
	signal h_diff_product : std_logic_vector(19 downto 0);
	
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
					 obj_sd_output	=> obj_h_back,
					 obj_y_output 	=> obj_y,
					 obj_h_output 	=> obj_height,
					 obj_w_output 	=> obj_width,
					 obj_wb_output => obj_w_back,
					 top_h_output	=> top_height,
					 top_taper		=>	top_taper,
					 side_taper		=> side_taper);

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
	
	-- object back calculation
	w_diff <= (obj_width - obj_w_back)	when (obj_width >= obj_w_back)
													else (others => '0');
													
	w_diff_product <= w_diff * top_local_row;
	back_w_at_row  <= obj_width - w_diff_product(17 downto 8);
	
	-- side tapering less than front
	h_diff <= (obj_height - obj_h_back) 	when (obj_height >= obj_h_back)
														else (others => '0');
														
	side_col_offset <= ((obj_x - obj_width) - pixel_column) 	when (LANE = 2 and pixel_column <= obj_x - obj_width)
																				else (pixel_column - (obj_x + obj_width))
																				when (LANE = 0)
																				else (others => '0');
	h_diff_product    <= h_diff * side_col_offset;
	side_top_boundary <= h_diff_product(17 downto 8);
	
	-- object drawing side based on the front and top
	side_local_row <= (pixel_row - (obj_y - obj_height)) 	when (pixel_row >= (obj_y - obj_height))
																			else (others => '0');
	
	inverted_local <= obj_height - side_local_row;
	side_product     <= side_taper * inverted_local;
	actual_side_shift <= side_product(17 downto 8); 
	
	-- Hard clamp as safety net
	actual_side_shift_clamped <= (top_max_extension) when (actual_side_shift >= (top_max_extension)) else
										  (others => '0') 		when inverted_local = "0000000000" else
										  actual_side_shift;
	
	left_side_on <= '1' when ((pixel_row >= obj_y - obj_height - top_height)
								 and (pixel_row <= obj_y - side_top_boundary) 
								 and (pixel_column >= obj_x - obj_width - actual_side_shift_clamped) 
								 and (pixel_column <= obj_x - obj_width)) else '0';
								 
	right_side_on <= '1' when ((pixel_row >= obj_y - obj_height - top_height) 
								  and (pixel_row <= obj_y - side_top_boundary) 
								  and (pixel_column <= obj_x + obj_width + actual_side_shift_clamped) 
								  and (pixel_column >= obj_x + obj_width)) else '0';
	
	side_on <= 	left_side_on 	when (LANE = 2) else 
					right_side_on 	when (LANE = 0) else '0';
	
	side_red		<=	"0001" when (side_on = '1') else "0000";
	side_green	<= "0011" when (side_on = '1') else "0000";
	side_blue	<= "0001" when (side_on = '1') else "0000";

	-- object drawing top
	-- top_local_row = distance from top of top face downward
	top_local_row <= (pixel_row - (obj_y - obj_height - top_height)) 	when (pixel_row >= (obj_y - obj_height - top_height))
																							else (others => '0');

	-- inverted so shift is max at top, zero at bottom of top face
	top_inv_local <= (top_height - top_local_row) 	when (top_height >= top_local_row)
																	else (others => '0');

	top_product    <= top_taper * top_inv_local;
	top_edge_shift <= top_product(17 downto 8);
	
	top_max_product   <= top_taper * top_height;
	top_max_extension <= top_max_product(17 downto 8);
		
	top_left  <= (obj_x - back_w_at_row  - top_edge_shift)  			when LANE = 2 else
					 (obj_x - back_w_at_row )              				when LANE = 1 else
					 (obj_x - back_w_at_row  + (top_edge_shift(8 downto 0) & '0'));

	top_right <= (obj_x + back_w_at_row  - (top_edge_shift(8 downto 0) & '0'))  	when LANE = 2 else
					 (obj_x + back_w_at_row )              				when LANE = 1 else
					 (obj_x + back_w_at_row  + top_edge_shift);


	top_on <= '1' when ((pixel_row >= obj_y - obj_height - top_height) 
						 and (pixel_row <= obj_y - obj_height) 
						 and (pixel_column >= top_left) 
						 and (pixel_column <= top_right)) else '0';
	
	top_red		<=	"0001" when (top_on = '1') else "0000";
	top_green	<= "1111" when (top_on = '1') else "0000";
	top_blue		<= "0001" when (top_on = '1') else "0000";
	
	-- priority output for layering the top side and front together
	-- prior : front > top > side
	red_out 		<= obj_red when (obj_on = '1') else
						top_red when (top_on = '1') else
						side_red;
						
	green_out 	<= obj_green when (obj_on = '1') else
						top_green when (top_on = '1') else
						side_green;
						
	blue_out 	<= obj_blue when (obj_on = '1') else
						top_blue when (top_on = '1') else
						side_blue;
						
end architecture rtl;