#************************************************************
# THIS IS A WIZARD-GENERATED FILE.                           
#
# Version 10.0 Build 262 08/18/2010 Service Pack 1 SJ Web Edition
#
#************************************************************

# Copyright (C) 1991-2010 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.



# Clock constraints

create_clock -name "clk_7Mhz" -period 142.875ns [get_ports {clk_7Mhz}] -waveform {0.000ns 71.437ns}


# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
#derive_clock_uncertainty
# Not supported for family Cyclone II

# tsu/th constraints

# tco constraints

# tpd constraints

set_max_delay 0ns -from [get_ports {clk_7Mhz}] -to [get_ports {clk_7Mhz}]


