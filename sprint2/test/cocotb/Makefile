SIM ?= icarus
TOPLEVEL_LANG ?= verilog

.PHONY: all register_bank key_sync exec_fsm input_fsm clean

all:
	$(MAKE) register_bank
	$(MAKE) key_sync
	$(MAKE) exec_fsm
	$(MAKE) input_fsm

ifeq ($(MAKECMDGOALS),key_sync)
TOPLEVEL = key_sync
MODULE = test_key_sync
VERILOG_SOURCES = $(PWD)/../../src/key_sync.sv
SIM_BUILD = sim_build_key_sync

else ifeq ($(MAKECMDGOALS),exec_fsm)
TOPLEVEL = exec_fsm
MODULE = test_exec_fsm
VERILOG_SOURCES = $(PWD)/../../src/exec_fsm.sv
SIM_BUILD = sim_build_exec_fsm

else ifeq ($(MAKECMDGOALS),input_fsm)
TOPLEVEL = input_fsm
MODULE = test_input_fsm
VERILOG_SOURCES = $(PWD)/../../src/input_fsm.sv
SIM_BUILD = sim_build_input_fsm

else
TOPLEVEL = register_bank
MODULE = test_register_bank
VERILOG_SOURCES = $(PWD)/../../src/register_bank.sv
SIM_BUILD = sim_build_register_bank
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

register_bank: sim
key_sync: sim
exec_fsm: sim
input_fsm: sim

clean::
	rm -rf sim_build_register_bank \
	       sim_build_key_sync \
	       sim_build_exec_fsm \
	       sim_build_input_fsm \
	       __pycache__ \
	       results.xml