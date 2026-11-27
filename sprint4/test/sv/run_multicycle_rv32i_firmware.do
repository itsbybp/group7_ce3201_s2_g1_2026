quit -sim

transcript file multicycle_rv32i_firmware_transcript.log

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Paquetes primero
vlog -sv ../../../sprint1/src/alu_types_pkg.sv
vlog -sv ../../src/multicycle_rv_opcodes_pkg.sv
vlog -sv ../../src/multicycle_rv_immediate_types_pkg.sv

# Control, decodificadores, ALU, registros y procesador
vlog -sv ../../src/multicycle_rv_control_fsm.sv
vlog -sv ../../src/alu_decoder.sv
vlog -sv ../../src/immediate_decoder.sv
vlog -sv ../../src/multicycle_rv_control_unit.sv
vlog -sv ../../../sprint1/src/alu_param.sv
vlog -sv ../../src/rv_register_file.sv
vlog -sv ../../src/multicycle_rv32i.sv

vlog -sv tb_multicycle_rv32i_firmware.sv

# Ruta a firmware.hex, relativa al directorio desde el que se ejecuta Questa
# (sprint4/test/sv/) o absoluta. Ajustar a donde este el archivo.
set FIRMWARE_HEX "../../firmware/firmware.hex"

vsim -voptargs=+acc -GFIRMWARE_HEX=$FIRMWARE_HEX work.tb_multicycle_rv32i_firmware

# ---------- Reloj y PC ----------
add wave -noupdate -divider "Reloj y PC"
add wave -noupdate /tb_multicycle_rv32i_firmware/clk
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/pc
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/old_pc

# ---------- Estado de la FSM y handshakes ----------
add wave -noupdate -divider "FSM y handshakes"
add wave -noupdate -unsigned /tb_multicycle_rv32i_firmware/dut/state_num
add wave -noupdate /tb_multicycle_rv32i_firmware/ready_in_instr_memory
add wave -noupdate /tb_multicycle_rv32i_firmware/dut/handshake_instr_memory
add wave -noupdate /tb_multicycle_rv32i_firmware/ready_in_data_memory
add wave -noupdate /tb_multicycle_rv32i_firmware/dut/handshake_data_memory

# ---------- Instruccion y decodificacion ----------
add wave -noupdate -divider "Instruccion e inmediato"
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/instruction
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/immediate

# ---------- ALU ----------
add wave -noupdate -divider "ALU"
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/alu_operand_a
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/alu_operand_b_shifts
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/alu_result
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/alu_result_reg

# ---------- Datos y write-back ----------
add wave -noupdate -divider "Datos y write-back"
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/read_data_reg
add wave -noupdate -hex /tb_multicycle_rv32i_firmware/dut/wb_mux

run -all

write wave multicycle_rv32i_firmware.wlf

# quit -f
