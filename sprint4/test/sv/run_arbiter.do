# Ejecutar desde sprint4/test/sv/:
#   questa -batch -do run_arbiter.do
#   (o en la GUI: do run_arbiter.do)

quit -sim

transcript file arbiter_transcript.log

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -sv ../../src/arbiter.sv
vlog -sv tb_arbiter.sv

vsim -voptargs=+acc -suppress 10908 work.tb_arbiter

# ---------- Reloj, reset y estado ----------
add wave -noupdate -divider "Reloj y reset"
add wave -noupdate /tb_arbiter/clk
add wave -noupdate /tb_arbiter/rst_n

add wave -noupdate -divider "Estado del arbitro"
add wave -noupdate /tb_arbiter/dut/state

# ---------- Puerto vJTAG (manager) ----------
add wave -noupdate -divider "Puerto vJTAG"
add wave -noupdate /tb_arbiter/vjtag_valid
add wave -noupdate -hex /tb_arbiter/vjtag_addr
add wave -noupdate -hex /tb_arbiter/vjtag_data
add wave -noupdate /tb_arbiter/vjtag_write_en
add wave -noupdate /tb_arbiter/vjtag_ready

# ---------- Puerto CPU (fsm) ----------
add wave -noupdate -divider "Puerto CPU (fsm)"
add wave -noupdate /tb_arbiter/fsm_valid
add wave -noupdate -hex /tb_arbiter/fsm_addr
add wave -noupdate -hex /tb_arbiter/fsm_data
add wave -noupdate /tb_arbiter/fsm_write_en
add wave -noupdate /tb_arbiter/fsm_ready

# ---------- Subordinado / bus concedido ----------
add wave -noupdate -divider "Subordinado y bus concedido"
add wave -noupdate /tb_arbiter/subordinate_ready
add wave -noupdate /tb_arbiter/mux_valid
add wave -noupdate /tb_arbiter/mux_is_cpu
add wave -noupdate -hex /tb_arbiter/mux_addr
add wave -noupdate -hex /tb_arbiter/mux_data
add wave -noupdate /tb_arbiter/mux_write_en

run -all

write wave arbiter.wlf

quit -f
