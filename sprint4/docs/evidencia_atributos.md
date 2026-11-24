# Evidencia de atributos: Sprint 4

**Proyecto:** CE3201 Taller de Diseño Digital, Grupo 7. Atributos DI (diseño de ingeniería) y HI (herramientas de ingeniería). Todos los números salen de reportes de Quartus Prime 25.1std.0 Build 1129 (Lite), dispositivo Cyclone V 5CSXFC6D6F31C6, reloj de 20 ns.

---

## 1. DI: comparación del procesador RV32I (Sprint 4) con el acelerador de Sprint 3

Sprint 3 es un acelerador de procesamiento de imágenes de lógica dedicada (FSMs y contador); Sprint 4 resuelve la misma tarea (histograma y binarización) con un procesador RV32I multiciclo, un árbitro, un decodificador MMIO, RAM y registros de control, controlado por firmware.

| Métrica | Sprint 3 (acelerador, 25 oct) | Sprint 4 sin SignalTap (19 nov) | Sprint 4 con SignalTap (23 nov) |
|---|---|---|---|
| ALMs | 1 044 / 41 910 (2 %) | 1 609 / 41 910 (4 %) | 2 173 / 41 910 (5 %) |
| Registros | 1 705 | 1 773 | 3 256 |
| Bits de memoria | 1 048 576 (19 %) | 1 187 840 (21 %) | 1 810 432 (32 %) |
| Bloques RAM (M10K) | 128 / 553 (23 %) | 143 / 553 (26 %) | 219 / 553 (40 %) |
| DSP | 0 | 0 | 0 |
| Fmax `clk`, 85 °C | 82,03 MHz | 67,33 MHz | 63,53 MHz |
| Fmax `clk`, 0 °C | 84,13 MHz | 68,79 MHz | 64,38 MHz |

Fuentes: `sprint3/quartus/output_files/top_level.fit.summary` y `top_level.sta.rpt`; `sprint4/quartus/output_files/` (19 nov) y `sprint4/docs/evidencia/final/top_level.*.summary` (23 nov). Los Fmax son los de la tabla "Fmax Summary" de cada `top_level.sta.rpt`.

### Lectura de los datos

- **Área.** El procesador usa 565 ALMs más que el acelerador (+54 %: 1 609 contra 1 044) y 15 M10K más (143 contra 128, +12 %). Los registros casi no cambian (+68, +4 %). El costo está en la lógica: el banco de registros, la ALU, la FSM de control, el árbitro y el decodificador MMIO.
- **Frecuencia.** Fmax baja de 82,03 a 67,33 MHz (-14,70 MHz, -18 %) en el peor caso (85 °C). Ambos cumplen los 50 MHz de la placa; el camino crítico del procesador multiciclo es más largo que el de las FSMs dedicadas.
- **Flexibilidad.** Cambiar el algoritmo (por ejemplo el umbral o el procesamiento) en Sprint 4 es cambiar `firmware.hex`, sin resintetizar. En Sprint 3 era cambiar el hardware. La velocidad de Sprint 4 es de ~83 ciclos por píxel (~27,3 ms para 16384 píxeles a 50 MHz, calculado de la simulación); no se midió el tiempo equivalente del acelerador de Sprint 3 en este trabajo, por lo que no se compara velocidad.
- **Costo de SignalTap.** Instrumentar el diseño agrega 564 ALMs, 1 483 registros, 76 M10K y 622 592 bits, y baja Fmax a 63,53 MHz; sigue cumpliendo 50 MHz con 4,260 ns de slack. Para comparar con Sprint 3 se usa la columna sin SignalTap.
- **Salvedad sobre Sprint 3 (suposición).** El `.qsf` de Sprint 3 tiene `ENABLE_SIGNALTAP ON`, pero los valores del `fit.summary` de Sprint 3 (128 M10K, 1 048 576 bits) coinciden con memorias del diseño y no con una instancia de SignalTap, por lo que se toman como una compilación sin SignalTap. Conviene confirmarlo si se requiere una comparación estricta.

### Decisiones de diseño que explican los números

| Decisión | Razón |
|---|---|
| Arquitectura multiciclo (4 a 5 ciclos por instrucción) | Reutiliza una sola ALU y una sola memoria de datos; menos ALMs que un diseño de un ciclo o segmentado |
| Harvard con bus de instrucciones independiente (AC 3) | El fetch no compite con el Host ni con los datos; la RAM de instrucciones tiene puerto propio |
| Árbitro solo en el bus de datos (el Host tiene prioridad) | El Host (vJTAG) puede leer y escribir la RAM mientras el CPU está parado, y el CPU espera con `ready` si hay colisión |
| Memorias en M10K con lectura de 1 ciclo | Evita usar ALMs como memoria; el costo es 2 ciclos por instrucción buscada (`imem_ready` alterna) |
| `busy`/`done` en hardware (`cpu_enable = start && !done`) | El firmware no necesita controlar el arranque; el CPU se congela solo al terminar |
| Solo `lw`/`sw` por palabras de 32 bits (AC 1) | Un píxel por palabra; menos lógica de alineación |

---

## 2. HI: herramientas utilizadas y justificación

| Herramienta | Uso en el proyecto | Por qué se eligió |
|---|---|---|
| Cocotb 2.1.0 + Verilator 5.053 | Repo del profesor (29 casos y 2 programas), pruebas unitarias y de sistema de Sprint 4, incluida la imagen completa de 16384 píxeles | Los modelos de referencia (histograma, binarización, xorshift, factorial) se escriben en Python y se comparan palabra por palabra. Verilator simula la imagen completa (59 391 822 ns) en 19,35 s reales. Corre sin licencia en WSL y en GitHub Actions |
| Icarus Verilog (con cocotb) | Pruebas negativas de Sprint 1 y banco de registros | Simulador de 4 valores: permite inyectar y detectar `X`, que Verilator (2 valores) no representa |
| Questa (`.do`) | Pruebas SystemVerilog de los Sprints 0 a 3 | Es la herramienta del curso para esos bancos y la que valida el gatekeeper (`questa_test_summary.log`). No corre en WSL, por eso no se repitió en Sprint 4 |
| Quartus Prime 25.1 Lite | Síntesis, ajuste y análisis de timing (`.fit.summary`, `.map.rpt`, `.sta.rpt`) | Es la herramienta que soporta el Cyclone V de la DE10-Standard en su edición gratuita. Sus reportes son la fuente de todas las métricas de la sección 1 |
| SignalTap | Captura en la placa de FSM, PC, instrucción, `valid`/`ready` y `done` a 50 MHz | Muestra el comportamiento real del diseño sin instrumentos externos ni cambios al RTL (solo marcas `keep`); la simulación no puede mostrar el comportamiento en la placa |
| vJTAG + `jtag_server.tcl` (`quartus_stp`) + `pixel_image_app.py` | Carga de `firmware.hex` y la imagen, arranque, lectura del histograma y la imagen de salida | Reutiliza el USB-Blaster de la placa; el cliente Python compara contra el mismo modelo que las pruebas cocotb |
| GitHub Actions (gatekeeper) | Verifica los artefactos de Quartus y Questa de cada sprint y corre las pruebas cocotb | Evita que se integre código sin evidencia |

Limitaciones de las herramientas encontradas: la prueba 3.2 de Sprint 1 usa `cocotb.binary`, que cocotb 2.1.0 ya no tiene; Questa no corre en WSL.