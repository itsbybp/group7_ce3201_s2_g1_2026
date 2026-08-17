TB_NAME ?= tb_parity_checker

SRC_FILES += ../../src/parity_checker_behavioral.sv
SRC_FILES += ../../src/parity_checker_structural.sv

LOG_FILE = transcript.log

QUESTA_BIN = /mnt/c/altera/25.1std/questa_fse/win64

.PHONY: simulate_questa clean

simulate_questa:
	$(QUESTA_BIN)/vlib.exe work
	$(QUESTA_BIN)/vlog.exe -sv $(SRC_FILES) $(TB_NAME).sv -l $(LOG_FILE)
	$(QUESTA_BIN)/vsim.exe -c -do "run -all; quit" work.$(TB_NAME) -l $(LOG_FILE) -appendlog
	python3 parse_logs.py $(LOG_FILE)

clean:
	rm -rf work
	rm -f $(LOG_FILE)
	rm -f vsim.wlf