SV_DIRS = $(wildcard sprint*/tests/sv)
COCOTB_DIRS = $(wildcard sprint*/tests/cocotb)
SPRINTS = $(wildcard sprint*)

.PHONY: all all_sv all_cocotb clean clean_sv clean_cocotb $(SV_DIRS) $(COCOTB_DIRS)

all: all_sv all_cocotb

all_sv: $(SV_DIRS)

all_cocotb: $(COCOTB_DIRS)

$(SV_DIRS):
	$(MAKE) -C $@ simulate_questa

$(COCOTB_DIRS):
	$(MAKE) -C $@

# Clean targets
clean: clean_sv clean_cocotb

clean_sv:
	for dir in $(SV_DIRS); \
	do \
		$(MAKE) -C "$$dir" clean; \
	done

clean_cocotb:
	for dir in $(COCOTB_DIRS); \
	do \
		$(MAKE) -C "$$dir" clean; \
	done

# Target specific sprints directly
%_sv:
	$(MAKE) -C $*/tests/sv simulate_questa

%_cocotb:
	$(MAKE) -C $*/tests/cocotb

%_clean:
	@if [ -d "$*/tests/sv" ]; \
	then \
		$(MAKE) -C "$*/tests/sv" clean; \
	fi
	@if [ -d "$*/tests/cocotb" ]; \
	then \
		$(MAKE) -C "$*/tests/cocotb" clean; \
	fi