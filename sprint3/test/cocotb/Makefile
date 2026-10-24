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

.PHONY: all arbiter fsm counter top_level clean

all:
	$(MAKE) arbiter
	$(MAKE) fsm
	$(MAKE) counter
	$(MAKE) top_level

ifeq ($(MAKECMDGOALS),arbiter)
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = $(PWD)/../../src/arbiter.sv
SIM_BUILD = sim_build_arbiter
export COCOTB_RESULTS_FILE = results_arbiter.xml

else ifeq ($(MAKECMDGOALS),fsm)
TOPLEVEL = fsm
MODULE = tb_fsm
VERILOG_SOURCES = $(PWD)/../../src/fsm.sv
SIM_BUILD = sim_build_fsm
COMPILE_ARGS = -GNUM_PIXELS=8
export COCOTB_RESULTS_FILE = results_fsm.xml

else ifeq ($(MAKECMDGOALS),counter)
TOPLEVEL = counter
MODULE = tb_counter
VERILOG_SOURCES = $(PWD)/../../src/counter.sv
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

else
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = $(PWD)/../../src/arbiter.sv
SIM_BUILD = sim_build_arbiter
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

arbiter: sim
fsm: sim
counter: sim
top_level: sim

clean::
	rm -rf sim_build_arbiter \
	       sim_build_fsm \
	       sim_build_counter \
	       sim_build_top_level \
	       __pycache__ \
	       results_arbiter.xml \
	       results_fsm.xml \
	       results_counter.xml \
	       results_top_level.xml