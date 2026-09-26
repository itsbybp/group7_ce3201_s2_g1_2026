# Resultados de Verificación — Sprint 2

## Epic 1 — register_bank.sv y key_sync.sv

### Cocotb (Icarus Verilog)

Ejecutado con `make all` en `sprint2/test/cocotb/`.

```
register_bank: TESTS=6 PASS=6 FAIL=0 SKIP=0
key_sync:      TESTS=5 PASS=5 FAIL=0 SKIP=0
```

11/11 pruebas pasando.

### Questa (SystemVerilog)

Ejecutado con los scripts `.do` en `sprint2/test/sv/`, generando
`questa_test_summary.log`:

```
ERRORS=0
WARNINGS=0
ALL_TESTS_PASSED
```

**Waveforms documentados:** `register_bank.wlf`, `key_sync.wlf` (generados
por `run_register_bank.do` y `run_key_sync.do`, con las señales de control,
selección de registros, datos, y resultado formateadas automáticamente en
el `.do`).

### Síntesis (Quartus Prime) — datapath Epic 1 (key_sync + register_bank)

**Dispositivo:** Cyclone V, `5CSXFC6D6F31C6` (DE10-Standard)

**Flow Status:** `Successful`

| Métrica | Valor |
|---|---|
| Logic utilization (ALMs) | 5 / 41,910 (< 1%) |
| Total registros | 11 |
| Total pines | 67 / 499 (13%) |
| Total bloques de memoria | 0 |
| Total bloques DSP | 0 |

### Timing (Quartus Timing Analyzer) — datapath Epic 1

Restricción de reloj: `CLOCK_50` a 20.000 ns (50 MHz), definida en
`sprint2/quartus/sdc/timing_constraints.sdc`. Ruta de `KEY[0]` excluida del
análisis (`set_false_path`), por ser intencionalmente asíncrona.

| Modelo | Worst-case setup slack | Worst-case hold slack |
|---|---|---|
| Slow 1100mV 85C | 14.858 ns | 0.438 ns |
| Slow 1100mV 0C | 15.077 ns | 0.438 ns |
| Fast 1100mV 85C | 16.716 ns | 0.268 ns |
| Fast 1100mV 0C | 17.063 ns | 0.254 ns |

Todos los slacks son positivos — el diseño cumple con sus requisitos de
temporización en las 4 esquinas de operación analizadas.

## Epic 2 / Epic 3 — input_fsm.sv, exec_fsm.sv, toggle.sv, binary_to_bcd_converter.sv, display_logic.sv, top_level.sv completo

### Cocotb (Icarus Verilog)

Ejecutado con `make input_fsm`, `make exec_fsm`, `make display_logic` y
`make top_level` en `sprint2/test/cocotb/`.

```
input_fsm:      TESTS=7 PASS=7 FAIL=0 SKIP=0
exec_fsm:       TESTS=6 PASS=6 FAIL=0 SKIP=0
display_logic:  TESTS=4 PASS=4 FAIL=0 SKIP=0
top_level:      TESTS=1 PASS=1 FAIL=0 SKIP=0
```

18/18 pruebas pasando (el caso de `top_level` es un escenario de uso
completo end-to-end que ejercita ambas FSMs, la ALU, el banco de
registros y los displays en una sola corrida).

### Questa (SystemVerilog)

Ejecutado con los scripts `.do` en `sprint2/test/sv/`
(`run_input_fsm.do`, `run_exec_fsm.do`, `run_top_level.do`, además de
`run_key_sync.do` y `run_register_bank.do`), generando
`questa_test_summary.log`:

```
key_sync:       errors=0 warnings=0 passed=True
register_bank:  errors=0 warnings=0 passed=True
input_fsm:      errors=0 warnings=0 passed=True
exec_fsm:       errors=0 warnings=0 passed=True
top_level:      errors=0 warnings=0 passed=True
------------------------------------------------
ERRORS=0
WARNINGS=0
ALL_TESTS_PASSED
```

`top_level` corrió 24/24 checks (`TOTAL_CHECKS=24`), cubriendo entrada
serial de nibbles, selección de registros/opcode, ejecución automática y
paso a paso, y las tres pruebas de escritura descritas en `tb_top_level.sv`.

### Síntesis (Quartus Prime) — top_level.sv completo (ambas FSMs integradas)

**Dispositivo:** Cyclone V, `5CSXFC6D6F31C6` (DE10-Standard)

**Flow Status:** `Successful`

| Métrica | Valor |
|---|---|
| Logic utilization (ALMs) | 373 / 41,910 (< 1%) |
| Total registros | 112 |
| Total pines | 67 / 499 (13%) |
| Total bloques de memoria | 0 |
| Total bloques DSP | 0 |

### Timing (Quartus Timing Analyzer) — top_level.sv completo

Restricción de reloj: `CLOCK_50` a 20.000 ns (50 MHz), definida en
`sprint2/quartus/sdc/timing_constraints.sdc`.

| Modelo | Worst-case setup slack | Worst-case hold slack |
|---|---|---|
| Slow 1100mV 85C | 10.855 ns | 0.374 ns |
| Slow 1100mV 0C | 10.921 ns | 0.373 ns |
| Fast 1100mV 85C | 14.466 ns | 0.181 ns |
| Fast 1100mV 0C | 14.993 ns | 0.171 ns |

Todos los slacks son positivos — el diseño completo (input_fsm, exec_fsm,
ALU, banco de registros y display_logic integrados) cumple con sus
requisitos de temporización en las 4 esquinas de operación analizadas.

Estos artefactos (`questa_test_summary.log`, `*.wlf`, `*.flow.rpt`,
`*.map.rpt`, `*.sta.rpt`) son además los que el Gatekeeper exige en cada
Pull Request que modifique `sprint2/`.