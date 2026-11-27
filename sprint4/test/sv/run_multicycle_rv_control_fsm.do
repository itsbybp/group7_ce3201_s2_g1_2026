quit -sim

transcript file multicycle_rv_control_fsm_transcript.log

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/multicycle_rv_opcodes_pkg.sv
vlog -sv ../../src/multicycle_rv_control_fsm.sv
vlog -sv tb_multicycle_rv_control_fsm.sv

vsim -voptargs=+acc -suppress 10908 work.tb_multicycle_rv_control_fsm

add wave -divider "Reloj y reset"
add wave -radix binary  /tb_multicycle_rv_control_fsm/clk
add wave -radix binary  /tb_multicycle_rv_control_fsm/rst_n
add wave -radix binary  /tb_multicycle_rv_control_fsm/soft_reset_n
add wave -radix binary  /tb_multicycle_rv_control_fsm/enable

add wave -divider "Opcode"
add wave -radix hex     /tb_multicycle_rv_control_fsm/op

add wave -divider "Bus de instrucciones (ready/valid)"
add wave -radix binary  /tb_multicycle_rv_control_fsm/ready_in_instr_memory
add wave -radix binary  /tb_multicycle_rv_control_fsm/valid_out_instr_memory
add wave -radix binary  /tb_multicycle_rv_control_fsm/handshake_instr_memory

add wave -divider "Bus de datos (ready/valid)"
add wave -radix binary  /tb_multicycle_rv_control_fsm/ready_in_data_memory
add wave -radix binary  /tb_multicycle_rv_control_fsm/valid_out_data_memory
add wave -radix binary  /tb_multicycle_rv_control_fsm/handshake_data_memory

add wave -divider "Estado de la FSM"
add wave                /tb_multicycle_rv_control_fsm/dut/current_state

configure wave -namecolwidth 260
configure wave -valuecolwidth 120
configure wave -timelineunits ns

run -all

write wave multicycle_rv_control_fsm.wlf

quit -f
