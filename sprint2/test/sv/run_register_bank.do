quit -sim

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/register_bank.sv
vlog -sv tb_register_bank.sv

vsim -voptargs=+acc work.tb_register_bank

add wave -divider "Control"
add wave -radix binary /tb_register_bank/clk
add wave -radix binary /tb_register_bank/reset_n
add wave -radix binary /tb_register_bank/write_en

add wave -divider "Seleccion de registros"
add wave -radix unsigned /tb_register_bank/rd
add wave -radix unsigned /tb_register_bank/rs1
add wave -radix unsigned /tb_register_bank/rs2

add wave -divider "Datos"
add wave -radix hexadecimal /tb_register_bank/write_data
add wave -radix hexadecimal /tb_register_bank/rs1_data
add wave -radix hexadecimal /tb_register_bank/rs2_data

add wave -divider "Registros internos (DUT)"
add wave -radix hexadecimal /tb_register_bank/dut/x1_q
add wave -radix hexadecimal /tb_register_bank/dut/x2_q
add wave -radix hexadecimal /tb_register_bank/dut/x3_q

add wave -divider "Resultado"
add wave -radix unsigned /tb_register_bank/checks
add wave -radix unsigned /tb_register_bank/errors

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

write wave register_bank.wlf

quit -f
