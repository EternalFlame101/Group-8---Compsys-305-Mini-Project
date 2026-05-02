library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity VGA_Sync is
	port (clock, enable_pulse 				: in std_logic;
			red, green, blue	  				: in std_logic;
			red_out, green_out, blue_out  : out	std_logic;
			horizontal_sync_out				: out	std_logic;
			vertical_sync_out					: out	std_logic;
			pixel_row, pixel_column       : out std_logic_vector(9 downto 0));
end entity VGA_Sync;

architecture vga_sync_behaviour of VGA_Sync is
	signal horizontal_sync, vertical_sync : std_logic;
	signal video_on, video_on_horizontal, video_on_vertical : std_logic;
	signal horizontal_count, vertical_count : std_logic_vector(9 downto 0);
begin
	-- video_on is high only when RGB data is displayed
	video_on <= video_on_horizontal and video_on_vertical;
	process(clock)
	begin
		if (rising_edge(clock)) then
			if (enable_pulse = '1') then
				-- Generate Horizontal and Vertical Timing Signals for Video Signal
				
				-- horizontal_count counts pixels (640 + extra time for sync signals)
				-- 
				-- horizontal_sync  ------------------------------------__________--------
				-- horizontal_count    0                640             659       755    799
				--
				if (horizontal_count = 799) then
					horizontal_count <= "0000000000";
				else
					horizontal_count <= horizontal_count + 1;
				end if;

				-- Generate Horizontal Sync Signal using H_count
				if ((horizontal_count <= 755) and (horizontal_count >= 659)) then
					horizontal_sync <= '0';
				else
					horizontal_sync <= '1';
				end if;

				-- vertical_count counts rows of pixels (480 + extra time for sync signals)
				--  
				-- vertical_sync  -----------------------------------------------_______------------
				-- vertical_count  0                                      480    493-494          524
				--
				if ((vertical_count >= 524) and (horizontal_count >= 699)) then
					vertical_count <= "0000000000";
				elsif (horizontal_count = 699) then
					vertical_count <= vertical_count + 1;
				end if;

				-- Generate Vertical Sync Signal using vertical_count
				if ((vertical_count <= 494) and (vertical_count >= 493)) then
					vertical_sync <= '0';
				else
					vertical_sync <= '1';
				end if;

				-- Generate Video on Screen Signals for Pixel Data
				if (horizontal_count <= 639) then
					video_on_horizontal <= '1';
					pixel_column <= horizontal_count;
				else
					video_on_horizontal <= '0';
				end if;

				if (vertical_count <= 479) then
					video_on_vertical <= '1';
					pixel_row <= vertical_count;
				else
					video_on_vertical <= '0';
				end if;

				-- Put all video signals through DFFs to elminate any delays that cause a blurry image
				red_out <= red and video_on;
				green_out <= green and video_on;
				blue_out <= blue and video_on;
				horizontal_sync_out <= horizontal_sync;
				vertical_sync_out <= vertical_sync;
			end if;
		end if;
	end process;
end architecture vga_sync_behaviour;