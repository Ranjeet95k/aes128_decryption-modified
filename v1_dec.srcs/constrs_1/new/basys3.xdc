## Basys 3 UART AES-128 decrypt constraints
## Board: Digilent Basys 3, Artix-7 xc7a35tcpg236-1

set_property PACKAGE_PIN W5 [get_ports clk_fpga]
set_property IOSTANDARD LVCMOS33 [get_ports clk_fpga]
create_clock -period 10.000 -name clk_fpga -waveform {0.000 5.000} [get_ports clk_fpga]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

create_generated_clock -name aes_clk -source [get_ports clk_fpga] -divide_by 8 [get_pins aes_clk_bufg/O]

# UART/control registers and AES registers are in separate clock domains.
# The wrapper only changes AES inputs before WAIT_AES and samples aes_out after
# a long fixed delay, so these CDC paths are intentionally not single-cycle paths.
set_clock_groups -asynchronous -group [get_clocks clk_fpga] -group [get_clocks aes_clk]

set_property PACKAGE_PIN U18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

set_property PACKAGE_PIN B18 [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]

set_property PACKAGE_PIN A18 [get_ports tx]
set_property IOSTANDARD LVCMOS33 [get_ports tx]

set_property PACKAGE_PIN U16 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]
set_property PACKAGE_PIN E19 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]
set_property PACKAGE_PIN U19 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[2]}]
set_property PACKAGE_PIN V19 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[3]}]
set_property PACKAGE_PIN W18 [get_ports {leds[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[4]}]
set_property PACKAGE_PIN U15 [get_ports {leds[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[5]}]
set_property PACKAGE_PIN U14 [get_ports {leds[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[6]}]
set_property PACKAGE_PIN V14 [get_ports {leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[7]}]

set_property PACKAGE_PIN L1 [get_ports done_led]
set_property IOSTANDARD LVCMOS33 [get_ports done_led]
