SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES = $(wildcard $(PWD)/../../src/*.sv)

MODULE    ?= tb_arbiter
TOPLEVEL  ?= arbiter
SIM_BUILD ?= sim_build_$(TOPLEVEL)

.PHONY: all arbiter ram mmio_decoder memory_mapped_register_file control_registers clean

all:
	$(MAKE) arbiter
	$(MAKE) ram
	$(MAKE) mmio_decoder
	$(MAKE) memory_mapped_register_file
	$(MAKE) control_registers

arbiter:
	$(MAKE) MODULE=tb_arbiter TOPLEVEL=arbiter SIM_BUILD=sim_build_arbiter sim

ram:
	$(MAKE) MODULE=tb_ram TOPLEVEL=ram SIM_BUILD=sim_build_ram sim

mmio_decoder:
	$(MAKE) MODULE=tb_mmio_decoder TOPLEVEL=mmio_decoder SIM_BUILD=sim_build_mmio_decoder sim

memory_mapped_register_file:
	$(MAKE) MODULE=test_memory_mapped_register_file TOPLEVEL=memory_mapped_register_file SIM_BUILD=sim_build_memory_mapped_register_file sim

control_registers:
	$(MAKE) MODULE=test_control_registers TOPLEVEL=control_registers SIM_BUILD=sim_build_control_registers sim

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf sim_build_arbiter \
	       sim_build_ram \
	       sim_build_mmio_decoder \
	       sim_build_memory_mapped_register_file \
	       sim_build_control_registers \
	       __pycache__ \
	       results.xml