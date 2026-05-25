library IEEE;
use IEEE.std_logic_1164.all;

-- ------------------------------------------------------------------------------
-- Object_Manager
--    Combines three lane-based sprite outputs into a single layer. 
--    Priority is determined strictly by the cat's current lane position:
--      - Cat in Left (00):   Sprite 0 (Left) -> Sprite 1 (Mid)  -> Sprite 2 (Right)
--      - Cat in Middle (01): Sprite 1 (Mid)  -> Sprite 0 (Left) -> Sprite 2 (Right)
--      - Cat in Right (10):  Sprite 2 (Right)-> Sprite 1 (Mid)  -> Sprite 0 (Left)
-- ------------------------------------------------------------------------------
entity Object_Manager is
    generic (
        SPRITE_0_LANE : integer range 0 to 2 := 0; -- Left Lane
        SPRITE_1_LANE : integer range 0 to 2 := 1; -- Middle Lane
        SPRITE_2_LANE : integer range 0 to 2 := 2  -- Right Lane
    );
    port (
        sprite_0_red, sprite_0_green, sprite_0_blue : in  std_logic_vector(3 downto 0);
        sprite_1_red, sprite_1_green, sprite_1_blue : in  std_logic_vector(3 downto 0);
        sprite_2_red, sprite_2_green, sprite_2_blue : in  std_logic_vector(3 downto 0);
        cat_lane                                    : in  std_logic_vector(1 downto 0);
        red_out, green_out, blue_out                : out std_logic_vector(3 downto 0)
    );
end entity Object_Manager;

architecture object_manager_behaviour of Object_Manager is

    signal sprite_0_active : std_logic;
    signal sprite_1_active : std_logic;
    signal sprite_2_active : std_logic;

begin

    -- A sprite is active if any of its color channels are non-zero.
    sprite_0_active <= '1' when (sprite_0_red or sprite_0_green or sprite_0_blue) /= "0000" else '0';
    sprite_1_active <= '1' when (sprite_1_red or sprite_1_green or sprite_1_blue) /= "0000" else '0';
    sprite_2_active <= '1' when (sprite_2_red or sprite_2_green or sprite_2_blue) /= "0000" else '0';

    -- Flattened Priority Multiplexer
    process(cat_lane, sprite_0_active, sprite_1_active, sprite_2_active,
            sprite_0_red, sprite_0_green, sprite_0_blue,
            sprite_1_red, sprite_1_green, sprite_1_blue,
            sprite_2_red, sprite_2_green, sprite_2_blue)
    begin
        case cat_lane is
            
            -- ==================================================================
            -- CAT IN LEFT LANE (00)
            -- Priority Order: Sprite 0 (Left) -> Sprite 1 (Mid) -> Sprite 2 (Right)
            -- ==================================================================
            when "00" =>
                if sprite_0_active = '1' then
                    red_out   <= sprite_0_red;
                    green_out <= sprite_0_green;
                    blue_out  <= sprite_0_blue;
                elsif sprite_1_active = '1' then
                    red_out   <= sprite_1_red;
                    green_out <= sprite_1_green;
                    blue_out  <= sprite_1_blue;
                elsif sprite_2_active = '1' then
                    red_out   <= sprite_2_red;
                    green_out <= sprite_2_green;
                    blue_out  <= sprite_2_blue;
                else
                    red_out   <= "0000";
                    green_out <= "0000";
                    blue_out  <= "0000";
                end if;

            -- ==================================================================
            -- CAT IN MIDDLE LANE (01)
            -- Priority Order: Sprite 1 (Mid) -> Sprite 0 (Left) -> Sprite 2 (Right)
            -- ==================================================================
            when "01" =>
                if sprite_1_active = '1' then
                    red_out   <= sprite_1_red;
                    green_out <= sprite_1_green;
                    blue_out  <= sprite_1_blue;
                elsif sprite_0_active = '1' then
                    red_out   <= sprite_0_red;
                    green_out <= sprite_0_green;
                    blue_out  <= sprite_0_blue;
                elsif sprite_2_active = '1' then
                    red_out   <= sprite_2_red;
                    green_out <= sprite_2_green;
                    blue_out  <= sprite_2_blue;
                else
                    red_out   <= "0000";
                    green_out <= "0000";
                    blue_out  <= "0000";
                end if;

            -- ==================================================================
            -- CAT IN RIGHT LANE (10)
            -- Priority Order: Sprite 2 (Right) -> Sprite 1 (Mid) -> Sprite 0 (Left)
            -- ==================================================================
            when "10" =>
                if sprite_2_active = '1' then
                    red_out   <= sprite_2_red;
                    green_out <= sprite_2_green;
                    blue_out  <= sprite_2_blue;
                elsif sprite_1_active = '1' then
                    red_out   <= sprite_1_red;
                    green_out <= sprite_1_green;
                    blue_out  <= sprite_1_blue;
                elsif sprite_0_active = '1' then
                    red_out   <= sprite_0_red;
                    green_out <= sprite_0_green;
                    blue_out  <= sprite_0_blue;
                else
                    red_out   <= "0000";
                    green_out <= "0000";
                    blue_out  <= "0000";
                end if;

            -- Fallback / Unused state
            when others =>
                red_out   <= "0000";
                green_out <= "0000";
                blue_out  <= "0000";
        end case;
    end process;

end architecture object_manager_behaviour;