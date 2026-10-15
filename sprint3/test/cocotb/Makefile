SIM ?= icarus
TOPLEVEL_LANG ?= verilog

.PHONY: all arbiter fsm clean

all:
	$(MAKE) arbiter

ifeq ($(MAKECMDGOALS),arbiter)
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = \
	$(PWD)/../../src/arbiter.sv
SIM_BUILD = sim_build_arbiter

else ifeq ($(MAKECMDGOALS),fsm)
TOPLEVEL = fsm
MODULE = tb_fsm
VERILOG_SOURCES = \
	$(PWD)/../../src/fsm.sv
SIM_BUILD = sim_build_fsm
COMPILE_ARGS = -Pfsm.NUM_PIXELS=8

else
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = \
	$(PWD)/../../src/arbiter.sv
SIM_BUILD = sim_build_arbiter
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

arbiter: sim
fsm: sim

clean::
	rm -rf sim_build_arbiter \
	       sim_build_fsm \
	       __pycache__ \
	       results.xml