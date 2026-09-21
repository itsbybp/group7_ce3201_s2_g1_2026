# Plan de Pruebas — Sprint 2

## Metodología

Siguiendo el paradigma TDHD (Desarrollo de Hardware Guiado por Pruebas),
el diseño RTL, la documentación y las pruebas se desarrollan de forma
concurrente, no en cascada. Cada bloque combinacional o secuencial se
valida con dos herramientas independientes antes de integrarse al
datapath completo:

- **Cocotb + Icarus Verilog**: pruebas funcionales unitarias, escritas en
  Python, corridas automáticamente por el Gatekeeper en cada Pull
  Request (`sprint2/test/cocotb/`).
- **Questa (SystemVerilog puro)**: testbenches independientes, corridos
  localmente, que generan waveforms (`.wlf`) documentados y un resumen
  (`questa_test_summary.log`) verificado por el Gatekeeper
  (`sprint2/test/sv/`).

Ambas suites prueban el mismo comportamiento desde implementaciones de
testbench distintas, reduciendo el riesgo de que un error en la lógica
de prueba (no en el diseño) pase inadvertido.

## Cobertura por bloque

### register_bank.sv

| Caso de prueba | Verifica |
|---|---|
| Reset | Todos los registros (x1-x3) inician en 0 tras `reset_n=0`. |
| x0 protegido | Ninguna escritura con `rd=2'b00` modifica x0; siempre lee 0. |
| Escritura y lectura | Un valor escrito en un registro se lee correctamente por `rs1`/`rs2`. |
| write_en desactivado | Sin `write_en=1`, ninguna escritura ocurre aunque `rd`/`write_data` cambien. |
| Write-enable individual | Escribir en x2 no afecta x3, y viceversa. |
| Limpieza en reset | Un valor previamente escrito se borra al activar `reset_n=0`. |

Implementado en: `test_register_bank.py` (Cocotb, 6 casos) y
`tb_register_bank.sv` (Questa, mismos 6 casos).

### key_sync.sv

| Caso de prueba | Verifica |
|---|---|
| Reset activo | `reset_n=0` mientras `KEY[0]` está presionado. |
| Liberación de reset | `reset_n` sube a 1 solo tras `KEY[0]` soltarse y 2 flancos de reloj. |
| Pulso de 1 ciclo | `key_pulse` se activa exactamente 1 ciclo al detectar flanco de subida. |
| No repetición | `key_pulse` no vuelve a activarse mientras el botón se mantiene presionado. |
| Segundo toque | `key_pulse` se activa de nuevo en un segundo flanco de subida independiente. |

Implementado en: `test_key_sync.py` (Cocotb, 5 casos) y `tb_key_sync.sv`
(Questa, mismos 5 casos).

## Pendiente (Epic 2)

Las pruebas de `input_fsm.sv` y `exec_fsm.sv` se documentarán en esta
sección una vez implementadas ambas FSMs. Se espera cubrir, como mínimo:

- Ensamblaje correcto de un dato de 16 bits en 4 cargas de nibble.
- Transiciones de estado válidas en ambas FSMs bajo `reset_n`.
- Ejecución correcta en modo continuo y en modo paso a paso.
- Ausencia de latches inferidos en la lógica combinacional de ambas FSMs.

## Herramientas y reproducibilidad

Ver instrucciones de ejecución local en el `README.md` de la raíz del
repositorio (sección "Plataformas Soportadas").