This document compiles a list of somewhat easy to follow tasks necessary for the project. 
As many as they could be gleaned from the original specs as possible while
still being meaningfull or not too abstract to implement.
Basically the specs without the bs* 

# Epic 1

Make a Harvard architecture, multicycle RV32I processor with only the instructions from Tabla 1 that passes the testbench (tb) in this repository:
https://github.com/rgarciatec/rv32i_cocotb_template

- The **Fetch**, **MemRead**, and **MemWrite** (not MemAdr) states should use ready/valid when interacting with memory.
  - This means they should freeze if a read or write doesn't go through instead of assuming they got or wrote a value in a single cycle.

- The processor should also be modified so that it advances using one of two options at a time: the clock or a pulse.
  - The pulse is a signal that is at 0 by default and is synchronously set to 1 for a single cycle at any moment.
  - It usually stays at 0 for many cycles between activations because it is ultimately driven by a button on the FPGA.
    - Driving this signal is not part of this requirement. This is implemented in the top module later on.

# Epic 2

- Create an enabler for the processor.
  - When disabled (`enabler == 1'b0`), the FSM can't change its state, and the `ready out` and `valid out` signals of both the instruction and data buses (4 signals) are 0.
    - They each connect to an AND gate with the enabler before exiting the processor.

  - Connect the enable directly to the first bit of CTRL.
    - This is just a possible implementation and might be wrong!

- Modify the existing MMIO decoder with the new MMIO addresses in Tabla 2.

# Epic 3

This is particularly straightforward. Look at sections 1.2 and 5.1 in the original `ce3201_G1_final_project_instructions.pdf`.

- Make a RISC-V assembly program (this is the firmware) that does the following:

  > Etapa A (Inicialización): Limpia con ceros las 256 direcciones de la memoria del Histograma.
  >
  > Etapa B (Cálculo del Histograma): Recorre la imagen de entrada leyendo cada píxel e incrementa la frecuencia del valor de intensidad correspondiente en la región de memoria dedicada al histograma.
  >
  > Etapa C (Binarización): Lee el umbral desde el registro THRESHOLD, compara cada píxel de entrada contra el umbral, asigna 255 si P(y,x) ≥ TH o 0 en caso contrario, y guarda el resultado en la región de memoria dedicada a la imagen de salida.

  - The program also executes `STATUS = 1` at the end.
  - The program ends in an infinite loop to freeze itself?

- Modify the Python program from sprint3 so that it can also binarize (umbralize?) images so that it can validate whether the process was correct.
  - at p. 2, near the end.

- Modify the Python program so that it periodically checks the STATUS register to know if the processor has finished.

- Modify the Python program so that it requests and saves the histogram too.
  - The image and histograms should be accessed using the MMIO addresses defined in Tabla 2.

- Modify the Python program so that it writes the firmware as well as the input image in RAM.

- "Automatización en Python vía vJTAG". This is already done in Sprint 3?

# Epic 4 - Testplan

- Create testbenches (tbs) for important modules. In this case, the processor uses the provided cocotb tb, and other modules that are adapted from Sprint 3 can use altered versions of their corresponding tbs.
- The end-to-end tb is the last and most important one.
  - It is described in section 6.2.

## Proposed tbs

- Update the tbs from Sprint 3 for these modules:
  - Arbiter
  - MMIO decoder
  - RAM
  - Control registers (some changes to allow the step-by-step mode in the processor must be considered).

- Create/add:
  - Adapt the RV32I tb from the provided repository.
  - A module to join the buses from the processor is being considered. It would need its own tb.


## Verification scenarios
- End-to-end tb: CPU, arbiter and memories run firmware.hex with a reduced image size.
  - Verifies that instructions are safely retained during stalls on the Harvard buses.
  - Verifies the exact histogram and the exact output image.
  - Results go to sprint4/docs/results.md.
- Memory-collision scenarios are documented in the testplan and validated with Questa and Cocotb.
- Stalls: when either bus reports ready = 0, the processor freezes until the transaction completes.
- Enabler: with enable = 0, the FSM does not change state and the four valid/ready signals are 0.
- Read-As-Zero: reads from unmapped addresses return 0.
- Write-Ignored: writes to instruction memory from the CPU and out-of-range writes are discarded.
- The testbenches run with no lint warnings in Verilator and Cocotb.

## Additional verification and documentation

- Signal Tap should now observe the FSM in the control unit of the multicycle processor, as per section 6.3.
  - Capture the main FSM, PC, decoded instruction, valid/ready, and done, at 50 MHz.
  - Captures are real and go into sprint4/docs/results.md.

- All this should be documented in sprint4/docs/testplan.md, hopefully beforehand.

- Create sprint4/docs/evidencia_atributos.md as per section 6.4.
  - Design attribute (DI): compare the processor against the Sprint 3 accelerator.
    - Metrics come from Quartus quartus_map (.map.rpt) and timing (.sta.rpt): ALMs, registers, memory blocks, and Fmax.
  - Engineering tools attribute (HI): justify the choice of the test and simulation tools (Cocotb, Questa, Verilator, SignalTap).
  - All metrics come from real Quartus runs. Do not write numbers that were not measured.

- Demo and defense preparation:
  - Be able to explain the execution logic in hardware.
  - Map an injected fault to its observed behavior using SignalTap.

# Git and GitHub

- New code starts in feature branches linked to an Issue.
- Feature branches are integrated into dev through Pull Requests reviewed by both team members.
- main receives its code from dev only.
- The commit history shows incremental development: more than 20 commits.
- GitHub Actions runs Verilator and Cocotb on every PR.
- Questa simulations are automated with scripts, .do files, or Makefiles.
- Tags per deliverable:
  - v0.0.0-proj (Avance 0, features.md)
  - v0.0.1-proj (Avance 1, architecture.md)
  - v0.0.2-proj (Avance 2, all instructions simulated)
  - v0.1.0-proj (Avance 3, synthesis and firmware on the board)
  - v1.0.0-proj (final delivery, 30 Nov 2026)
- Any change to the directory structure is documented in README.md.
- The repository link is delivered through TEC Digital.
- SystemVerilog code follows the style guidelines kept during the course and in previous sprints.

\* bonus stuff