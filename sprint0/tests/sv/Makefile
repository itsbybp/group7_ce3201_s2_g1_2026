TB_NAME ?= tb_parity_checker

SRC_FILES += ../../src/parity_checker_behavioral.sv
SRC_FILES += ../../src/parity_checker_structural.sv

LOG_FILE = transcript.log

.PHONY: simulate_questa clean

simulate_questa:
	vlib work
	vlog -sv $(SRC_FILES) $(TB_NAME).sv -l $(LOG_FILE)
	vsim -c -do "run -all; quit" work.$(TB_NAME) -l $(LOG_FILE) -appendlog
#   python3 parse_logs.py $(LOG_FILE) ##TODO: Uncomment this line when parse_logs.py is implemented

clean:
	rm -rf work
	rm -f $(LOG_FILE)
	rm -f vsim.wlf