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

El código fuente y las suites de prueba (Cocotb y Questa) para estos
módulos ya están implementados:

- `input_fsm.sv` / `test_input_fsm.py` / `tb_input_fsm.sv`
- `exec_fsm.sv` / `test_exec_fsm.py` / `tb_exec_fsm.sv`
- `display_logic.sv` / `test_display_logic.py`
- `top_level.sv` (integrado) / `test_top_level.py` / `tb_top_level.sv`

**Estado:** esta sección está pendiente de completarse con la evidencia
real de una corrida local, ya que las transcripciones de estas ejecuciones
específicas (Cocotb y Questa para estos módulos, y la síntesis en Quartus
del `top_level.sv` con ambas FSMs integradas) todavía no se han generado en
este entorno. No se reportan números aquí para evitar registrar resultados
no verificados.

Para completar esta sección, ejecutar localmente y pegar la salida real:

```bash
# Cocotb (Icarus Verilog)
cd sprint2/test/cocotb
make input_fsm
make exec_fsm
make display_logic
make top_level

# Questa (SystemVerilog)
cd sprint2/test/sv
vsim -c -do run_input_fsm.do -l input_fsm_transcript.log
vsim -c -do run_exec_fsm.do -l exec_fsm_transcript.log
vsim -c -do run_top_level.do -l top_level_transcript.log
python parse_logs.py

# Síntesis en Quartus del top_level completo (con ambas FSMs)
# Abrir sprint2/quartus/top_level.qpf y ejecutar Compilación Completa,
# o desde línea de comandos:
quartus_sh --flow compile top_level
```

Una vez generados `questa_test_summary.log` (con `ERRORS=0`, `WARNINGS=0`,
`ALL_TESTS_PASSED`) y los reportes `*.flow.rpt`/`*.map.rpt`/`*.sta.rpt` con
`Successful`, reemplazar este apartado con:

- Los conteos `TESTS=N PASS=N FAIL=0 SKIP=0` de cada módulo Cocotb.
- El resumen `ERRORS=0 WARNINGS=0 ALL_TESTS_PASSED` de Questa.
- Los recursos de síntesis (ALMs, registros, pines) del `top_level.fit.rpt`.
- Los slacks de *setup*/*hold* del `top_level.sta.rpt` para las 4 esquinas
  de operación, usando el mismo `timing_constraints.sdc`.

Estos artefactos (`questa_test_summary.log`, `*.wlf`, `*.flow.rpt`,
`*.map.rpt`, `*.sta.rpt`) son además los que el Gatekeeper exige en cada
Pull Request que modifique `sprint2/`, por lo que deben generarse de todas
formas antes de abrir el PR de Epic 2/Epic 3, independientemente de esta
documentación.