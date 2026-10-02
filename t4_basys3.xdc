## Basys-3 pins + CDC constraints for the dual-clock FIFO demo
set_property -dict {PACKAGE_PIN W5  IOSTANDARD LVCMOS33} [get_ports clk100]
create_clock -period 10.000 -name sys_clk [get_ports clk100]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports btnC]

set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {led[7]}]
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {led[8]}]
set_property -dict {PACKAGE_PIN V3  IOSTANDARD LVCMOS33} [get_ports {led[9]}]
set_property -dict {PACKAGE_PIN W3  IOSTANDARD LVCMOS33} [get_ports {led[10]}]
set_property -dict {PACKAGE_PIN U3  IOSTANDARD LVCMOS33} [get_ports {led[11]}]
set_property -dict {PACKAGE_PIN P3  IOSTANDARD LVCMOS33} [get_ports {led[12]}]
set_property -dict {PACKAGE_PIN N3  IOSTANDARD LVCMOS33} [get_ports {led[13]}]
set_property -dict {PACKAGE_PIN P1  IOSTANDARD LVCMOS33} [get_ports {led[14]}]
set_property -dict {PACKAGE_PIN L1  IOSTANDARD LVCMOS33} [get_ports {led[15]}]
set_false_path -from [get_ports btnC]
set_false_path -to   [get_ports {led[*]}]

## ---------------- Clock-domain-crossing constraints ----------------
## wclk (100 MHz) and rclk (40 MHz) come from the same MMCM but are treated as asynchronous
set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_nets wclk]] \
    -group [get_clocks -of_objects [get_nets rclk]]

## Gray-coded pointers: only bound the data-path delay (<= one fast clock period) so that all bits
## arrive within a single destination cycle (keeps skew between bits small).
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME =~ *u_rptr_empty/rptr_reg[*]}] \
                             -to   [get_cells -hier -filter {NAME =~ *u_sync_r2w/wq1_rptr_reg[*]}] 10.000
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME =~ *u_wptr_full/wptr_reg[*]}] \
                             -to   [get_cells -hier -filter {NAME =~ *u_sync_w2r/rq1_wptr_reg[*]}] 10.000
