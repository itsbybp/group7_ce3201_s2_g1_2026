SIM ?= verilator
TOPLEVEL_LANG ?= verilog

.PHONY: all arbiter fsm counter clean

all:
	$(MAKE) arbiter
	$(MAKE) fsm
	$(MAKE) counter

ifeq ($(MAKECMDGOALS),arbiter)
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = $(PWD)/../../src/arbiter.sv
SIM_BUILD = sim_build_arbiter

else ifeq ($(MAKECMDGOALS),fsm)
TOPLEVEL = fsm
MODULE = tb_fsm
VERILOG_SOURCES = $(PWD)/../../src/fsm.sv
SIM_BUILD = sim_build_fsm
COMPILE_ARGS = -Pfsm.NUM_PIXELS=8

else ifeq ($(MAKECMDGOALS),counter)
TOPLEVEL = counter
MODULE = tb_counter
VERILOG_SOURCES = $(PWD)/../../src/counter.sv
SIM_BUILD = sim_build_counter

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

clean::
	rm -rf sim_build_arbiter \
	       sim_build_fsm \
	       sim_build_counter \
	       __pycache__ \
	       results.xml