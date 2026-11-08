# Resultados de Verificación: Sprint 4 (Avance 1)

**Proyecto:** CE3201 Taller de Diseño Digital, Grupo 7
**Fecha:** 07 nov 2026
**Avance:** 1, tag `v0.0.1-proj`
**Arquitectura:** ver `docs/architecture.md`
**Plan de pruebas:** ver `docs/testplan.md`

---

## Resumen

| Verificación | Herramienta | Resultado | Estado |
|---|---|---|---|
| Prueba del repo con mock CPU | Cocotb | 29/29 PASS | Ejecutada |
| Verificación con el repo sobre `rv32i_cpu` | Cocotb | 28/29 PASS, 1 FAIL (`jalr`) | Ejecutada  |
| Pruebas unitarias de Sprint 3 | Questa | No ejecutadas en Sprint 4 | Pendiente |
| Síntesis en Quartus | Quartus Prime | No hay top de Sprint 4 | Pendiente |
| Captura en hardware | SignalTap | No ejecutada | Pendiente |

---

## 1. Prueba del repo con mock CPU

Siguiendo el README del repo del profesor, se ejecutó la prueba con el `mock_cpu`

```
TESTS=29 PASS=29 FAIL=0 SKIP=0
```

---

## 2. Verificación con el repo para `rv32i_cpu`

Comando:

```
make test_cpu SV_FILELIST=files.f TOPLEVEL=rv32i_cpu 2>&1 | tee avance1_cocotb.log
```

Resultado
```
****************************************************************************************
** TEST                            STATUS  SIM TIME (ns)  REAL TIME (s)  RATIO (ns/s) **
****************************************************************************************
** test_rv32i.add                   PASS         416.00           0.00      83854.65  **
** test_rv32i.sub                   PASS         416.00           0.01      78689.28  **
** test_rv32i.and                   PASS         416.00           0.00      85627.44  **
** test_rv32i.or                    PASS         416.00           0.01      81142.41  **
** test_rv32i.xor                   PASS         416.00           0.01      82742.70  **
** test_rv32i.sll                   PASS         416.00           0.01      76077.11  **
** test_rv32i.srl                   PASS         416.00           0.01      79646.00  **
** test_rv32i.sra                   PASS         416.00           0.01      70442.95  **
** test_rv32i.slt                   PASS         416.00           0.01      75993.13  **
** test_rv32i.sltu                  PASS         416.00           0.01      65315.01  **
** test_rv32i.addi                  PASS         296.00           0.00      59671.89  **
** test_rv32i.andi                  PASS         296.00           0.00      68388.80  **
** test_rv32i.ori                   PASS         296.00           0.00      65213.42  **
** test_rv32i.xori                  PASS         296.00           0.00      64733.74  **
** test_rv32i.slli                  PASS         296.00           0.00      63987.02  **
** test_rv32i.srli                  PASS         296.00           0.00      68298.43  **
** test_rv32i.srai                  PASS         296.00           0.00      59209.26  **
** test_rv32i.slti                  PASS         296.00           0.00      60468.97  **
** test_rv32i.sltiu                 PASS         296.00           0.00      67520.19  **
** test_rv32i.beq                   PASS         326.00           0.00      68097.79  **
** test_rv32i.bne                   PASS         276.00           0.01      51852.91  **
** test_rv32i.blt                   PASS         276.00           0.00      59953.03  **
** test_rv32i.bge                   PASS         326.00           0.00      72995.38  **
** test_rv32i.jal                   PASS         286.00           0.00      65191.63  **
** test_rv32i.jalr                  FAIL        3036.00           0.01     250528.33  **
** test_rv32i.lui                   PASS         176.00           0.00      47707.93  **
** test_rv32i.lw                    PASS         356.00           0.00      73222.85  **
** test_rv32i.sw                    PASS         296.00           0.00      60275.74  **
** test_rv32i.illegal               PASS          66.00           0.00      15916.33  **
****************************************************************************************
** TESTS=29 PASS=28 FAIL=1 SKIP=0              12244.03           0.17      71899.15  **
****************************************************************************************

...

=========================== short test summary info ============================
FAILED cocotb/test_dashboard.py::test_cocotb_case[jalr] - AssertionError: JAL...
========================= 1 failed, 29 passed in 0.25s =========================
make: *** [Makefile:40: test_cpu] Error 1
```

### Fallo

```
test_rv32i.jalr FAIL  (11350.02 ns)
AssertionError: Timed out after 300 cycles: JALR did not fetch expected PC 0x00000020
```


### Instrucciones

| Formato | Instrucciones | Resultado |
|---|---|---|
| R | add, sub, and, or, xor, sll, srl, sra, slt, sltu | PASS |
| I (ALU) | addi, andi, ori, xori, slli, srli, srai, slti, sltiu | PASS |
| I (carga) | lw | PASS |
| I (salto) | jalr | FAIL |
| S | sw | PASS |
| B | beq, bne, blt, bge | PASS |
| U | lui | PASS |
| J | jal | PASS |

Este resultado es visible en `dashboard_cpu.html`.

### Evidencia

Archivos en `docs/evidencia/avance1/`:

- `avance1_cocotb.log`: salida completa de la corrida.
- `coverage.json`: bins cubiertos y conteo de hits.
- `dashboard_cpu.html`: resultado por prueba y cobertura por instrucción.

---

## 3. Pruebas unitarias (Questa)

Se realizarán con de la misma forma que en el sprint 3 adaptando las pruebas pertinentes.

---

## 4. Síntesis y timing (Quartus Prime)

Pendiente. El proyecto de Quartus compila los archivos de la prueba del procesador, pero no existe un top de Sprint 4. Cuando exista, esta sección incluirá:

| Métrica | Valor |
|---|---|
| Flow Status | Pendiente |
| ALMs | Pendiente |
| Registros | Pendiente |
| Bloques de memoria | Pendiente |
| Fmax (`.sta.rpt`) | Pendiente |

---

## 5. Captura en hardware (SignalTap)

Pendiente...

---

## 6. Pendientes

| Pendiente | Referencia |
|---|---|
| Corregir `jalr` | `architecture.md` |
| Modo stepping | `architecture.md` |
| Top de Quartus de Sprint 4 | `testplan.md`, TP-14 |
| Pruebas unitarias en Sprint 4 | `testplan.md`, TP-03 a TP-09 |
| Testbench end-to-end | `testplan.md`, TP-13 |
| Captura SignalTap | `testplan.md`, TP-15 |
