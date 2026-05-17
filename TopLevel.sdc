create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks
derive_clock_uncertainty

set_false_path -from [get_ports {RESET_N KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*] GPIO_0[*]}]
set_false_path -to   [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS}]