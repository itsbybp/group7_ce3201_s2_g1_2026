# Resultados de Verificación — Sprint 2 (Epic 1)

## Cocotb (Icarus Verilog)

Ejecutado con `make all` en `sprint2/test/cocotb/`.

```
register_bank: TESTS=6 PASS=6 FAIL=0 SKIP=0
key_sync:      TESTS=5 PASS=5 FAIL=0 SKIP=0
```

11/11 pruebas pasando.

## Questa (SystemVerilog)

Ejecutado con los scripts `.do` en `sprint2/test/sv/`, generando
`questa_test_summary.log`:

```
ERRORS=0
WARNINGS=0
ALL_TESTS_PASSED
```

**Waveforms documentados:** `register_bank.wlf`, `key_sync.wlf`
(generados por `run_register_bank.do` y `run_key_sync.do`, con las
señales de control, selección de registros, datos, y resultado
formateadas automáticamente en el `.do`).

## Síntesis (Quartus Prime)

**Dispositivo:** Cyclone V, `5CSXFC6D6F31C6` (DE10-Standard)

**Flow Status:** `Successful`

| Métrica | Valor |
|---|---|
| Logic utilization (ALMs) | 5 / 41,910 (< 1%) |
| Total registros | 11 |
| Total pines | 67 / 499 (13%) |
| Total bloques de memoria | 0 |
| Total bloques DSP | 0 |

## Timing (Quartus Timing Analyzer)

Restricción de reloj: `CLOCK_50` a 20.000 ns (50 MHz), definida en
`sprint2/quartus/sdc/timing_constraints.sdc`. Ruta de `KEY[0]` excluida
del análisis (`set_false_path`), por ser intencionalmente asíncrona.

| Modelo | Worst-case setup slack | Worst-case hold slack |
|---|---|---|
| Slow 1100mV 85C | 14.858 ns | 0.438 ns |
| Slow 1100mV 0C | 15.077 ns | 0.438 ns |
| Fast 1100mV 85C | 16.716 ns | 0.268 ns |
| Fast 1100mV 0C | 17.063 ns | 0.254 ns |

Todos los slacks son positivos — el diseño cumple con sus requisitos de
temporización en las 4 esquinas de operación analizadas.

## Pendiente (Epic 2)

Los resultados de `input_fsm.sv` y `exec_fsm.sv` (Cocotb, Questa, y
síntesis del `top_level.sv` completo con ambas FSMs integradas) se
documentarán en esta sección una vez implementadas.