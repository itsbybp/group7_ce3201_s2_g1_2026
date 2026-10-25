# Copias de simulacion (no se toca nada en src/):
# 1) vjtag.sv a partir del stub, con el nombre que espera top_level
# 2) top_level_sim.sv sin "default_nettype none": Questa 2020.1 no acepta
#    puertos "input logic" (sin wire) bajo esa directiva (vlog-2892)
proc strip_none {src dst} {
    set data [read [open $src r]]
    set data [string map {"`default_nettype none" ""} $data]
    set f [open $dst w]
    puts $f $data
    close $f
}

quit -sim

transcript file top_level_transcript.log

strip_none ../../src/vjtag_sim_stub.sv vjtag.sv
set data [read [open vjtag.sv r]]
set data [string map {"module vjtag_sim_stub" "module vjtag"} $data]
set f [open vjtag.sv w]
puts $f $data
close $f
strip_none ../../src/top_level.sv top_level_sim.sv

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv -timescale 1ns/1ps -work work \
  ../../../sprint1/src/alu_types_pkg.sv \
  ../../../sprint1/src/alu_param.sv \
  ../../../sprint1/src/decoder_4x16.sv \
  ../../../sprint1/src/seven_segment_adapter.sv \
  ../../../sprint2/src/binary_to_bcd_converter.sv \
  ../../../sprint2/src/key_sync.sv \
  ../../src/vjtag_interface.sv \
  ../../src/arbiter.sv \
  ../../src/fsm.sv \
  ../../src/counter.sv \
  ../../src/mmio_decoder.sv \
  ../../src/control_registers.sv \
  ../../src/memory_mapped_register_file.sv \
  ../../src/ram.sv \
  top_level_sim.sv \
  vjtag.sv \
  tb_top_level.sv

vsim -wlf "run_top_level.wlf" -voptargs=+acc work.tb_top_level
log -r /*

add wave -divider "Entradas"
add wave -radix binary /tb_top_level/CLOCK_50
add wave -radix binary /tb_top_level/KEY
add wave -radix binary /tb_top_level/SW

add wave -divider "Salidas"
add wave -radix binary /tb_top_level/LEDR
add wave -radix hex    /tb_top_level/HEX0
add wave -radix hex    /tb_top_level/HEX1
add wave -radix hex    /tb_top_level/HEX2
add wave -radix hex    /tb_top_level/HEX3
add wave -radix hex    /tb_top_level/HEX4
add wave -radix hex    /tb_top_level/HEX5

add wave -divider "Bus MMIO (DUT)"
add wave -radix hex    /tb_top_level/dut/mux_addr
add wave -radix hex    /tb_top_level/dut/mux_data
add wave -radix binary /tb_top_level/dut/mux_valid
add wave -radix binary /tb_top_level/dut/mux_write_en

add wave -divider "Arbitraje"
add wave -radix binary /tb_top_level/dut/vjtag_valid
add wave -radix binary /tb_top_level/dut/vjtag_ready
add wave -radix binary /tb_top_level/dut/fsm_valid
add wave -radix binary /tb_top_level/dut/fsm_ready

add wave -divider "Estado FSM"
add wave -radix binary   /tb_top_level/dut/fsm_busy_w
add wave -radix unsigned /tb_top_level/dut/fsm_state_w
add wave -radix unsigned /tb_top_level/dut/pixel_count_w
add wave -radix binary   /tb_top_level/dut/status_q

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

set fp [open "top_level_test_summary.log" w]
puts $fp "Simulation completed. Check top_level_transcript.log for PASS/FAIL results."
close $fp

quit -f
