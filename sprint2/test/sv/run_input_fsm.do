quit -sim

transcript file input_fsm_transcript.log

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/input_fsm.sv
vlog -sv tb_input_fsm.sv

vsim -voptargs=+acc work.tb_input_fsm

add wave -divider "Entradas"
add wave -radix binary /tb_input_fsm/clk
add wave -radix binary /tb_input_fsm/reset
add wave -radix hexadecimal /tb_input_fsm/nibble_input
add wave -radix binary /tb_input_fsm/step

add wave -divider "Salidas"
add wave -radix hexadecimal /tb_input_fsm/out
add wave -radix binary /tb_input_fsm/current_state

add wave -divider "Estado interno (DUT)"
add wave -radix binary /tb_input_fsm/dut/serial_assembly_FSM_finished

add wave -divider "Resultado"

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run 100 ns

write wave input_fsm.wlf

quit -f
