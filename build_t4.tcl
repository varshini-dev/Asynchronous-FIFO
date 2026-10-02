# vivado -mode batch -source build_t4.tcl      (run from this folder)
set here [file dirname [file normalize [info script]]]
create_project t4_fifo $here/vivado_t4 -part xc7a35tcpg236-1 -force
add_files [glob $here/../rtl/*.v]
add_files -fileset sim_1 $here/../tb/tb_async_fifo.v
add_files -fileset constrs_1 $here/../xdc/t4_basys3.xdc
set_property top fifo_board_top [current_fileset]
set_property top tb_async_fifo [get_filesets sim_1]
update_compile_order -fileset sources_1

launch_simulation ; run all ; close_sim

launch_runs synth_1 -jobs 4 ; wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4 ; wait_on_run impl_1
open_run impl_1

# ---------------- timing / CDC analysis ----------------
report_clock_networks       -file $here/t4_clock_networks.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file $here/t4_timing_summary.rpt
report_timing -delay_type max -max_paths 5 -sort_by slack -file $here/t4_setup_paths.rpt
report_timing -delay_type min -max_paths 5 -sort_by slack -file $here/t4_hold_paths.rpt
report_clock_interaction -delay_type min_max -file $here/t4_clock_interaction.rpt
report_cdc                  -details -file $here/t4_cdc.rpt
check_timing                -file $here/t4_check_timing.rpt
report_methodology          -file $here/t4_methodology.rpt
report_utilization          -file $here/t4_utilization.rpt
