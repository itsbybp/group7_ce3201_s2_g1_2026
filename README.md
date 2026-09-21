# CE-3201 Taller de Diseño Digital

Repositorio base para los sprints del curso CE-3201 Taller de Diseño Digital. Este repositorio centraliza el código fuente, la documentación y los flujos de integración continua (CI) organizados modularmente por sprints (`sprint0`, `sprint1`, `sprint2`, etc.).

## Estructura General del Repositorio

* `.devcontainer/`: Configuración del entorno aislado para simulación y Cocotb.
* `.github/workflows/gatekeeper.yml`: Pipeline de CI automatizado para validación y control de calidad.
* `sprint0/`: Directorio correspondiente al Sprint 0 (Características Eléctricas y Lógica Combinacional):
    * `docs/hardware_fisico/`: Documentación y reportes de mediciones físicas en protoboard.
    * `output_files/`: Artefactos y reportes de síntesis extraídos de Quartus.
    * `quartus/`: Configuración del proyecto (`.qsf`) y scripts de post-síntesis (`post_flow.tcl`).
    * `src/`: Modelos SystemVerilog (`parity_checker_structural.sv` y `parity_checker_behavioral.sv`).
    * `tests/`: Makefile unificado y banco de pruebas funcional en Cocotb (`test_parity_checker.py`).
* `sprint1/`, `sprint2/`: Directorios de los sprints siguientes, cada uno con la misma sub-estructura:
    * `docs/`: Documentación del sprint (ICD, arquitectura, diagramas de FSM, plan y resultados de pruebas).
    * `quartus/`: Proyecto de Quartus Prime (`.qpf`/`.qsf`), restricciones de temporización en `sdc/`, y reportes de síntesis generados en `output_files/` (`.flow.rpt`, `.fit.rpt`, `.map.rpt`, `.sta.rpt`).
    * `src/`: Código fuente SystemVerilog (`.sv`).
    * `test/cocotb/`: Pruebas funcionales en Python con Cocotb.
    * `test/sv/`: Testbenches en SystemVerilog puro, corridos en Questa, junto con sus scripts `.do` y el resumen `questa_test_summary.log`.
* `Dockerfile`: Imagen de contenedor para la ejecución estandarizada en la nube.
* `Makefile`: Orquestrador global de tareas para el repositorio.
* `README.md`: Documentación principal del repositorio.

## Flujo de Trabajo General

### 1. Verificación Funcional Local (Fase 1)
* Desarrolle los modelos de hardware en SystemVerilog dentro de la carpeta del sprint correspondiente aplicando la restricción de una única sentencia por línea.
* Ejecute las simulaciones funcionales locales utilizando Cocotb (con Icarus Verilog como simulador open-source) y, adicionalmente, testbenches en SystemVerilog puro corridos en Questa.

### 2. Síntesis Local
* Compile los diseños utilizando Quartus Prime Lite en el entorno local.
* Los reportes de temporización y Place & Route deben quedar en la carpeta `output_files/` del sprint respectivo.

### 3. Integración Continua (Gatekeeper)
Al abrir un *Pull Request*, el pipeline de GitHub Actions (`gatekeeper.yml`) corre únicamente sobre los sprints modificados (y los que dependan de ellos), validando tres cosas:
* **Simulación funcional open-source:** ejecuta `make -C sprintN/test/cocotb` (Cocotb + Icarus Verilog) si esa carpeta existe.
* **Artefactos locales:** exige que `sprintN/quartus/output_files/*.flow.rpt` reporte síntesis exitosa, y que `sprintN/test/sv/questa_test_summary.log` (generado localmente con Questa) muestre `ERRORS=0`, `WARNINGS=0` y `ALL_TESTS_PASSED`.
* **Estilo de código:** rechaza múltiples sentencias SystemVerilog en una misma línea dentro de `sprintN/src/`.

## Plataformas Soportadas

* **Cocotb + Icarus Verilog:** Linux, macOS, o Windows vía WSL2.
* **Quartus Prime y Questa:** Windows o Linux, con instalación local (Questa requiere licencia).
* El repositorio se ha probado en Windows 11 con WSL2 (Ubuntu) para Cocotb, y Windows nativo para Quartus/Questa.

## Integrantes

- Byron Josué Bolaños Porras 1 - 2025078620
- Esteban Andres Campos Abarca 2 - 2022207705

## Referencias

[1] Harris, S., & Harris, D. (2015). Digital Design and Computer Architecture: ARM Edition. Morgan Kaufmann.

[2] Cocotb Documentation. Available at: https://docs.cocotb.org/

[3] Altera / Intel FPGA Design Software Documentation. Available at: https://www.altera.com/

[4] GitHub Actions Documentation. Available at: https://docs.github.com/en/actions

[5] Icarus Verilog Documentation. Available at: https://steveicarus.github.io/iverilog/