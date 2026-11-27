# Ejecutar desde sprint4/test/sv/:
#   questa -batch -do run_mmio_decoder.do
#   (o en la GUI: do run_mmio_decoder.do)

quit -sim

transcript file mmio_decoder_transcript.log

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -sv ../../src/mmio_decoder.sv
vlog -sv tb_mmio_decoder.sv

vsim -voptargs=+acc -suppress 10908 work.tb_mmio_decoder

# ---------- Reloj y reset ----------
add wave -noupdate -divider "Reloj y reset"
add wave -noupdate /tb_mmio_decoder/clk
add wave -noupdate /tb_mmio_decoder/rst_n

# ---------- Entrada del bus arbitrado ----------
add wave -noupdate -divider "Entrada del bus (arbitrado)"
add wave -noupdate /tb_mmio_decoder/valid
add wave -noupdate /tb_mmio_decoder/write_en
add wave -noupdate /tb_mmio_decoder/is_cpu
add wave -noupdate -hex /tb_mmio_decoder/addr

# ---------- Estado interno de la latencia ----------
add wave -noupdate -divider "Latencia de lectura"
add wave -noupdate /tb_mmio_decoder/dut/pending_q
add wave -noupdate /tb_mmio_decoder/dut/sel
add wave -noupdate /tb_mmio_decoder/dut/sel_q

# ---------- Handshake y datos de salida ----------
add wave -noupdate -divider "Handshake y rdata"
add wave -noupdate /tb_mmio_decoder/ready
add wave -noupdate -hex /tb_mmio_decoder/rdata

# ---------- Habilitaciones de lectura (RAM) ----------
add wave -noupdate -divider "re_* (lectura RAM)"
add wave -noupdate /tb_mmio_decoder/re_instr
add wave -noupdate /tb_mmio_decoder/re_in
add wave -noupdate /tb_mmio_decoder/re_out
add wave -noupdate /tb_mmio_decoder/re_hist

# ---------- Habilitaciones de escritura ----------
add wave -noupdate -divider "we_* (escritura)"
add wave -noupdate /tb_mmio_decoder/we_instr
add wave -noupdate /tb_mmio_decoder/we_in
add wave -noupdate /tb_mmio_decoder/we_out
add wave -noupdate /tb_mmio_decoder/we_hist
add wave -noupdate /tb_mmio_decoder/we_ledr
add wave -noupdate /tb_mmio_decoder/we_hex
add wave -noupdate /tb_mmio_decoder/we_ctrl
add wave -noupdate /tb_mmio_decoder/we_status
add wave -noupdate /tb_mmio_decoder/we_threshold

run -all

write wave mmio_decoder.wlf

quit -f
