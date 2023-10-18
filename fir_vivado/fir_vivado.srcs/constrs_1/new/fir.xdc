#create_clock -period 17.000 -waveform {0.000 8.500} [get_ports -filter { NAME =~  "*clk*" && DIRECTION == "IN" }]
create_clock -period 17.000 -name axis_clk -waveform {0.000 8.500} [get_ports axis_clk]

set _xlnx_shared_i0 [get_ports -filter { NAME =~  "*" && DIRECTION == "OUT" }]
set_output_delay -clock [get_clocks *] 4.000 $_xlnx_shared_i0
set _xlnx_shared_i1 [get_ports -filter { NAME =~  "*" && DIRECTION == "IN" }]
set_input_delay -clock [get_clocks *] 4.000 $_xlnx_shared_i1





