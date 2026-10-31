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

# Epic 2

2. Create an enabler for the processor.
  - When disabled (`enabler == 1'b0`), the FSM can't change its state, and the `ready out` and `valid out` signals of both the instruction and data buses (4 signals) are 0.
    - They each connect to an AND gate with the enabler before exiting the processor.

  - Connect the enable directly to the first bit of CTRL.
    - (This is just a possible implementation)

3. Modify the existing MMIO decoder with the new MMIO addresses in Tabla 2.

# Epic 3

This is particularly straightforward. Look at sections 1.2 and 5.1 in the original `ce3201_G1_final_project_instructions.pdf`.

4. Make a RISC-V assembly program (this is the firmware) that does the following:

  > Etapa A (Inicialización): Limpia con ceros las 256 direcciones de la memoria del Histograma.
  >
  > Etapa B (Cálculo del Histograma): Recorre la imagen de entrada leyendo cada píxel e incrementa la frecuencia del valor de intensidad correspondiente en la región de memoria dedicada al histograma.
  >
  > Etapa C (Binarización): Lee el umbral desde el registro THRESHOLD, compara cada píxel de entrada contra el umbral, asigna 255 si P(y,x) ≥ TH o 0 en caso contrario, y guarda el resultado en la región de memoria dedicada a la imagen de salida.

  - 4.1 The program also executes `STATUS = 1` at the end.
  - 4.2 The program ends in an infinite loop to freeze itself?

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
  - 8.2 MMIO decoder
  - 8.3 RAM
  - 8.4 Control registers (some changes to allow the step-by-step mode in the processor must be considered).

9. Create/add:
  - 9.1 Adapt the RV32I tb from the provided repository.
  - 9.2 A module to join the buses from the processor is being considered. It would need its own tb.


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


"Clasificación de módulos reutilizables"
    From sprint0
        none
    From sprint1
        alu_param.sv
        alu_types_pkg.sv (its associated package)
        decoder_4x16.sv (display related)
        seven_segment_adapter.sv (display related)
    From sprint2
        binary_to_bcd_converter (display related, right size)
        key_sync.sv
        toggle.sv
        (there's no mode selector module in our sprint2, that was implemented inside the execute fsm itself as will be inside the processor for sprint4)
    From sprint3
        arbiter.sv (directly requested in the specs. Modifications are needed and requested too)
        mmio_decoder.sv (directly requested in the specs)
        contorl_registers.sv
        memory_mapped_register_file.sv (won't need the MMIO part as it is now inside the RV32I)
        ram.sv
        vjtag_interface.sv
        vjtag_sim_stub.sv (tbs still require driving the jtag)

