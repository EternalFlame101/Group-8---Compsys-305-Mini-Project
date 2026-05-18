library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Player is
   generic (SCREEN_WIDTH  : positive := 640;
            SCREEN_HEIGHT : positive := 480;
            SPRITE_SIZE   : positive := 32;   -- base sprite is 32x32
            SPRITE_SCALE  : positive := 4);   -- 32x32 * 4 = 128x128 on screen
   port (clock                                 : in  std_logic;
         pixel_row, pixel_column               : in  std_logic_vector(9 downto 0);
         player_red, player_green, player_blue : out std_logic_vector(3 downto 0);
         player_lane                           : out std_logic_vector(1 downto 0);
         player_state                          : out std_logic);
end entity Player;

architecture player_behaviour of Player is

   component Sprites_Display is
      generic (SPRITE_WIDTH  : positive := 32;
               SPRITE_HEIGHT : positive := 32;
               ADDR_BITS     : positive := 12;
               SCALE         : positive := 4;
               MIF_FILE      : string   := "mif/jasper.mif");
      port (clock                        : in  std_logic;
            pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
            sprite_x,  sprite_y          : in  std_logic_vector(9 downto 0);
            red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
   end component Sprites_Display;

   -- Sprite size on screen after scaling (128 px at SCALE = 4).
   constant SCALED_SPRITE_SIZE : positive := SPRITE_SIZE * SPRITE_SCALE;

   -- Lane 1 (middle) is dead-centre horizontally.
   constant LANE_1_CENTRE_X    : positive := SCREEN_WIDTH / 2;             -- 320

   -- Internal lane and animation state.
   -- For now both are hardcoded: middle lane, grounded/running (player_state = '0').
   -- These will be driven by mouse-input lane switching and jump/roll logic next.
   signal current_lane  : std_logic_vector(1 downto 0) := "01";
   signal current_state : std_logic                    := '0';

   -- Top-left position of the sprite on screen.
   signal sprite_x_position : std_logic_vector(9 downto 0);
   signal sprite_y_position : std_logic_vector(9 downto 0);

begin

   -- Sprite x-position depends on current lane. Only the middle lane is wired up
   -- for now; lane 0 (left) and lane 2 (right) will be added when lane switching
   -- is implemented (their X-coords need to match the track perspective layout):
   --
   --   current_lane = "00" -> lane 0 (left)   sprite_x = TBD
   --   current_lane = "01" -> lane 1 (middle) sprite_x = 320 - 64 = 256
   --   current_lane = "10" -> lane 2 (right)  sprite_x = TBD
   sprite_x_position <= conv_std_logic_vector(LANE_1_CENTRE_X - (SCALED_SPRITE_SIZE / 2), 10);

   -- Bottom-aligned: 480 - 128 = 352 -> sprite occupies rows 352..479.
   sprite_y_position <= conv_std_logic_vector(SCREEN_HEIGHT - SCALED_SPRITE_SIZE, 10);

   Player_Sprite : Sprites_Display
      generic map (SPRITE_WIDTH  => SPRITE_SIZE,
                   SPRITE_HEIGHT => SPRITE_SIZE,
                   ADDR_BITS     => 12,
                   SCALE         => SPRITE_SCALE,
                   MIF_FILE      => "mif/neutral.mif")
      port map (clock        => clock,
                pixel_row    => pixel_row,
                pixel_column => pixel_column,
                sprite_x     => sprite_x_position,
                sprite_y     => sprite_y_position,
                red_out      => player_red,
                green_out    => player_green,
                blue_out     => player_blue);

   player_lane  <= current_lane;
   player_state <= current_state;

end architecture player_behaviour;