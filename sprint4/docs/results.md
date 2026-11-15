# Resultados de Verificación: Sprint 4 (Avance 2)

**Proyecto:** CE3201 Taller de Diseño Digital, Grupo 7
**Fecha:** 15 nov 2026
**Avance:** 2, tag `v0.0.2-proj`
**Arquitectura:** ver `docs/architecture.md`
**Plan de pruebas:** ver `docs/testplan.md`
**Entorno de simulación:** Verilator 5.053 (devel), cocotb 2.1.0, Python 3.12, WSL. Todos los resultados de las secciones 2 a 5 son de la corrida del 15 nov 2026, con el diseño ya corregido (sección 5).

---

## Resumen

| Verificación | Herramienta | Resultado | Estado |
|---|---|---|---|
| Prueba del repo con mock CPU | Cocotb | 29/29 PASS | Ejecutada en Avance 1 (no repetida el 15 nov) |
| Verificación del repo sobre `rv32i_cpu` | Cocotb | 29/29 PASS | Ejecutada |
| Enabler (`enable = 0`) | Cocotb | Sin `valid` activo | Ejecutada antes de las correcciones de la sección 5; no repetida el 15 nov |
| Unitaria `arbiter` | Cocotb | 8/8 PASS | Ejecutada |
| Unitaria `mmio_decoder` | Cocotb | 7/7 PASS | Ejecutada |
| Unitaria `ram` | Cocotb | 8/8 PASS | Ejecutada |
| Unitaria `control_registers` | Cocotb | 10/10 PASS | Ejecutada |
| Sistema `rv32i_top` (CPU + árbitro + MMIO + RAM + registros) | Cocotb | 3/3 PASS | Ejecutada |
| Síntesis en Quartus | Quartus Prime | Pendiente | Pendiente |
| Captura en hardware | SignalTap | No ejecutada | Pendiente |

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

Resultado (después de las correcciones de la sección 5):

```
** TESTS=29 PASS=29 FAIL=0 SKIP=0               7144.03           0.07     103927.16  **
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

### Enabler

Con `enable = 0` en el wrapper, el procesador no genera `valid` (0 mensajes de `valid activo` frente a 300 antes de la corrección) y la prueba termina por timeout, como se espera de una CPU apagada. Esta prueba se ejecutó antes de las correcciones de la sección 5 y no se repitió el 15 nov. Las correcciones no tocan la lógica de `enable`, pero no se verificó de nuevo.

### Evidencia

Archivos en `docs/evidencia/avance2/`:

- `avance2_cocotb.log`: salida completa de la corrida (29/29 y pytest 30 passed).
- `coverage.json`: bins cubiertos y conteo de hits.
- `dashboard_cpu.html`: resultado por prueba y cobertura por instrucción.

Los tres archivos corresponden a la corrida posterior a las correcciones.

---

## 3. Pruebas unitarias (Cocotb + Verilator)

Directorio: `sprint4/test/cocotb`. Comando: `make all` (ejecuta `arbiter`, `mmio_decoder`, `ram`, `control_registers` y `top`; la salida completa se guardó en `docs/evidencia/avance2/avance2_unit_system.log`).

| Módulo | Pruebas | Resultado | Qué verifican |
|---|---|---|---|
| `arbiter` | 8 | 8/8 PASS | Prioridad del Host, backpressure, la CPU conserva el bus mientras espera `ready`, reset, aleatoria contra modelo de referencia |
| `mmio_decoder` | 7 | 7/7 PASS | Permisos de escritura de la Tabla 2, selección de lectura, latencia de `rdata`, RAZ/WI fuera de mapa, `valid = 0`, secuencia de `ready` |
| `ram` | 8 | 8/8 PASS | Primera y última palabra de cada memoria, independencia entre memorias, latencia de 1 ciclo, histograma (0x3FC), puerto de instrucciones |
| `control_registers` | 10 | 10/10 PASS | Valores de reset, LEDR/HEX/THRESHOLD, CTRL start/busy, STATUS done, re-armado, lecturas sin mapear en 0, reset asíncrono |

---

## 4. Prueba de sistema (`rv32i_top`)

Se integró la CPU con el árbitro, el decodificador MMIO, la RAM (M10K) y los registros de control en `src/rv32i_top.sv`. El Host (vJTAG simulado) carga `firmware.hex` y la imagen, escribe CTRL y espera `done`.

Comando: `make top` (en `sprint4/test/cocotb`).

```
** TESTS=3 PASS=3 FAIL=0 SKIP=0                     425582.00           0.16    2641908.91  **
```

| Prueba | Qué verifica | Resultado |
|---|---|---|
| `test_fetch_secuencial` | Las primeras 10 búsquedas de instrucción son 0x0, 0x4, …, 0x24 (cada instrucción una sola vez y en orden) y no hay instrucción ilegal | PASS |
| `test_firmware_end_to_end` (TP-13) | Histograma de 256 bins e imagen binarizada exactos contra un modelo en Python; la suma del histograma es N; `STATUS = 0b10`; `HEX = N`; nada se escribe fuera de la imagen; ninguna instrucción ilegal. 64 píxeles, ~9280 ciclos hasta `done` | PASS |
| `test_firmware_with_bus_stalls` (TP-12) | Mismo resultado con el Host leyendo direcciones al azar durante la ejecución (1507 lecturas); la CPU espera por el bus y no pierde datos. ~9792 ciclos hasta `done` | PASS |

### Qué se observó

- **Orden de búsqueda.** La traza de `test_fetch_secuencial` fue `0x0, 0x4, 0x8, 0xc, 0x10, 0x14, 0x18, 0x1c, 0x20, 0x24, 0x28, 0x2c, 0x24, 0x28`. Las primeras 10 son las que verifica la prueba. Después de `0x2c` (el `bne` del bucle `clear` de `firmware.s`) vuelve a `0x24`, que es lo esperado del salto hacia atrás.
- **Costo de los stalls.** Con el Host leyendo al azar, el firmware tardó ~9792 ciclos contra ~9280 sin ruido (~5 % más). Los ciclos se miden revisando `done` cada 64 ciclos, por lo que son aproximados (±64).
- **Velocidad.** ~9280 ciclos para 64 píxeles son ~145 ciclos por píxel. Con la imagen completa (16384 píxeles) serían del orden de 2,4 millones de ciclos; es una extrapolación, no una medición.

### Cómo se redujo la imagen

La prueba no ejecuta `firmware.hex` tal cual: carga solo 64 píxeles y `shorten_loop` modifica dos palabras del firmware en la RAM de instrucciones para que el bucle termine tras 64 píxeles:

| Palabra original | Palabra en la prueba | Efecto |
|---|---|---|
| `addi t0, zero, 1` (0x14) | `addi a1, s0, 4*64` | a1 = fin de la imagen reducida. El `sw t0, 4(s4)` siguiente escribe 0 en STATUS en lugar de 1 (busy); no cambia el resultado porque `busy` ahora se calcula en hardware (`start && !done`) |
| `bne t0, s1, loop` | `bne t0, a1, loop` | El bucle termina en 0x10000 + 4*64 en vez de 0x20000 |

El resto del firmware (limpieza del histograma, histograma, binarización, escritura de HEX y de `STATUS.done`) se ejecuta sin cambios. El firmware original completo (16384 píxeles) no se simuló: la prueba tiene la opción `FULL_IMAGE=1`, pero no se ejecutó.

### Limitaciones de las pruebas

- La imagen de entrada es aleatoria con semilla fija (64 píxeles, con un píxel justo en el umbral y otro justo debajo); no es una imagen real.
- `THRESHOLD` se fijó en 100. Otros umbrales no se probaron.
- Las pruebas de JAL y JALR del repo del profesor verifican el destino del salto, no el valor de enlace (`rd = pc + 4`). El firmware solo usa `jal` implícito en `j halt`.

---

## 5. Errores encontrados al integrar

La prueba de sistema encontró dos errores de la CPU que las 29 pruebas del profesor no detectaban:

| Error | Síntoma observado | Causa | Corrección |
|---|---|---|---|
| En FETCH el ALU sumaba 4 a `old_pc` en lugar de `pc` | En la primera corrida de `make top` (3 pruebas en FAIL) cada instrucción se buscaba dos veces y el firmware no marcó `done` | `alu_src_a` caía en el `default` del `case` (01 = `old_pc`) en FETCH | `multicycle_rv_control_fsm.sv`: `FETCH: alu_src_a = 2'b00` (pc) |
| JALR no limpiaba el bit 0 del destino | Al corregir el error anterior, `test_rv32i.jalr` falló en la corrida del 15 nov: `JALR did not fetch expected PC 0x00000020` (la prueba salta con rs1 = 0x21) | El PC se escribía con `wb_mux` completo; el ISA exige `(rs1 + imm) & ~1` | `multicycle_rv32i.sv`: `pc <= {wb_mux[31:1], 1'b0}` |

Sobre por qué las 29 pruebas aprobaban antes: con el primer error, el PC avanzaba desde `old_pc` y las pruebas solo comprueban que el PC esperado aparezca en la lista de búsquedas, no el orden ni la cantidad. Para JALR, la explicación (por análisis del diseño, no verificada reproduciendo el estado anterior) es que la CPU pasaba por 0x20 al recorrer direcciones, por lo que la prueba aprobaba sin que el salto fuera correcto.

Después de ambas correcciones se repitieron las 29 pruebas del profesor (29/29, dashboard 30 passed), las 4 unitarias (8, 7, 8 y 10 PASS) y el sistema (3/3), todas el 15 nov.

---

## 6. Síntesis y timing (Quartus Prime)

Pendiente. El top `rv32i_top` ya existe y se simula; falta crear el proyecto de Quartus con él (conexión a vJTAG, LEDR y HEX de la DE10-Standard). Esta sección incluirá:

| Métrica | Valor |
|---|---|
| Flow Status | Pendiente |
| ALMs | Pendiente |
| Registros | Pendiente |
| Bloques de memoria | Pendiente |
| Fmax (`.sta.rpt`) | Pendiente |

---

## 7. Captura en hardware (SignalTap)

Pendiente.

---

## 8. Pendientes

| Pendiente | Referencia |
|---|---|
| Modo stepping | `architecture.md`, TP-11 |
| Proyecto de Quartus con `rv32i_top` | `testplan.md`, TP-14 |
| Captura SignalTap | `testplan.md`, TP-15 |
| Imagen completa (16384 píxeles) en simulación | `FULL_IMAGE=1`, no ejecutada |
| Repetir la prueba del enabler con el diseño corregido | TP-10 |