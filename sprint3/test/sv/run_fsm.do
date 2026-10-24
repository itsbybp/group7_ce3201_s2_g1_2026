quit -sim

transcript file fsm_transcript.log

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/fsm.sv
vlog -sv tb_fsm.sv

vsim -wlf "run_fsm.wlf" -voptargs=+acc work.tb_fsm
log -r /*

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
add wave -radix unsigned /tb_fsm/fsm_state_num
add wave -radix binary   /tb_fsm/fsm_busy
add wave -radix binary   /tb_fsm/clear_on_start
add wave -radix unsigned /tb_fsm/pixel_count
add wave -radix hex      /tb_fsm/last_pixel
add wave -radix hex      /tb_fsm/last_result

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

set fp [open "fsm_test_summary.log" w]
puts $fp "Simulation completed. Check fsm_transcript.log for PASS/FAIL results."
close $fp

quit -f
