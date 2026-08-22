\# Sprint 0 - FPGA Physical Validation



\## 1. Objective



The objective of this validation is to synthesize, implement, program, and physically verify the Sprint 0 parity checker on an FPGA.



The validation also includes resource utilization and timing analysis using Quartus Prime.



\---



\## 2. FPGA Board



The hardware available for the physical validation was a \*\*Terasic DE10-Standard\*\* board.



The FPGA device configured in Quartus Prime was:



\- Family: Cyclone V SX

\- Device: `5CSXFC6D6F31C6`



The Sprint 0 instructions reference a DE1-SoC board. However, the board available for the physical implementation was a DE10-Standard, so the Quartus device and pin assignments were updated accordingly.



\---



\## 3. Design



The FPGA top-level module is:



```text

parity\_checker\_top

