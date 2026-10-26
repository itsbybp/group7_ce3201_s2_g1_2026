SIM ?= verilator
TOPLEVEL_LANG ?= verilog

SRC = $(PWD)/../../src
S1  = $(PWD)/../../../sprint1/src
S2  = $(PWD)/../../../sprint2/src

# Fuentes de top_level (sprint1 y sprint2 primero; el paquete antes que todo)
TOP_SRCS = $(S1)/alu_types_pkg.sv $(S1)/alu_param.sv $(S1)/decoder_4x16.sv $(S1)/seven_segment_adapter.sv \
           $(S2)/binary_to_bcd_converter.sv $(S2)/key_sync.sv \
           $(SRC)/vjtag_interface.sv $(SRC)/arbiter.sv $(SRC)/fsm.sv $(SRC)/counter.sv \
           $(SRC)/mmio_decoder.sv $(SRC)/control_registers.sv $(SRC)/memory_mapped_register_file.sv \
           $(SRC)/ram.sv $(SRC)/top_level.sv

.PHONY: all arbiter fsm counter top_level ram mmio_decoder memory_mapped_register_file control_registers clean

all:
	$(MAKE) arbiter
	$(MAKE) fsm
	$(MAKE) counter
	$(MAKE) top_level
	$(MAKE) ram
	$(MAKE) mmio_decoder
	$(MAKE) memory_mapped_register_file
	$(MAKE) control_registers

ifeq ($(MAKECMDGOALS),arbiter)
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = $(SRC)/arbiter.sv
SIM_BUILD = sim_build_arbiter
export COCOTB_RESULTS_FILE = results_arbiter.xml

else ifeq ($(MAKECMDGOALS),fsm)
TOPLEVEL = fsm
MODULE = tb_fsm
VERILOG_SOURCES = $(SRC)/fsm.sv
SIM_BUILD = sim_build_fsm
COMPILE_ARGS = -GNUM_PIXELS=8
export COCOTB_RESULTS_FILE = results_fsm.xml

else ifeq ($(MAKECMDGOALS),counter)
TOPLEVEL = counter
MODULE = tb_counter
VERILOG_SOURCES = $(SRC)/counter.sv
SIM_BUILD = sim_build_counter
export COCOTB_RESULTS_FILE = results_counter.xml

else ifeq ($(MAKECMDGOALS),top_level)
TOPLEVEL = top_level
MODULE = tb_top_level
SIM_BUILD = sim_build_top_level
# El top instancia "vjtag" (IP de Intel): en sim se genera a partir del stub, sin tocar el .qsf
VERILOG_SOURCES = $(TOP_SRCS) $(SIM_BUILD)/vjtag.sv
export COCOTB_RESULTS_FILE = results_top_level.xml

$(SIM_BUILD)/vjtag.sv: $(SRC)/vjtag_sim_stub.sv
	mkdir -p $(SIM_BUILD)
	sed 's/module vjtag_sim_stub/module vjtag/' $< > $@

else ifeq ($(MAKECMDGOALS),ram)
TOPLEVEL = ram
MODULE = tb_ram
VERILOG_SOURCES = $(SRC)/ram.sv
SIM_BUILD = sim_build_ram
export COCOTB_RESULTS_FILE = results_ram.xml

else ifeq ($(MAKECMDGOALS),mmio_decoder)
TOPLEVEL = mmio_decoder
MODULE = tb_mmio_decoder
VERILOG_SOURCES = $(SRC)/mmio_decoder.sv
SIM_BUILD = sim_build_mmio_decoder
export COCOTB_RESULTS_FILE = results_mmio_decoder.xml

else ifeq ($(MAKECMDGOALS),memory_mapped_register_file)
TOPLEVEL = memory_mapped_register_file
MODULE = test_memory_mapped_register_file
VERILOG_SOURCES = $(SRC)/memory_mapped_register_file.sv
SIM_BUILD = sim_build_memory_mapped_register_file
export COCOTB_RESULTS_FILE = results_memory_mapped_register_file.xml

else ifeq ($(MAKECMDGOALS),control_registers)
TOPLEVEL = control_registers
MODULE = test_control_registers
VERILOG_SOURCES = $(SRC)/control_registers.sv
SIM_BUILD = sim_build_control_registers
export COCOTB_RESULTS_FILE = results_control_registers.xml

else
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = $(SRC)/arbiter.sv
SIM_BUILD = sim_build_arbiter
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

arbiter: sim
fsm: sim
counter: sim
top_level: sim
ram: sim
mmio_decoder: sim
memory_mapped_register_file: sim
control_registers: sim

clean::
	rm -rf sim_build_arbiter \
	       sim_build_fsm \
	       sim_build_counter \
	       sim_build_top_level \
	       sim_build_ram \
	       sim_build_mmio_decoder \
	       sim_build_memory_mapped_register_file \
	       sim_build_control_registers \
	       __pycache__ \
	       results_arbiter.xml \
	       results_fsm.xml \
	       results_counter.xml \
	       results_top_level.xml \
	       results_ram.xml \
	       results_mmio_decoder.xml \
	       results_memory_mapped_register_file.xml \
	       results_control_registers.xml