transcript file mmio_decoder_transcript.log

vlib work
vmap work work

vlog -sv ../../src/mmio_decoder.sv
vlog -sv tb_mmio_decoder.sv

vsim -t 1ns work.tb_mmio_decoder

add wave -divider "Manager"
add wave -hex /tb_mmio_decoder/dut/addr
add wave -hex /tb_mmio_decoder/dut/valid
add wave -hex /tb_mmio_decoder/dut/ready
add wave -hex /tb_mmio_decoder/dut/rdata

add wave -divider "Chip-selects"
add wave -logic /tb_mmio_decoder/dut/cs_ram
add wave -logic /tb_mmio_decoder/dut/cs_rb
add wave -logic /tb_mmio_decoder/dut/cs_ledr
add wave -logic /tb_mmio_decoder/dut/cs_hex
add wave -logic /tb_mmio_decoder/dut/cs_cr

add wave -divider "rdata subordinates"
add wave -hex /tb_mmio_decoder/dut/ram_rdata
add wave -hex /tb_mmio_decoder/dut/rb_rdata
add wave -hex /tb_mmio_decoder/dut/cr_rdata

add wave -divider "Interno"
add wave /tb_mmio_decoder/dut/sel
add wave /tb_mmio_decoder/dut/sel_q

run -all

transcript file ""
echo "Pruebas completadas exitosamente"
quit -sim