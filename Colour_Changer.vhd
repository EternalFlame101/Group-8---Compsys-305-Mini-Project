library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Colour_Changer is
	port (clock, vertical_sync         				  					 		  : in std_logic;
         dip_switch_0, dip_switch_1, dip_switch_2, dip_switch_3 		  : in std_logic;
         push_button_0, push_button_1, push_button_2, push_button_3 	  : in std_logic;
         seven_segment_display_digit_0, seven_segment_display_digit_1,
			seven_segment_display_digit_2, seven_segment_display_digit_3,
			seven_segment_display_digit_5 										  : out std_logic_vector(6 downto 0);
         red_out, green_out, blue_out                           		  : out std_logic_vector(3 downto 0));
end entity Colour_Changer;

architecture colour_changer_behavior of Colour_Changer is
	signal red_register, green_register, blue_register : std_logic_vector(3 downto 0) := "0000";
   signal colour_in 												: std_logic_vector(3 downto 0);
   signal hex_digit 												: std_logic_vector(3 downto 0);
	signal vertical_sync_previous 							: std_logic := '1';
	signal channel_register 									: std_logic_vector(3 downto 0) := "1111";

   component BCD_To_Seven_Segment is
		port (bcd_digit     : in std_logic_vector(3 downto 0);
            seven_seg_out : out std_logic_vector(6 downto 0));
   end component BCD_To_Seven_Segment;
begin

   colour_in <= dip_switch_3 & dip_switch_2 & dip_switch_1 & dip_switch_0;

	process(clock)
	begin
		if rising_edge(clock) then
			vertical_sync_previous <= vertical_sync;
			if ((vertical_sync_previous = '0') and (vertical_sync = '1')) then
				if (push_button_3 = '0') then
					red_register     <= "0000";
					green_register   <= "0000";
					blue_register    <= "0000";
					channel_register <= "1111";
				else
					if (push_button_0 = '0') then
						red_register 	  <= colour_in;
						channel_register <= "0000";
					elsif (push_button_1 = '0') then
						green_register   <= colour_in;
						channel_register <= "0001";
					elsif (push_button_2 = '0') then
						blue_register 	  <= colour_in;
						channel_register <= "0010";
					end if;
				end if;
			end if;
		end if;
	end process;

	red_out   <= red_register;
	green_out <= green_register;
   blue_out  <= blue_register;
	hex_digit <= channel_register;

   HEX0 : BCD_To_Seven_Segment port map (bcd_digit => "000" & dip_switch_0,
													  seven_seg_out => seven_segment_display_digit_0);
					 
   HEX1 : BCD_To_Seven_Segment port map (bcd_digit => "000" & dip_switch_1,
													  seven_seg_out => seven_segment_display_digit_1);
					 
   HEX2 : BCD_To_Seven_Segment port map (bcd_digit => "000" & dip_switch_2,
													  seven_seg_out => seven_segment_display_digit_2);
					 
   HEX3 : BCD_To_Seven_Segment port map (bcd_digit => "000" & dip_switch_3,
													  seven_seg_out => seven_segment_display_digit_3);

   HEX5 : BCD_To_Seven_Segment port map (bcd_digit => hex_digit,
													  seven_seg_out => seven_segment_display_digit_5);
end architecture colour_changer_behavior;