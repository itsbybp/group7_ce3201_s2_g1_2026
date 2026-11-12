# Resultados de Verificación: Sprint 4 (Avance 2)

**Proyecto:** CE3201 Taller de Diseño Digital, Grupo 7
**Fecha:** 11 nov 2026
**Avance:** 2, tag `v0.0.2-proj`
**Arquitectura:** ver `docs/architecture.md`
**Plan de pruebas:** ver `docs/testplan.md`

---

## Resumen

| Verificación | Herramienta | Resultado | Estado |
|---|---|---|---|
| Prueba del repo con mock CPU | Cocotb | 29/29 PASS | Ejecutada |
| Verificación con el repo sobre `rv32i_cpu` | Cocotb | 29/29 PASS | Ejecutada |
| Enabler (`enable = 0`) | Cocotb | Sin `valid` activo | Ejecutada |
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
make test_cpu SV_FILELIST=files.f TOPLEVEL=rv32i_cpu 2>&1 | tee ../../docs/evidencia/avance2/avance2_cocotb.log
```

Resultado:

```
** TESTS=29 PASS=29 FAIL=0 SKIP=0               9934.03           0.06     165696.66  **
```

Cobertura de instrucciones: 29/29 bins (100 %).

| Formato | Instrucciones | Resultado |
|---|---|---|
| R | add, sub, and, or, xor, sll, srl, sra, slt, sltu | PASS |
| I (ALU) | addi, andi, ori, xori, slli, srli, srai, slti, sltiu | PASS |
| I (carga) | lw | PASS |
| I (salto) | jalr | PASS (corregido respecto al Avance 1) |
| S | sw | PASS |
| B | beq, bne, blt, bge | PASS |
| U | lui | PASS |
| J | jal | PASS |
| Ilegal | illegal | PASS |

### Enabler

Con `enable = 0` en el wrapper, el procesador no genera `valid` (0 mensajes de `valid activo` frente a 300 antes de la corrección) y la prueba termina por timeout, como se espera de una CPU apagada.

### Evidencia

Archivos en `docs/evidencia/avance2/`:

- `avance2_cocotb.log`: salida completa de la corrida.
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
| Modo stepping | `architecture.md` |
| Top de Quartus de Sprint 4 | `testplan.md`, TP-14 |
| Pruebas unitarias en Sprint 4 | `testplan.md`, TP-03 a TP-09 |
| Testbench end-to-end | `testplan.md`, TP-13 |
| Captura SignalTap | `testplan.md`, TP-15 |