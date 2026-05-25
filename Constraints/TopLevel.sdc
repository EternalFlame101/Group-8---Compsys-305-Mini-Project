# =============================================================================
# Primary input clock: DE0-CV 50 MHz oscillator
# =============================================================================
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# =============================================================================
# Derived clocks (PLL outputs: 25 MHz pixel_clock, VCO, etc.)
# =============================================================================
derive_pll_clocks
derive_clock_uncertainty

# =============================================================================
# Mouse PS/2 filter clock
#   Mouse.vhd uses an 8-tap glitch filter to debounce the external PS/2 mouse
#   clock signal, producing mouse_clock_filter. The Send_UART and Receive_UART
#   processes inside Mouse use mouse_clock_filter'event as their clock — so
#   from TimeQuest's perspective mouse_clock_filter IS a clock, but it is
#   derived from logic, not from a PLL or input pin.
#
#   The actual rate is whatever the PS/2 mouse decides (~10-16.7 kHz per the
#   PS/2 protocol spec). We declare it here with a conservative ~12 kHz period
#   so it shows as Constrained, and then false-path it against every other
#   clock because the mouse is fundamentally asynchronous to anything else.
# =============================================================================
create_clock -name mouse_filter_clk -period 83333.000 \
    [get_registers {Mouse:Mouse_Controller|mouse_clock_filter}]

set_false_path -from [get_clocks mouse_filter_clk] -to [get_clocks {CLOCK_50}]
set_false_path -from [get_clocks {CLOCK_50}] -to [get_clocks mouse_filter_clk]
set_false_path -from [get_clocks mouse_filter_clk] \
    -to [get_clocks {Pixel_Clock_PLL|video_pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path -from [get_clocks {Pixel_Clock_PLL|video_pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -to [get_clocks mouse_filter_clk]

# =============================================================================
# Asynchronous inputs (buttons, switches, reset)
#   These come from human fingers and bouncy mechanical contacts; they have
#   no fixed timing relationship to any clock. We tell TimeQuest not to
#   bother trying to time them.
# =============================================================================
set_false_path -from [get_ports {RESET_N KEY[*] SW[*]}] -to [all_registers]

# =============================================================================
# Bidirectional PS/2 lines (mouse + keyboard)
#   PS/2 protocol clocks are driven by the external device, not by us.
#   Treat both directions as async.
# =============================================================================
set_false_path -from [get_ports {PS2_DAT PS2_CLK PS2_DAT2 PS2_CLK2}] -to [all_registers]
set_false_path -from [all_registers] -to [get_ports {PS2_DAT PS2_CLK PS2_DAT2 PS2_CLK2}]

# =============================================================================
# Asynchronous / non-timing-critical outputs
#   VGA: monitors are tolerant of large skew (sync pulses set the frame).
#   LEDR/HEX: human-visible, no timing requirement.
#   GPIO_0: scope probes and DAC; not registered destinations.
# =============================================================================
set_false_path -from [all_registers] -to [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*] GPIO_0[*]}]
set_false_path -from [all_registers] -to [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS}]

# =============================================================================
# SD card SPI interface (currently slow; not timing-critical at <1 MHz)
# =============================================================================
set_false_path -from [all_registers] -to [get_ports {SD_CLK SD_CMD SD_DATA[*]}]

# SD_DATA[0] is bidirectional and shares a physical pin with GPIO_0[3]
# on the DE0-CV (intentional, for scope probing). Both logical ports
# need every-direction false_path because of the shared-pin routing.
set_false_path -from [get_ports {SD_DATA[0] GPIO_0[3]}]
set_false_path -to   [get_ports {SD_DATA[0] GPIO_0[3]}]