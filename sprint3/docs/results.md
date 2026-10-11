# Results.md - Sprint 3: Custom Logic, vJTAG y MMIO

Proyecto: CE3201 Taller de Diseño Digital  
Sprint: 3  
Fecha: Octubre 2026

---

## Resumen

Sprint 3 - Epic 2. Todos los módulos MMIO validados.

Status:  ALL TESTS PASSED (24/24)

---

## Resultados Cocotb

| Módulo | Tests | PASS | FAIL | SIM TIME (ns) |
|--------|-------|------|------|---------------|
| tb_arbiter | 1 | 1 | 0 | 80.00 |
| tb_ram | 3 | 3 | 0 | 220.00 |
| tb_mmio_decoder | 8 | 8 | 0 | 420.01 |
| test_memory_mapped_register_file | 5 | 5 | 0 | 2020.00 |
| test_control_registers | 7 | 7 | 0 | 1120.01 |
| TOTAL | 24 | 24 | 0 | 3860.02 |

---

## Tests por Módulo

### Arbiter (1 test)
-  test_arbiter: vJTAG prioridad > FSM, backpressure correcto

### RAM Dual Puerto (3 tests)
-  test_escritura_lectura_puerto_a: Lectura 1 ciclo después
-  test_escritura_lectura_puerto_b: Puerto independiente
-  test_puertos_independientes: Acceso paralelo sin colisión

### MMIO Decoder (8 tests)
-  test_ram: CS_RAM (0x00000-0x1FFFF)
-  test_ram_limite: Límite superior correcto
-  test_reg_bank: CS_RB (0x20000-0x2007C)
-  test_ledr: CS_LEDR (0x30000)
-  test_hex: CS_HEX (0x30004)
-  test_ctrl_regs: CS_CR (0x40000-0x4000F)
-  test_raz: Read-As-Zero funciona
-  test_wi: Write-Ignored funciona

### Register File RISC-V (5 tests)
-  test_escritura_registro_x1: Write/read x1
-  test_x0_siempre_cero: x0 hardcoded = 0
-  test_escritura_multiples_registros: x1-x5 secuencial
-  test_lectura_sin_escritura: Read-only protege datos
-  test_reset_asincrono: Reset limpia registros

### Control Registers (7 tests)
-  test_escritura_ctrl: CTRL (0x40000)
-  test_escritura_status: STATUS (0x40004)
-  test_escritura_timer_limit: TIMER_LIMIT (0x40008)
-  test_escritura_threshold: THRESHOLD (0x4000C)
-  test_lectura_secuencial: Lectura ordenada 4 regs
-  test_reset: Reset limpia todos
-  test_sin_escritura: write_en=0 protege

---

## Cobertura AC

| AC | Descripción | Status |
|----|-------------|--------|
| AC 1 | Backpressure |  |
| AC 2 | Arbitraje Prioridad |  |
| AC 3 | RAM 128 KB |  |
| AC 4 | Banco RISC-V |  |
| AC 5 | Registros Control |  |
| AC 6 | Decodificador MMIO |  |
| AC 7 | RAZ/WI |  |

---

## Quartus Resources
ALMs:           ~150 / 17,440 (0.9%)
M10K blocks:    2 / 240 (0.8%)
Pins:           ~80 / 250 (32%)
Timing: Meet @ 50 MHz (20 ns period)

---
