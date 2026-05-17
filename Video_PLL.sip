set_global_assignment -entity "Video_PLL" -library "lib_Video_PLL" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "Video_PLL" -library "lib_Video_PLL" -name IP_TOOL_VERSION "18.1"
set_global_assignment -entity "Video_PLL" -library "lib_Video_PLL" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_Video_PLL" -name SPD_FILE [file join $::quartus(sip_path) "Video_PLL.spd"]

set_global_assignment -library "lib_Video_PLL" -name MISC_FILE [file join $::quartus(sip_path) "Video_PLL_sim/Video_PLL.vho"]
