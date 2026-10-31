create_clock -name sys_clk -period 10.000 \
    -waveform {0.000 5.000} [get_ports {clk}]

set_false_path -from [get_ports {raw_rst}] \
    -to [get_pins {reset_sync_/sync_ff1_reg/D}]

set_false_path -to [get_ports {debug_led[*]}]