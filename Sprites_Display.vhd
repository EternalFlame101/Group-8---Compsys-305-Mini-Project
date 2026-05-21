library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ------------------------------------------------------------------------------
-- Sprites_Display
--   Draws a rectangular sprite at a given (sprite_x, sprite_y) screen position,
--   loaded from a MIF file via Sprites_ROM. Each source pixel is replicated
--   SCALE x SCALE times on screen, giving a chunky pixel-art look.
--
--   On-screen footprint:
--     width  = SPRITE_WIDTH  * SCALE
--     height = SPRITE_HEIGHT * SCALE
--
--   The MIF must contain SPRITE_WIDTH * SPRITE_HEIGHT entries, stored in
--   row-major order (address = row * SPRITE_WIDTH + column).
--
--   Outputs are black outside the sprite footprint, so this block can be
--   layered with other graphics using the standard "non-zero means active"
--   convention used elsewhere in the project.
-- ------------------------------------------------------------------------------

entity Sprites_Display is
   generic (SPRITE_WIDTH  : positive := 64;
            SPRITE_HEIGHT : positive := 64;
            ADDR_BITS     : positive := 12;
            SCALE         : positive := 2;
            MIF_FILE      : string   := "knee.mif");
   port (clock                        : in  std_logic;
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
         sprite_x,  sprite_y          : in  std_logic_vector(9 downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Sprites_Display;

architecture sprites_display_behaviour of Sprites_Display is

   component Sprites_ROM is
      generic (DEPTH     : positive := 1024;
               ADDR_BITS : positive := 12;
               MIF_FILE  : string   := "knee.mif");
      port (clock   : in  std_logic;
            address : in  std_logic_vector(11 downto 0);
            red     : out std_logic_vector(3 downto 0);
            green   : out std_logic_vector(3 downto 0);
            blue    : out std_logic_vector(3 downto 0));
   end component Sprites_ROM;

   -- On-screen sprite footprint (independent X/Y so non-square sprites work).
   constant SPRITE_WIDTH_SCALED  : integer := SPRITE_WIDTH  * SCALE;
   constant SPRITE_HEIGHT_SCALED : integer := SPRITE_HEIGHT * SCALE;

   -- 11-bit unsigned versions of the inputs so boundary additions
   -- (sprite_x + width) can't overflow within the 640x480 visible area.
   signal pixel_column_unsigned : unsigned(10 downto 0);
   signal pixel_row_unsigned    : unsigned(10 downto 0);
   signal sprite_x_unsigned     : unsigned(10 downto 0);
   signal sprite_y_unsigned     : unsigned(10 downto 0);

   signal sprite_on              : std_logic;
   signal sprite_on_registered   : std_logic;  -- delayed one cycle to match ROM latency

   signal sprite_address : std_logic_vector(ADDR_BITS - 1 downto 0);

   signal rom_red   : std_logic_vector(3 downto 0);
   signal rom_green : std_logic_vector(3 downto 0);
   signal rom_blue  : std_logic_vector(3 downto 0);

begin

   pixel_column_unsigned <= resize(unsigned(pixel_column), 11);
   pixel_row_unsigned    <= resize(unsigned(pixel_row),    11);
   sprite_x_unsigned     <= resize(unsigned(sprite_x),     11);
   sprite_y_unsigned     <= resize(unsigned(sprite_y),     11);

   -- The current pixel is inside the sprite footprint when it's within
   -- the scaled width and height of the sprite's top-left corner.
   sprite_on <= '1' when (pixel_column_unsigned >= sprite_x_unsigned                                              and
                          pixel_column_unsigned <  sprite_x_unsigned + to_unsigned(SPRITE_WIDTH_SCALED,  11)      and
                          pixel_row_unsigned    >= sprite_y_unsigned                                              and
                          pixel_row_unsigned    <  sprite_y_unsigned + to_unsigned(SPRITE_HEIGHT_SCALED, 11))
                 else '0';

   -- Pipeline sprite_on by one cycle so it aligns with the ROM data, which
   -- arrives one cycle after the address is presented.
   Pipeline_Sprite_On : process(clock)
   begin
      if rising_edge(clock) then
         sprite_on_registered <= sprite_on;
      end if;
   end process Pipeline_Sprite_On;

   -- Compute the ROM address from the local pixel offset within the sprite
   -- footprint. Divide by SCALE to "pixelate" each source pixel into a
   -- SCALE x SCALE block on screen.
   Compute_Address : process(pixel_column_unsigned, pixel_row_unsigned,
                             sprite_x_unsigned,     sprite_y_unsigned,
                             sprite_on)
      variable local_column : integer;
      variable local_row    : integer;
      variable address_int  : integer;
   begin
      if sprite_on = '1' then
         local_column := (to_integer(pixel_column_unsigned) - to_integer(sprite_x_unsigned)) / SCALE;
         local_row    := (to_integer(pixel_row_unsigned)    - to_integer(sprite_y_unsigned)) / SCALE;
         address_int  := local_row * SPRITE_WIDTH + local_column;
      else
         address_int := 0;
      end if;
      sprite_address <= std_logic_vector(to_unsigned(address_int, ADDR_BITS));
   end process Compute_Address;

   -- ROM instance: MIF_FILE is propagated from the outer generic so callers
   -- can choose which image to load per instance.
   Sprite_Instance : Sprites_ROM
      generic map (DEPTH     => SPRITE_WIDTH * SPRITE_HEIGHT,
                   ADDR_BITS => ADDR_BITS,
                   MIF_FILE  => MIF_FILE)
      port map (clock   => clock,
                address => sprite_address,
                red     => rom_red,
                green   => rom_green,
                blue    => rom_blue);

   -- Gate outputs using the registered sprite_on so the on/off signal is
   -- aligned with the ROM data it's gating.
   red_out   <= rom_red   when sprite_on_registered = '1' else (others => '0');
   green_out <= rom_green when sprite_on_registered = '1' else (others => '0');
   blue_out  <= rom_blue  when sprite_on_registered = '1' else (others => '0');

end architecture sprites_display_behaviour;