quit -sim

transcript file counter_transcript.log

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/counter.sv
vlog -sv tb_counter.sv

vsim -wlf "run_counter.wlf" -voptargs=+acc work.tb_counter
log -r /*

add wave -divider "Clock & Reset"
add wave -radix binary /tb_counter/clk
add wave -radix binary /tb_counter/reset_n

add wave -divider "Counter Inputs"
add wave -radix binary /tb_counter/clear
add wave -radix binary /tb_counter/increase
add wave -radix decimal /tb_counter/timer_limit

add wave -divider "Output"
add wave -radix binary /tb_counter/timeout

add wave -divider "Internal DUT"
add wave -radix decimal /tb_counter/dut/count

add wave -divider "Test Counters"
add wave -radix decimal /tb_counter/checks
add wave -radix decimal /tb_counter/errors

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

set fp [open "counter_test_summary.log" w]
puts $fp "Simulation completed. Check counter_transcript.log for PASS/FAIL results."
close $fp

quit -f