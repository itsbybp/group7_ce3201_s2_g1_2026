# Un solo Makefile para todo el Epic 3.
# "make" (sin argumentos) corre US 3.1 y US 3.2, cada una a WIDTH=8 y WIDTH=32
# (requisito del DoD: "Pruebas negativas y funcionales validadas a 32 bits").
# Se auto-invoca (-f sobre si mismo) para poder usar Verilator e Icarus, y dos
# anchos distintos, sin que las variables (SIM, MODULE, SIM_BUILD) choquen entre si.

_RUN ?=
_WIDTH ?= 8
RTL_DIR ?= ../../src
THIS_MAKEFILE := $(firstword $(MAKEFILE_LIST))

ifeq ($(_RUN),)

.PHONY: all test-3.1 test-3.2

all: test-3.1 test-3.2

test-3.1:
	@echo "===================================================="
	@echo " US 3.1 - Pruebas funcionales (Verilator) - WIDTH=8"
	@echo "===================================================="
	@$(MAKE) -f $(THIS_MAKEFILE) _RUN=functional _WIDTH=8
	@echo "===================================================="
	@echo " US 3.1 - Pruebas funcionales (Verilator) - WIDTH=32"
	@echo "===================================================="
	@$(MAKE) -f $(THIS_MAKEFILE) _RUN=functional _WIDTH=32

test-3.2:
	@echo "===================================================="
	@echo " US 3.2 - Pruebas negativas / inyeccion de X (Icarus) - WIDTH=8"
	@echo "===================================================="
	@$(MAKE) -f $(THIS_MAKEFILE) _RUN=negative _WIDTH=8
	@echo "===================================================="
	@echo " US 3.2 - Pruebas negativas / inyeccion de X (Icarus) - WIDTH=32"
	@echo "===================================================="
	@$(MAKE) -f $(THIS_MAKEFILE) _RUN=negative _WIDTH=32

else ifeq ($(_RUN),functional)

SIM = verilator
TOPLEVEL_LANG = verilog
TOPLEVEL = alu_param
MODULE = test_alu_param
SIM_BUILD = sim_build_functional_$(_WIDTH)
export WIDTH := $(_WIDTH)

VERILOG_SOURCES += $(RTL_DIR)/alu_types_pkg.sv
VERILOG_SOURCES += $(RTL_DIR)/alu_param.sv

EXTRA_ARGS += --trace --trace-structs
EXTRA_ARGS += -GWIDTH=$(_WIDTH)

include $(shell cocotb-config --makefiles)/Makefile.sim

else ifeq ($(_RUN),negative)

SIM = icarus
TOPLEVEL_LANG = verilog
TOPLEVEL = alu_param
MODULE = test_negative
SIM_BUILD = sim_build_negative_$(_WIDTH)
export WIDTH := $(_WIDTH)

VERILOG_SOURCES += $(RTL_DIR)/alu_types_pkg.sv
VERILOG_SOURCES += $(RTL_DIR)/alu_param.sv

COMPILE_ARGS += -P$(TOPLEVEL).WIDTH=$(_WIDTH)

include $(shell cocotb-config --makefiles)/Makefile.sim

endif