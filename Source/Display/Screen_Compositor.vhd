-- ------------------------------------------------------------------------------
-- Screen_Compositor
--   Selects between the three top-level visual pipelines and produces the
--   final pixel that feeds VGA_Sync. Pure combinational logic; the latching
--   that prevents mid-game mode changes happens inside Start_Screen.
--
--   Selection rules:
--     start_screen_active = '1'                 -> compose start screen:
--                                                    1. Mouse cursor on top
--                                                    2. Start screen text below
--                                                    3. Start screen sprite as
--                                                       the background image
--     start_screen_active = '0', latched_mode = '1'
--                                                -> normal pipeline (single
--                                                   player)
--     start_screen_active = '0', latched_mode = '0'
--                                                -> training pipeline
--                                                   (training mode demo;
--                                                   default before any
--                                                   selection has been made)
--
--   In game modes (start_screen_active = '0'), the HUD overlays on top of
--   whichever pipeline is active wherever it produces a non-zero pixel.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Screen_Compositor is
   port (clock               : in  std_logic;
         start_screen_active : in  std_logic;
         paused              : in  std_logic;
         end_screen_active   : in  std_logic;
         latched_mode        : in  std_logic;

         start_screen_red, start_screen_green, start_screen_blue : in std_logic_vector(3 downto 0);
         pause_text_red, pause_text_green, pause_text_blue : in std_logic_vector(3 downto 0);
         start_screen_sprite_red, start_screen_sprite_green, start_screen_sprite_blue : in std_logic_vector(3 downto 0);
         mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue : in std_logic_vector(3 downto 0);
         HUD_red, HUD_green, HUD_blue : in std_logic_vector(3 downto 0);
         training_red, training_green, training_blue : in std_logic_vector(3 downto 0);
         game_red, game_green, game_blue : in std_logic_vector(3 downto 0);
         end_screen_red,     end_screen_green,     end_screen_blue  : in std_logic_vector(3 downto 0);
         red_out, green_out, blue_out : out std_logic_vector(3 downto 0));
end entity Screen_Compositor;

architecture screen_compositor_behaviour of Screen_Compositor is

   -- Input pipeline registers. All display-layer RGB inputs plus the control
   -- signals are captured together every clock. This breaks the ~24 ns path
   --   pixel_row -> (Start_Screen / Track_Generator / etc.) -> Final_Mux -> Output_Reg
   -- into two stages each ~10-12 ns, clearing the 80 MHz target.
   -- Control and data are registered in the same process so the compositor
   -- always sees a consistent snapshot.
   signal start_screen_active_r         : std_logic;
   signal paused_r                      : std_logic;
   signal end_screen_active_r           : std_logic;
   signal start_screen_red_r,  start_screen_green_r,  start_screen_blue_r  : std_logic_vector(3 downto 0);
   signal pause_text_red_r,    pause_text_green_r,    pause_text_blue_r    : std_logic_vector(3 downto 0);
   signal start_screen_sprite_red_r,
          start_screen_sprite_green_r,
          start_screen_sprite_blue_r                                        : std_logic_vector(3 downto 0);
   signal mouse_cursor_red_r,  mouse_cursor_green_r,  mouse_cursor_blue_r  : std_logic_vector(3 downto 0);
   signal HUD_red_r,            HUD_green_r,            HUD_blue_r          : std_logic_vector(3 downto 0);
   signal game_red_r,           game_green_r,           game_blue_r         : std_logic_vector(3 downto 0);
   signal end_screen_red_r,    end_screen_green_r,    end_screen_blue_r    : std_logic_vector(3 downto 0);

   signal mouse_cursor_active        : std_logic;
   signal start_screen_text_active   : std_logic;
   signal start_screen_sprite_active : std_logic;
   signal HUD_active                 : std_logic;
   signal end_screen_text_active     : std_logic;
   signal pause_text_active          : std_logic;

   signal red_next, green_next, blue_next : std_logic_vector(3 downto 0);

begin

   -- Input pipeline stage: register all inputs simultaneously so both data
   -- and control signals see exactly 1 clock of added latency.
   Input_Pipe : process(clock)
   begin
      if rising_edge(clock) then
         start_screen_active_r       <= start_screen_active;
         paused_r                    <= paused;
         end_screen_active_r         <= end_screen_active;
         start_screen_red_r          <= start_screen_red;
         start_screen_green_r        <= start_screen_green;
         start_screen_blue_r         <= start_screen_blue;
         pause_text_red_r            <= pause_text_red;
         pause_text_green_r          <= pause_text_green;
         pause_text_blue_r           <= pause_text_blue;
         start_screen_sprite_red_r   <= start_screen_sprite_red;
         start_screen_sprite_green_r <= start_screen_sprite_green;
         start_screen_sprite_blue_r  <= start_screen_sprite_blue;
         mouse_cursor_red_r          <= mouse_cursor_red;
         mouse_cursor_green_r        <= mouse_cursor_green;
         mouse_cursor_blue_r         <= mouse_cursor_blue;
         HUD_red_r                   <= HUD_red;
         HUD_green_r                 <= HUD_green;
         HUD_blue_r                  <= HUD_blue;
         game_red_r                  <= game_red;
         game_green_r                <= game_green;
         game_blue_r                 <= game_blue;
         end_screen_red_r            <= end_screen_red;
         end_screen_green_r          <= end_screen_green;
         end_screen_blue_r           <= end_screen_blue;
      end if;
   end process Input_Pipe;

   mouse_cursor_active        <= '1' when (mouse_cursor_red_r    or mouse_cursor_green_r    or mouse_cursor_blue_r)    /= "0000" else '0';
   start_screen_text_active   <= '1' when (start_screen_red_r    or start_screen_green_r    or start_screen_blue_r)    /= "0000" else '0';
   start_screen_sprite_active <= '1' when (start_screen_sprite_red_r or start_screen_sprite_green_r or start_screen_sprite_blue_r) /= "0000" else '0';
   HUD_active                 <= '1' when (HUD_red_r             or HUD_green_r             or HUD_blue_r)             /= "0000" else '0';
   end_screen_text_active     <= '1' when (end_screen_red_r    or end_screen_green_r    or end_screen_blue_r)    /= "0000" else '0';
   pause_text_active          <= '1' when (pause_text_red_r or pause_text_green_r or pause_text_blue_r) /= "000" else '0';

   Final_Mux : process(start_screen_active_r, end_screen_active_r, paused_r,
                       mouse_cursor_active, start_screen_text_active, start_screen_sprite_active,
                       HUD_active, end_screen_text_active, pause_text_active,
                       start_screen_red_r,        start_screen_green_r,        start_screen_blue_r,
                       start_screen_sprite_red_r, start_screen_sprite_green_r, start_screen_sprite_blue_r,
                       pause_text_red_r,          pause_text_green_r,         pause_text_blue_r,
                       mouse_cursor_red_r,        mouse_cursor_green_r,        mouse_cursor_blue_r,
                       HUD_red_r,                 HUD_green_r,                 HUD_blue_r,
                       game_red_r,                game_green_r,                game_blue_r,
                       end_screen_red_r,          end_screen_green_r,          end_screen_blue_r)
   begin
      if start_screen_active_r = '1' then
         if mouse_cursor_active = '1' then
            red_next   <= mouse_cursor_red_r;
            green_next <= mouse_cursor_green_r;
            blue_next  <= mouse_cursor_blue_r;
         elsif start_screen_text_active = '1' then
            red_next   <= start_screen_red_r;
            green_next <= start_screen_green_r;
            blue_next  <= start_screen_blue_r;
         elsif start_screen_sprite_active = '1' then
            red_next   <= start_screen_sprite_red_r;
            green_next <= start_screen_sprite_green_r;
            blue_next  <= start_screen_sprite_blue_r;
         else
            red_next   <= (others => '0');
            green_next <= (others => '0');
            blue_next  <= (others => '0');
         end if;

      elsif end_screen_active_r = '1' then
         if mouse_cursor_active = '1' then
            red_next   <= mouse_cursor_red_r;
            green_next <= mouse_cursor_green_r;
            blue_next  <= mouse_cursor_blue_r;
         elsif end_screen_text_active = '1' then
            red_next   <= end_screen_red_r;
            green_next <= end_screen_green_r;
            blue_next  <= end_screen_blue_r;
         else
            red_next   <= (others => '0');
            green_next <= (others => '0');
            blue_next  <= (others => '0');
         end if;
      elsif (paused_r = '1') then
         if pause_text_active = '1' then
            red_next <= pause_text_red_r;
            green_next <= pause_text_green_r;
            blue_next <= pause_text_blue_r;
         elsif HUD_active = '1' then
            red_next   <= HUD_red_r;
            green_next <= HUD_green_r;
            blue_next  <= HUD_blue_r;
         else
            red_next   <= game_red_r;
            green_next <= game_green_r;
            blue_next  <= game_blue_r;
         end if;
      else
         if HUD_active = '1' then
            red_next   <= HUD_red_r;
            green_next <= HUD_green_r;
            blue_next  <= HUD_blue_r;
         else
            red_next   <= game_red_r;
            green_next <= game_green_r;
            blue_next  <= game_blue_r;
         end if;
      end if;
   end process Final_Mux;

   Output_Reg : process(clock)
   begin
      if rising_edge(clock) then
         red_out   <= red_next;
         green_out <= green_next;
         blue_out  <= blue_next;
      end if;
   end process;

end architecture screen_compositor_behaviour;