This document compiles a list of somewhat easy to follow tasks necessary for the project. 
As many as they could be gleaned from the original specs as possible while
still being meaningfull or not too abstract to implement.

The base architecture for this project is that of sprint3 and the following changes describe new modules and tasks specific for this sprint4
and also changes to be applied to existing features of sprint3.

# Epic 1

1. Make a Harvard architecture, multicycle RV32I processor with only the instructions from Tabla 1 that passes the testbench (tb) in this repository:
https://github.com/rgarciatec/rv32i_cocotb_template

- 1.1. The **Fetch**, **MemRead**, and **MemWrite** (not MemAdr) states should use ready/valid when interacting with memory.
  - This means they should freeze if a read or write doesn't go through instead of assuming they got or wrote a value in a single cycle.

- 1.2 The processor should also be modified so that it advances using one of two options at a time: the clock or a pulse.
  - The pulse is a signal that is at 0 by default and is synchronously set to 1 for a single cycle at any moment.
  - It usually stays at 0 for many cycles between activations because it is ultimately driven by a button on the FPGA.
    - Driving this signal is not part of this requirement. This is implemented in the top module later on.

- 1.3 Only word accesses: `lw` and `sw` (AC 1). `lb`, `lh`, `sb` and `sh` are out of scope.
- 1.4 `lui` (AC 2): executed in EXECUTE_I with operand A = 0 and the U-type immediate; used to load the upper 20 bits of the MMIO base addresses.
- 1.5 M10K latency: reads are synchronous and take one cycle, so `ready` of a read rises one cycle after `valid` (the instruction bus delivers one instruction every 2 cycles). The FSM keeps `valid` until it receives `ready`; no asynchronous reads are inferred.

# Epic 2

2. Create an enabler for the processor.
  - When disabled (`enabler == 1'b0`), the FSM can't change its state, and the `ready out` and `valid out` signals of both the instruction and data buses (4 signals) are 0.
    - They each connect to an AND gate with the enabler before exiting the processor.

  - `start` (CTRL[0], AC 7) is what starts the processor, and the PC must be initialized to 0x0000_0000 when it starts.
    - Implemented as a level used as the CPU `soft_reset_n`: while `start = 0` the PC stays at 0 and the FSM stays in FETCH; when it rises the CPU runs from address 0. (suposición: the specs call it a pulse; the level has the same effect on the PC)
    - The enabler is not wired directly to CTRL[0]: `cpu_enable = start && !done`, so setting `done` also disables the processor (see 4.2).

  - In stepping mode, if the processor is disabled during a ready valid transaction, the transaction could be lost,
  but this is only possible if the user disables the processor few clock cycles after manually pressing the step button,
  which is not feasible, so this scenario is not contemplated.

3. Modify the existing MMIO decoder with the new MMIO addresses in Tabla 2.
  - Permissions per manager (Host / CPU): instruction RAM 00000-01FFF R/W / RO (WI); input RAM 10000-1FFFF R/W / RO (WI); output RAM 20000-2FFFF RO / R/W; histogram 30000-303FC RO / R/W; LEDR 40000 and HEX 40004 R/W / R/W; CTRL 50000 R/W / RO (bit 0 = start); STATUS 50004 RO / R/W (bit 0 = busy, bit 1 = done); THRESHOLD 5000C R/W / RO. Unmapped: RAZ/WI.
  - Notice that memory spaces also have a Read and Write availabilty per manager.
  - This functionality is implemented in the MMIO decoder.
    - read/write permission is the default
    - To implement read only interactions the mmio_decoder must know who is the current manager
    and and present a fake ready signal to the manager so that the writes are ignored.
    - This ready signal is driven by an always_comb block based on the mmio address and manager
      - looking at address[18:16] and the current manager (a 1-bit signal) is enough to determine this. 

# Epic 3

This is particularly straightforward. Look at sections 1.2 and 5.1 in the original `ce3201_G1_final_project_instructions.pdf`.

4. Make a RISC-V assembly program (this is the firmware) that does the following:

  > Etapa A (Inicialización): Limpia con ceros las 256 direcciones de la memoria del Histograma.
  >
  > Etapa B (Cálculo del Histograma): Recorre la imagen de entrada leyendo cada píxel e incrementa la frecuencia del valor de intensidad correspondiente en la región de memoria dedicada al histograma.
  >
  > Etapa C (Binarización): Lee el umbral desde el registro THRESHOLD, compara cada píxel de entrada contra el umbral, asigna 255 si P(y,x) ≥ TH o 0 en caso contrario, y guarda el resultado en la región de memoria dedicada a la imagen de salida.

  - 4.1 The program also writes `STATUS = 0b10` at the end, i.e. 'done' (bit 1). Bit 0 is busy, read-only, computed in hardware as `start && !done`.
  - 4.2 This change must lead to the processor being disabled: `cpu_enable = start && !done` drops, the FSM stops and both `valid` outputs are 0 (AC 7). The firmware ends in an infinite loop (`j halt`) but the CPU no longer issues requests.
  - 4.3 Only the processor can write to `STATUS`, so the first thing in the program must be `STATUS[1] = 0`.
  - 4.4 Pixels are accessed only with `lw` and `sw` (one pixel per 32-bit word); `lui` loads the upper 20 bits of the MMIO base addresses (AC 1 and AC 2).
  - 4.5 `firmware.hex` is generated with `riscv64-unknown-elf-as -march=rv32i -mabi=ilp32`, `objcopy -O binary -j .text` and `xxd` (see `architecture.md`, section 11).

5. Python script modifications from sprint3
- 5.1 Modify the Python program from sprint3 so that it can also binarize (umbralize?) images so that it can validate whether the process was correct.
  - at p. 2, near the end.

- 5.2 Modify the Python program so that it periodically checks the STATUS register to know if the processor has finished.

- 5.3 Modify the Python program so that it requests and saves the histogram too.
  - The image and histograms should be accessed using the MMIO addresses defined in Tabla 2.

- 5.4 Modify the Python program so that it writes the firmware as well as the input image in RAM.

- "Automatización en Python vía vJTAG". This is already done in Sprint 3?

# Epic 4 - Testplan

6. Create testbenches (tbs) for important modules. In this case, the processor uses the provided cocotb tb, and other modules that are adapted from Sprint 3 can use altered versions of their corresponding tbs.
7. The end-to-end tb is the last and most important one.
  - It is described in section 6.2.
  - It must include the top level and a subsequent signal tap test and evidence should be added to the documentations as results.

## Proposed tbs

8. Update the tbs from Sprint 3 for these modules:
  - 8.1 Arbiter
  -- The arbiter has two managers (Host vJTAG and the CPU data bus), as in sprint3. The instruction bus is independent (AC 3) and does not go through it. It also outputs `mux_is_cpu` so the MMIO decoder can apply per-manager permissions.
  - 8.2 MMIO decoder
  - 8.3 RAM
  - 8.4 Control registers (some changes to allow the step-by-step mode in the processor must be considered).

9. Create/add:
  - 9.1 Adapt the RV32I tb from the provided repository.
  - 9.2 (Discarded) A module to join the processor buses. It contradicts AC 3 (two independent physical buses); the instruction bus goes straight to the RAM instruction port and only the data bus is arbitrated against the Host. See `architecture.md`, section 6.


## Verification scenarios
10. End-to-end tb: CPU, arbiter and memories run firmware.hex with a reduced image size.
  - 10.1 Verifies that instructions are safely retained during stalls on the Harvard buses.
  - 10.2 Verifies the exact histogram and the exact output image.
  - 10.3 Results go to sprint4/docs/results.md.
11. End-to-end tb acceptance criteria:
- 11.1 Memory-collision scenarios are documented in the testplan and validated with Questa and Cocotb.
- 11.2 Stalls: when either bus reports ready = 0, the processor freezes until the transaction completes.
- 11.3 Enabler: with enable = 0, the FSM does not change state and the four valid/ready signals are 0.
- 11.4 Read-As-Zero: reads from unmapped addresses return 0.
- 11.5 Write-Ignored: writes to instruction memory from the CPU and out-of-range writes are discarded.
- 11.6 The testbenches run with no lint warnings in Verilator and Cocotb.

## Additional verification and documentation

12. Signal Tap should now observe the FSM in the control unit of the multicycle processor, as per section 6.3.
  - 12.1 Capture the main FSM, PC, decoded instruction, valid/ready, and done, at 50 MHz.
  - 12.2 Captures are real and go into sprint4/docs/results.md.

13. All this should be documented in sprint4/docs/testplan.md, hopefully beforehand.

14. Create sprint4/docs/evidencia_atributos.md as per section 6.4.
  - 14.1 Design attribute (DI): compare the processor against the Sprint 3 accelerator.
    - Metrics come from Quartus quartus_map (.map.rpt) and timing (.sta.rpt): ALMs, registers, memory blocks, and Fmax.
  - 14.2 Engineering tools attribute (HI): justify the choice of the test and simulation tools (Cocotb, Questa, Verilator, SignalTap).
  - 14.3 All metrics come from real Quartus runs. Do not write numbers that were not measured.

15. Demo and defense preparation:
  - 15.1 Be able to explain the execution logic in hardware.
  - 15.2 Map an injected fault to its observed behavior using SignalTap.

# Infrastructure plan

17. Infrastructure
- 17.1 Firmware tool: `firmware.hex` is generated from `firmware.s` with the `gcc-riscv64-unknown-elf` toolchain (`as -march=rv32i -mabi=ilp32`, `objcopy -O binary -j .text`, `xxd`) inside `sprint4/firmware/`. Only `firmware.s` and `firmware.hex` are versioned, so the CI does not need the toolchain.
- 17.2 CI changes (`gatekeeper.yml` and `Dockerfile`):
  - Run `make -C sprint4/test/cocotb` (team unit and system tbs) on every PR that touches `sprint4`.
  - Also run the professor's tbs in `sprint4/test/rv32i_cocotb`: `make test_cpu` and `make test_programs`, both with `SV_FILELIST=files.f TOPLEVEL=rv32i_cpu` (without them the Makefile builds the professor's mock instead of our CPU).
  - The `Dockerfile` must install `pytest-html` (the `test_cpu` dashboard uses `--html`).
  - A failure in any `make` of the loop must fail the job (accumulate the exit status).
- 17.3 Structure of `sprint4/`: `src/` (RTL), `test/cocotb/` (unit and system tbs), `test/rv32i_cocotb/` (professor's repo plus the `rv32i_cpu*.sv` wrappers), `firmware/`, `scripts/`, `quartus/` and `docs/`. Any change is documented in `README.md`.

# Git and GitHub

16. Git and GitHub specific requirements
- 16.1 New code starts in feature branches linked to an Issue.
- 16.2 Feature branches are integrated into dev through Pull Requests reviewed by both team members.
- 16.3 main receives its code from dev only.
- 16.4 The commit history shows incremental development: more than 20 commits.
- 16.5 GitHub Actions runs Verilator and Cocotb on every PR.
- 16.6 Questa simulations are automated with scripts, .do files, or Makefiles.
- 16.7 Tags per deliverable:
  - 16.7.1 v0.0.0-proj (Avance 0, features.md)
  - 16.7.2 v0.0.1-proj (Avance 1, architecture.md)
  - 16.7.3 v0.0.2-proj (Avance 2, all instructions simulated)
  - 16.7.4 v0.1.0-proj (Avance 3, synthesis and firmware on the board)
  - 16.7.5 v1.0.0-proj (final delivery, 30 Nov 2026)
- 16.8 Any change to the directory structure is documented in README.md.
- 16.9 The repository link is delivered through TEC Digital.
- 16.10 SystemVerilog code follows the style guidelines kept during the course and in previous sprints.







--------------------------------------

Clasificación de módulos reutilizables (detalle y cambios en `architecture.md`, sección 10)

- From sprint0: none
- From sprint1: `alu_param.sv`, `alu_types_pkg.sv`, `decoder_4x16.sv`, `seven_segment_adapter.sv` (reused without changes)
- From sprint2: `key_sync.sv` (reused without changes); `binary_to_bcd_converter.sv` and `toggle.sv` are not used in sprint4
- From sprint3:
  - `vjtag_interface.sv` and the `vjtag` IP: reused without changes (`vjtag_sim_stub.sv` is for tbs only)
  - `arbiter.sv`: modified (two managers, CPU keeps the bus until ready, new `mux_is_cpu` output)
  - `mmio_decoder.sv`: modified (Tabla 2 addresses, per-manager permissions, RAZ/WI, 1-cycle read ready)
  - `control_registers.sv`: modified (LEDR, HEX, CTRL, STATUS, THRESHOLD; outputs `start`, `cpu_enable`, `busy`, `done`)
  - `ram.sv`: modified (four memories and a second read port for the instruction bus)