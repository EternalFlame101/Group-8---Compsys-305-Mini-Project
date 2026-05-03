library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Colour_Changer is
    port (clock, enable_pulse, vertical_sync         				  : in std_logic;
          dip_switch_0, dip_switch_1, dip_switch_2, dip_switch_3 : in std_logic;
          push_button_0, push_button_1, push_button_2 			  : in std_logic;
          seven_segment_display_digit_0              				  : out std_logic_vector(6 downto 0);
          red, green, blue                           				  : out std_logic_vector(3 downto 0));
end entity Colour_Changer;

architecture colour_changer_behavior of Colour_Changer is

    signal red_register, green_register, blue_register : std_logic_vector(3 downto 0) := "0000";
    signal colour_in : std_logic_vector(3 downto 0);
    signal hex_digit : std_logic_vector(3 downto 0);

    component BCD_To_Seven_Segment is
        port (bcd_digit    : in  std_logic_vector(3 downto 0);
              seven_seg_out : out std_logic_vector(6 downto 0));
    end component BCD_To_Seven_Segment;

begin

    colour_in <= dip_switch_3 & dip_switch_2 & dip_switch_1 & dip_switch_0;

    process(vertical_sync)
    begin
        if rising_edge(vertical_sync) then
            if push_button_0 = '0' then
                red_register <= colour_in;
            elsif push_button_1 = '0' then
                green_register <= colour_in;
            elsif push_button_2 = '0' then
                blue_register <= colour_in;
            end if;
        end if;
    end process;

    red   <= red_register;
    green <= green_register;
    blue  <= blue_register;

    hex_digit <= "0001" when push_button_1 = '0' else
                 "0010" when push_button_2 = '0' else
                 "0000";

    HEX0 : BCD_To_Seven_Segment port map (bcd_digit => hex_digit,
														seven_seg_out => seven_segment_display_digit_0);
end architecture colour_changer_behavior;