SIM ?= icarus
TOPLEVEL_LANG ?= verilog

.PHONY: all arbiter clean

all:
	$(MAKE) arbiter

ifeq ($(MAKECMDGOALS),arbiter)
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = \
	$(PWD)/../../src/arbiter.sv
SIM_BUILD = sim_build_arbiter

else
TOPLEVEL = arbiter
MODULE = tb_arbiter
VERILOG_SOURCES = \
	$(PWD)/../../src/arbiter.sv
SIM_BUILD = sim_build_arbiter
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

arbiter: sim

clean::
	rm -rf sim_build_arbiter \
	       __pycache__ \
	       results.xml