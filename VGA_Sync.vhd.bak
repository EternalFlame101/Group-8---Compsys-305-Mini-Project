library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity VGA_Sync is
   port (clock                        : in  std_logic;  -- 50MHz
			enable_pulse                 : in  std_logic;  -- 25MHz enable
			red, green, blue             : in  std_logic_vector(3 downto 0);
			red_out, green_out, blue_out : out std_logic_vector(3 downto 0);
			horizontal_sync_out          : out std_logic;
			vertical_sync_out            : out std_logic;
			video_on                     : out std_logic;
			pixel_row, pixel_column      : out std_logic_vector(9 downto 0));
end entity VGA_Sync;

architecture vga_sync_behaviour of VGA_Sync is
   signal horizontal_count  : std_logic_vector(9 downto 0) := (others => '0');
   signal vertical_count    : std_logic_vector(9 downto 0) := (others => '0');
   signal horizontal_active : std_logic;
   signal vertical_active   : std_logic;
   signal video_on_signal   : std_logic;
begin
   -- Generate Horizontal and Vertical Timing Signals for Video Signal

   -- horizontal_count counts pixels (640 + extra time for sync signals)
   --
   -- horizontal_sync  ------------------------------------__________--------
   -- horizontal_count    0                640             659       755    799

   -- vertical_count counts rows of pixels (480 + extra time for sync signals)
   --
   -- vertical_sync  -----------------------------------------------_______------------
   -- vertical_count  0                                      480    493-494          524
   process(clock)
	begin
	if rising_edge(clock) then
		if enable_pulse = '1' then
			if horizontal_count = 799 then
				horizontal_count <= (others => '0');
				if vertical_count = 524 then
					vertical_count <= (others => '0');
				else
					vertical_count <= vertical_count + 1;
				end if;
			else
				horizontal_count <= horizontal_count + 1;
			end if;
		end if;
	end if;
	end process;

   -- Everything below is combinational — no clock involved

   -- Sync pulses
   horizontal_sync_out <= '0' when (horizontal_count >= 659 and horizontal_count <= 755) else '1';
   vertical_sync_out   <= '0' when (vertical_count >= 493 and vertical_count <= 494) else '1';

   -- Video on
   horizontal_active <= '1' when horizontal_count < 640 else '0';
   vertical_active   <= '1' when vertical_count < 480 else '0';
   video_on_signal   <= horizontal_active and vertical_active;
   video_on 		   <= video_on_signal;

   -- Pixel coordinates
   pixel_column <= horizontal_count when horizontal_active = '1' else (others => '0');
   pixel_row    <= vertical_count when vertical_active = '1' else (others => '0');

   -- RGB gated by video_on
   red_out   <= red   when video_on_signal = '1' else (others => '0');
   green_out <= green when video_on_signal = '1' else (others => '0');
   blue_out  <= blue  when video_on_signal = '1' else (others => '0');
end architecture vga_sync_behaviour;