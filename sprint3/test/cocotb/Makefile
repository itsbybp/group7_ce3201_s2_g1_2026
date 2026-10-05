SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES = $(wildcard $(PWD)/../../src/*.sv)

MODULE   ?= tb_arbiter
TOPLEVEL ?= arbiter
SIM_BUILD ?= sim_build_$(TOPLEVEL)

.PHONY: all arbiter ram mmio_decoder clean

all:
	$(MAKE) arbiter

arbiter:
	$(MAKE) MODULE=tb_arbiter TOPLEVEL=arbiter SIM_BUILD=sim_build_arbiter sim

ram:
	$(MAKE) MODULE=tb_ram TOPLEVEL=ram SIM_BUILD=sim_build_ram sim

mmio_decoder:
	$(MAKE) MODULE=tb_mmio_decoder TOPLEVEL=mmio_decoder SIM_BUILD=sim_build_mmio_decoder sim

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf sim_build_arbiter \
	       sim_build_ram \
	       sim_build_mmio_decoder \
	       __pycache__ \
	       results.xml