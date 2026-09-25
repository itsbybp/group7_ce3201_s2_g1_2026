quit -sim

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

# Compilation of dependencies (Packages must be compiled first)
vlog -sv ../../../sprint1/src/alu_types_pkg.sv
vlog -sv ../../../sprint1/src/alu_param.sv
vlog -sv ../../../sprint1/src/seven_segment_adapter.sv
vlog -sv ../../../sprint1/src/n_bit_absolute_value.sv
vlog -sv ../../../sprint1/src/decoder_4x16.sv
vlog -sv ../../src/toggle.sv
vlog -sv ../../src/binary_to_bcd_converter.sv
vlog -sv ../../src/exec_fsm.sv
vlog -sv ../../src/input_fsm.sv
vlog -sv ../../src/key_sync.sv
vlog -sv ../../src/register_bank.sv
vlog -sv ../../src/display_logic.sv
vlog -sv ../../src/top_level.sv

# Compilation of Testbench
vlog -sv tb_top_level.sv

# Elaborate simulation
vsim -voptargs=+acc work.tb_top_level

# Waveform layout
add wave -divider "Control"
add wave -radix binary /tb_top_level/*

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

write wave top_level.wlf

quit -f