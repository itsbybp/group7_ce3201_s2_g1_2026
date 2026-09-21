quit -sim

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/key_sync.sv
vlog -sv tb_key_sync.sv

vsim -voptargs=+acc work.tb_key_sync

add wave -divider "Entradas"
add wave -radix binary /tb_key_sync/clk
add wave -radix binary /tb_key_sync/key_raw
add wave -radix binary /tb_key_sync/key0_raw

add wave -divider "Salidas"
add wave -radix binary /tb_key_sync/key_pulse
add wave -radix binary /tb_key_sync/reset_n

add wave -divider "Etapas internas de sincronizacion (DUT)"
add wave -radix binary /tb_key_sync/dut/sync_ff1
add wave -radix binary /tb_key_sync/dut/sync_ff2
add wave -radix binary /tb_key_sync/dut/sync_ff3
add wave -radix binary /tb_key_sync/dut/reset_ff1
add wave -radix binary /tb_key_sync/dut/reset_ff2

add wave -divider "Resultado"
add wave -radix unsigned /tb_key_sync/checks
add wave -radix unsigned /tb_key_sync/errors

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

write wave key_sync.wlf

quit -f
