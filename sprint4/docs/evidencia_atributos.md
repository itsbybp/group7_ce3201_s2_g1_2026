# Evidencia de atributos: Sprint 4

**Proyecto:** CE3201 Taller de Diseño Digital, Grupo 7. Atributos DI (diseño de ingeniería) y HI (herramientas de ingeniería), con la gobernanza del uso de IA (sección 3).
**Herramienta de síntesis:** Quartus Prime 25.1std.0 Build 1129 (Lite), Cyclone V 5CSXFC6D6F31C6, reloj `clk` de 20 ns (`sprint3/sdc/timing_constraints.sdc`).

**Convención de las cifras.** *Medido*: copiado de un reporte (`.fit.rpt`, `.map.rpt`, `.sta.rpt`, `.flow.rpt`, log de cocotb, CSV de SignalTap). *Calculado*: obtenido de cifras medidas con la fórmula indicada. Todo lo que no sale de un reporte se marca **(suposición)**. Las estimaciones teóricas se rotulan "estimación".

---

## 1. DI: procesador RV32I (Sprint 4) contra el acelerador de Sprint 3

Sprint 3 es un acelerador de lógica dedicada que **solo binariza** (FSM `fsm.sv` de 10 estados, ALU con `code = SUB` fijo, contador de timeout; no calcula histograma). Sprint 4 hace histograma y binarización con un procesador RV32I multiciclo, un árbitro, un decodificador MMIO, RAM y registros de control, guiado por firmware.

### 1.1 Compilaciones y su procedencia

Los reportes de Sprint 3 que quedaron en el repositorio vienen de **dos compilaciones distintas**; se verificó con la fecha interna de cada reporte y con el historial de git. Por eso se comparan cuatro compilaciones.

| Id | Fecha del reporte | Archivos (commit) | SignalTap | RTL |
|---|---|---|---|---|
| S3-a | 25 oct 2026, 14:47–14:48 | `sprint3/quartus/output_files/top_level.fit.rpt`, `.fit.summary`, `.map.summary`, `.sta.summary` (9ebdca9) | No: 1 048 576 bits = solo `mem_in` y `mem_out` | Acelerador de Sprint 3 |
| S3-b | 26 oct 2026, 04:04–04:05 | `.map.rpt`, `.sta.rpt`, `.flow.rpt` (4d0d145). El `.map.rpt` contiene 183 referencias a `sld_signaltap` | Sí (`ENABLE_SIGNALTAP ON` en el `.qsf` de Sprint 3) | Mismo RTL funcional (suposición: el commit e22113f, 25 oct 16:37, solo separa sentencias por línea en `top_level.sv`) |
| S4-a | 19 nov 2026, 00:23–00:25 (repetida el 21 nov, 08:25–08:28, con los mismos totales y el mismo Fmax) | `sprint4/docs/evidencia/avance3/` (`.fit.summary`, `.map.rpt`, `.sta.rpt`) y `top_level.fit.rpt` de la repetición del 21 nov (Fitter Successful a las 08:27:21), de donde sale la tabla por entidad | No | RTL anterior al arreglo de LUI y al filtro de búsqueda de `rv32i_top` (commits del 21 nov, 22:54) |
| S4-b | 23 nov 2026, 15:58–16:00 | `sprint4/docs/evidencia/final/`: `.fit.summary`, `.map.summary`, `.sta.rpt`, `.sta.summary`, y los `.fit.rpt`, `.map.rpt` y `.flow.rpt` de la misma compilación; los `cp_*.rpt` del 24 nov salen de su base de datos (sección 1.5) | Sí (`stp_rv32i.stp`: 8 192 muestras × 76 bits) | RTL final: el último commit en `sprint4/src` es del 21 nov (22:54) |

El `fit.summary` de Sprint 3 que citaba el Avance 3 (1 044 ALMs) es S3-a. Los Fmax de 82,03 y 84,13 MHz que se le asociaban son de S3-b, de modo que mezclaban dos compilaciones; la retroalimentación de Sprint 3 ya había señalado que los reportes versionados no coincidían con las cifras del `results.md` y que el flujo estaba fechado el 26 oct 04:05. Aquí cada columna usa solo su propia compilación. El Fmax de S3-a no está en un `.sta.rpt`; se calcula (sección 1.2) a partir del slack de su `.sta.summary`.

### 1.2 Métricas globales

| Métrica | S3-a (sin ST) | S3-b (con ST) | S4-a (sin ST) | S4-b (con ST) |
|---|---|---|---|---|
| ALMs (fit) | 1 044 / 41 910 (2 %) | 1 565 (4 %) | 1 609 (4 %) | 2 173 (5 %) |
| Registros (fit) | 1 705 | 3 263 | 1 773 | 3 256 |
| ALMs estimados tras la síntesis (`.map.rpt`) | n/d (`.map.summary` dice N/A) | 2 026 | 1 640 | 2 327 |
| Registros tras síntesis (`.map`) | 1 678 | 3 218 | 1 662 | 3 100 |
| ALUT combinacionales | 1 139 (fit) | 1 495 (map) | 1 929 (fit); 1 927 (map) | 2 386 (fit); 2 382 (map) |
| Bits de memoria | 1 048 576 | 1 061 760 | 1 187 840 | 1 810 432 |
| Bloques M10K | 128 / 553 | n/d | 143 | 219 (40 %) |
| DSP | 0 | 0 | 0 | 0 |
| Slack de setup `clk`, 85 °C | 7,706 ns | 7,809 ns | 5,148 ns | 4,260 ns |
| Fmax `clk`, 85 °C | 81,34 MHz (calculado) | 82,03 MHz | 67,33 MHz | 63,53 MHz |
| Fmax `clk`, 0 °C | n/d | 84,13 MHz | 68,79 MHz | 64,38 MHz |
| Hold mínimo `clk`, 85 °C | 0,364 ns | 0,294 ns | 0,283 ns | 0,317 ns |
| Fmax `altera_reserved_tck`, 85 °C | n/d | 64,26 MHz | 106,21 MHz | 59,88 MHz |

"n/d": no figura en los archivos que están en el repositorio. Todos los TNS valen 0,000. Todas las compilaciones cumplen los 50 MHz de la placa.

Los Fmax de `.sta.rpt` coinciden con `1 / (20 ns − slack de setup)`: 7,809 → 82,03; 8,114 → 84,13; 5,148 → 67,33; 5,463 → 68,79; 4,260 → 63,53; 4,468 → 64,38 MHz (las seis, a ±0,01 MHz). Se usa la misma fórmula para S3-a.

### 1.3 Comparación pareada (calculada)

| Pareja | ALMs | Registros | Bits de memoria | M10K | Fmax `clk`, 85 °C |
|---|---|---|---|---|---|
| Sin SignalTap: S3-a → S4-a | +565 (+54,1 %) | +68 (+4,0 %) | +139 264 (+13,3 %) | +15 (+11,7 %) | 81,34 → 67,33 MHz: −14,01 (−17,2 %) |
| Con SignalTap: S3-b → S4-b | +608 (+38,8 %) | −7 (−0,2 %) | +748 672 (+70,5 %) | n/d | 82,03 → 63,53 MHz: −18,50 (−22,6 %) |

La pareja sin SignalTap es la comparación de diseño; la pareja con SignalTap muestra que la conclusión no depende de la instrumentación (en ambas el procesador cuesta más ALMs y baja Fmax). Los +139 264 bits son exactamente 2 × 65 536 (RAM de instrucciones, dos copias, sección 1.4.3) + 8 192 (histograma).

### 1.4 Correlación con los módulos RTL

#### 1.4.1 ALMs por bloque

Valores de la tabla "Fitter Resource Utilization by Entity" de cada `.fit.rpt` (ALMs necesarios, jerárquicos; la suma de los hijos reproduce al padre, por ejemplo `multicycle_rv32i:cpu` 1 332,5 = 221,1 + 319,1 + 35,2 + 757,1 en S4-b).

| Bloque (módulo RTL) | S3-a | S4-a | S4-b | Δ S4-a − S3-a |
|---|---|---|---|---|
| Banco de registros (`rv_register_file`; en S3 `memory_mapped_register_file`, periférico MMIO) | 232,5 | 743,6 | 757,1 | +511,1 |
| ALU (`alu_param`) | 12,8 | 291,1 | 319,1 | +278,3 |
| Datapath propio, unidad de control, FSM y decodificadores (`multicycle_rv32i`, `multicycle_rv_control_unit`, `multicycle_rv_control_fsm`) | n/a | 242,6 | 256,3 | +242,6 |
| `counter` + `fsm` de Sprint 3 | 83,3 | n/a | n/a | −83,3 |
| `mmio_decoder` | 328,4 | 104,9 | 110,0 | −223,5 |
| `arbiter` | 25,1 | 25,0 | 29,3 | −0,1 |
| `control_registers` | 38,1 | 29,2 | 28,5 | −8,9 |
| `ram` (lógica de control; las M10K no cuentan como ALM) | 4,0 | 6,1 | 4,0 | +2,1 |
| vJTAG (`vjtag_interface`, IP `vjtag`, `sld_hub`) | 111,2 | 81,0 | 135,7 | −30,2 |
| BCD, `seven_segment_adapter`, `key_sync` | 75,1 | 22,1 | 22,1 | −53,0 |
| Lógica propia de `top_level` y `rv32i_top` | 132,6 | 62,7 | 70,8 | −69,9 |
| Instancia SignalTap (`sld_signaltap`) | n/a | n/a | 439,8 | n/a |
| **Suma** | 1 043,1 | 1 608,3 | 2 172,7 | +565,2 |
| Total reportado | 1 043,5 | 1 608,5 | 2 173,0 | +565,0 |

Las sumas difieren del total en ≤ 0,4 ALM por el redondeo a una décima de cada entidad.

Lectura (los números salen de la tabla; las causas son de diseño y se marcan donde no se pudieron verificar):

- **El aumento lo explican tres bloques: banco de registros (+511,1), ALU (+278,3) y datapath/control de la CPU (+242,6), en total +1 032,0 ALMs.** El resto del diseño baja 466,8 ALMs netos (decodificador −223,5, `counter` y `fsm` −83,3, lógica propia del top −69,9, displays y BCD −53,0, vJTAG −30,2, `control_registers` −8,9; `ram` +2,1 y árbitro −0,1), de modo que el neto es +565,2.
- **Banco de registros (232,5 → 743,6).** En S3 era un periférico con un puerto de lectura que entregaba el dato por el bus; en S4 es interno, con **dos puertos de lectura simultáneos** (`rs1`, `rs2`) y una escritura. Teoría: un mux 32:1 por bit y por puerto necesita 8 mux 4:1 + 2 mux 4:1 + 1 mux 2:1 = 11 ALUT de 6 entradas, es decir 2 puertos × 32 bits × 11 = **704 ALUT (estimación)**. El reporte da 740 ALUT combinacionales (S4-a) y 741 (S4-b), +5 % sobre la estimación (el resto es el decodificador de escritura 5→32 y la compuerta de `x0`). Como cada función de 6 entradas ocupa un ALM completo, 741 ALUT corresponden a 757,1 ALMs (1,02 ALM por ALUT).
- **Decodificador MMIO (328,4 → 104,9).** En S3 el decodificador contenía el mux de lectura de 32 palabras del banco de registros MMIO (512 ALUT combinacionales en S3; 189 en S4-a). La diferencia, 323 ALUT, es del orden de un mux 32:1 de 32 bits (352 ALUT, estimación). Es consistente con que en S4 ese mux ya no está en el decodificador sino en el banco de registros interno (suposición: no se separó el costo del mux en el reporte de S3).
- **ALU (12,8 → 291,1).** En S3 la ALU se instanció con `code = SUB` constante y solo se usan sus banderas (`.result()` sin conectar): una resta de 32 bits más la detección de cero. En S4 es la ALU completa: suma/resta, AND/OR/XOR, desplazamientos lógico y aritmético (SLL, SRL, SRA), `slt` y `sltu`, con la operación elegida por `alu_control`. Estimación por bit: sumador (cadena de acarreo, 2 bits por ALM) 16 ALM, lógica 32 ALUT, desplazador de barril de 5 etapas con inversión de bits ≈ 160 ALUT, banderas y mux de salida ≈ 80 ALUT; total ≈ 300 ALUT. El reporte da 371 (S4-a) y 417 (S4-b) ALUT; el orden de magnitud coincide y la diferencia (+25 %…+39 %) no se puede atribuir con este reporte.
- **FSM de control.** La FSM se declara con un `enum` de 11 estados (4 bits en binario), pero Quartus la recodifica a **One-Hot** (tabla "State Machine" del `.map.rpt`, "Encoding Type: One-Hot", Auto en "State Machine Processing"): 11 registros, uno por estado, con FETCH como código de todos ceros (el bit `current_state.FETCH` vale 0 solo en FETCH y 1 en los otros diez estados). La entidad `control_fsm` reporta 11 registros tras la síntesis (`.map.rpt`) y 14 tras el ajuste: 11 + 3 duplicados del fitter (tabla "Fitter Netlist Optimizations"). Teoría: one-hot gasta 7 FF más que los 4 bits binarios, pero cada estado se decodifica leyendo un solo bit y no un comparador de 4 bits, lo que acorta el camino de las salidas de control; ningún nodo de la FSM figura en el camino crítico medido (sección 1.5). El costo es de 7 ALMs de registros en una FPGA de 41 910.
- **Árbitro y registros de control.** Cambian poco entre S3 y S4 (25,1 → 25,0/29,3 y 38,1 → 29,2/28,5). Los registros de control bajan de 128 (4 registros de 32 bits: CTRL, STATUS, TIMER_LIMIT y THRESHOLD) a 68 porque S4 solo guarda los bits usados (sección 1.4.2).

#### 1.4.2 Registros: teoría contra reporte (S4-b)

La diferencia entre el total del fitter (3 256) y el de la síntesis (3 100) es de **156 registros, exactamente la cantidad de nodos "Duplicated" de la tabla "Fitter Netlist Optimizations"** (motivo "Router Logic Cell Insertion and Logic Duplication", "Routability optimization"). Reparto de los 156 duplicados: banco de registros 123, SignalTap 13, `sld_hub` 9, datapath de la CPU 4, FSM de control 3, y uno en cada uno de `arbiter`, `control_registers`, `mmio_decoder` y `vj_state`.

| Módulo | Registros teóricos (RTL) | Duplicados | Reportado (fit) |
|---|---|---|---|
| `rv_register_file` | 31 × 32 = 992 (sin `x0`) | 123 | 1 115 |
| `multicycle_rv32i` (propio) | 7 × 32 = 224 (`pc`, `old_pc`, `instruction`, `read_data_reg`, `rs1_data_reg`, `rs2_data_reg`, `alu_result_reg`) − 2 (el bit 0 de `pc` y de `old_pc` es constante 0 por `pc <= {wb_mux[31:1], 1'b0}`) = 222 | 4 | 226 |
| `multicycle_rv_control_fsm` | 11 (One-Hot, tabla "State Machine" del `.map.rpt`) | 3 | 14 |
| `control_registers` | `start`, `done`, `threshold` (8), `ledr` (10), `hex` (24) = 44, más `selected_register` con sus 24 bits bajos útiles (los 8 altos son siempre 0) = 68 | 1 | 69 |
| `top_level` (propio) | `addr_sync_q` 3 + `write_sync_q` 3 + `jtag_addr_q` 32 + `jtag_wdata_q` 32 + `read_data_q` 32 + `vj_state` 4 + `step_mode_sync_q` 2 + `step_active_q` 1 + `step_ref_q` 4 = 113 | 1 | 114 (= 3 256 − suma de las demás entidades) |

Cinco de cinco módulos cuadran exactamente. Los bits constantes los elimina la síntesis (tabla "Registers Removed During Synthesis" del `.map.rpt`, "Stuck at GND"): `pc[0]`, `old_pc[0]` y `selected_register[24..31]`. Los registros no cambian entre S3-a y S4-a (+4 %) porque el banco de registros ya existía como periférico (992 FF en S3) y los datos grandes viven en las M10K, no en FF.

#### 1.4.3 Memoria: M10K y bits

| Memoria | Tamaño | Bits | M10K | Teoría (modo ancho × profundidad de la M10K) |
|---|---|---|---|---|
| Imagen de entrada (`mem_in`) | 16 384 × 32 | 524 288 | 64 | Modo 8K×1: ⌈16 384 / 8 192⌉ = 2 bloques por bit × 32 bits = 64 |
| Imagen de salida (`mem_out`) | 16 384 × 32 | 524 288 | 64 | 64 |
| Histograma (`mem_hist`) | 256 × 32 | 8 192 | 1 | Modo 256×40 (o 256×32): 1 bloque |
| RAM de instrucciones, copia 0 (`mem_instr_rtl_0`) | 2 048 × 32 | 65 536 | 7 | Modo 2K×5: ⌈32 / 5⌉ = 7 bloques |
| RAM de instrucciones, copia 1 (`mem_instr_rtl_1`) | 2 048 × 32 | 65 536 | 7 | 7 |
| **Total** | | **1 187 840** | **143** | 64 + 64 + 1 + 7 + 7 = 143 |

Los bits reportados suman exactamente 2 × 524 288 + 8 192 + 2 × 65 536 = 1 187 840. Los modos de la M10K (8K×1, 2K×5, 256×40) son los del Cyclone V; los tamaños por bloque salen de la hoja de datos y no se verificaron en este proyecto (suposición). Los 143 bloques son el 25,9 % de los 553 de la FPGA.

La RAM de instrucciones aparece **duplicada** en S4-a y S4-b (`mem_instr_rtl_0` y `mem_instr_rtl_1`, 7 M10K cada una). El RTL de `ram.sv` pide una escritura y dos lecturas con direcciones independientes (puerto de datos del Host, con `we_instr`/`re_instr` sobre `addr[12:2]`, y puerto de instrucciones de la CPU, con `imem_addr[12:2]`); el reporte no dice por qué se duplicó. Hipótesis (suposición): un bloque M10K ofrece un puerto de escritura y uno de lectura en doble puerto simple, de modo que 1 escritura + 2 lecturas independientes necesitan una segunda copia que reciba las mismas escrituras. Costo de la decisión: 7 M10K (1,3 % de la FPGA) y 65 536 bits (5,5 % del total). Beneficio: la búsqueda de instrucciones no pasa por el árbitro (AC 3, dos buses independientes) y el Host puede leer y escribir la RAM de instrucciones sin detener a la CPU. S3 no tenía esta RAM: 128 M10K = 64 + 64.

#### 1.4.4 Dispersión de la atribución entre compilaciones

Módulos cuyo RTL no cambió entre S4-a y S4-b reportan ALMs distintos: `vjtag_interface` 27,0 → 52,3; `alu_param` 291,1 → 319,1; `arbiter` 25,0 → 29,3. Es variación de empaquetado del fitter y no del diseño; por eso los ALMs por módulo tienen una incertidumbre de ±10 % (suposición: orden de magnitud tomado de estos tres casos) y solo las diferencias grandes de la tabla 1.4.1 (banco de registros, ALU, decodificador) son concluyentes. Los totales y los conteos de M10K y bits son exactos.

#### 1.4.5 Costo de SignalTap

| | ALMs | Registros | Bits | M10K | Fmax `clk`, 85 °C |
|---|---|---|---|---|---|
| S4-b − S4-a (calculado) | +564 | +1 483 | +622 592 | +76 | −3,80 MHz (−5,6 %); incluye el arreglo de LUI (sección 1.5) |
| Directo, entidad `sld_signaltap` (S4-b) | 439,8 | 1 420 | 622 592 | 76 | n/a |
| Aumento de `sld_hub` (S4-b − S4-a) | +29,6 | +34 | 0 | 0 | n/a |
| S3-b − S3-a (calculado) | +521 | +1 558 | +13 184 | n/d | n/d |

Bits y M10K cuadran con la teoría: 8 192 muestras × 76 bits = 622 592 bits = 76 bloques de 8 192 bits. De los +564 ALMs, 469,4 son atribuibles a SignalTap (439,8 + 29,6); los **94,6 ALMs restantes (y 29 registros) son diferencias del resto del diseño entre S4-a y S4-b** (RTL del 19 al 23 nov y variación del fitter, sección 1.4.4), no instrumentación. Lo mismo vale para Fmax: de los −3,80 MHz (0,888 ns de periodo), el nivel de decodificación `is_lui` que añadió el arreglo de LUI (0,802 ns, sección 1.5) puede explicar la mayor parte, así que el costo de SignalTap en Fmax no se puede separar con las compilaciones disponibles (suposición). Para comparar con Sprint 3 se usa la pareja sin SignalTap.

### 1.5 Fmax y camino crítico

**Qué dicen los reportes.** `clk` es el único reloj del diseño de 50 MHz; el peor camino de `clk` fija Fmax = 1 / (20 ns − slack). En S4-b el slack es 4,260 ns, de modo que el camino crítico de `clk` dura 20 − 4,260 = **15,74 ns** (calculado). En S4-a dura 14,85 ns y en S3-b 12,19 ns. El `.sta.rpt` entregado solo trae el slack por reloj y no la ruta, así que la ruta se obtuvo con el Timing Analyzer sobre la misma base de datos (apartado siguiente).

**Cómo se midió.** El 24 nov se ejecutó `quartus_sta -t ../scripts/critical_path.tcl` desde `sprint4/quartus` (Timing Analyzer de Quartus Prime 25.1std.0, 0 errores y 0 advertencias) con el SDC de `sprint3/sdc/timing_constraints.sdc` y el modelo "Slow 1100mV 85C". La base de datos es la de la última compilación (S4-b, con SignalTap). El script tiene tres partes y todos los reportes están en `sprint4/docs/evidencia/final/`: (1) el peor camino global: `cp_peor_camino.rpt` (nodo por nodo), `cp_20_peores.rpt`, `cp_hold_peor.rpt` y `cp_fmax.rpt`, cuyo slack (4,260 ns) y Fmax (63,53 MHz) son los de `top_level.sta.rpt`; (2) la peor holgura por grupo de registros de origen o de destino: `cp_real_cpu.rpt`, `cp_real_bus_cpu.rpt`, `cp_real_bus_host.rpt` y `cp_real_resto.rpt`; (3) dos excepciones de ruta falsa declaradas solo durante el análisis: `cp_exc_peor_camino.rpt` y `cp_exc_5_peores.rpt` (apartado "Más allá del peor camino"). La tabla por etapa de más abajo suma los incrementos de cada nodo de `cp_peor_camino.rpt`; sus totales reproducen el retardo de datos (15,908 ns), la interconexión (9,283 ns), las celdas (6,625 ns) y los 12 niveles de LUT del reporte.

**Resultado (medido).**

| Propiedad | Valor |
|---|---|
| Origen | `multicycle_rv32i:cpu\|instruction[3]` (registro de instrucción, bit 3 del código de operación) |
| Destino | `ram:ram_inst\|altsyncram:mem_out_rtl_0\|…\|ram_block1a30~porta_we_reg` (registro de write enable de una M10K de `mem_out`) |
| Llegada del dato | 19,713 ns = 3,805 (reloj hasta el origen) + 15,908 (camino de datos) |
| Dato requerido | 23,973 ns = 20,000 (periodo) + 4,103 (reloj hasta el destino) + 0,040 (pesimismo de reloj eliminado) − 0,170 (incertidumbre de reloj) |
| Holgura | 23,973 − 19,713 = **4,260 ns** (el sesgo de reloj, 0,338 ns, juega a favor) |
| Camino de datos | 15,908 ns en 12 niveles de LUT: celdas 6,625 ns (41,6 %; las 12 LUT suman 5,238 ns y la M10K 1,387 ns) e interconexión 9,283 ns (58,4 %) |
| Fmax | 1 000 / (20 − 4,260) = 63,53 MHz |

**Desglose por etapa** (suma de los incrementos de cada nodo del peor camino; entre paréntesis, el fan-out de la salida del nodo):

| # | Etapa | Nodos de Quartus (fan-out de la salida) | RTL | Celdas (ns) | Ruteo (ns) | Total (ns) | % |
|---|---|---|---|---|---|---|---|
| 1 | Control | `instruction[3]` (9) → `control_unit\|Equal0~0` (7) → `alu_decoder_instance\|Mux0~2` (6) → `cpu\|always7~2` (28) | `op` → `is_lui` y `alu_funct_3` (`multicycle_rv_control_unit.sv`) → `alu_control` (`alu_decoder.sv`) → condición `alu_control == SLL/SRL/SRA` del bloque `alu_operand_b_shifts` (`multicycle_rv32i.sv`) | 1,275 | 0,919 | 2,194 | 13,8 |
| 2 | ALU | `alu_operand_b_shifts[24]~24` (2) → `rv32i_alu\|ShiftLeft0~3` (6) → `ShiftRight0~0` (44) → `ShiftRight0~13` (1) → `Selector4~0` (4) | Máscara de `b` para desplazamientos y desplazadores de `alu_param` (`a << b`, `a >> b`, `$signed(a) >>> b`) con el mux de resultado por `code` (`sprint1/src/alu_param.sv`) | 2,166 | 3,618 | 5,784 | 36,4 |
| 3 | Decodificador MMIO | `mmio_decoder_inst\|always0~9` (3) → `always0~10` (4) → `always0~11` (7) | Decodificación de rango `sel` y `we_*` (`mmio_decoder.sv`); `wb_mux`, `address_data_memory` y el mux de dirección del árbitro no aparecen como celdas propias: Quartus los absorbió en estas LUT o en `Selector4~0` (suposición) | 1,321 | 2,213 | 3,534 | 22,2 |
| 4 | Decodificador de bloque de la RAM | `ram_inst\|mem_out_rtl_0\|auto_generated\|decode2\|eq_node[0]~1` (32) | Lógica que Quartus genera para el `altsyncram` de `mem_out` (16 384 palabras sobre bloques de 8K × 1, sección 1.4.3): combina `we_out` con el bit alto de `img_addr` y alimenta 32 bloques (la función es suposición; el fan-out de 32 es del reporte) | 0,476 | 0,312 | 0,788 | 5,0 |
| 5 | Entrada de escritura de la M10K | `ram_block1a30\|portawe` → `porta_we_reg` | Registro interno de write enable de la M10K | 1,387 | 2,221 | 3,608 | 22,7 |
| | **Total** | 12 LUT y 1 M10K | | **6,625** | **9,283** | **15,908** | 100 |

Los porcentajes suman 100,1 por redondeo. `always7` y `always0` son los nombres que Quartus da a los bloques `always` en orden de aparición: el séptimo de `multicycle_rv32i.sv` es el de `alu_operand_b_shifts` y el primero de `mmio_decoder.sv` es el `always_comb` de `sel` (suposición por la numeración; el fan-out de 28 es compatible con los 27 bits altos de `b` que se ponen a 0 en un desplazamiento).

**Hipótesis contra medición.** Antes de medir se plantearon cuatro candidatos a partir del RTL:

| Hipótesis | Resultado |
|---|---|
| P1: resta → `zero` → condición de salto → habilitación de `pc` | No aparece entre los 20 peores caminos (todos terminan en una M10K, holgura ≥ 4,434 ns), pero eso era un efecto del filtro: la familia estructural hacia la M10K tapa los caminos hacia `pc`. Al medir por destino, el peor camino hacia los registros de la CPU termina en `pc` (4,677 ns, 65,26 MHz) y, con las excepciones E1 y E2, es el peor de todo el diseño (4,989 ns, 66,62 MHz). Confirmada en la estructura; el origen medido (`instruction`) no se activa (apartado "Más allá del peor camino") |
| P2: instrucción → decodificador de ALU → ALU | Confirmada: es la primera mitad del peor camino medido (etapas 1 y 2) |
| P3: handshake → habilitación de registros de instrucción | Descartada: no figura entre los 20 peores |
| P4: dirección del bus de datos → árbitro → decodificador MMIO → write enables de las M10K | Confirmada en la segunda mitad (etapas 3 a 5); el origen no es `alu_result_reg` (un registro) sino la salida combinacional de la ALU |

**Lectura.**

- **Los 20 peores caminos son una misma estructura.** Todos terminan en el `porta_we_reg` de una M10K (15 en `mem_out` y 5 en `mem_in`; 5 bloques y 16 pares origen-destino distintos), con holguras de 4,260 a 4,434 ns y retardos de datos de 15,73 a 15,91 ns. Nacen en bits de `instruction` (13 caminos, bits 1, 3, 4, 5 y 6) o del campo `rs1` (7 caminos, bits 1 a 3), que direcciona la lectura del banco de registros hacia el operando A de la ALU (suposición: solo se entregó el detalle del peor). Ninguno termina en `pc`, en el banco de registros ni en la FSM. El 20.º tiene 4,434 ns de holgura, de modo que cualquier camino fuera de la lista dura como máximo 20 − 4,434 = 15,57 ns (calculado).
- **El ruteo pesa más que la lógica (58 % contra 42 %).** Las 12 LUT cuestan 5,238 ns (0,44 ns por nivel) y la interconexión 9,283 ns. Las conexiones más lentas salen de nodos con muchas cargas: 2,221 ns tras `eq_node[0]~1` (fan-out 32, hacia las `portawe` de las M10K, que están en la columna X69 mientras esa LUT está en la X47), 1,049 ns tras `ShiftRight0~0` (fan-out 44) y 0,859 ns tras `always7~2` (fan-out 28). Teoría: con muchas cargas el retardo lo fija la distancia a la carga más lejana y no la LUT, así que acortar la lógica ayuda menos que reducir el fan-out o registrar la señal.
- **Es un camino estructural que el funcionamiento no activa (lectura del RTL; el efecto en Fmax no se midió).** La dirección del bus de datos es `address_data_memory = wb_mux`. `wb_mux` toma `alu_result`, la salida combinacional de la ALU, solo con `result_src = 2'b10`, y `result_src = {current_state == FETCH, current_state == MEM_WB}` (`multicycle_rv_control_fsm.sv`): esa rama entrega PC + 4 al `pc` en FETCH (decisión 10 de `architecture.md`). Una escritura ocurre en MEM_WRITE, donde `result_src = 2'b00` y la dirección sale del registro `alu_result_reg`; en FETCH `valid_out_data_memory` vale 0 (solo vale 1 en MEM_READ y MEM_WRITE), de modo que `wr = valid && write_en` es 0 y ningún `we_*` se levanta. FETCH y MEM_WRITE son estados excluyentes, pero Quartus analiza la estructura combinacional y no conoce esa exclusión, así que cronometra ALU → `wb_mux` → decodificador → `we_out` como si pudiera completarse en un ciclo. Consecuencia: 63,53 MHz (S4-b) y 67,33 MHz (S4-a) son una **cota inferior** de la frecuencia que soporta la CPU. Los 20 peores caminos son de esta familia y tapan a los demás; el apartado "Más allá del peor camino" mide qué hay debajo.
- **Relación con la caída de Fmax de Sprint 3 a Sprint 4.** En Sprint 3 la ALU solo se usaba por sus banderas (`.result()` sin conectar, sección 1.4.1) y su salida no llegaba a ningún bus. En Sprint 4 `alu_result` llega por `wb_mux` a la dirección del bus de datos y de ahí al decodificador y a las M10K; la caída de 14,01 MHz entre S3-a y S4-a es consistente con ese camino nuevo (suposición: no hay reporte de rutas de S3-a ni de S4-a).
- **El arreglo de LUI añadió un nivel a este camino.** `control_unit|Equal0~0` (0,802 ns: 0,304 de ruteo y 0,498 de celda) es el comparador `is_lui = (op == 7'b0110111)` que agregó el commit `0089c94` (21 nov, 22:54) delante del decodificador de ALU; S4-a es anterior a ese commit y S4-b es posterior (sección 1.1). La diferencia de periodo entre S4-b y S4-a es (20 − 4,260) − (20 − 5,148) = 0,888 ns (calculado), del orden de los 0,802 ns de ese nivel. Es consistente con que el arreglo explique la mayor parte de la diferencia, pero no está demostrado: SignalTap y la variación del fitter también la afectan y no hay una compilación del RTL final sin SignalTap (suposición). Por eso los −3,80 MHz de la sección 1.4.5 no son solo costo de SignalTap, y la comparación con Sprint 3 de la sección 1.6, que usa S4-a, no incluye este nivel: con el RTL final el costo en Fmax es algo mayor.
- **En el peor camino global el control viene de `instruction`, pero la FSM sí participa en los demás.** En el peor camino y en los 20 peores el control nace en `instruction` (por `is_lui` y `alu_decoder`) y ningún origen es un registro de estado. Esto no vale para los caminos de debajo: el peor camino de origen CPU hacia la M10K nace en `current_state.JAL` (`cp_real_bus_cpu.rpt`, 4,501 ns), porque el estado también selecciona los operandos de la ALU (`alu_src_a`, `alu_src_b`), y el peor camino con excepciones pasa por una LUT de la FSM (`control_fsm|Selector1~2`, fan-out 16). Que la codificación One-Hot (sección 1.4.1) favorezca la frecuencia no se puede afirmar con estos reportes.
- **Hold.** El peor hold del modelo lento es 0,317 ns y es un registro de segmentación de SignalTap, no del diseño: `sld_signaltap…acq_data_in_pipe_reg[0][43]` → `acq_data_in_pipe_reg[1][43]` (1 nivel de lógica, sesgo 0,073 ns, retardo de datos 0,390 ns; llegada 3,688 y requerido 3,371 ns). Coincide con el hold mínimo de S4-b de la sección 1.2 y no hay riesgo de hold en la CPU.
- **Mejora identificada, no aplicada.** `assign address_data_memory = alu_result_reg;` eliminaría este camino sin cambiar el comportamiento, porque en MEM_READ y MEM_WRITE (los únicos estados con `valid_out_data_memory`) `wb_mux` ya vale `alu_result_reg`. Se deja sin aplicar: el RTL está validado con las pruebas y en la placa, la holgura de 4,260 ns ya cumple los 50 MHz, y el cambio exigiría recompilar y repetir cocotb y la corrida de la placa. Que no cambie el comportamiento es una lectura del RTL (suposición: no se simuló). Con los reportes de destino se puede acotar lo que ganaría: sin la familia hacia la M10K, el siguiente camino es el de `pc` (4,677 ns, 65,26 MHz; `cp_real_cpu.rpt`), de modo que la Fmax reportada subiría de 63,53 a unos 65,26 MHz (+1,73 MHz, calculado; suposición: el cambio elimina toda esa familia y no crea otro camino más lento). El cambio, por sí solo, no cambia el orden de magnitud de la Fmax.
- **Alcance de la medición.** El camino es el de S4-b (con SignalTap). En S4-a no se midió; que sea el mismo salvo por `Equal0~0` es una suposición. La base de datos del 23 nov es la única disponible y la compilación del RTL final sin SignalTap no existe entre los reportes entregados. Las cifras de la parte 2 y de la parte 3 (65,26, 64,52, 98,53 y 66,62 MHz) son resultados del análisis con filtros y excepciones sobre esa base de datos, no de una compilación, y las excepciones no están en el SDC del proyecto.

**Más allá del peor camino.** Los 20 peores caminos son de la familia estructural de arriba y tapan lo que hay debajo. Las partes 2 y 3 de `critical_path.tcl` miden qué queda.

*Parte 2: peor holgura por grupo* (Fmax = 1 000 / (20 − holgura), calculado):

| Grupo (reporte) | Peor camino: origen → destino | Datos (ns) y niveles | Holgura (ns) | Fmax (MHz) | Lectura |
|---|---|---|---|---|---|
| Destino: registros de la CPU (`cp_real_cpu.rpt`; `cp_real_resto.rpt` da lo mismo) | `cpu\|rs1[2]` → `cpu\|pc[9]` | 15,069; 15 | 4,677 | 65,26 | Lectura directa del banco de registros → operando A → ALU → `zero` → condición de salto → habilitación de `pc` (hipótesis P1). Estructural: la lectura directa solo entra con `forward_rs1` |
| Origen: `alu_result_reg`, `rs2_data_reg`, `current_state` → M10K (`cp_real_bus_cpu.rpt`) | `control_fsm\|current_state.JAL` → `mem_out…ram_block1a30~porta_we_reg` | 15,660; 12 | 4,501 | 64,52 | Misma familia estructural de arriba: el estado también selecciona los operandos de la ALU, y el camino pasa por la ALU y el decodificador MMIO |
| Origen: `jtag_addr_q`, `jtag_wdata_q`, `vj_state` → M10K (`cp_real_bus_host.rpt`) | `jtag_addr_q[30]` → `mem_out…ram_block1a30~porta_we_reg` | 10,366; 7 | 9,851 | 98,53 | Camino funcional: el host escribe por el bus sin pasar por la ALU |

Solo el camino del host es funcional; los otros dos son rutas que Quartus cronometra y el funcionamiento no activa. Por eso la parte 3 las excluye.

*Parte 3: excepciones de ruta falsa (`set_false_path`), declaradas solo en la sesión de `quartus_sta`.* No están en `sprint3/sdc/timing_constraints.sdc` y no cambian la compilación. Las cuentas son las que imprimió el script.

| Id | Excepción | Por qué no se activa (lectura del RTL) |
|---|---|---|
| E1 | A través de las salidas combinacionales de la ALU (384 pines) hacia los registros fuera de la CPU (10 385: M10K, host, etc.) | `alu_result` llega al bus solo por `wb_mux` en FETCH, donde `valid_out_data_memory` vale 0 y ningún `we_*` se levanta (viñeta "Es un camino estructural") |
| E2 | A través de las salidas de lectura directa del banco de registros (387 pines) hacia los registros `pc` (31) | La lectura directa solo entra al operando A con `forward_rs1`, que vale 1 en DECODE con JALR; en DECODE `branch` (`current_state == BEQ`) y `pc_update` valen 0, de modo que `pc_write = pc_update \|\| branch && branch_condition` vale 0 |

**Resultado con E1 y E2** (`cp_exc_peor_camino.rpt`, `cp_exc_5_peores.rpt`): la peor holgura sube de 4,260 a **4,989 ns** (66,62 MHz, calculado), solo +0,729 ns. Los cinco peores caminos nacen en `instruction` y terminan en `pc`: `instruction[3]` → `pc[9]` y `pc[10]` (4,989), `instruction[5]` → `pc[9]` y `pc[10]` (5,009) e `instruction[3]` → `pc[27]` (5,037). El peor:

| Propiedad | Valor |
|---|---|
| Origen → destino | `cpu\|instruction[3]` → `cpu\|pc[9]` (habilitación `pc[9]\|ena`) |
| Llegada y requerido | 18,529 ns = 3,805 + 14,724; 23,518 ns = 20,000 + 3,688 − 0,170. Holgura 4,989 ns (el sesgo de reloj, −0,117 ns, juega en contra) |
| Camino de datos | 14,724 ns en 12 niveles de LUT: celdas 5,347 ns (36 %) e interconexión 9,377 ns (64 %) |
| Nodos (fan-out) | `instruction[3]` (9) → `control_unit\|Equal0~2` (5) → `control_fsm\|Selector1~2` (16) → `cpu\|Mux27~1` (3) → `Mux27~2` (9) → cadena de acarreo de la ALU (`rv32i_alu\|_~129` … `_~85`) → `Selector20~1` (3) → `Equal10~3` → `Equal10~4` → `control_unit\|Mux0~3` → `Mux0~4` → `Mux0~1` → `cpu\|pc[20]~1` (31) → `pc[9]\|ena` |
| RTL (suposición por los nombres de nodo) | código de operación → selección del operando A (`alu_src_a`) → suma o resta de la ALU → comparación con cero → selección de la condición de salto por `funct_3` → `pc_write` |

- **Es la hipótesis P1 y existe en la estructura.** La comparación de la ALU sí decide el salto: en BEQ `pc_write = branch && branch_condition`, y `branch_condition` depende de `zero`.
- **Con este origen no se activa.** `instruction` solo cambia al pasar de FETCH a DECODE (`ir_write`), y en DECODE `pc_write` vale 0 (`branch` y `pc_update` valen 0). El salto se decide en BEQ, al menos un ciclo después de que `instruction` cambió, y en ese ciclo `instruction` es estable. Los orígenes que sí cambian al entrar a BEQ son `current_state` y los registros de operandos.
- **El camino con orígenes que sí se activan no está entre los cinco peores.** Por tanto todo camino que no nace en `instruction` tiene holgura ≥ 5,037 ns (66,83 MHz, calculado).
- **Qué se puede afirmar de la Fmax de la CPU.** No se midió el límite real. Con E1, E2 y el enmascaramiento de `instruction` es **≥ 66,83 MHz** (≥ 66,62 MHz si no se acepta el enmascaramiento), y la cifra que no depende de ninguna suposición es la de los reportes, 63,53 MHz. Para el funcionamiento no cambia nada: el reloj es de 50 MHz y la holgura sin excepciones es 4,260 ns (suposición: E1, E2 y el enmascaramiento son correctos; se justificaron leyendo el RTL y no se simularon).

### 1.6 Compromiso de diseño frente a Sprint 3

| Eje | Sprint 3 (acelerador) | Sprint 4 (RV32I) | Respaldo teórico | Respaldo medido |
|---|---|---|---|---|
| Función | Solo binarización | Histograma + binarización | El firmware hace ambas en un recorrido (sección 3 de `architecture.md`) | Histograma e imagen exactos (cocotb y placa, umbrales 0, 64, 128, 255) |
| Área (ALMs, sin SignalTap) | 1 044 | 1 609 (+54 %) | Banco de registros de 2 puertos y ALU completa (sección 1.4.1) | S3-a, S4-a |
| Fmax `clk` | 81,34 MHz | 67,33 MHz (−17,2 %) | En S3 la salida de la ALU no llegaba a ningún bus; en S4 `alu_result` recorre ALU → decodificador MMIO → write enable de la M10K (camino medido en S4-b, sección 1.5) | S3-a (calculado), S4-a (anterior al arreglo de LUI, sección 1.5) |
| Memoria | 128 M10K | 143 M10K (+12 %) | RAM de instrucciones con 3 puertos lógicos → 2 copias | `.fit.rpt` |
| Ciclos por píxel | ≥ 6 (cota: `fsm.sv` recorre 6 estados por píxel, `S_FETCH_REQ`, `S_FETCH_CAP`, `S_STORE_REQ`, `S_COMPUTE`, `S_WRITE_REQ` y `S_NEXT`, cada uno de al menos 1 ciclo; no medido) | 83 (medido en SignalTap, 15 instrucciones, CPI 5,53) | Multiciclo: CPI de 4 a 8 según la clase de instrucción (sección 14 de `architecture.md`) | 1 499 instrucciones capturadas, todas con los ciclos teóricos (`results.md`, sección 8.1) |
| Tiempo para 16 384 píxeles a 50 MHz | ≥ 1,97 ms (cota inferior, 16 384 × 6 × 20 ns; **no medido**) | 27,28 ms (modelo exacto 3 920 + 83·N ciclos; **no medido en la placa**) | S4 ≤ 83 / 6 = 13,8 veces más lento por píxel que la cota de S3 | Modelo contra cocotb: 9 232 (64 px) y 1 363 792 ciclos, redondeados por el sondeo cada 64 ciclos a los 9 280 y 1 363 840 observados |
| Cambiar el algoritmo | Rediseñar y resintetizar (el flujo completo de Quartus de S4-b tomó 2 min 12 s) | Cambiar `firmware.hex` (34 palabras) y cargarlo por vJTAG | Programa almacenado: el hardware es de propósito general | `pixel_image_app.py` carga el firmware (`Programa: 34/34`) en la corrida de la placa |
| Cuello de botella real | La FSM | El JTAG del Host (30,6 s para cargar la imagen y 38,6 s para leer la salida) frente a 27,3 ms de la CPU (modelo) | Una palabra de 32 bits por transacción JTAG | `results.md`, sección 7 (corrida de la placa del 22–24 nov) |

Una comparación de igual función (solo binarización) daría ≈ 43 ciclos por píxel para el mismo firmware sin la parte del histograma (8 de la lectura del píxel + 21 de la binarización + 10 de avanzar los dos punteros + 4 del salto, calculado a partir de la tabla de ciclos, **no ejecutado**), es decir ≈ 7,2 veces la cota de S3. Ninguna de las dos razones (13,8 y 7,2) es una medición del acelerador: son cotas teóricas, porque el tiempo de Sprint 3 no se midió.

**Cuándo conviene cada diseño.** El acelerador gana en velocidad y área si la tarea no cambia. El procesador gana si la tarea cambia: cuesta 565 ALMs (1,3 % de los 41 910 de la FPGA) y 14,01 MHz de Fmax, y conserva un margen de 17,33 MHz (34,7 %) sobre los 50 MHz de la placa sin SignalTap (13,53 MHz, 27 %, con SignalTap). El tiempo de cómputo del modelo (27,3 ms) es mucho menor que el de transferencia por JTAG de la corrida de la placa (30,6 s + 38,6 s), de modo que la lentitud por píxel del procesador no domina el tiempo total que ve el usuario.

---

## 2. HI: herramientas y justificación con hallazgos del proyecto

### 2.1 Elección justificada por lo que cada herramienta encontró o midió

| Herramienta | Uso | Hallazgo concreto del proyecto | Por qué otra herramienta no lo habría dado |
|---|---|---|---|
| Cocotb 2.1.0 + Verilator 5.053 | Pruebas del profesor (29 casos `test_cpu` y 2 programas `test_programs`), pruebas unitarias y de sistema (`sprint4/test/cocotb`) | (1) En la primera corrida de `make top` hubo 3 pruebas en FAIL: cada instrucción se buscaba dos veces porque FETCH sumaba 4 a `old_pc`, y las 29 del profesor pasaban. (2) `test_programs.xorshift` detectó el error de LUI (`lui s0, 0x12345` dejaba 0). (3) La imagen completa de 16 384 píxeles corre en 19,35 s reales para 59 391 822 ns simulados (≈ 3,07 M ns/s) | Los modelos de referencia (histograma, binarización, xorshift, factorial) están en Python y se comparan palabra por palabra; la imagen completa de 1,36 M ciclos corre en 19 s |
| Questa (`.do`) | Bancos SystemVerilog de los Sprints 0 a 3 | Es la herramienta que valida el gatekeeper (`questa_test_summary.log`). La retroalimentación de Sprint 3 mostró que `ram` y `control_registers` fallaban con el RTL vigente: las transcripciones y los `.wlf` eran del 11 oct y los módulos cambiaron el 24 oct, de modo que el resumen del 25 oct declaraba 8/8 con transcripciones desactualizadas | Produce las formas de onda (`.wlf`) que exige el enunciado. No corre en WSL |
| Quartus Prime 25.1 Lite | Síntesis, ajuste y timing | Reveló la RAM de instrucciones duplicada (2 × 7 M10K), 156 registros duplicados por el fitter, el costo de SignalTap y la caída de Fmax de 81,34 a 67,33 MHz; con el Timing Analyzer, el camino crítico real (instrucción → ALU → decodificador MMIO → write enable de la M10K, 15,908 ns, 58 % ruteo) y que el arreglo de LUI le añadió un nivel de 0,802 ns | Es la única fuente de ALMs, M10K, Fmax y rutas del Cyclone V |
| SignalTap | Captura en la placa a 50 MHz (`stp_rv32i.stp`) | (1) FETCH dura 2 ciclos, no 1: cada `lui` o `addi` ocupa 5 muestras. (2) 1 499 de 1 499 instrucciones capturadas duran los ciclos teóricos (4, 5, 6 y 8). (3) El bucle por píxel dura 83 ciclos: 86 intervalos consecutivos de exactamente 83 ciclos en la captura B. (4) Con `done` el PC se queda en `0x84` y la CPU no pide buses: se congela por `cpu_enable`, no por el `j halt` (que nunca se busca) | La simulación no prueba el comportamiento del bitstream real; las fotos del paso a paso no distinguen los 2 ciclos de FETCH (una pulsación por estado) |
| Modo paso a paso, displays y LEDR | Depuración en la placa sin recompilar | Cada pulsación avanzó exactamente un estado (1 → 8 → 7 → 0 → 1 en `lui`), lo que valida `cpu_hold` | SignalTap da resolución de ciclo pero exige recompilar; las fotos solo necesitan la placa. Son complementarios |
| vJTAG + `jtag_server.tcl` + `pixel_image_app.py` | Carga de firmware e imagen, arranque, lectura | `OK` con cuatro umbrales (0, 64, 128 y 255); el cliente compara contra el mismo modelo que cocotb | Reutiliza el USB-Blaster y el cliente de Sprint 3 |
| GitHub Actions (gatekeeper) | Verifica en cada PR | 4 checks en verde en el PR #82 (`detect-changes`, `open-source-verification`, `repo-artifact-validation`, `style-check`) | Evita integrar sin evidencia |

### 2.2 Qué detectó cada nivel de prueba

| Defecto | Pruebas del profesor (29) | Pruebas unitarias | Prueba de sistema / programas | SignalTap / placa |
|---|---|---|---|---|
| `FETCH` suma a `old_pc` | No detecta | n/a | **Detecta** (primera corrida de `make top`: 3 FAIL) | n/a |
| JALR sin limpiar el bit 0 | No detectado hasta corregir FETCH; luego **detecta** `jalr` | n/a | n/a | n/a |
| LUI con `funct3`/`funct7` del inmediato | No detecta (el caso usaba `0xABCDE`, que da OR) | n/a | **Detecta** `test_programs.xorshift` | n/a |
| `read_data_reg` se corrompe al congelar en `MEM_WB` | No | No | No | Detectado por análisis; ninguna prueba lo cubre |
| Latencia de FETCH de 2 ciclos | No | `test_imem_ready_pattern` la observa | Ciclos de `done` | **SignalTap la mide ciclo a ciclo** |

Lección: ningún nivel basta. Las pruebas por instrucción no ven la secuencia de búsquedas ni los programas largos, y la prueba de sistema no ve el comportamiento real de la placa.

### 2.3 Límites de las herramientas

- SignalTap no tiene las señales del vJTAG en el `.stp`: no hay captura de una colisión real con el Host; la colisión se verifica en simulación (`test_firmware_with_bus_stalls`).
- Verilator simula con 2 valores (no representa `X`); las memorias M10K no se reinician, por lo que una lectura de una posición no escrita no se distingue de un 0 en la simulación (suposición: no se probó este caso).
- Questa no corrió en Sprint 4 (WSL).
- La prueba 3.2 de Sprint 1 usa `cocotb.binary`, que cocotb 2.1.0 ya no tiene.

---

## 3. Gobernanza del uso de IA

### 3.1 Declaración

Se usó **Claude (Anthropic)**, por Byron Bolaños, en chats de claude.ai dentro del proyecto "Taller de Diseño Digital" ("Proyecto: explicación breve", ≈ 4–12 nov; "Cocotb test setup debugging", ≈ 11–12 nov; y los chats posteriores del 15 al 24 nov). Además se usó **ChatGPT**, por Esteban Campos, para revisar sintaxis y errores lógicos del procesador (5 nov). Alcance, con su evidencia en el repositorio:

| Producto | Autoría con IA | Commits |
|---|---|---|
| `sprint4/firmware/firmware.s` y `firmware.hex` | Apoyado con Claude para sintaxis; el ensamblado y la verificación en CPU real los hizo el equipo | 24ccc76, 134213d (5 nov) |
| `sprint4/scripts/pixel_image_app.py` (adaptado del de Sprint 3) | Apoyado en la version anterior y cambios sugeridos por Claude; el cambio de relleno blanco lo editó Byron a mano a partir de una lista de 5 cambios | 25b5874 (5 nov), e828fc3 (10 nov) |
| Revisión estática del CPU de Esteban | Claude, sin simulador: señaló 3 posibles errores | dddbba4 (12 nov), f9e43d1 y 207bcff (15 nov) |
| `mmio_decoder.sv`, `control_registers.sv`, `ram.sv`, `arbiter.sv` | Escritos con apoyo en Claude y sus versiones anteriores a partir de la Tabla 2; Claude declaró que no los compiló; Byron ejecutó el lint de Verilator | 1a7a88e (12 nov) |
| Pruebas cocotb de esos cuatro módulos y primer borrador de la integración y de la prueba de sistema | Escritos con Claude, que no pudo ejecutarlos; el equipo los corrió | ce91c2e, f9e43d1 (15 nov) |
| `architecture.md`, `testplan.md`, `results.md`, `features.md`, `evidencia_atributos.md` | Redactados con Claude a partir de logs, reportes y capturas aportados por el equipo | a95a2bf (20 nov), 4642c63 (23 nov), fa6d15f (24 nov) y el commit de esta entrega |
| Análisis de los CSV de SignalTap (script local de Python, no versionado); tablas de Quartus; script `critical_path.tcl` y análisis de los `cp_*.rpt` | Analizados y confirmados con ayuda de Claude, a partir de los CSV y los reportes de Quartus del equipo; Byron ejecutó `quartus_sta` y aportó los reportes | commit de esta entrega |

El CPU (`multicycle_rv32i`, FSM, unidad de control, decodificadores, banco de registros) lo escribió Esteban Campos (commits `EstebanACamposA`). Sobre esos archivos, la IA se usó para: revisión de sintaxis y errores lógicos menores con ChatGPT (5 nov); la revisión estática con Claude que originó las correcciones de la tabla 3.3 (dddbba4, f9e43d1, 207bcff); y cambios propuestos por la IA que Esteban revisó y aprobó (`alu_src_a` en FETCH, bitácora del 15 nov). El error de JALR lo corrigió Esteban: la IA propuso limpiar el bit 0 del destino, pero la causa principal era la señal `forward_rs1` en la FSM de control. La IA no hizo commits, ramas ni PR (los hizo el equipo; los commits con autor "Your Name" salieron de una máquina sin nombre configurado en git, suposición: la de Byron) y no ejecutó Quartus, Questa, la placa ni el simulador del CPU real.

### 3.2 Reglas aplicadas

| Id | Regla | Cómo se cumplió (evidencia) |
|---|---|---|
| R1 | Ninguna cifra sin fuente: sale de un log, reporte o captura; las derivadas se rotulan "calculado" | Secciones 1.2 a 1.5; `results.md` cita el log de cada cifra |
| R2 | Todo supuesto se marca "(suposición)" | Este documento y `results.md` (9.11) |
| R3 | La IA declara lo que no pudo ejecutar y el humano lo ejecuta | "No los compilé ni simulé" (módulos de Epic 2, 12 nov); Byron corrió Verilator y cocotb (lint limpio; 8, 7, 8 y 10 PASS) |
| R4 | La IA no valida su propio trabajo | El firmware que Claude validó con su propio simulador de la FPGA se volvió a validar en el CPU real con cocotb y en la placa (`OK` con 4 umbrales) |
| R5 | El humano decide y ejecuta commits, ramas y PR | Los comandos de git los corre Byron; la IA solo propone mensajes |
| R6 | Cuando la evidencia primaria contradice un texto escrito con IA, se corrige el texto | Sección 3.4, casos 3 a 7, 10 y 11 |
| R7 | Cambios pequeños se piden como lista de cambios, no como archivo nuevo | `pixel_image_app.py` (caso 8 de 3.4) |
| R8 | Integración solo con el gatekeeper en verde | PR #82 a `dev`, 4 checks en verde |

### 3.3 Registro: prompt, salida, commit y resultado

"(texto)" indica un prompt copiado del chat; "(resumen)" una descripción del chat cuyo texto exacto no se archivó.

| Fecha | Prompt | Salida de la IA | Commit | Resultado y verificación |
|---|---|---|---|---|
| ≈ 5 nov | (texto) "Pero que ac del epic 2 y 3 puedo hacer COMPLETAMENTE ahorita, que no esta lo del epic 1" | Orden de trabajo: firmware y consola Python primero, porque no dependen de la CPU | 24ccc76 (`firmware.s`), 134213d (`firmware.hex`) | `test_firmware_end_to_end` PASS con 64 y 16 384 píxeles (23 nov) y `OK` en la placa con umbrales 0, 64, 128 y 255 |
| ≈ 5 nov | (resumen) adaptar la consola de Sprint 3 al mapa de la Tabla 2 | `pixel_image_app.py` con carga, `start`, espera de `done`, descarga y gráficas | 25b5874 | `OK: histograma e imagen binarizada coinciden` en la placa (22–24 nov) |
| ≈ 10 nov | (resumen) recordar el requisito del profesor de Sprint 3: si se agota el tiempo, mostrar la imagen parcial con blanco | Lista de 5 cambios (`ADDR_HEX`, `wait_done`, `read_partial_output`, `display_results`, `main`); Byron los aplicó | e828fc3 | La IA lo probó contra un servidor FPGA simulado (corrida completa y cortada). Esta entrega no tiene una corrida de la placa con tiempo agotado (`results.md`, sección 9.11) |
| ≈ 11–12 nov | (resumen) revisar el CPU en curso contra el enunciado | Sin simulador: `alu_src_a` en FETCH cae en `default`; tipos de paquete antes del `import`; `valid` sin AND con `enable` | dddbba4 (enabler), f9e43d1 (FETCH), 207bcff (imports, Esteban) | 29/29 del profesor y prueba de sistema PASS tras las correcciones (15 nov) |
| ≈ 11–12 nov | (resumen) Para el epic 2 dime cuales modulos de tb puedo reutilizar y cuales mejor hacer de 0 | `mmio_decoder`, `control_registers`, `ram`, `arbiter` con permisos por maestro, RAZ/WI y lectura de 1 ciclo | 1a7a88e | Lint de Verilator limpio tras corregir los avisos de fin de archivo; pruebas cocotb 8/8, 7/7, 8/8 y 10/10 (23 nov) |
| ≈ 12–15 nov | (resumen) pruebas cocotb de los cuatro módulos y de la integración | 33 pruebas unitarias y una prueba de sistema que la IA no pudo ejecutar | ce91c2e, f9e43d1 | La primera corrida de `make top` dio 3 FAIL (error de FETCH), corregido el 15 nov |
| 20–23 nov | (resumen) documentar los avances con los logs reales | `architecture.md`, `testplan.md`, `results.md`, `evidencia_atributos.md` | a95a2bf, 4642c63, fa6d15f | Cada cifra se contrastó con el log; ver 3.4 |
| 24 nov | (texto) "Tomate tu tiempo, ayudame con el analisis de SignalTap, dime si crees que algo no es coherente" | Análisis de los CSV de SignalTap, modelo exacto de ciclos, tablas por módulo de Quartus, camino crítico y esta revisión | Commit de esta entrega | 1 499 de 1 499 instrucciones con los ciclos teóricos; 156 registros duplicados = 3 256 − 3 100 |
| 5 nov | (resumen) revisar sintaxis y errores lógicos del procesador con ChatGPT | Varios errores de sintaxis y un error lógico (falta un `else` tras el reset asíncrono en un `always_ff`) | — (corregidos por Esteban) | Bitácora, 5 nov (L65-67) |
| 6 nov | (resumen) integrar el repositorio de pruebas provisto por el profesor en el repositorio de trabajo | Apoyo de la IA en la integración | — | Bitácora, 6 nov (L69) |
| 23 nov | (resumen) convertir un cocotb a SystemVerilog con IA o descartarlo | Código de los tb de Questa escrito por la IA a partir de un diseño propio y explícito (plan de pruebas de la bitácora, L151-184) | — | Bitácora, 23 nov (L189) y 25 nov (L199-200) |
| 25 nov | (resumen) generar `tb_multicycle_rv_control_fsm.sv` | Claude lo generó; Esteban pidió seguir su diseño exactamente y revisó la forma de onda en Questa | — | Bitácora, 25 nov (L247-250) |
| 25 nov | (resumen) generar `tb_arbiter.sv` y `tb_mmio_decoder.sv` | Generados con Claude; Esteban revisó la forma de onda de cada uno | — | Bitácora, 25 nov (L252, L254) |
| 25 nov | (texto, L218-237) programa de SystemVerilog que ejecuta `firmware.hex` y produce el waveform del procesador con las señales indicadas | Diseño de las señales y del comportamiento por Esteban; la IA escribió el tb, sin verificaciones adicionales (L256-257) | — | Bitácora, 25 nov (L218-237, L256-257) |
| 26 nov | (texto, L272-343) instrucciones para editar la documentación y mantener la coherencia entre las tablas de testplan, results, architecture y evidencia | Ediciones de los documentos y la consulta de qué docs editar (L335) | — | Bitácora, 26 nov (L272-343) |

### 3.4 Salidas de la IA rechazadas o corregidas (control humano)

| # | Salida de la IA | Cómo se detectó | Corrección | Evidencia |
|---|---|---|---|---|
| 1 | Plan de 4 commits para `firmware.s`, cortando el archivo por etapas con `sed` (propuesto a pedido de Byron) | Byron lo descartó: "no primero eliminesmos los dos bin y o, luego un commit para s y otro para hex" | 2 commits (`firmware.s` y `firmware.hex`); `firmware.o` y `firmware.bin` no se versionan | 24ccc76, 134213d |
| 2 | Comandos de bash (`rm -f`, rutas relativas) para una terminal PowerShell | Byron los ejecutó y pegó los errores ("parameter name 'f' is ambiguous", "pathspec did not match") | La IA los rehízo con `Remove-Item` y rutas desde la raíz del repo | Chat "Proyecto: explicación breve" |
| 3 | "Sprint 3: una FSM [...] hecha para hacer solo una cosa: histograma + binarización" (explicación inicial del proyecto) | Contraste con `sprint3/src/fsm.sv`, que solo binariza (el histograma no existe en Sprint 3) | Este documento parte de "solo binarización" (sección 1 y tabla 1.6) | `sprint3/src/fsm.sv` (estados `S_FETCH_REQ` a `S_NEXT`, sin acceso a un histograma) |
| 4 | Revisión estática del CPU que propuso limpiar el bit 0 de JALR como única corrección | El caso `jalr` del profesor falló al ejecutarlo (15 nov): `JALR did not fetch expected PC 0x00000020` | Esteban añadió `forward_rs1` en la FSM de control; la máscara `pc <= {wb_mux[31:1], 1'b0}` propuesta por la IA no bastaba sola | Bitácora 15 nov; `results.md` sección 5 (suposición: esa sección aún describe solo la máscara) |
| 5 | Borrador de `results.md` con "4 a 5 ciclos por instrucción" | La captura A de SignalTap muestra 5 ciclos para ALU/`lui`/`addi` y 2 ciclos de FETCH | Tabla de ciclos de 4 a 8 con 1 499 de 1 499 coincidencias | `results.md` sección 8.2 |
| 6 | Modelo "3 968 + 83·N" en `results.md` | Conteo instrucción por instrucción del firmware contra el modelo | 3 920 + 83·N exacto; 3 968 es 3 920 redondeado al múltiplo de 64 del sondeo (⌈3 920 / 64⌉ × 64) | `results.md` sección 9.5 |
| 7 | Comparación DI con Sprint 3 que mezclaba el `fit.summary` del 25 oct con el Fmax del 26 oct | Fechas internas de los reportes, `git log` y la retroalimentación de Sprint 3 | Cuatro compilaciones separadas (sección 1.1) | Sección 1.1 |
| 8 | Reescritura completa de `pixel_image_app.py` para el relleno blanco | Byron pidió solo la lista de cambios y los aplicó a mano | Lista de 5 cambios (`ADDR_HEX`, `wait_done`, `read_partial_output`, `display_results`, `main`) | e828fc3 |
| 9 | Versión acortada de `results.md` que eliminó tablas de evidencia | Byron lo señaló (chat "Cocotb test setup debugging") | La IA restauró la tabla completa de pruebas a partir del log | Chat "Cocotb test setup debugging" (sin commit propio) |
| 10 | Atribución de los −3,80 MHz entre S4-a y S4-b solo a SignalTap, y cuatro hipótesis de camino crítico (P1 a P4) sin medir | Byron ejecutó `quartus_sta` el 24 nov: el peor camino pasa por `is_lui`, comparador del arreglo de LUI que es posterior a S4-a | Secciones 1.4.5 y 1.5: la diferencia no se puede separar; el peor camino medido es instrucción → ALU → decodificador MMIO → write enable de la M10K (estructural, ver caso 11) | `cp_peor_camino.rpt`, `cp_20_peores.rpt`, `results.md` sección 9.6 |
| 11 | Sobre ese resultado, tres afirmaciones de la IA: (a) P1 "descartada" y "el siguiente camino real no aparece en los reportes" porque ningún camino de los 20 peores terminaba en `pc`; (b) un filtro que trataba `current_state` como origen funcional del bus; (c) dos excepciones (E1, E2) que debían dejar al descubierto el límite de la CPU | Byron ejecutó las partes 2 y 3 de `critical_path.tcl` (24 nov): (a) con el destino filtrado a la CPU el peor camino sí termina en `pc` (4,677 ns); (b) el estado también selecciona los operandos de la ALU y el peor camino de ese filtro sigue siendo el estructural (4,501 ns, 64,52 MHz); (c) con E1 y E2 el peor camino sigue siendo `instruction` → `pc` (4,989 ns), que tampoco se activa | Sección 1.5: P1 queda "confirmada en la estructura, origen sin activación"; la afirmación sobre la FSM se limita a los 20 peores caminos; el límite real de la CPU queda como cota inferior de 66,83 MHz (suposición), no como cifra medida | `cp_real_cpu.rpt`, `cp_real_bus_cpu.rpt`, `cp_real_bus_host.rpt`, `cp_exc_peor_camino.rpt`, `cp_exc_5_peores.rpt` |

### 3.5 Lo que la IA no hizo

No tomó decisiones de arquitectura de la CPU, no modificó el RTL de la CPU de Esteban, no ejecutó el simulador del CPU real (Verilator y cocotb), Quartus, SignalTap ni la placa, y no cargó datos en ella. Solo ejecutó modelos propios en Python (un simulador del firmware, un servidor de FPGA simulado para la consola) y el análisis de los CSV y de los reportes que aportó el equipo. Los resultados de las ejecuciones reales los produjo el equipo; los números de este documento salen de esos reportes.

---

## 4. Referencias

[2] S. L. Harris y D. M. Harris, *Digital Design and Computer Architecture: RISC-V Edition*, Morgan Kaufmann, 2021. [7] Altera, *Signal Tap Logic Analyzer Introduction*. [8] Altera, *Quartus Prime Timing Analyzer*. (Numeración del enunciado, sección 10.)