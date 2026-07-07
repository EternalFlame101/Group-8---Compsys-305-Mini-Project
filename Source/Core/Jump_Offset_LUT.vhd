-- ------------------------------------------------------------------------------
-- Jump_Offset_LUT
--   Precomputed parabolic jump offsets indexed by jump_frame_count. Replaces a
--   runtime divide by JUMP_TOTAL_FRAMES**2 with a single table read, which was
--   the dominant critical path inside Player's jump math.
--
--   offset(f) = JUMP_PEAK_HEIGHT - (JUMP_PEAK_HEIGHT * d(f)**2)/(JUMP_TOTAL_FRAMES**2)
--   where d(f) = |JUMP_TOTAL_FRAMES - 2*f|, so offset peaks at f = frames/2.
--
--   Output is registered so the index-to-offset path has a clean clock-to-clock
--   hop; jump_frame_count only ticks once per vsync, so the 1-cycle latency is
--   invisible at the pixel pipeline level.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Jump_Offset_LUT is
   generic (JUMP_TOTAL_FRAMES : positive := 120;
            JUMP_PEAK_HEIGHT  : positive := 60);
   port (clock             : in  std_logic;
         jump_frame_count  : in  integer range 0 to JUMP_TOTAL_FRAMES;
         jump_pixel_offset : out integer range 0 to JUMP_PEAK_HEIGHT);
end entity Jump_Offset_LUT;

architecture lut_behaviour of Jump_Offset_LUT is

   type offset_table_t is array (0 to JUMP_TOTAL_FRAMES) of integer range 0 to JUMP_PEAK_HEIGHT;

   function build_offset_table return offset_table_t is
      variable table : offset_table_t;
      variable d     : integer;
   begin
      for f in 0 to JUMP_TOTAL_FRAMES loop
         d        := abs(JUMP_TOTAL_FRAMES - 2 * f);
         table(f) := JUMP_PEAK_HEIGHT
                     - (JUMP_PEAK_HEIGHT * d * d) / (JUMP_TOTAL_FRAMES * JUMP_TOTAL_FRAMES);
      end loop;
      return table;
   end function build_offset_table;

   constant OFFSET_TABLE : offset_table_t := build_offset_table;

   signal offset_reg : integer range 0 to JUMP_PEAK_HEIGHT := 0;

begin

   Lookup_Process : process(clock)
   begin
      if rising_edge(clock) then
         offset_reg <= OFFSET_TABLE(jump_frame_count);
      end if;
   end process Lookup_Process;

   jump_pixel_offset <= offset_reg;

end architecture lut_behaviour;
