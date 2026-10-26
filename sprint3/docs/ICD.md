# ICD — Interface Control Document (Sprint 3)

## 1. Mapa de memoria MMIO (32 bits de dirección, bus de datos de 32 bits)

| Rango                   | Bloque                        | Ancho dato |
|-------------------------|--------------------------------|------------|
| 0x00000 - 0x0FFFF       | RAM_IN (entrada de imagen, `mem_in`)     | 32 bits |
| 0x10000 - 0x1FFFF       | RAM_OUT (salida de imagen, `mem_out`)    | 32 bits |
| 0x20000 - 0x2007C       | Banco de registros RISC-V (x0-x31) | 32 bits |
| 0x30000                 | LEDR                             | 32 bits    |
| 0x30004                 | HEX                              | 32 bits    |
| 0x40000                 | CTRL                             | 32 bits    |
| 0x40004                 | STATUS                           | 32 bits    |
| 0x40008                 | TIMER_LIMIT                      | 32 bits    |
| 0x4000C                 | THRESHOLD                        | 32 bits    |

Cualquier dirección fuera de estos rangos retorna `rdata=0` y las escrituras se ignoran (RAZ/WI), decodificado por `mmio_decoder.sv` (`SEL_NONE`).

## 2. Protocolo vJTAG (`vjtag_interface.sv`)

El IR (Instruction Register) de la IP `vjtag` selecciona la operación vía `jtag_ir_state_t`:

| Código IR | Operación   |
|-----------|-------------|
| `2'b00`   | BYPASS      |
| `2'b01`   | WRITE       |
| `2'b10`   | READ        |
| `2'b11`   | SET_ADDR    |

Secuencia típica de escritura:
1. IR = `SET_ADDR`, se desplaza la dirección de 32 bits por `DR_ADDR`, pulso `udr` → `addr_out` se actualiza y se genera `jtag_addr_toggle`.
2. IR = `WRITE`, se desplaza el dato de 32 bits por `DR1`, pulso `udr` → `data_out` se actualiza y se genera `jtag_write_toggle`.

Ambos toggles cruzan el dominio `tck`→`clk` en `top_level.sv` mediante un sincronizador de 3 flip-flops + detección de flanco (XOR):
```systemverilog
assign addr_pulse  = addr_sync_q[2]  ^ addr_sync_q[1];
assign write_pulse = write_sync_q[2] ^ write_sync_q[1];
```
Estos pulsos de un ciclo disparan la FSM interna de vJTAG (`vj_state_t`: `VJ_IDLE → VJ_WRITE_REQ` o `VJ_IDLE → VJ_READ_REQ → VJ_READ_CAP`), que es la que genera `vjtag_valid`/`vjtag_write_en` hacia el `arbiter`.

## 3. RAM (0x00000 - 0x1FFFF)

Dos memorias físicas separadas de 16384 palabras x 32 bits (64 KB cada una), dirección de 14 bits:

```systemverilog
module ram (
    input  wire logic        clk,
    input  wire logic [13:0] addr_a,   // RAM_IN  (0x00000-0x0FFFF)
    input  wire logic [31:0] data_in_a,
    input  wire logic        we_a,
    input  wire logic        re_a,
    output logic [31:0]      data_out_a,
    input  wire logic [13:0] addr_b,   // RAM_OUT (0x10000-0x1FFFF)
    input  wire logic [31:0] data_in_b,
    input  wire logic        we_b,
    input  wire logic        re_b,
    output logic [31:0]      data_out_b
);
```
`top_level.sv` selecciona el buffer con `buf_sel = mux_addr[16]` (0 = `mem_in`, 1 = `mem_out`); ambos puertos usan el mismo índice `mux_addr[15:2]`. No hay conflicto de prioridad entre puertos porque cada uno escribe en un arreglo físico distinto. La RAM **no tiene puerto de reset** (ni físico ni `soft_reset`); su contenido nunca se borra.

## 4. Banco de registros RISC-V (0x20000 - 0x2007C)

### 4.1 Convención de uso
- `x0`: siempre 0, protegido contra escritura (write-ignored).
- `x1`: usado por `fsm.sv` como registro de scratch de ALU durante el procesamiento de la imagen.
- `x2`-`x31`: de propósito general, disponibles para el usuario vía JTAG.

### 4.2 Direccionamiento
```systemverilog
module memory_mapped_register_file (
    input  logic        clk,
    input  logic        reset_n,
    input  logic [31:0] mmio_address,
    input  logic        write_en,
    input  logic [31:0] write_data,
    output logic [31:0] selected_register
);
```
`address = mmio_address[6:2]` (5 bits, selecciona x0-x31). `x0` no tiene componente físico (`registers[31:1]`); se fuerza a `0` combinacionalmente y las escrituras a esa dirección se ignoran. Reset físico únicamente (`reset_n`), sin `soft_reset`.

## 5. Registros de control (0x40000 - 0x4000C)

### CTRL (0x40000)
| Bit | Nombre        | Descripción |
|-----|---------------|-------------|
| 0   | `start`       | `fsm.sv` lo lee en `S_IDLE` (`fsm_rdata[0]`); si es 1, arranca el procesamiento. La propia FSM emite el pulso `clear_on_start` (fuera del bus) que limpia `CTRL` y `STATUS` a 0 en `control_registers.sv` directamente, sin gastar un ciclo de bus. |
| 1   | `soft_reset`  | **Detectado en `top_level.sv`**, no dentro de `control_registers.sv`: cuando hay una escritura a `CTRL` (`we_cr && mmio_address[3:2]==00`) con `write_data[1]=1`, se genera un pulso de 1 ciclo (`soft_rst_q`) que resetea de forma síncrona `core_rst_n = rst_n & ~soft_rst_q`. Esto resetea `fsm.sv`, `counter.sv`, `control_registers.sv` y los registros sombra de `top_level` (timer/threshold/status/ledr/hex) — **no** resetea la RAM, el banco de registros x0-x31, el `arbiter` ni la FSM interna de vJTAG. |

### STATUS (0x40004)
```systemverilog
2'b01: selected_register = {status[31:1], status[0] | busy_in};
```
| Bit | Nombre    | Descripción |
|-----|-----------|-------------|
| 0   | `busy`    | **No se almacena**: es un OR combinacional en el mux de lectura entre el bit guardado y `busy_in = (fsm.state != S_IDLE)`. Mientras la FSM procesa, la lectura de `STATUS[0]` siempre da 1 sin importar lo que se haya escrito; en reposo, refleja el último valor escrito. |
| 1   | `done`    | Escrito por `fsm.sv` en `S_DONE_REQ` (`STATUS_DONE = 32'h2`) cuando termina sin timeout. |
| 2   | `timeout` | Escrito por `fsm.sv` en `S_DONE_REQ` (`STATUS_TIMEOUT = 32'h4`) cuando `timed_out_q=1`. |

`clear_on_start` limpia `CTRL` y `STATUS` a 0 directamente dentro de `control_registers.sv` (puerto dedicado, no transacción de bus) cada vez que la FSM detecta `CTRL.start=1` en `S_IDLE` — por lo tanto `STATUS` **no persiste** entre corridas, se limpia automáticamente al iniciar la siguiente.

### TIMER_LIMIT (0x40008) y THRESHOLD (0x4000C)
Se escriben por el bus igual que los demás registros de `control_registers.sv`, pero **también** se sombrean en `top_level.sv` (`timer_limit_q`, `threshold_q`) en el mismo ciclo de escritura (`we_cr && mux_addr[3:2]==10/11`), porque `control_registers.sv` solo expone su valor cuando está seleccionado por una lectura MMIO, y `counter.sv`/el display HEX necesitan acceso continuo a estos valores.

```systemverilog
module control_registers (
    input  logic clk,
    input  logic reset_n,
    input  logic [31:0] write_data,
    input  logic [31:0] mmio_address,
    input  logic write_en,
    input  logic busy_in,         // bit0 de STATUS (OR combinacional)
    input  logic clear_on_start,  // limpia CTRL y STATUS
    output logic [31:0] selected_register
);
```

## 6. Interfaces de módulos

### 6.1 `arbiter.sv`
```systemverilog
module arbiter (
    input  logic clk, rst_n,
    input  logic vjtag_valid, output logic vjtag_ready,
    input  logic [31:0] vjtag_addr, vjtag_data, input logic vjtag_write_en,
    input  logic fsm_valid, output logic fsm_ready,
    input  logic [31:0] fsm_addr, fsm_data, input logic fsm_write_en,
    input  logic subordinate_ready,
    output logic [31:0] mux_addr, mux_data,
    output logic mux_write_en, mux_valid
);
```
Prioridad: si ambos piden el bus en el mismo ciclo, **gana `vjtag_valid`** (desde cualquier estado: `IDLE`, `VJTAG_ACCESS`, `FSM_ACCESS`); `fsm_ready` se mantiene en 0 hasta que vJTAG libere el bus.

### 6.2 `mmio_decoder.sv`
`ready = valid` siempre (aceptación en el mismo ciclo). `sel_q` registrado para el mux de lectura (1 ciclo de latencia). Rangos: `SEL_RAM` ≤0x1FFFF, `SEL_RB` 0x20000-0x2007C, `SEL_IO` ==0x30000/0x30004, `SEL_CR` 0x40000-0x4000C, si no `SEL_NONE`.

### 6.3 `fsm.sv`
10 estados: `S_IDLE, S_TH_REQ, S_TH_CAP, S_FETCH_REQ, S_FETCH_CAP, S_STORE_REQ, S_COMPUTE, S_WRITE_REQ, S_NEXT, S_DONE_REQ`. `NUM_PIXELS=16384`. Usa `ADDR_MMRF_X1=0x00020004` como scratch del ALU.
- `S_IDLE`: lee `CTRL`; si `fsm_ready && fsm_rdata[0]`, emite `clear_on_start=1` (limpia `CTRL`/`STATUS` fuera del bus) y pasa a `S_TH_REQ`.
- Timeout: si `timer_timeout=1` y el estado no tiene una transacción de bus a medias, salta directo a `S_DONE_REQ` con `timed_out_q=1`; si lo tiene, espera a ganar el bus ese mismo ciclo antes de saltar (no deja una transacción incompleta).
- `S_DONE_REQ`: única salida de reporte — escribe `STATUS = timed_out_q ? 32'h4 : 32'h2` y `timer_clear=1`.
- Interfaces propias: ALU (`alu_a, alu_b, alu_start, alu_done, alu_n`), Timer (`timer_start, timer_clear, timer_timeout`), y señales de depuración/display (`fsm_busy`, `clear_on_start`, `pixel_count[13:0]`, `last_pixel[7:0]`, `last_result[7:0]`, `fsm_state_num[3:0]`).

### 6.4 `counter.sv` (temporizador, AC8)
```systemverilog
module counter (
    input  logic clk, reset_n, clear, increase,
    input  logic [31:0] timer_limit,
    output logic timeout
);
```
`timeout = (count >= timer_limit) && (count != 0)` (combinacional). En `top_level.sv` se instancia como `u_counter` con `increase(timer_running_q)` — un registro que se activa con `timer_start` (de `fsm.sv`, en `S_TH_CAP`) y se apaga con `timer_clear` (en `S_DONE_REQ`).

### 6.5 `top_level.sv` — integración
- **Reset físico**: `key_sync` sincroniza/libera `KEY[0]` → `rst_n`.
- **Reset por software**: `CTRL[1]=1` en una escritura → pulso `soft_rst_q` → `core_rst_n = rst_n & ~soft_rst_q` (resetea `fsm`, `counter`, `control_registers` y los registros sombra; no resetea RAM, banco x0-x31, `arbiter` ni la FSM de vJTAG).
- Cadena: `vjtag` (IP) → `vjtag_interface.sv` → sincronizador tck→clk (`addr_pulse`/`write_pulse`) → FSM vJTAG (`vj_state_t`) → `arbiter` ← `fsm.sv` → `mmio_decoder` → `ram` / `memory_mapped_register_file` / `control_registers` / `LEDR`/`HEX`.
- **Registros sombra en `top_level`** (no viven dentro de `control_registers.sv`): `timer_limit_q`, `threshold_q`, `status_q[2:1]`, `ledr_q`, `hex_q` — se actualizan en paralelo a las escrituras del bus porque `control_registers.sv` solo expone su valor cuando es leído.
- **Display de depuración** (`SW[1:0]` selecciona qué mostrar en `HEX0-5`): `00`=contador de píxeles + estado FSM, `01`=threshold, `10`=último píxel + resultado, `11`=último valor escrito por MMIO a `HEX`.
- `LEDR`: si `SW==11`, valor escrito por MMIO (`ledr_q`); si no, `{7'b0, status_q[2:1], fsm_busy_w}` (bit0=busy, bit1=done, bit2=timeout).