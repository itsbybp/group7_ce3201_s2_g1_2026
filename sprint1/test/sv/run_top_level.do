quit -sim
if {[file exists work]} { vdel -all }
vlib work
vmap work work

vlog -sv ../../src/alu_types_pkg.sv
vlog -sv ../../src/alu_param.sv
vlog -sv ../../src/n_bit_absolute_value.sv
vlog -sv ../../src/decoder_4x16.sv
vlog -sv ../../src/seven_segment_adapter.sv
vlog -sv ../../src/three_bit_absolute_value_binary_to_7_segment_converter.sv
vlog -sv ../../src/eight_bit_absolute_value_binary_to_7_segment_BCD_converter.sv
vlog -sv ../../src/mode_b_constants.sv
vlog -sv ../../src/control_logic.sv
vlog -sv ../../src/top_level.sv
vlog -sv tb_top_level.sv

vsim -voptargs=+acc work.tb_top_level

add wave -divider "Entradas"
add wave -radix decimal /tb_top_level/src0
add wave -radix decimal /tb_top_level/src1
add wave -radix hexadecimal /tb_top_level/control

add wave -divider "Banderas"
add wave -radix binary /tb_top_level/zero
add wave -radix binary /tb_top_level/carry
add wave -radix binary /tb_top_level/negative
add wave -radix binary /tb_top_level/overflow

add wave -divider "Signos"
add wave -radix binary /tb_top_level/operand_a_is_negative
add wave -radix binary /tb_top_level/operand_b_is_negative
add wave -radix binary /tb_top_level/result_is_negative

add wave -divider "Resultado"
add wave -radix unsigned /tb_top_level/checks
add wave -radix unsigned /tb_top_level/errors

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all
write wave top_level.wlf
quit -f
