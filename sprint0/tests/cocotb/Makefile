TOPLEVEL_LANG ?= verilog
SIM ?= verilator

PWD = $(shell pwd)

VERILOG_SOURCES = $(PWD)/../../src/parity_checker_top.sv
VERILOG_SOURCES += $(PWD)/../../src/parity_checker_behavioral.sv
VERILOG_SOURCES += $(PWD)/../../src/parity_checker_structural.sv

TOPLEVEL = parity_checker_top
MODULE = test_parity_checker

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf sim_build
	rm -rf __pycache__
	rm -f results.xml