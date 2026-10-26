# Plan de pruebas (Sprint 3)

## Arbiter

| ID    | Descripción                                            | Resultado esperado |
|-------|-----------------------------------------------------------|---------------------|
| TP-01 | Priority arbitration: `fsm_valid` y `vjtag_valid` simultáneos | Bus concedido a vJTAG; `fsm_ready=0` |
| TP-02 | Backpressure: `subordinate_ready=0` sostenido              | `fsm_ready`/`vjtag_ready` permanecen en 0 hasta que el bus se libera |

## mmio_decoder / RAM / banco de registros / control_registers

| ID    | Descripción                                                     | Resultado esperado |
|-------|-------------------------------------------------------------------|---------------------|
| TP-03 | Escritura/lectura en cada rango (`RAM_IN`, `RAM_OUT`, banco x1-x31, `LEDR`, `HEX`, `CTRL`, `TIMER_LIMIT`, `THRESHOLD`) | Dato escrito == dato leído |
| TP-04 | RAZ/WI en direcciones fuera de rango (ej. `0x50000`)              | Lectura retorna 0; escritura no tiene efecto, no se cuelga el bus |
| TP-05 | Escritura a `x0`                                                  | `x0` permanece en 0 (write-ignored) |
| TP-06 | Lectura de `STATUS` mientras la FSM procesa (`state != S_IDLE`)   | Bit 0 (`busy`) siempre en 1, sin importar lo escrito (OR combinacional con `busy_in`); bits 1-2 reflejan lo último escrito por `fsm.sv` |
| TP-06b| Lectura de `STATUS` con la FSM en `S_IDLE`                        | Bit 0 refleja el valor almacenado (0, salvo escritura manual previa) |

## counter.sv (temporizador)

| ID    | Descripción                                        | Resultado esperado |
|-------|------------------------------------------------------|---------------------|
| TP-07 | `timer_limit=0`                                     | `timeout=1` inmediato en el primer `increase` |
| TP-08 | Conteo normal hasta `count==timer_limit`            | `timeout=1` exactamente en ese ciclo |
| TP-09 | `clear` durante conteo                               | `count` vuelve a 0, `timeout` se limpia |

## fsm.sv

| ID    | Descripción                                                              | Resultado esperado |
|-------|------------------------------------------------------------------------------|---------------------|
| TP-10 | Procesamiento completo de imagen (`NUM_PIXELS` píxeles) sin timeout         | `STATUS=0x2` (DONE) al final en `S_DONE_REQ`, todos los píxeles binarizados correctamente contra `THRESHOLD` |
| TP-11 | `CTRL.start=1` detectado en `S_IDLE`                                        | Emite `clear_on_start=1` (limpia `CTRL`/`STATUS` fuera del bus, sin transacción extra) y pasa directo a `S_TH_REQ` |
| TP-12 | Timeout inyectado mientras la FSM espera en un estado de trabajo sin transacción de bus a medias | Salta inmediatamente a `S_DONE_REQ` con `timed_out_q=1`, escribe `STATUS=0x4` y vuelve a `S_IDLE` |
| TP-12b| Timeout inyectado con una transacción de bus a medias (`*_REQ`/`*_CAP`)    | Espera a ganar el bus ese mismo ciclo antes de saltar a `S_DONE_REQ` (no deja `fsm_addr`/`fsm_data` a medias) |
| TP-13 | `THRESHOLD=0` y `THRESHOLD=255` (casos límite)                             | Binarización correcta en ambos extremos |
| TP-18 | `STATUS` leído después de un segundo `CTRL.start`                         | Se limpia a 0 automáticamente por `clear_on_start` antes de iniciar — **no** persiste de la corrida anterior |

## soft_reset (CTRL[1], AC8)

| ID    | Descripción                                                     | Resultado esperado |
|-------|---------------------------------------------------------------------|---------------------|
| TP-19 | Escritura a `CTRL` con bit 1 en 1 mientras la FSM procesa a medio camino | Pulso `soft_rst_q` de 1 ciclo; `fsm.sv`, `counter.sv`, `control_registers.sv` y los registros sombra de `top_level` vuelven a su estado inicial |
| TP-20 | Mismo caso, verificar RAM y banco de registros x0-x31              | **No** se alteran — el soft reset no llega a `ram.sv` ni a `memory_mapped_register_file.sv` |

## vjtag_interface.sv / top_level.sv (integración)

| ID    | Descripción                                                         | Resultado esperado |
|-------|-------------------------------------------------------------------------|---------------------|
| TP-14 | Secuencia `SET_ADDR` → `WRITE` vía `vjtag_sim_stub`                    | `jtag_write_toggle` pulsa una vez por `udr`; dato llega correcto al bus |
| TP-15 | Secuencia `SET_ADDR` → `READ`                                          | `jtag_addr_toggle` dispara la FSM vJTAG interna (`VJ_READ_REQ`→`VJ_READ_CAP`), dato correcto disponible en `DR2` |
| TP-16 | Arbitraje real en `top_level`: vJTAG y FSM compiten por el bus          | Igual comportamiento que TP-01/TP-02, verificado end-to-end |
| TP-17 | Imagen completa vía hardware real (JTAG físico) con distintos `THRESHOLD`/`TIMER_LIMIT` | Resultado en `RAM_OUT` coincide con cálculo esperado; `LEDR`/`HEX` reflejan `STATUS`/contador según `SW` |