quit -sim

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/arbiter.sv
vlog -sv tb_arbiter.sv

vsim -voptargs=+acc work.tb_arbiter

add wave -divider "Entradas vJTAG"
add wave -radix binary  /tb_arbiter/clk
add wave -radix binary  /tb_arbiter/rst_n
add wave -radix binary  /tb_arbiter/vjtag_valid
add wave -radix hex     /tb_arbiter/vjtag_addr
add wave -radix hex     /tb_arbiter/vjtag_data

add wave -divider "Entradas FSM"
add wave -radix binary  /tb_arbiter/fsm_valid
add wave -radix hex     /tb_arbiter/fsm_addr
add wave -radix hex     /tb_arbiter/fsm_data

add wave -divider "Subordinado"
add wave -radix binary  /tb_arbiter/subordinate_ready

add wave -divider "Salidas"
add wave -radix hex     /tb_arbiter/mux_addr
add wave -radix hex     /tb_arbiter/mux_data
add wave -radix binary  /tb_arbiter/mux_valid
add wave -radix binary  /tb_arbiter/vjtag_ready
add wave -radix binary  /tb_arbiter/fsm_ready

add wave -divider "Estado interno (DUT)"
add wave -radix binary  /tb_arbiter/dut/state

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

write wave arbiter.wlf

quit -f