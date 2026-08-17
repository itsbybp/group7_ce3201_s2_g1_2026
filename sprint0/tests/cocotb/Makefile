TOPLEVEL_LANG ?= verilog
SIM ?= verilator

PWD = $(shell pwd)

VERILOG_SOURCES = $(PWD)/../../src/parity_checker_top.sv
VERILOG_SOURCES += $(PWD)/../../src/parity_checker_behavioral.sv
VERILOG_SOURCES += $(PWD)/../../src/parity_checker_structural.sv

TOPLEVEL = parity_checker_top
MODULE = test_parity_checker

.DEFAULT_GOAL := verify

.PHONY: verify behavioral structural

verify: behavioral structural

behavioral:
	$(MAKE) sim \
		SIM=verilator \
		SIM_BUILD=sim_build_behavioral \
		COCOTB_RESULTS_FILE=results_behavioral.xml

structural:
	COMPILE_ARGS="-DSTRUCTURAL" $(MAKE) sim \
		SIM=verilator \
		SIM_BUILD=sim_build_structural \
		COCOTB_RESULTS_FILE=results_structural.xml

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf sim_build
	rm -rf sim_build_behavioral
	rm -rf sim_build_structural
	rm -rf __pycache__
	rm -f results.xml
	rm -f results_behavioral.xml
	rm -f results_structural.xml