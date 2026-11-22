# Resultados de Verificación: Sprint 4 (Avance 3)

**Proyecto:** CE3201 Taller de Diseño Digital, Grupo 7
**Fecha:** 20 y 21 nov 2026
**Avance:** 3, tag `v0.1.0-proj` (el Avance 2, `v0.0.2-proj`, es del 15 nov 2026)
**Arquitectura:** ver `docs/architecture.md`
**Plan de pruebas:** ver `docs/testplan.md`
**Entorno de simulación:** Verilator 5.053 (devel), cocotb 2.1.0, Python 3.12, WSL. Los resultados de las secciones 2 a 4 son de las corridas del 21 nov 2026, hechas después de los últimos cambios al CPU (`state_num`, `cpu_hold`, la corrección de `read_data_reg` y el arreglo de LUI, sección 5) y del filtro de búsquedas fuera de rango en `rv32i_top`. La síntesis (sección 6) es del 19 nov 2026 (Fitter).

---

## Resumen

| Verificación | Herramienta | Resultado | Estado |
|---|---|---|---|
| Prueba del repo con mock CPU | Cocotb | 29/29 PASS | Ejecutada en Avance 1 (el mock no cambió) |
| Verificación del repo sobre `rv32i_cpu` | Cocotb | 29/29 PASS (pytest 30 passed) | Ejecutada el 21 nov, después del arreglo de LUI (sección 5) |
| Programas completos (`test_programs`: factorial y xorshift) sobre `rv32i_cpu` | Cocotb | 2/2 PASS | Ejecutada el 21 nov, después del arreglo de LUI (en el tag `v0.0.2-proj`: 1/2, falla `xorshift`) |
| Enabler (`enable = 0`) | Cocotb | 29/29 casos con timeout a 300 ciclos (pytest: 30 failed), ninguna instrucción completada | Ejecutada el 20 nov |
| Unitaria `arbiter` | Cocotb | 8/8 PASS | Ejecutada el 21 nov |
| Unitaria `mmio_decoder` | Cocotb | 7/7 PASS | Ejecutada el 21 nov |
| Unitaria `ram` | Cocotb | 8/8 PASS | Ejecutada el 21 nov |
| Unitaria `control_registers` | Cocotb | 10/10 PASS | Ejecutada el 21 nov |
| Sistema `rv32i_top`, 64 píxeles | Cocotb | 4/4 PASS | Ejecutada el 21 nov |
| Sistema `rv32i_top`, imagen completa (16384 píxeles, `FULL_IMAGE=1`) | Cocotb | 4/4 PASS | Ejecutada el 21 nov |
| Síntesis del top de placa (`top_level`) | Quartus Prime 25.1 Lite | Fitter Successful, 1609 ALMs, Fmax 67.33 MHz | Ejecutada el 19 nov |
| Modo paso a paso (SW[0], KEY[1]) | — | Implementado en `top_level`; compila | Sin simular ni probar en la placa |
| Carga por vJTAG y captura en hardware | DE10-Standard, SignalTap | No ejecutada | Pendiente |

---

## 1. Prueba del repo con mock CPU

Siguiendo el README del repo del profesor, se ejecutó la prueba con el `mock_cpu` (resultado de Avance 1; el mock no cambió, por lo que no se repitió el 15 nov):

```
TESTS=29 PASS=29 FAIL=0 SKIP=0
```

---

## 2. Verificación del repo para `rv32i_cpu`

Comando:

```
make test_cpu SV_FILELIST=files.f TOPLEVEL=rv32i_cpu 2>&1 | tee ../../docs/evidencia/avance2/avance2_cocotb.log
```

Resultado (corrida del 21 nov, después del arreglo de LUI; el caso `lui` ahora prueba cinco inmediatos, por eso el tiempo simulado sube de 7144 a 7704 ns):

```
** TESTS=29 PASS=29 FAIL=0 SKIP=0               7704.03           0.07     104708.18  **
```

El dashboard de pytest reporta `30 passed` (29 casos de instrucción más `test_functional_instruction_coverage`). La cobertura de instrucciones (29/29 bins, 1 hit por instrucción) se lee de `coverage.json`, que genera esta misma corrida.

| Formato | Instrucciones | Resultado |
|---|---|---|
| R | add, sub, and, or, xor, sll, srl, sra, slt, sltu | PASS |
| I (ALU) | addi, andi, ori, xori, slli, srli, srai, slti, sltiu | PASS |
| I (carga) | lw | PASS |
| I (salto) | jalr | PASS |
| S | sw | PASS |
| B | beq, bne, blt, bge | PASS |
| U | lui | PASS |
| J | jal | PASS |
| Ilegal | illegal | PASS |

### Programas completos (`test_programs`)

Comando:

```
make test_programs SV_FILELIST=files.f TOPLEVEL=rv32i_cpu 2>&1 | tee ../../docs/evidencia/avance3/avance3_programs.log
```

Resultado del 21 nov (sobre `rv32i_cpu`, no sobre el mock del profesor):

```
** test_programs.factorial        PASS      183175.00 **
** test_programs.xorshift         PASS       38275.00 **
** TESTS=2 PASS=2 FAIL=0 SKIP=0             221450.00 **
```

`factorial` (recursivo, 0 a 13) y `xorshift` (16 números y 9 estadísticas con signo y sin signo) coinciden con Python. Log: `docs/evidencia/avance3/avance3_programs.log`. Sin el arreglo de LUI (sección 5), `xorshift` falla en el tag `v0.0.2-proj` y en el RTL anterior con el mismo resultado.

### Enabler (TP-10)

Con `enable = 0` en el wrapper (`files_enable.f`, `TOPLEVEL=rv32i_cpu_enable`), la CPU queda apagada y ninguna prueba puede terminar. Resultado del 20 nov: cocotb `TESTS=29 PASS=0 FAIL=29` y pytest `30 failed`; cada caso de instrucción termina con `Timed out after 300 cycles` (por ejemplo `LUI failed: Timed out after 300 cycles: CPU did not write the result to 0x00000100`, y `CPU did not assert illegal_instruction` en `illegal`). El trigésimo fallo de pytest es el caso de cobertura, que falla por falta de datos (`Missing Cocotb functional coverage data`). Esto es lo esperado: la CPU apagada no completa ninguna instrucción. Log: `docs/evidencia/avance3/avance3_enabler.log`.

### Evidencia

Archivos en `docs/evidencia/avance2/`:

- `avance2_cocotb.log`: salida completa de la corrida (29/29 y pytest 30 passed).
- `coverage.json`: bins cubiertos y conteo de hits.
- `dashboard_cpu.html`: resultado por prueba y cobertura por instrucción.

Los tres archivos de `avance3/` corresponden a una corrida normal posterior a los cambios, hecha después del enabler (que sobrescribe `results/`).

---

## 3. Pruebas unitarias (Cocotb + Verilator)

Directorio: `sprint4/test/cocotb`. Comando: `make all` (ejecuta `arbiter`, `mmio_decoder`, `ram`, `control_registers` y `top`; la salida completa del Avance 3 está en `docs/evidencia/avance3/avance3_unit_system.log`; la del Avance 2 está en `docs/evidencia/avance2/avance2_unit_system.log`).

| Módulo | Pruebas | Resultado | Qué verifican |
|---|---|---|---|
| `arbiter` | 8 | 8/8 PASS | Prioridad del Host, backpressure, la CPU conserva el bus mientras espera `ready`, reset, aleatoria contra modelo de referencia |
| `mmio_decoder` | 7 | 7/7 PASS | Permisos de escritura de la Tabla 2, selección de lectura, latencia de `rdata`, RAZ/WI fuera de mapa, `valid = 0`, secuencia de `ready` |
| `ram` | 8 | 8/8 PASS | Primera y última palabra de cada memoria, independencia entre memorias, latencia de 1 ciclo, histograma (0x3FC), puerto de instrucciones |
| `control_registers` | 10 | 10/10 PASS | Valores de reset, LEDR/HEX/THRESHOLD, CTRL start/busy, STATUS done, re-armado, lecturas sin mapear en 0, reset asíncrono |

---

## 4. Prueba de sistema (`rv32i_top`)

Se integró la CPU con el árbitro, el decodificador MMIO, la RAM (M10K) y los registros de control en `src/rv32i_top.sv`. El Host (vJTAG simulado) carga `firmware.hex` y la imagen, escribe CTRL y espera `done`.

Comando: `make top` (en `sprint4/test/cocotb`), 64 píxeles.

```
** TESTS=4 PASS=4 FAIL=0 SKIP=0                          428722.00           0.14    3091386.48  **
```

| Prueba | Qué verifica | Resultado |
|---|---|---|
| `test_fetch_secuencial` | Las primeras 10 búsquedas de instrucción son 0x0, 0x4, …, 0x24 (cada instrucción una sola vez y en orden) y no hay instrucción ilegal | PASS |
| `test_firmware_end_to_end` (TP-13) | Histograma de 256 bins e imagen binarizada exactos contra un modelo en Python; la suma del histograma es N; `STATUS = 0b10`; `HEX = N`; nada se escribe fuera de la imagen; ninguna instrucción ilegal. 64 píxeles, ~9280 ciclos hasta `done` | PASS |
| `test_firmware_with_bus_stalls` (TP-12) | Mismo resultado con el Host leyendo direcciones al azar durante la ejecución (1507 lecturas); la CPU espera por el bus y no pierde datos. ~9792 ciclos hasta `done` | PASS |
| `test_fetch_fuera_de_rango_lee_cero` (TP-18) | Un `jal x0, 0x2000` en la dirección 0 lleva el PC fuera de la RAM de instrucciones (0x0000–0x1FFF). La instrucción leída es 0 (RAZ), decodifica como ilegal y la CPU no se bloquea: las búsquedas fueron `0x0, 0x2000, 0x2004, 0x2008, …` | PASS |

### Qué se observó

- **Orden de búsqueda.** La traza de `test_fetch_secuencial` fue `0x0, 0x4, 0x8, 0xc, 0x10, 0x14, 0x18, 0x1c, 0x20, 0x24, 0x28, 0x2c, 0x24, 0x28`. Las primeras 10 son las que verifica la prueba. Después de `0x2c` (el `bne` del bucle `clear` de `firmware.s`) vuelve a `0x24`, que es lo esperado del salto hacia atrás.
- **Costo de los stalls.** Con el Host leyendo al azar, el firmware tardó ~9792 ciclos contra ~9280 sin ruido (~5 % más). Los ciclos se miden revisando `done` cada 64 ciclos, por lo que son aproximados (±64).
- **Velocidad.** ~9280 ciclos para 64 píxeles incluyen la limpieza del histograma, que es un costo fijo. Con la imagen completa el costo por píxel es menor (sección 4.1).

### Cómo se redujo la imagen

La prueba no ejecuta `firmware.hex` tal cual: carga solo 64 píxeles y `shorten_loop` modifica dos palabras del firmware en la RAM de instrucciones para que el bucle termine tras 64 píxeles:

| Palabra original | Palabra en la prueba | Efecto |
|---|---|---|
| `addi t0, zero, 1` (0x14) | `addi a1, s0, 4*64` | a1 = fin de la imagen reducida. El `sw t0, 4(s4)` siguiente escribe 0 en STATUS en lugar de 1 (busy); no cambia el resultado porque `busy` ahora se calcula en hardware (`start && !done`) |
| `bne t0, s1, loop` | `bne t0, a1, loop` | El bucle termina en 0x10000 + 4*64 en vez de 0x20000 |

El resto del firmware (limpieza del histograma, histograma, binarización, escritura de HEX y de `STATUS.done`) se ejecuta sin cambios. El firmware original completo se simuló aparte con `FULL_IMAGE=1` (sección 4.1).

### 4.1 Imagen completa (`FULL_IMAGE=1`)

Comando (en `sprint4/test/cocotb`): `FULL_IMAGE=1 make top`. Corre `firmware.hex` sin modificar con los 16384 píxeles. Log: `docs/evidencia/avance3/avance3_full_image.log`.

```
** TESTS=4 PASS=4 FAIL=0 SKIP=0                        59391822.00          17.24    3445820.54  **
```

| Prueba | Resultado | Ciclos hasta `done` |
|---|---|---|
| `test_fetch_secuencial` | PASS | n/a (misma traza de búsquedas que con 64 píxeles) |
| `test_firmware_end_to_end` | PASS: 16384 píxeles, histograma e imagen exactos | ~1 363 840 |
| `test_firmware_with_bus_stalls` | PASS: 220 363 lecturas del Host | ~1 440 192 |
| `test_fetch_fuera_de_rango_lee_cero` | PASS (misma prueba que con 64 píxeles) | n/a |

- ~1 363 840 ciclos son ~83 ciclos por píxel. A 50 MHz serían ~27,3 ms (cálculo a partir de los ciclos simulados, no una medición en la placa).
- Con el Host leyendo al azar el firmware tardó ~5,6 % más (1 440 192 contra 1 363 840 ciclos).
- Los ciclos se miden revisando `done` cada 64 ciclos (±64).

### Limitaciones de las pruebas

- La imagen de entrada es aleatoria con semilla fija (con un píxel justo en el umbral y otro justo debajo); no es una imagen real.
- `THRESHOLD` se fijó en 100. Otros umbrales no se probaron.
- Las pruebas de JAL y JALR del repo del profesor verifican el destino del salto, no el valor de enlace (`rd = pc + 4`). El firmware solo usa `jal` implícito en `j halt`.

---

## 5. Errores encontrados al integrar

La prueba de sistema encontró dos errores de la CPU que las 29 pruebas del profesor no detectaban:

| Error | Síntoma observado | Causa | Corrección |
|---|---|---|---|
| En FETCH el ALU sumaba 4 a `old_pc` en lugar de `pc` | En la primera corrida de `make top` (3 pruebas en FAIL) cada instrucción se buscaba dos veces y el firmware no marcó `done` | `alu_src_a` caía en el `default` del `case` (01 = `old_pc`) en FETCH | `multicycle_rv_control_fsm.sv`: `FETCH: alu_src_a = 2'b00` (pc) |
| JALR no limpiaba el bit 0 del destino | Al corregir el error anterior, `test_rv32i.jalr` falló en la corrida del 15 nov: `JALR did not fetch expected PC 0x00000020` (la prueba salta con rs1 = 0x21) | El PC se escribía con `wb_mux` completo; el ISA exige `(rs1 + imm) & ~1` | `multicycle_rv32i.sv`: `pc <= {wb_mux[31:1], 1'b0}` |

Un tercer error apareció al preparar el modo paso a paso (Avance 3), no por una prueba que fallara sino al revisar el diseño:

| Error | Causa | Corrección |
|---|---|---|
| `read_data_reg` se corrompía si la CPU se congelaba en `MEM_WB` | Capturaba `bus_rdata` en todos los ciclos, aun con `enable = 0`; al congelar la CPU se perdía el dato de un `lw` | `multicycle_rv32i.sv`: `else if (enable) read_data_reg <= read_data_data_memory;` |

Detectado por análisis, no por una prueba fallida; las pruebas existentes no congelan la CPU en medio de un `lw`. Tras este cambio y los de `state_num`/`cpu_hold` se repitieron todas las pruebas el 20 nov (secciones 2 a 4).

Sobre por qué las 29 pruebas aprobaban antes: con el primer error, el PC avanzaba desde `old_pc` y las pruebas solo comprueban que el PC esperado aparezca en la lista de búsquedas, no el orden ni la cantidad. Para JALR, la explicación (por análisis del diseño, no verificada reproduciendo el estado anterior) es que la CPU pasaba por 0x20 al recorrer direcciones, por lo que la prueba aprobaba sin que el salto fuera correcto.

Un cuarto error lo encontró `test_programs.xorshift` el 21 nov (falla también en el tag `v0.0.2-proj`):

| Error | Síntoma observado | Causa | Corrección |
|---|---|---|---|
| LUI con ciertos inmediatos daba un resultado incorrecto | `xorshift`: los números del CPU formaban una cadena xorshift válida, pero con semilla `0x678` en lugar de `0x12345678`; `lui s0, 0x12345` dejaba 0 | En LUI, `instr[31:12]` es el inmediato, pero el `alu_decoder` leía `instr[14:12]` y `instr[30]` como `funct3` y `funct7`. Con `0x12345`, `funct3 = 101` decodificaba SRL (0 >> imm = 0); con `0x0F0F1`, SLL; con `0xFFFFF`, SUB o SRA | `multicycle_rv_control_unit.sv`: `funct_3` y `funct_7[5]` se fuerzan a 0 cuando `op` es LUI (la ALU suma 0 + imm) |

La prueba `lui` del repo pasaba por casualidad: su inmediato `0xABCDE` da `funct3 = 110` (OR), y `0 OR imm = imm`. El firmware de la imagen usa inmediatos con esos bits en cero, por eso funcionaba en la placa. `run_lui` en `test_rv32i.py` ahora ejecuta un programa con cinco `lui` (`0xABCDE`, `0x12345`, `0x0F0F1`, `0xFFFFF`, `0x40001`). Tras el arreglo: 29/29 (pytest 30 passed) y `test_programs` 2/2, ambas el 21 nov. Las pruebas unitarias y de sistema (secciones 3 y 4) se repitieron el 21 nov después de este cambio y del filtro de `rv32i_top`: arbiter 8/8, mmio_decoder 7/7, ram 8/8, control_registers 10/10 y `top` 4/4 (con 64 píxeles y con `FULL_IMAGE=1`).

Después de las dos primeras correcciones se repitieron las 29 pruebas del profesor (29/29, dashboard 30 passed), las 4 unitarias (8, 7, 8 y 10 PASS) y el sistema (3/3), todas el 15 nov (repetidas el 20 nov).

---

## 6. Síntesis y timing (Quartus Prime 25.1 Lite)

Proyecto: `sprint4/quartus/top_level.qpf`, entidad top `top_level`, dispositivo 5CSXFC6D6F31C6, SDC `sprint3/sdc/timing_constraints.sdc` (reloj de 20 ns), SignalTap apagado. Compilación completa del 19 nov 2026 sin errores.

| Métrica | Valor |
|---|---|
| Fitter Status | Successful (19 nov 2026) |
| ALMs | 1 609 / 41 910 (4 %) |
| Registros | 1 773 (1 662 tras la síntesis) |
| Pines | 58 / 499 |
| Bits de memoria | 1 187 840 / 5 662 720 (21 %) |
| Bloques RAM (M10K) | 143 / 553 (26 %) |
| Bloques DSP | 0 |
| Fmax `clk` (85 °C, Slow 1100mV) | 67,33 MHz |
| Fmax `clk` (0 °C, Slow 1100mV) | 68,79 MHz |
| Fmax `altera_reserved_tck` (85 °C) | 106,21 MHz |

El reloj de 50 MHz de la placa cumple timing con Fmax de 67,33 MHz en el peor caso. Advertencias del compilador: latch inferido sobre `i` en `rv_register_file.sv`, `tap_handshake_instr` sin uso y puertos de E/S sin restricción completa en el SDC. La comparación con Sprint 3 está en `docs/evidencia_atributos.md`.

Archivos: `sprint4/quartus/output_files/top_level.fit.summary`, `top_level.map.rpt` y `top_level.sta.rpt`.

---

## 7. Modo paso a paso y vistas de depuración

Implementado en `src/top_level.sv` y compilado; no se simuló ni se probó en la placa. SW[0] elige entre 50 MHz y avance manual con KEY[1]. En modo manual, cada pulsación deja correr la FSM hasta que `cpu_state` cambia, porque un pulso de un solo ciclo de `enable` no completa un FETCH ni un handshake de datos. SW[2:1] elige qué muestran los HEX: registros, PC, instrucción o instrucción alta; en las vistas distintas de registros, LEDR muestra `{step_mode, done, busy, illegal, 2'b00, cpu_state}`.

---

## 8. Captura en hardware (SignalTap)

Pendiente. El `.stp` a 50 MHz capturará estado de la FSM, PC, instrucción, `valid`/`ready` y `done`.

---

## 9. Pendientes

| Pendiente | Referencia |
|---|---|
| Programar la DE10-Standard y cargar `firmware.hex` y la imagen por vJTAG (`jtag_server.tcl` + `pixel_image_app.py`) | TP-16 |
| Probar el modo paso a paso en la placa (SW[0], KEY[1], SW[2:1]) y revisar la orientación de los dígitos HEX | TP-11 |
| Captura SignalTap | TP-15 |
| Fmax de Sprint 3 sin SignalTap para una comparación equivalente | `evidencia_atributos.md` |