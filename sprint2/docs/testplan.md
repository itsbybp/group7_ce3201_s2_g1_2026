# Plan de Pruebas — Sprint 2

## Metodología

Siguiendo el paradigma TDHD (Desarrollo de Hardware Guiado por Pruebas), el
diseño RTL, la documentación y las pruebas se desarrollan de forma
concurrente, no en cascada. Cada bloque combinacional o secuencial se valida
con dos herramientas independientes antes de integrarse al datapath
completo:

- **Cocotb + Icarus Verilog**: pruebas funcionales unitarias, escritas en
  Python, corridas automáticamente por el Gatekeeper en cada Pull Request
  (`sprint2/test/cocotb/`).
- **Questa (SystemVerilog puro)**: testbenches independientes, corridos
  localmente, que generan waveforms (`.wlf`) documentados y un resumen
  (`questa_test_summary.log`) verificado por el Gatekeeper
  (`sprint2/test/sv/`).

Ambas suites prueban el mismo comportamiento desde implementaciones de
testbench distintas, reduciendo el riesgo de que un error en la lógica de
prueba (no en el diseño) pase inadvertido.

Cada caso de prueba en las tablas siguientes documenta: **qué** se prueba,
**cómo** se prueba, **por qué** es necesario probarlo, el **resultado
esperado**, y las **limitaciones** conocidas de esa prueba.

## register_bank.sv

| Qué se prueba | Cómo se prueba | Por qué | Resultado esperado | Limitaciones |
|---|---|---|---|---|
| Reset | `reset_n=0` por 3 ciclos, luego se leen x1-x3 | Garantizar un estado inicial conocido tras encender el FPGA | x1, x2, x3 leen `0` | No cubre un reset a mitad de una escritura en curso |
| x0 protegido | Se intenta escribir con `rd=2'b00` y luego se lee `rs1=0` | x0 debe comportarse como constante de arquitectura (convención RISC-like) | `rs1_data` sigue en `0` | No prueba lectura simultánea de x0 por `rs1` y `rs2` |
| Escritura y lectura | Se escribe un valor con `write_en=1` y se lee por `rs1` | Verificar el camino de datos básico write→read | El valor leído coincide con el escrito | Un solo valor por caso; no cubre secuencias de escrituras alternadas |
| write_en desactivado | Se cambian `rd`/`write_data` sin activar `write_en` | Evitar escrituras accidentales por glitches en las señales de control | Ningún registro cambia | No cubre glitches combinacionales reales (solo el modelo RTL) |
| Write-enable individual | Se escribe x2 y x3 en ciclos distintos y se leen ambos | Confirmar que los decodificadores de destino son independientes | x2 y x3 retienen sus valores propios sin interferencia | Solo 2 de 3 registros generales cubiertos simultáneamente |
| Limpieza en reset | Se escribe un valor, se activa `reset_n=0`, se lee de nuevo | Un reset a mitad de operación no debe dejar datos residuales | El registro vuelve a `0` | — |

Implementado en: `test_register_bank.py` (Cocotb, 6 casos) y
`tb_register_bank.sv` (Questa, mismos 6 casos).

## key_sync.sv

| Qué se prueba | Cómo se prueba | Por qué | Resultado esperado | Limitaciones |
|---|---|---|---|---|
| Reset activo | `key0_raw=0` sostenido | El sistema debe permanecer en reset mientras el botón físico está presionado | `reset_n=0` | No modela ruido de rebote (bounce) del botón físico |
| Liberación de reset | `key0_raw` sube a 1, se esperan ciclos | La liberación debe ser síncrona para evitar metaestabilidad aguas abajo | `reset_n=1` solo tras 2 flancos de reloj | Simulación ideal: no inyecta metaestabilidad real |
| Pulso de 1 ciclo | Flanco de subida de `key_raw`, se cuentan ciclos con `key_pulse=1` | Un botón físico se mantiene presionado muchos ciclos; el sistema debe reaccionar una sola vez | Exactamente 1 pulso de 1 ciclo | — |
| No repetición | `key_raw` se mantiene en alto 10 ciclos | Evitar múltiples acciones por una sola pulsación | Un solo pulso en toda la ventana | — |
| Segundo toque | Se libera y se vuelve a presionar `key_raw` | Confirmar que el detector de flancos se rearma correctamente | Un nuevo pulso en el segundo flanco | No cubre pulsaciones extremadamente rápidas (sub-ciclo) |

Implementado en: `test_key_sync.py` (Cocotb, 5 casos) y `tb_key_sync.sv`
(Questa, mismos 5 casos).

## input_fsm.sv

| Qué se prueba | Cómo se prueba | Por qué | Resultado esperado | Limitaciones |
|---|---|---|---|---|
| Reset | Reset asíncrono activo | Estado inicial conocido antes de aceptar entradas | `current_state=2'b11`, `out=0` | — |
| `step=0` no avanza | Se mantiene `step=0` con `nibble_input` fijo | El usuario no debe perder o duplicar datos si no confirma con `KEY[2]` | Estado y `out` no cambian | — |
| Un nibble | Un pulso de `step` con un nibble | Verificar la escritura del primer nibble en la posición correcta (LSB) | `out[3:0]` = nibble, avanza a `2'b10` | — |
| Ensamblaje de 4 nibbles | 4 pulsos consecutivos de `step` con nibbles distintos | Es el caso de uso real: un dato de 16 bits requiere 4 cargas | `out` = concatenación correcta, LSB-first | No cubre entradas fuera de secuencia (siempre se prueba en orden) |
| Bloqueo tras finalizar | Se intenta un quinto nibble tras completar los 4 | El hardware solo tiene 4 estados; una quinta entrada no debe corromper el dato ya ensamblado | `out` y `current_state` no cambian | Depende de que `top_level.sv` limpie el reset en el ciclo de escritura; no se prueba esa interacción a este nivel |
| Reset asíncrono a mitad de ensamblaje | Reset se activa después de cargar un nibble | El reset debe interrumpir el ensamblaje en cualquier punto, no solo en reposo | `out` vuelve a `0`, estado vuelve a `2'b11` | — |

Implementado en: `test_input_fsm.py` (Cocotb) y `tb_input_fsm.sv` (Questa).

## exec_fsm.sv

| Qué se prueba | Cómo se prueba | Por qué | Resultado esperado | Limitaciones |
|---|---|---|---|---|
| Reset | Reset asíncrono activo | Estado inicial conocido (`Idle`) antes de cualquier ejecución | `current_state=Idle (2'b11)`, `write_enable=0` | — |
| Ejecución en modo continuo | `start_execute=1` con `stepping_mode=0`, se avanza ciclo a ciclo | Verifica el recorrido automático de los 4 estados sin intervención del usuario | Secuencia `Idle→Wait1→Write→Wait2→Idle` correcta | — |
| Pulso de `write_enable` | Se observa `write_enable` durante toda la secuencia | `write_enable` debe activarse un único ciclo, exactamente cuando el dato es válido para escribir | `write_enable=1` solo en la transición `Wait1→Write` | — |
| Pausa en modo paso a paso | `stepping_mode=1`, se alterna `step=0`/`step=1` | El usuario debe poder controlar manualmente el avance de la ejecución | La FSM permanece en el mismo estado mientras `step=0` | — |
| `write_enable` no se repite en modo paso a paso | Se mantiene la FSM varios ciclos en `Write` con `step=0` | Aunque la FSM permanezca en `Write` varios ciclos por el modo paso a paso, la escritura real solo debe ocurrir una vez | `write_enable=0` en los ciclos adicionales dentro de `Write` | — |
| Reset asíncrono a mitad de ejecución | Reset se activa entre flancos de reloj, durante `Wait1` | El reset debe poder interrumpir una ejecución en curso sin dejar `write_enable` activo incorrectamente | Retorno inmediato a `Idle`, `write_enable=0` | — |

Implementado en: `test_exec_fsm.py` (Cocotb) y `tb_exec_fsm.sv` (Questa).

## display_logic.sv

| Qué se prueba | Cómo se prueba | Por qué | Resultado esperado | Limitaciones |
|---|---|---|---|---|
| Menú 00 (inmediato) | Se fija `immediate` positivo y negativo | El valor mostrado debe reflejar exactamente lo que el usuario ensambló, con signo correcto | Dígitos BCD y signo correctos en `HEX0`-`HEX5` | — |
| Prioridad de `immediate` sobre `alu_result_freeze` en menú 00 | Se fijan ambos valores simultáneamente en menú 00 | Confirmar que el multiplexado interno no mezcla ambas fuentes | Solo se muestra `immediate` | — |
| Menú 01 (registros) | Se varían `rd`/`rs1`/`rs2` | El usuario debe poder confirmar visualmente qué registros configuró antes de ejecutar | `HEX0`-`HEX2` muestran `rd`, `rs1`, `rs2`; resto apagado | Solo verifica combinaciones puntuales, no las 64 combinaciones posibles de `rd,rs1,rs2` |
| Menú 10 (opcode) | Se varía `opcode` entre `0x0` y `0xF` | El opcode debe mostrarse en decimal de 2 dígitos para operadores no familiarizados con hexadecimal | `HEX0`-`HEX1` decimal correcto; resto apagado | — |
| Menú 11 (resultado ALU) | Se fija `alu_result_freeze` positivo y negativo | Es el resultado final que el usuario necesita leer tras ejecutar | Dígitos BCD y signo correctos | — |
| Prioridad de `alu_result_freeze` sobre `immediate` en menú 11 | Se fijan ambos simultáneamente en menú 11 | Igual que el caso simétrico del menú 00, para la fuente contraria | Solo se muestra `alu_result_freeze` | — |

Implementado en: `test_display_logic.py` (Cocotb). El convertidor BCD
(`binary_to_bcd_converter.sv`) se ejercita indirectamente a través de estas
pruebas, ya que no dispone de un testbench propio: su comportamiento numérico
(Double Dabble) queda cubierto por los valores de 5 dígitos verificados en
los casos de menú 00 y 11.

## top_level.sv (integración)

| Qué se prueba | Cómo se prueba | Por qué | Resultado esperado | Limitaciones |
|---|---|---|---|---|
| Flujo completo (caso de uso típico) | Secuencia real de switches y botones: cargar inmediato, configurar registros y opcode, ejecutar, verificar LEDR/HEX | Es la única prueba que verifica que todos los módulos están correctamente cableados entre sí | El resultado final coincide con el cálculo esperado y se refleja en pantalla | Cubre un subconjunto de combinaciones de opcode/registros/config_aux, no el espacio completo |
| Encadenamiento de resultados (usar un resultado como operando de la siguiente operación) | Se ejecuta una operación, luego se usa el registro destino como fuente en la siguiente | Verifica que el banco de registros y el freeze de la ALU sostienen el dato correctamente entre operaciones | El segundo resultado usa el valor recién escrito, no uno obsoleto | — |
| Ejecución con modo paso a paso activado a mitad de flujo | Se alterna `KEY[3]` antes de lanzar `exec_fsm` | El modo de ejecución debe ser seleccionable independientemente del resto del flujo | La FSM de ejecución respeta el modo activo al momento de lanzarse | — |
| Cambio del inmediato durante una ejecución en curso | Se cambia `SW`/menú mientras `exec_fsm` está en `Wait1` (modo paso a paso) | El resultado ya congelado (`alu_result_freeze`) no debe verse afectado por cambios posteriores en las entradas | El resultado escrito corresponde al operando vigente al iniciar la ejecución, no al modificado después | — |
| Intento de escritura a x0 | Se configura `rd=0` y se ejecuta una operación | x0 debe seguir protegido incluso llegando desde el datapath completo, no solo desde `register_bank` aislado | x0 permanece en `0` tras la ejecución | — |

Implementado en: `test_top_level.py` (Cocotb) y `tb_top_level.sv` (Questa).

## Limitaciones generales del plan de pruebas

- Ninguna de las suites modela metaestabilidad física real ni rebote de
  botones: `key_sync.sv` se prueba únicamente a nivel de su modelo lógico
  ideal en simulación.
- Las pruebas de integración (`top_level`) cubren escenarios de uso
  representativos, no una verificación exhaustiva del espacio de entradas
  (a diferencia de la ALU combinacional de Sprint 1, que sí se verificó de
  forma exhaustiva por ser puramente combinacional y de espacio de estados
  pequeño).
- No existe todavía un testbench dedicado para `binary_to_bcd_converter.sv`
  de forma aislada; su corrección se infiere de las pruebas de
  `display_logic.sv`.

## Herramientas y reproducibilidad

Ver instrucciones de ejecución local en el `README.md` de la raíz del
repositorio (sección "Plataformas Soportadas").