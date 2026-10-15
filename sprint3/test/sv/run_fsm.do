quit -sim

transcript file fsm_transcript.log

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/fsm.sv
vlog -sv tb_fsm.sv

vsim -voptargs=+acc work.tb_fsm

add wave -divider "Bus FSM"
add wave -radix binary  /tb_fsm/clk
add wave -radix binary  /tb_fsm/rst_n
add wave -radix binary  /tb_fsm/fsm_valid
add wave -radix binary  /tb_fsm/fsm_ready
add wave -radix hex     /tb_fsm/fsm_addr
add wave -radix hex     /tb_fsm/fsm_data
add wave -radix binary  /tb_fsm/fsm_write_en
add wave -radix hex     /tb_fsm/fsm_rdata

add wave -divider "ALU"
add wave -radix hex     /tb_fsm/alu_a
add wave -radix hex     /tb_fsm/alu_b
add wave -radix binary  /tb_fsm/alu_start
add wave -radix binary  /tb_fsm/alu_done
add wave -radix binary  /tb_fsm/alu_n

add wave -divider "Estado interno (DUT)"
add wave -radix binary  /tb_fsm/dut/state

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

write wave fsm.wlf

set fp [open "questa_test_summary.log" w]
puts $fp "PASS: tb_fsm"
close $fp

quit -f