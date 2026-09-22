quit -sim

transcript file exec_fsm_transcript.log

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/exec_fsm.sv
vlog -sv tb_exec_fsm.sv

vsim -voptargs=+acc work.tb_exec_fsm

add wave -divider "Entradas"
add wave -radix binary /tb_exec_fsm/clk
add wave -radix binary /tb_exec_fsm/reset
add wave -radix binary /tb_exec_fsm/start_execute
add wave -radix binary /tb_exec_fsm/step
add wave -radix binary /tb_exec_fsm/stepping_mode

add wave -divider "Salidas"
add wave -radix binary /tb_exec_fsm/write_enable
add wave -radix binary /tb_exec_fsm/current_state

add wave -divider "Estado interno (DUT)"
add wave -radix binary /tb_exec_fsm/dut/current_state_delayed

add wave -divider "Resultado"

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run 100 ns

write wave exec_fsm.wlf

quit -f
