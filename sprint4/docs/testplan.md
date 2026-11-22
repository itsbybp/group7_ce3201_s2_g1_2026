# Plan de pruebas: Sprint 4 (Procesador RV32I multiciclo)

## 1. Alcance

Este plan cubre:

- La verificación del procesador con el repo de pruebas del profesor (Epic 4, pruebas de núcleo).
- Las pruebas unitarias heredadas de Sprint 3 que se adaptan al Sprint 4.
- Las pruebas nuevas de Sprint 4: enabler, modo paso a paso, mapa MMIO y end-to-end.
- La síntesis y las mediciones en hardware.

## 2. Herramientas

| Herramienta | Uso | Estado |
|---|---|---|
| Cocotb 2.1.0 + Verilator 5.053 (devel) | Repo del profesor (`rv32i_cocotb_template`) | Ejecutada (pasan 29/29) |
| Cocotb + Verilator | Validación con el mock CPU del profesor | Ejecutado |
| Cocotb + Verilator | Pruebas unitarias y de sistema de Sprint 4 (`sprint4/test/cocotb`) | Ejecutadas |
| Questa (`.do`) | Pruebas unitarias de Sprint 3 | Pendiente en Sprint 4 |
| Quartus Prime 25.1 Lite | Síntesis, reportes `.map.rpt`, `.fit.summary` y `.sta.rpt` | Ejecutada el 19 nov |
| SignalTap | Captura de FSM y bus en hardware | Pendiente |

## 3. Matriz de pruebas

| ID | Prueba | Alcance | Herramienta | Comando | Criterio de aceptación | Estado (20 nov) |
|---|---|---|---|---|---|---|
| TP-01 | Prueba del repo | Mock CPU del profesor | Cocotb + Verilator | `make test_cpu` | 29/29 PASS | Ejecutada en Avance 1: 29/29 |
| TP-02 | Validación con el repo | `rv32i_cpu` (diseño del equipo) | Cocotb + Verilator | `make test_cpu SV_FILELIST=files.f TOPLEVEL=rv32i_cpu` | 29/29 PASS | Ejecutada el 21 nov: 29/29 (el caso `lui` ahora prueba cinco inmediatos) |
| TP-03 | Árbitro | `arbiter` | Cocotb | `make arbiter` | Prioridad del Host, backpressure y CPU conserva el bus | Ejecutada el 21 nov: 8/8 |
| TP-04 | Contador | `counter` | Questa | `run_counter.do` | ERRORS=0, WARNINGS=0 | Pendiente en Sprint 4 (ejecutada en Sprint 3) |
| TP-05 | FSM de Sprint 3 | `fsm` | Questa | `run_fsm.do` | ERRORS=0, WARNINGS=0 | Pendiente en Sprint 4 (ejecutada en Sprint 3) |
| TP-06 | Decodificador MMIO | `mmio_decoder` | Cocotb | `make mmio_decoder` | Chip selects según Tabla 2, RAZ/WI | Ejecutada el 21 nov: 7/7 |
| TP-07 | RAM | `ram` | Cocotb | `make ram` | Lectura de 1 ciclo y puertos independientes | Ejecutada el 21 nov: 8/8 |
| TP-08 | Registros de control | `control_registers` | Cocotb | `make control_registers` | Escritura y lectura de CTRL, STATUS, LEDR, HEX, THRESHOLD; sin `we` no modifica | Ejecutada el 21 nov: 10/10 |
| TP-09 | Reg file x0–x31 | `memory_mapped_register_file` | Questa | `run_memory_mapped_register_file.do` | x0 siempre 0; escritura y reset | Pendiente en Sprint 4 |
| TP-10 | Enabler | `rv32i_cpu` con `enable = 0` | Cocotb | `make test_cpu SV_FILELIST=files_enable.f TOPLEVEL=rv32i_cpu_enable` | Con `enable = 0` ninguna instrucción se completa (todas las pruebas terminan por timeout) | Ejecutada el 20 nov: 29/29 casos con timeout a 300 ciclos (pytest 30 failed), 0 instrucciones completadas |
| TP-11 | Modo pulse | `rv32i_cpu` con pulse | Hardware (DE10-Standard) | SW[0] y KEY[1] | Cada pulsación de KEY[1] avanza la FSM hasta el siguiente estado | Implementada en `top_level` y compilada; falta probarla en la placa |
| TP-12 | Stalls de bus | `rv32i_top` con el Host leyendo al azar | Cocotb | `make top` (`test_firmware_with_bus_stalls`) | La CPU espera y no pierde datos | Ejecutada el 21 nov: PASS con 64 píxeles (1507 lecturas, ~9792 ciclos) y con 16384 píxeles (220 363 lecturas, ~1 440 192 ciclos) |
| TP-13 | End-to-end | CPU, árbitro, RAM y MMIO con `firmware.hex` y una imagen reducida | Cocotb | `make top` (`test_firmware_end_to_end`) | Histograma e imagen de salida exactos | Ejecutada el 21 nov: PASS con 64 píxeles (~9280 ciclos; bucle reducido, ver `results.md`) y con la imagen completa de 16384 píxeles, firmware sin modificar (~1 363 840 ciclos, `FULL_IMAGE=1`) |
| TP-14 | Síntesis | Top de Sprint 4 | Quartus | Compilación del `.qpf` | Flow Status: Successful; reportes `.map.rpt` y `.sta.rpt` | Ejecutada el 19 nov: Fitter Successful, 1609 ALMs, Fmax 67,33 MHz (ver `results.md`, sección 6) |
| TP-15 | Captura en hardware | FSM, PC, instrucción, `valid`/`ready`, `done` | SignalTap | Por definir | Captura a 50 MHz guardada en `results.md` | Pendiente |
| TP-16 | Carga por vJTAG y ejecución en la placa | `jtag_server.tcl` y `pixel_image_app.py` con `firmware.hex` y una imagen | Hardware + Python | Programar la FPGA, abrir `jtag_server.tcl` y ejecutar `pixel_image_app.py` | Histograma e imagen de salida correctos; `STATUS.done` en la placa | Pendiente |
| TP-17 | Programas completos | `rv32i_cpu`: factorial recursivo y xorshift32 con estadísticas | Cocotb + Verilator | `make test_programs SV_FILELIST=files.f TOPLEVEL=rv32i_cpu` | 2/2 PASS, resultados iguales a Python | Ejecutada el 21 nov: 2/2 (en `v0.0.2-proj`: 1/2, `xorshift` fallaba por LUI; ver `results.md`, sección 5) |
| TP-18 | Búsqueda fuera de rango | `rv32i_top`: PC fuera de la RAM de instrucciones (0x0000–0x1FFF) | Cocotb | `make top` (`test_fetch_fuera_de_rango_lee_cero`) | La instrucción leída es 0 (RAZ), decodifica como ilegal y la CPU no se bloquea (AC 5, Tabla 2) | Ejecutada el 21 nov: PASS (búsquedas `0x0, 0x2000, 0x2004, …`) |

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

Ejecución del repo con el procesador propio, `TP-02` (tras corregir FETCH y JALR, ver `results.md`):

```
TESTS=29 PASS=29 FAIL=0 SKIP=0
```

Pytest: 30 passed. Cobertura: 29/29 bins (100 %), según `coverage.json`.

Archivos en `docs/evidencia/avance2/`:

- `avance2_cocotb.log`: salida de consola completa.
- `coverage.json`: bins cubiertos y conteo de hits.
- `dashboard_cpu.html`: resultado por prueba y cobertura por instrucción.
- `avance2_unit_system.log`: salida de `make all` en `sprint4/test/cocotb` (4 pruebas unitarias y prueba de sistema).

## 6. Evidencia del Avance 3

Archivos en `docs/evidencia/avance3/`:

- `avance3_full_image.log`: `FULL_IMAGE=1 make top` (3/3 PASS, 16384 píxeles).
- `avance3_enabler.log`: prueba del enabler (29 timeouts esperados, pytest 30 failed).
- `avance3_unit_system.log`: `make all` (4 pruebas unitarias y prueba de sistema).
- `avance3_cocotb.log`, `coverage.json`, `dashboard_cpu.html`: corrida normal de TP-02 (29/29, pytest 30 passed) después del cambio de CPU.
- `avance3_programs.log`: `make test_programs` sobre `rv32i_cpu` (2/2 PASS, TP-17), después del arreglo de LUI.
- Reportes de Quartus: `top_level.fit.summary`, `top_level.map.rpt`, `top_level.sta.rpt`.