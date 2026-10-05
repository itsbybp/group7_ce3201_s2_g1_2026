quit -sim

transcript file ram_transcript.log

if {[file exists work]} {
    vdel -all
}
vlib work
vmap work work

vlog -sv ../../src/ram.sv
vlog -sv tb_ram.sv

vsim -voptargs=+acc work.tb_ram

add wave -divider "Puerto A"
add wave -radix binary   /tb_ram/clk
add wave -radix hex      /tb_ram/addr_a
add wave -radix hex      /tb_ram/data_in_a
add wave -radix binary   /tb_ram/we_a
add wave -radix binary   /tb_ram/re_a
add wave -radix hex      /tb_ram/data_out_a

add wave -divider "Puerto B"
add wave -radix hex      /tb_ram/addr_b
add wave -radix hex      /tb_ram/data_in_b
add wave -radix binary   /tb_ram/we_b
add wave -radix binary   /tb_ram/re_b
add wave -radix hex      /tb_ram/data_out_b

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns

run -all

write wave ram.wlf

quit -f