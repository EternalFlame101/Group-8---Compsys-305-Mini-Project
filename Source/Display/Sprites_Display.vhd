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
            MIF_FILE      : string   := "Assets/Memory_Initialization_Files/Placeholder.mif");
   port (clock                        : in  std_logic;
         pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
         sprite_x,  sprite_y          : in  std_logic_vector(9 downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Sprites_Display;

architecture sprites_display_behaviour of Sprites_Display is

   component Sprites_ROM is
      generic (DEPTH     : positive := 1024;
               ADDR_BITS : positive := 12;
               MIF_FILE  : string   := "Assets/Memory_Initialization_Files/Placeholder.mif");
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
   signal sprite_on_pipe_1       : std_logic;  -- aligned with local_*_reg (1 cycle)
   signal sprite_on_pipe_2       : std_logic;  -- aligned with ROM data    (2 cycles)

   -- Address-compute pipeline: the chain
   --   pixel_row/col -> subtract -> divide-by-SCALE -> multiply-by-WIDTH ->
   --   add -> ROM address pin
   -- was the worst pixel_clock path in the design (~15 ns, capping Fmax at
   -- ~64 MHz) because there are 20+ sprite instances all reading pixel_row
   -- and feeding M9K blocks scattered across the chip. Splitting it in half
   -- here gets both halves down to ~7 ns, ample headroom for HD pixel rates.
   signal local_column_combinational : unsigned(10 downto 0);
   signal local_row_combinational    : unsigned(10 downto 0);
   signal local_column_reg           : unsigned(10 downto 0);
   signal local_row_reg              : unsigned(10 downto 0);

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

   -- Stage 1 combinational: subtract the sprite's top-left corner from the
   -- current pixel position. 11-bit unsigned subtract wraps when the pixel is
   -- outside the sprite (sprite_on='0'), but the output gate masks that case
   -- so the garbage address doesn't matter.
   local_column_combinational <= pixel_column_unsigned - sprite_x_unsigned;
   local_row_combinational    <= pixel_row_unsigned    - sprite_y_unsigned;

   -- Stage 1 register + sprite_on pipeline.
   -- sprite_on_pipe_1 stays aligned with local_*_reg so Compute_Address can
   -- still mux the address to 0 outside the sprite footprint (safer than
   -- letting a wrapped value go to the ROM). sprite_on_pipe_2 trails by one
   -- more cycle to align with the ROM read latency.
   Pipeline_Address_Stage : process(clock)
   begin
      if rising_edge(clock) then
         local_column_reg <= local_column_combinational;
         local_row_reg    <= local_row_combinational;
         sprite_on_pipe_1 <= sprite_on;
         sprite_on_pipe_2 <= sprite_on_pipe_1;
      end if;
   end process Pipeline_Address_Stage;

   -- Stage 2 combinational: divide by SCALE (pixelation) and combine into a
   -- linear ROM address. Quartus collapses /SCALE and *SPRITE_WIDTH to bit
   -- selects whenever SCALE and SPRITE_WIDTH are powers of two (they are
   -- here: 2 and 64).
   Compute_Address : process(local_row_reg, local_column_reg, sprite_on_pipe_1)
      variable address_int : integer;
   begin
      if sprite_on_pipe_1 = '1' then
         address_int := (to_integer(local_row_reg)    / SCALE) * SPRITE_WIDTH +
                        (to_integer(local_column_reg) / SCALE);
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

   -- Gate outputs using the 2-stage-pipelined sprite_on so the on/off signal
   -- is aligned with the ROM data it's gating (1 cycle for the address-compute
   -- register + 1 cycle for the ROM's internal read register).
   red_out   <= rom_red   when sprite_on_pipe_2 = '1' else (others => '0');
   green_out <= rom_green when sprite_on_pipe_2 = '1' else (others => '0');
   blue_out  <= rom_blue  when sprite_on_pipe_2 = '1' else (others => '0');

end architecture sprites_display_behaviour;