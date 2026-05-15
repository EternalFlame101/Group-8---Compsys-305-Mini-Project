library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Sprites_Display is
    generic (
        SPRITE_WIDTH  : positive := 64;
        SPRITE_HEIGHT : positive := 64;
        ADDR_BITS     : positive := 12;
		  SCALE 			 : positive := 4
    );
    port (
        clock                        : in  std_logic;
        pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
        sprite_x,  sprite_y          : in  std_logic_vector(9 downto 0);
        red_out, green_out, blue_out : out std_logic_vector(3 downto 0)
    );
end entity Sprites_Display;

architecture beh of Sprites_Display is

    component Sprites_ROM is
        generic (
            DEPTH     : positive := 4096;
            ADDR_BITS : positive := 12;
            MIF_FILE  : string   := "skull.mif"
        );
        port (
            clock   : in  std_logic;
            address : in  std_logic_vector(ADDR_BITS - 1 downto 0);
            red     : out std_logic_vector(3 downto 0);
            green   : out std_logic_vector(3 downto 0);
            blue    : out std_logic_vector(3 downto 0)
        );
    end component Sprites_ROM;
	 
	constant SPRITE_SIZE 	: integer := SPRITE_WIDTH * SCALE;

	-- Avoid overflow on boundary addition
	signal col_u : unsigned(10 downto 0);
	signal row_u : unsigned(10 downto 0);
	signal sx_u  : unsigned(10 downto 0);
	signal sy_u  : unsigned(10 downto 0);

	signal sprite_on     : std_logic;
	signal sprite_on_reg : std_logic;  -- registered one cycle to match ROM latency

	signal sprite_address : std_logic_vector(ADDR_BITS - 1 downto 0);

	signal rom_red   : std_logic_vector(3 downto 0);
	signal rom_green : std_logic_vector(3 downto 0);
	signal rom_blue  : std_logic_vector(3 downto 0);

begin

	col_u <= resize(unsigned(pixel_column), 11);
	row_u <= resize(unsigned(pixel_row),    11);
	sx_u  <= resize(unsigned(sprite_x),     11);
	sy_u  <= resize(unsigned(sprite_y),     11);

	sprite_on <= '1' when
						(col_u >= sx_u) and
						(col_u <  sx_u + to_unsigned(SPRITE_SIZE,  11)) and
						(row_u >= sy_u) and
						(row_u <  sy_u + to_unsigned(SPRITE_SIZE, 11))
				  else '0';

	process (clock)
	begin
		if rising_edge(clock) then
			sprite_on_reg <= sprite_on;
		end if;
	end process;

	-- Compute ROM address from local pixel offset (combinatorial)
	process (col_u, row_u, sx_u, sy_u, sprite_on)
		variable local_x  : integer;
		variable local_y  : integer;
		variable addr_int : integer;
	begin
		if sprite_on = '1' then
		  local_x  := (to_integer(col_u) - to_integer(sx_u)) / SCALE;
		  local_y  := (to_integer(row_u) - to_integer(sy_u)) / SCALE;
		  addr_int := local_y * SPRITE_WIDTH + local_x;
		else
			addr_int := 0;
		end if;
		sprite_address <= std_logic_vector(to_unsigned(addr_int, ADDR_BITS));
	end process;

    -- ROM instance (no semicolon between generic map and port map)
    Sprite_Instance : Sprites_ROM
        generic map (
            DEPTH     => 4096,
            ADDR_BITS => 12,
            MIF_FILE  => "knee.mif"
        )
        port map (
            clock   => clock,
            address => sprite_address,
            red     => rom_red,
            green   => rom_green,
            blue    => rom_blue
        );

    -- Gate outputs using REGISTERED sprite_on so it aligns with ROM data
    red_out   <= rom_red   when sprite_on_reg = '1' else (others => '0');
    green_out <= rom_green when sprite_on_reg = '1' else (others => '0');
    blue_out  <= rom_blue  when sprite_on_reg = '1' else (others => '0');

end architecture beh;