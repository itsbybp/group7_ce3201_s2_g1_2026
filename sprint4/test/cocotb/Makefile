SIM ?= verilator
TOPLEVEL_LANG ?= verilog

SRC = $(CURDIR)/../../src
SPRINT1 = $(CURDIR)/../../../sprint1/src

# Cada prueba se elige con la variable TEST (no con la meta de la linea de comandos),
# de modo que `make top`, `make TEST=top` y `make sim TEST=top` ejecutan lo mismo.
TEST ?= arbiter

.PHONY: all arbiter mmio_decoder ram control_registers top clean

all:
	$(MAKE) arbiter
	$(MAKE) mmio_decoder
	$(MAKE) ram
	$(MAKE) control_registers
	$(MAKE) top

ifeq ($(TEST),arbiter)
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = $(SRC)/arbiter.sv
SIM_BUILD = sim_build_arbiter
export COCOTB_RESULTS_FILE = results_arbiter.xml

else ifeq ($(TEST),mmio_decoder)
TOPLEVEL = mmio_decoder
MODULE = tb_mmio_decoder
VERILOG_SOURCES = $(SRC)/mmio_decoder.sv
SIM_BUILD = sim_build_mmio_decoder
export COCOTB_RESULTS_FILE = results_mmio_decoder.xml

else ifeq ($(TEST),ram)
TOPLEVEL = ram
MODULE = tb_ram
VERILOG_SOURCES = $(SRC)/ram.sv
SIM_BUILD = sim_build_ram
export COCOTB_RESULTS_FILE = results_ram.xml

else ifeq ($(TEST),control_registers)
TOPLEVEL = control_registers
MODULE = tb_control_registers
VERILOG_SOURCES = $(SRC)/control_registers.sv
SIM_BUILD = sim_build_control_registers
export COCOTB_RESULTS_FILE = results_control_registers.xml

else ifeq ($(TEST),top)
TOPLEVEL = rv32i_top
MODULE = tb_top
VERILOG_SOURCES = $(SPRINT1)/alu_types_pkg.sv $(SPRINT1)/alu_param.sv \
                  $(SRC)/multicycle_rv_immediate_types_pkg.sv \
                  $(SRC)/multicycle_rv_opcodes_pkg.sv \
                  $(SRC)/alu_decoder.sv $(SRC)/immediate_decoder.sv \
                  $(SRC)/rv_register_file.sv \
                  $(SRC)/multicycle_rv_control_fsm.sv \
                  $(SRC)/multicycle_rv_control_unit.sv \
                  $(SRC)/multicycle_rv32i.sv \
                  $(SRC)/arbiter.sv $(SRC)/mmio_decoder.sv $(SRC)/ram.sv \
                  $(SRC)/control_registers.sv $(SRC)/rv32i_top.sv
SIM_BUILD = sim_build_top
export COCOTB_RESULTS_FILE = results_top.xml

else
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = $(SRC)/arbiter.sv
SIM_BUILD = sim_build_arbiter
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

arbiter mmio_decoder ram control_registers top:
	$(MAKE) sim TEST=$@

clean::
	rm -rf sim_build_arbiter sim_build_mmio_decoder sim_build_ram \
	       sim_build_control_registers sim_build_top __pycache__ \
	       results_arbiter.xml results_mmio_decoder.xml \
	       results_ram.xml results_control_registers.xml results_top.xml