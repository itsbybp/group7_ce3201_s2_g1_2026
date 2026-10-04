# Test Plan - Sprint 3

## Árbitro de Bus

### Herramientas
- **cocotb** — simulación funcional (`test_arbiter.py`)
- **Questa** — verificación RTL (`tb_arbiter.sv`)

### Casos de prueba

| ID | Descripción | Estímulo | Resultado esperado |
|----|-------------|----------|--------------------|
| TP-01 | Arbitraje de prioridad | `vjtag_valid=1`, `fsm_valid=1` simultáneo | `mux_addr` = addr de vJTAG, `vjtag_ready=1`, `fsm_ready=0` |
| TP-02 | Backpressure | `vjtag_valid=1`, `subordinate_ready=0` | `vjtag_ready=0`, `mux_addr` se mantiene estable |

### Criterios de aceptación
- Todos los `assert` de cocotb pasan sin errores
- Verilator no reporta warnings
- Formas de onda en Questa confirman comportamiento correcto