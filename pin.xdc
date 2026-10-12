################################################################################
# Clock Constraints
################################################################################
#  (Assuming ~16.368 MHz reference)
create_clock -period 61.095 -name ref_clk_0 [get_ports ref_clk_0]

################################################################################
# Input Pin Assignments
################################################################################
# Reference Clock Input
set_property PACKAGE_PIN H16 [get_ports ref_clk_0]
set_property IOSTANDARD LVCMOS18 [get_ports ref_clk_0]

# External Reset Pin (Active High)
set_property PACKAGE_PIN w19 [get_ports reset_0]
set_property IOSTANDARD LVCMOS33 [get_ports reset_0]

################################################################################
# Output Pin Assignments
################################################################################
# Physical Feedback Interface Clock Output (AD936x TX Path)
set_property PACKAGE_PIN K17 [get_ports fb_clk_out_0]
set_property IOSTANDARD LVCMOS18 [get_ports fb_clk_out_0]

# Parallel Phase Error Outputs (To AD936x TX Data Bus Pins)
set_property PACKAGE_PIN G17 [get_ports {phase_error_out_0[0]}]
set_property PACKAGE_PIN H18 [get_ports {phase_error_out_0[1]}]
set_property PACKAGE_PIN G20 [get_ports {phase_error_out_0[2]}]
set_property PACKAGE_PIN J18 [get_ports {phase_error_out_0[3]}]
set_property PACKAGE_PIN D18 [get_ports {phase_error_out_0[4]}]
set_property PACKAGE_PIN J19 [get_ports {phase_error_out_0[5]}]
set_property PACKAGE_PIN K16 [get_ports {phase_error_out_0[6]}]
set_property PACKAGE_PIN K18 [get_ports {phase_error_out_0[7]}]
set_property PACKAGE_PIN L20 [get_ports {phase_error_out_0[8]}]
set_property PACKAGE_PIN L19 [get_ports {phase_error_out_0[9]}]
set_property PACKAGE_PIN E19 [get_ports {phase_error_out_0[10]}]
set_property PACKAGE_PIN L16 [get_ports {phase_error_out_0[11]}]

set_property IOSTANDARD LVCMOS18 [get_ports {phase_error_out_0[*]}]