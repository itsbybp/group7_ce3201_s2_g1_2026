# Documento de Control de Interfaz (ICD) — Sprint 2

## Propósito

Este documento define el contrato de interfaz entre los bloques del
datapath de Sprint 2: anchos de bus, codificación de señales, y el
protocolo de menú local por el que el usuario interactúa con el sistema
a través de los switches y botones físicos de la DE10-Standard.

## Ancho de datos

Todo el datapath opera en **16 bits**: operandos, resultados, y cada uno
de los 4 registros del banco.

## Banco de registros (x0-x3)

| Registro | Código (2 bits) | Tipo | Descripción |
|---|---|---|---|
| x0 | `2'b00` | Constante | Fijo en `16'h0000`. Protegido contra escritura: si se selecciona como destino, ninguna escritura ocurre. |
| x1 | `2'b01` | General | Registro de 16 bits, con write-enable individual. |
| x2 | `2'b10` | General | Registro de 16 bits, con write-enable individual. |
| x3 | `2'b11` | General | Registro de 16 bits, con write-enable individual. |

**Puertos de `register_bank.sv`:**

| Puerto | Dirección | Ancho | Descripción |
|---|---|---|---|
| `clk` | input | 1 | Reloj del sistema (`CLOCK_50`, ya sincronizado). |
| `reset_n` | input | 1 | Reset activo en bajo, ya sincronizado (viene de `key_sync`). |
| `rd` | input | 2 | Registro destino de la escritura actual. |
| `rs1` | input | 2 | Registro fuente 1 (para lectura hacia la ALU). |
| `rs2` | input | 2 | Registro fuente 2 (para lectura hacia la ALU). |
| `write_en` | input | 1 | Habilita la escritura en el registro seleccionado por `rd`. |
| `write_data` | input | 16 | Dato a escribir cuando `write_en=1`. |
| `rs1_data` | output | 16 | Valor leído del registro seleccionado por `rs1`. |
| `rs2_data` | output | 16 | Valor leído del registro seleccionado por `rs2`. |

## Protocolo de menú local (SW[7:6])

El usuario interactúa con el sistema a través de un menú de 4 modos,
seleccionado con `SW[7:6]`. El significado de `SW[5:0]` cambia según el
modo activo:

| `SW[7:6]` | Modo | `SW[5:0]` significa |
|---|---|---|
| `2'b00` | Carga de nibble | `SW[3:0]` = nibble a cargar (confirmado con `KEY[2]`) |
| `2'b01` | Selección de registros | `SW[5:4]`=rd, `SW[3:2]`=rs1, `SW[1:0]`=rs2 |
| `2'b10` | Selección de opcode | `SW[5:0]` = código de operación de la ALU |
| `2'b11` | Ejecución | No aplica; se usa `KEY[1]` (paso a paso) o modo continuo |

### Carga de un dato de 16 bits

Como solo hay 4 switches disponibles para datos (`SW[3:0]`), un valor de
16 bits se ensambla en **4 cargas sucesivas de nibble** (4 bits cada
una), confirmando cada una con `KEY[2]`.

## Botones físicos (KEY[3:0])

| Botón | Función |
|---|---|
| `KEY[0]` | Reset global (activo en bajo). Acondicionado por `key_sync` mediante reset bridge: entrada asíncrona, liberación síncrona. |
| `KEY[1]` | Avanza un paso en modo de ejecución paso a paso. |
| `KEY[2]` | Confirma/carga (nibble, selección de registros, u opcode, según el modo activo). |
| `KEY[3]` | Selecciona modo continuo (automático a 50MHz) vs. paso a paso. |

## Acondicionamiento de entradas (`key_sync.sv`)

**Puertos:**

| Puerto | Dirección | Ancho | Descripción |
|---|---|---|---|
| `clk` | input | 1 | Reloj del sistema. |
| `key_raw` | input | 1 | Botón físico sin acondicionar (KEY[1] o KEY[2], según la instancia). |
| `key0_raw` | input | 1 | KEY[0] sin acondicionar, usado para el reset bridge. |
| `key_pulse` | output | 1 | Pulso de exactamente 1 ciclo de reloj al detectar flanco de subida de `key_raw`. |
| `reset_n` | output | 1 | Reset acondicionado: entrada asíncrona, liberación síncrona. |

**Garantías de la interfaz:**
- `key_pulse` nunca se mantiene en alto por más de 1 ciclo de reloj, sin
  importar cuánto tiempo se mantenga presionado `key_raw`.
- `reset_n` se activa (cae a 0) de forma inmediata al presionar `KEY[0]`,
  pero solo se libera (sube a 1) alineado a un flanco de reloj — nunca
  antes.