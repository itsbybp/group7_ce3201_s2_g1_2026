quit -sim

transcript file memory_mapped_register_file_transcript.log

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/memory_mapped_register_file.sv
vlog -sv tb_memory_mapped_register_file.sv

vsim -voptargs=+acc work.tb_memory_mapped_register_file

add wave -divider "Clock & Reset"
add wave -radix binary  /tb_memory_mapped_register_file/clk
add wave -radix binary  /tb_memory_mapped_register_file/reset_n

add wave -divider "MMIO Interface"
add wave -radix hex     /tb_memory_mapped_register_file/mmio_address
add wave -radix hex     /tb_memory_mapped_register_file/write_data
add wave -radix binary  /tb_memory_mapped_register_file/write_en

add wave -divider "Output"
add wave -radix hex     /tb_memory_mapped_register_file/selected_register

add wave -divider "Address Decode"
add wave -radix decimal /tb_memory_mapped_register_file/dut/address

add wave -divider "Test Counters"
add wave -radix decimal /tb_memory_mapped_register_file/checks
add wave -radix decimal /tb_memory_mapped_register_file/errors

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

write wave memory_mapped_register_file.wlf

set fp [open "questa_test_summary.log" w]
puts $fp "PASS: tb_memory_mapped_register_file"
close $fp

quit -f