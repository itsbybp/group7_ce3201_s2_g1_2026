transcript file mmio_decoder_transcript.log

vlib work
vmap work work

vlog -sv ../../src/mmio_decoder.sv
vlog -sv tb_mmio_decoder.sv

vsim -t 1ns -voptargs=+acc work.tb_mmio_decoder

add wave -divider "Manager"
add wave -hex /tb_mmio_decoder/addr
add wave -logic /tb_mmio_decoder/valid
add wave -logic /tb_mmio_decoder/ready
add wave -hex /tb_mmio_decoder/rdata

add wave -divider "Chip-selects"
add wave -logic /tb_mmio_decoder/cs_ram
add wave -logic /tb_mmio_decoder/cs_rb
add wave -logic /tb_mmio_decoder/cs_ledr
add wave -logic /tb_mmio_decoder/cs_hex
add wave -logic /tb_mmio_decoder/cs_cr

add wave -divider "rdata subordinates"
add wave -hex /tb_mmio_decoder/ram_rdata
add wave -hex /tb_mmio_decoder/rb_rdata
add wave -hex /tb_mmio_decoder/cr_rdata

add wave -divider "Interno"
add wave /tb_mmio_decoder/dut/sel
add wave /tb_mmio_decoder/dut/sel_q

run -all

transcript file ""
echo "Simulacion finalizada. Revise mmio_decoder_transcript.log para los resultados."
quit -sim