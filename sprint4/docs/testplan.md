# Plan de pruebas: Sprint 4 (Procesador RV32I multiciclo)

## 1. Alcance

Este plan cubre:

- La verificación del procesador con el repo de pruebas del profesor (Epic 4, pruebas de núcleo).
- Las pruebas unitarias heredadas de Sprint 3 que se adaptan al Sprint 4.
- Las pruebas nuevas de Sprint 4: enabler, modo pulse, mapa MMIO y end-to-end.
- La síntesis y las mediciones en hardware.

## 2. Herramientas

| Herramienta | Uso | Estado |
|---|---|---|
| Cocotb + Verilator 5.052 | Repo del profesor (`rv32i_cocotb_template`) | Ejecutada (pasan 29/29) |
| Cocotb + Verilator | Validación con el mock CPU del profesor | Ejecutado |
| Questa (`.do`) | Pruebas unitarias de Sprint 3 | Pendiente en Sprint 4 |
| Quartus Prime | Síntesis, reportes `.map.rpt` y `.sta.rpt` | Pendiente: no hay top de Sprint 4 |
| SignalTap | Captura de FSM y bus en hardware | Pendiente |

## 3. Matriz de pruebas

| ID | Prueba | Alcance | Herramienta | Comando | Criterio de aceptación | Estado (11 nov) |
|---|---|---|---|---|---|---|
| TP-01 | Prueba del repo | Mock CPU del profesor | Cocotb + Verilator | `make test_cpu` | 29/29 PASS | Ejecutada: 29/29 |
| TP-02 | Validación con el repo | `rv32i_cpu` (diseño del equipo) | Cocotb + Verilator | `make test_cpu SV_FILELIST=files.f TOPLEVEL=rv32i_cpu` | 29/29 PASS | Ejecutada: 29/29 |
| TP-03 | Árbitro | `arbiter` | Questa | `run_arbiter.do` | ERRORS=0, WARNINGS=0 | Pendiente en Sprint 4 (ejecutada en Sprint 3) |
| TP-04 | Contador | `counter` | Questa | `run_counter.do` | ERRORS=0, WARNINGS=0 | Pendiente en Sprint 4 (ejecutada en Sprint 3) |
| TP-05 | FSM de Sprint 3 | `fsm` | Questa | `run_fsm.do` | ERRORS=0, WARNINGS=0 | Pendiente en Sprint 4 (ejecutada en Sprint 3) |
| TP-06 | Decodificador MMIO | `mmio_decoder` | Cocotb | `make` del módulo | Chip selects según Tabla 2, RAZ/WI | Pendiente: cambia con Tabla 2 |
| TP-07 | RAM | `ram` | Cocotb | `make` del módulo | Lectura de 1 ciclo y puertos independientes | Pendiente en Sprint 4 |
| TP-08 | Registros de control | `control_registers` | Questa | `run_control_registers.do` | Escritura y lectura de CTRL, STATUS, TIMER_LIMIT, THRESHOLD; `write_en=0` no modifica | Pendiente: debe adaptarse a Tabla 2 |
| TP-09 | Reg file x0–x31 | `memory_mapped_register_file` | Questa | `run_memory_mapped_register_file.do` | x0 siempre 0; escritura y reset | Pendiente en Sprint 4 |
| TP-10 | Enabler | `rv32i_cpu` con `enable = 0` | Cocotb o Questa | Por definir | La FSM no cambia de estado y los cuatro `valid`/`ready` son 0 | Ejecutada: sin `valid` activo con `enable = 0` |
| TP-11 | Modo pulse | `rv32i_cpu` con pulse | Cocotb o Questa | Por definir | Avanza un paso por pulso de un ciclo | Pendiente: no implementado |
| TP-12 | Stalls de memoria | `rv32i_cpu` con `ready = 0` | Cocotb | Por definir | La FSM se congela y no pierde datos | Pendiente |
| TP-13 | End-to-end | CPU, árbitro, RAM y MMIO con `firmware.hex` y una imagen reducida | Questa | Por definir | Histograma e imagen de salida exactos | Pendiente |
| TP-14 | Síntesis | Top de Sprint 4 | Quartus | Compilación del `.qpf` | Flow Status: Successful; reportes `.map.rpt` y `.sta.rpt` | Pendiente: no hay top |
| TP-15 | Captura en hardware | FSM, PC, instrucción, `valid`/`ready`, `done` | SignalTap | Por definir | Captura a 50 MHz guardada en `results.md` | Pendiente |

## 4. Evidencia del Avance 1

Ejecución del repo con el procesador propio, `TP-02`:

```
TESTS=29 PASS=28 FAIL=1 SKIP=0
FAILED cocotb/test_dashboard.py::test_cocotb_case[jalr]
```

Archivos en `docs/evidencia/avance1/`:

- `avance1_cocotb.log`: salida de consola completa.
- `coverage.json`: bins cubiertos y conteo de hits.
- `dashboard_cpu.html`: resultado por prueba y cobertura por instrucción.

## 5. Evidencia del Avance 2

Ejecución del repo con el procesador propio, `TP-02`:

```
TESTS=29 PASS=29 FAIL=0 SKIP=0
```

Cobertura: 29/29 bins (100 %).

Archivos en `docs/evidencia/avance2/`:

- `avance2_cocotb.log`: salida de consola completa.
- `coverage.json`: bins cubiertos y conteo de hits.
- `dashboard_cpu.html`: resultado por prueba y cobertura por instrucción.