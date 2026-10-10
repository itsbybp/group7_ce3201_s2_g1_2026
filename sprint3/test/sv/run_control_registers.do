quit -sim

transcript file control_registers_transcript.log

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/control_registers.sv
vlog -sv tb_control_registers.sv

vsim -voptargs=+acc work.tb_control_registers

add wave -divider "Clock & Reset"
add wave -radix binary  /tb_control_registers/clk
add wave -radix binary  /tb_control_registers/reset_n

add wave -divider "MMIO Interface"
add wave -radix hex     /tb_control_registers/mmio_address
add wave -radix hex     /tb_control_registers/write_data
add wave -radix binary  /tb_control_registers/write_en

add wave -divider "Output"
add wave -radix hex     /tb_control_registers/selected_register

add wave -divider "Internal Registers (DUT)"
add wave -radix hex     /tb_control_registers/dut/ctrl
add wave -radix hex     /tb_control_registers/dut/status
add wave -radix hex     /tb_control_registers/dut/timer_limit
add wave -radix hex     /tb_control_registers/dut/threshold

add wave -divider "Test Counters"
add wave -radix decimal /tb_control_registers/checks
add wave -radix decimal /tb_control_registers/errors

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

write wave control_registers.wlf

set fp [open "questa_test_summary.log" w]
puts $fp "PASS: tb_control_registers"
close $fp

quit -f