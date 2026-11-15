SIM ?= verilator
TOPLEVEL_LANG ?= verilog

SRC = $(CURDIR)/../../src

.PHONY: all arbiter mmio_decoder ram control_registers clean

all:
	$(MAKE) arbiter
	$(MAKE) mmio_decoder
	$(MAKE) ram
	$(MAKE) control_registers

ifeq ($(MAKECMDGOALS),arbiter)
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = $(SRC)/arbiter.sv
SIM_BUILD = sim_build_arbiter
export COCOTB_RESULTS_FILE = results_arbiter.xml

else ifeq ($(MAKECMDGOALS),mmio_decoder)
TOPLEVEL = mmio_decoder
MODULE = tb_mmio_decoder
VERILOG_SOURCES = $(SRC)/mmio_decoder.sv
SIM_BUILD = sim_build_mmio_decoder
export COCOTB_RESULTS_FILE = results_mmio_decoder.xml

else ifeq ($(MAKECMDGOALS),ram)
TOPLEVEL = ram
MODULE = tb_ram
VERILOG_SOURCES = $(SRC)/ram.sv
SIM_BUILD = sim_build_ram
export COCOTB_RESULTS_FILE = results_ram.xml

else ifeq ($(MAKECMDGOALS),control_registers)
TOPLEVEL = control_registers
MODULE = tb_control_registers
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
mmio_decoder: sim
ram: sim
control_registers: sim

clean::
	rm -rf sim_build_arbiter sim_build_mmio_decoder sim_build_ram \
	       sim_build_control_registers __pycache__ \
	       results_arbiter.xml results_mmio_decoder.xml \
	       results_ram.xml results_control_registers.xml