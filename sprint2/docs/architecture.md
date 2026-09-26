# Arquitectura del Sistema — Sprint 2

## Descripción General

El sistema implementa una unidad de ejecución secuencial de 16 bits controlada
por dos máquinas de estados finitos (FSM) que operan sobre un datapath
discreto. El usuario interactúa con el sistema exclusivamente a través de los
switches (`SW[9:0]`) y botones (`KEY[3:0]`) físicos de la DE10-Standard,
navegando un menú local de 4 modos (`SW[7:6]`).

El flujo general es:

1. **Entrada serial de un dato de 16 bits** (`input_fsm.sv`): el usuario carga
   un valor inmediato en 4 nibbles sucesivos de `SW[3:0]`, confirmando cada
   uno con `KEY[2]`.
2. **Selección de registros y opcode** (lógica de menú en `top_level.sv`): el
   usuario configura `rd`/`rs1`/`rs2` (menú `01`) y el opcode de la ALU (menú
   `10`), cada uno confirmado con `KEY[2]`.
3. **Selección de operandos**: `SW[9:8]` (`config_aux`) determina qué
   combinación de `rs1_data`, `rs2_data` e `immediate` se usa como operandos
   `a`/`b` de la ALU.
4. **Ejecución controlada** (`exec_fsm.sv`): al entrar al menú `11` y pulsar
   `KEY[2]`, la FSM de ejecución recorre una secuencia de 4 estados que
   garantiza que el resultado de la ALU se escriba en el banco de registros
   de forma síncrona y libre de riesgos de carrera, ya sea en modo continuo
   (a 50 MHz) o en modo paso a paso (`KEY[1]`, habilitado por `KEY[3]`).
5. **Visualización** (`display_logic.sv`): los displays de 7 segmentos
   muestran, según el menú activo, el inmediato, los registros configurados,
   el opcode, o el resultado de la ALU, todos en decimal con signo.

La ALU de 16 bits (`alu_param.sv`) y el banco de registros discreto
(`register_bank.sv`) se reutilizan sin cambios funcionales desde Epic 1 /
Sprint 1. Los módulos `n_bit_absolute_value.sv` y `seven_segment_adapter.sv`
también se reutilizan del Sprint 1 dentro de `display_logic.sv`.

## Diagrama de Bloques

![Diagrama de arquitectura](img/architecture.png)

## Componentes

### key_sync.sv (Epic 1, sin cambios)

Tres instancias en `top_level.sv`: `u_step_key_sync` (sobre `KEY[1]`),
`u_load_key_sync` (sobre `KEY[2]`) y `u_stepping_key_sync` (sobre `KEY[3]`).
Sólo la salida `reset_n` de `u_step_key_sync` se conecta (a `RB`, `IFSM`,
`EFSM` y `TOG`); en las otras dos instancias esa salida queda sin usar,
porque el reset bridge solo necesita generarse una vez.

### toggle.sv

Registro de 1 bit que invierte su valor cada vez que `enable` recibe un
pulso síncrono de un ciclo. Se usa para convertir el pulso de `KEY[3]`
(`stepping_mode_pulse`) en un estado persistente (`stepping_mode_is_on`),
ya que la Tabla de especificación no define `KEY[3]` como un botón momentáneo
sino como un selector de modo.

### input_fsm.sv

FSM de 4 estados (`2'b11 → 2'b10 → 2'b01 → 2'b00`) que ensambla un valor de
16 bits a partir de 4 nibbles sucesivos de 4 bits (`SW[3:0]`), confirmados
uno a uno por `load_pulse` (proveniente de `KEY[2]`). Los nibbles se cargan
de más significativo a menos significativo en el orden de estados, pero el
**primer nibble ingresado ocupa los bits menos significativos** de `out`
(entrada LSB-first). Al llegar al estado `2'b00`, la bandera interna
`serial_assembly_FSM_finished` se activa y bloquea nuevas entradas hasta que
el módulo se reinicia.

En `top_level.sv`, el reset de esta FSM es `reset_n & ~execute_FSM_write_enable`:
el valor ensamblado se limpia automáticamente en el mismo ciclo en que la
FSM de ejecución escribe el resultado, permitiendo reutilizar el registro
para el siguiente dato sin una señal de limpieza explícita adicional.

### exec_fsm.sv

FSM de 4 estados (`Idle=2'b11 → Wait1=2'b10 → Write=2'b01 → Wait2=2'b00 →
Idle`) responsable de que el resultado de la ALU se escriba en el banco de
registros exactamente un ciclo de reloj, sin importar si el usuario avanza
en modo continuo o modo paso a paso.

- `write_enable` se activa combinacionalmente cuando
  `current_state_delayed == 2'b10 && current_state == 2'b01`, es decir, un
  registro de estado retrasado un ciclo (`current_state_delayed`) se usa
  para generar un pulso de un único ciclo, incluso si la FSM permanece varios
  ciclos en el estado `Write` por causa del modo paso a paso.
- El avance de estado ocurre si `step || ~stepping_mode`: en modo continuo
  (`stepping_mode=0`) avanza cada flanco de reloj; en modo paso a paso
  requiere `step=1` (pulso de `KEY[1]`).
- El reset es asíncrono activo en bajo (`negedge reset`).

### register_bank.sv y ALU de 16 bits (Epic 1 / Sprint 1, sin cambios)

Ver `ICD.md` para el detalle de puertos. Sin modificaciones funcionales
respecto a Epic 1 (banco de registros) y Sprint 1 (`alu_param.sv`).

Selección de operandos (`config_aux`, `SW[9:8]`), lógica combinacional en
`top_level.sv`:

| `config_aux` | `operand_a` | `operand_b` |
|---|---|---|
| `2'b00` | `rs1_data` | `immediate` |
| `2'b01` | `rs1_data` | `rs2_data` |
| `2'b10` | `immediate` | `rs1_data` |
| `2'b11` | `rs2_data` | `rs1_data` |

**Registro de congelamiento (`alu_result_freeze`)**: dado que la ALU es
combinacional y sus operandos pueden cambiar mientras la FSM de ejecución
está en curso, el resultado se captura en un registro síncrono cuando
`execute_fsm_is_idle` es verdadero (es decir, se actualiza únicamente
mientras no hay una ejecución en curso). Esto imita una etapa de pipeline,
asegurando que `write_data` y el valor mostrado en pantalla permanezcan
estables durante toda la secuencia de escritura.

### binary_to_bcd_converter.sv

Convertidor binario a BCD de 16 bits mediante el algoritmo Double Dabble
(desplazar y sumar 3), sin usar operadores de módulo o división. Su salida
es de 20 bits (5 dígitos BCD empaquetados). Recibe el valor absoluto del
número a convertir (el signo se maneja fuera de este módulo).

### display_logic.sv

Módulo combinacional que decide qué mostrar en los 6 displays de 7
segmentos según `local_menu` (`SW[7:6]`):

| `local_menu` | Contenido mostrado |
|---|---|
| `2'b00` | Inmediato ensamblado (`immediate`), decimal con signo, `HEX5` = signo |
| `2'b01` | `rd`, `rs1`, `rs2` en `HEX0`-`HEX2` (decimal), resto apagado |
| `2'b10` | Opcode (`alu_control`) en `HEX0`-`HEX1` (decimal), resto apagado |
| `2'b11` | `alu_result_freeze`, decimal con signo, `HEX5` = signo |

Internamente instancia `n_bit_absolute_value` (16 bits, reutilizado del
Sprint 1) para obtener el valor absoluto antes de la conversión BCD, y 5
instancias de `seven_segment_adapter` (reutilizado del Sprint 1) para
convertir cada dígito BCD a segmentos.

## Limitaciones y trabajo futuro conocido

- Los estados de `input_fsm.sv` y `exec_fsm.sv` se codifican con literales
  `2'bXX` en lugar de un `typedef enum`. Es una mejora de legibilidad
  pendiente que no afecta la funcionalidad verificada.
- `input_fsm.sv` contiene comentarios informales en el bloque `default` del
  `case`; están marcados para limpieza en una futura iteración de estilo.
- El resto de las secciones de este documento (`ICD.md`, `testplan.md`,
  `results.md`, `fsm.md`) detallan, respectivamente, el contrato de
  interfaz, la cobertura de pruebas, la evidencia de verificación y las
  máquinas de estado en profundidad.