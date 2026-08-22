# Virtual clock used only as a timing reference.
# The design itself is purely combinational.
create_clock -name virtual_clk -period 20.000

# FPGA inputs: SW0-SW5
set_input_delay -clock virtual_clk -max 0.000 \
    [get_ports {data[0] data[1] data[2] data[3] p_even p_odd}]

set_input_delay -clock virtual_clk -min 0.000 \
    [get_ports {data[0] data[1] data[2] data[3] p_even p_odd}]

# FPGA outputs: LEDR0-LEDR2
set_output_delay -clock virtual_clk -max 0.000 \
    [get_ports {error_even error_odd valid}]

set_output_delay -clock virtual_clk -min 0.000 \
    [get_ports {error_even error_odd valid}]