# Documento de Control de Interfaz (ICD) — Sprint 2

## Propósito

Este documento define el contrato de interfaz entre los bloques del
datapath de Sprint 3: anchos de bus, codificación de señales, las interacciones
de protocolo ready valid entre módulos y el mapeo de memoria MMIO.

## Ancho de datos

Todo el datapath opera en **32 bits**: El dato de lectura y escritura del registro
de la interfaz JTAG, así como todas las direcciones de memoria mapeadas
por MMIO son de 32 bits. Los pixeles de la imagen son de 8 bits y no comparten
espacios de memoria.

## 1. Descripción General del Sistema

El sistema implementa una arquitectura de procesamiento de imágenes con:

- **Host PC:** comunica vía USB usando el protocolo vJTAG desde un servidor tcl alimentado por un programa de Python.
- **FPGA (DE10-Standard):** contiene lógica personalizada (FSM + ALU) para umbralización binaria.
- **Protocolo de comunicación:** Ready/Valid con arbitraje de prioridad fija (vJTAG > FSM).
- **Frecuencia base:** 50 MHz.

---

## 2. Especificación de Interfaces

### 2.1 Bus de Datos General

| Parámetro | Valor | Descripción |
|---|---|---|
| **Ancho de dirección** | 32 bits | Espacio de direcciones completo. |
| **Ancho de datos** | 32 bits | Una palabra de datos de 32 bits. |
| **Frecuencia de reloj** | 50 MHz | Periodo = 20 ns. |
| **Reset** | Active LOW | Reset asíncrono. |

## 3. Mapa de Memoria (MMIO)

### 3.1 Distribución General

| Rango | Almacenamiento | Direccionamiento válido | Destino | Descripción |
|---|---:|---:|---|---|
| `0x00000`–`0x0FFFF` | 64 KB | 16kB |RAM (buffer de entrada) | Almacena píxeles originales. |
| `0x10000`–`0x1FFFF` | 64 KB | 16kB |RAM (buffer de salida) | Almacena píxeles umbralizados. |
| `0x20000`–`0x2007C` | 128 B | 32 |Banco RISC-V (x0–x31) | 32 registros de 32 bits. |
| `0x30000` | 4 B | 1 |LEDR | Control de 10 LEDs de salida. |
| `0x30004` | 4 B | 1 |Displays HEX | Control de 6 displays de 7 segmentos. |
| `0x40000`–`0x4000F` | 16 B | 4 |Registros de control | `CTRL`, `STATUS`, `TIMER_LIMIT` y `THRESHOLD`. |

### 3.2 RAM (MMIO `0x00000`–`0x1FFFF`)

**Características:**

- Bloques M10K de doble puerto.
- Puerto A: vJTAG y FSM comparten el puerto mediante arbitraje.
- Puerto B: puerto independiente previsto para futuras expansiones.
- Profundidad: 32K palabras x 32 bits = 128 KB.
- Latencia de lectura y escritura: un ciclo de reloj.

---

## 4. Banco de Registros RISC-V (MMIO `0x20000`–`0x2007C`)

### 4.1 Descripción General

- 32 registros (`x0` a `x31`) de 32 bits cada uno.
- `x0` está fijo a cero.
- `x1`–`x31` **la distribución está por definirse según la implementación de la FSM**.

### 4.2 Mapeo de Direcciones

Cálculo de la dirección MMIO de cada registro.

dirección = 0x20000 + (índice_del_registro × 4)

| Registro | Código (2 bits) | Tipo | Descripción |
|---|---|---|---|
| x0 | `5'b00000` | Constante | Fijo en `32'h00000000`. Protegido contra escritura: si se selecciona como destino, ninguna escritura ocurre. |
| x1 | `5'b00001` | General | Registro de 32 bits. |
| x2 | `5'b00010` | General | Registro de 32 bits. |
| x3 | `5'b00011` | General | Registro de 32 bits. |
| ... | ... | ... | ... |
| x31 | `5'b11111` | General | Registro de 32 bits. |


---

## 5. Registros de Control (MMIO `0x40000`–`0x4000F`)

### 5.1 `CTRL` (`0x40000`) — Control

| Bit(s) | Nombre | Función |
|---|---|---|
| 0 | `start` | Pulso que inicia la FSM y reinicia el temporizador. |
| 1 | `soft_reset` | Reinicio forzado del acelerador. |
| 2–31 | - | Sin uso. |

## 6. Módulos de Hardware

### 6.1 `arbiter.sv` — Árbitro de Bus

**Función:** arbitraje de prioridad entre vJTAG (manager) y FSM (manager).

**Interfaz:**

```systemverilog
// vJTAG (manager)
input  logic        vjtag_valid,
input  logic [31:0] vjtag_addr,
input  logic [31:0] vjtag_data,
output logic        vjtag_ready,

// FSM (manager)
input  logic        fsm_valid,
input  logic [31:0] fsm_addr,
input  logic [31:0] fsm_data,
output logic        fsm_ready,

// Subordinate
input  logic        subordinate_ready,
output logic [31:0] mux_addr,
output logic [31:0] mux_data,
output logic        mux_valid
```

**Lógica de arbitraje:**

- Si `vjtag_valid=1`, vJTAG tiene prioridad y la FSM espera (`fsm_ready=0`).
- Si `vjtag_valid=0` y `fsm_valid=1`, la FSM obtiene acceso.
- Ambos managers pueden activar `valid` al mismo tiempo, pero el árbitro selecciona a vJTAG.

### 6.2 `memory_mapped_register_file.sv` — Banco RISC-V

**Función:** crea el ragister file de los 32 registros mapeado por MMIO:  `x0`–`x31`, con `x0` = cero.

**Interfaz:**

```systemverilog
input  logic [31:0] mmio_address;
input  logic        write_en;
input  logic [31:0] write_data;
output logic [31:0] selected_register;
```

**Decodificación de dirección:**

```systemverilog
logic [4:0] address; 
assign address = mmio_address[6:2];  // MMIO address ranges from 20000 to 2007C
// The last two hex digits of the two numbers are: 0000 0000 and 0111 1100.
```

El decodificador MMIO garantiza que solo se habilite el register file con sus direcciones MMIO válidas.
Esto sucede mediante la señal de valid del dato de lectura. Por tanto solo se puede escribir al register file
con sus direcciones válidas.

### 6.3 `control_registers.sv` — Registros de Control

**Función:** instancia un registro por cada una de las señales de control `CTRL`, `STATUS`, `TIMER_LIMIT` y `THRESHOLD`.

**Interfaz:**

```systemverilog
input  logic [31:0] write_data;
input  logic [31:0] mmio_address; // Bits [3:2] seleccionan el registro
input  logic        write_en;
output logic [31:0] selected_register;
```

**Decodificación de los cuatro registros:**

```systemverilog
    logic [1:0] select;
    assign select = mmio_address[3:2];  // MMIO address ranges from 40000 to 4000C

    logic [31:0] ctrl;
    logic [31:0] status;
    logic [31:0] timer_limit;
    logic [31:0] threshold;

    always_comb begin
        case (select)
            2'b00: selected_register = ctrl;
            2'b01: selected_register = status;
            2'b10: selected_register = timer_limit;
            2'b11: selected_register = threshold;
            default: selected_register = '0;
        endcase
    end
```

### 6.4 `mmio_decoder.sv` — Decodificador de Direcciones

**Función:** enruta las transacciones a los periféricos correctos.

**Señales de selección (`chip-select`):**

```systemverilog
output logic cs_ram;   // 0x00000–0x1FFFF
output logic cs_rb;    // 0x20000–0x2007C
output logic cs_ledr;  // 0x30000
output logic cs_hex;   // 0x30004
output logic cs_cr;    // 0x40000–0x4000F
```

Las direcciones fuera de los rangos asignados no deben activar ningún `chip-select`.

### 6.5 `ram.sv` — Memoria de Doble Puerto

**Función:** memoria de 128 KiB basada en bloques M10K, con puertos A y B independientes.

**Interfaz:**

```systemverilog
// Puerto A
input  logic        clk;
input  logic [14:0] addr_a;
input  logic [31:0] data_in_a;
input  logic        we_a;
input  logic        re_a;
output logic [31:0] data_out_a;

// Puerto B
input  logic [14:0] addr_b;
input  logic [31:0] data_in_b;
input  logic        we_b;
input  logic        re_b;
output logic [31:0] data_out_b;
```

---