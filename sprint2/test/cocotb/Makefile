SIM ?= icarus
TOPLEVEL_LANG ?= verilog

.PHONY: all register_bank key_sync clean

all:
	$(MAKE) register_bank
	$(MAKE) key_sync

ifeq ($(MAKECMDGOALS),key_sync)
TOPLEVEL = key_sync
MODULE = test_key_sync
VERILOG_SOURCES = $(PWD)/../../src/key_sync.sv
SIM_BUILD = sim_build_key_sync
else
TOPLEVEL = register_bank
MODULE = test_register_bank
VERILOG_SOURCES = $(PWD)/../../src/register_bank.sv
SIM_BUILD = sim_build_register_bank
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

register_bank: sim
key_sync: sim

clean::
	rm -rf sim_build_register_bank sim_build_key_sync __pycache__ results.xml