# CE-3201 Taller de Diseño Digital

Repositorio base para los sprints del curso CE-3201 Taller de Diseño Digital. Este repositorio centraliza el código fuente, la documentación y los flujos de integración continua (CI) organizados modularmente por sprints (`sprint0`, `sprint1`, etc.).

## Estructura General del Repositorio

* `.devcontainer/`: Configuración del entorno aislado para Verilator y Cocotb.
* `.github/workflows/gatekeeper.yml`: Pipeline de CI automatizado para validación y control de calidad.
* `sprint0/`: Directorio correspondiente al Sprint 0 (Características Eléctricas y Lógica Combinacional):
    * `docs/hardware_fisico/`: Documentación y reportes de mediciones físicas en protoboard.
    * `output_files/`: Artefactos y reportes de síntesis extraídos de Quartus.
    * `quartus/`: Configuración del proyecto (`.qsf`) y scripts de post-síntesis (`post_flow.tcl`).
    * `src/`: Modelos SystemVerilog (`parity_checker_structural.sv` y `parity_checker_behavioral.sv`).
    * `tests/`: Makefile unificado y banco de pruebas funcional en Cocotb (`test_parity_checker.py`).
* `sprint1/`, `sprint2/`, ...: Directorios reservados para los siguientes sprints del curso.
* `Dockerfile`: Imagen de contenedor para la ejecución estandarizada en la nube.
* `Makefile`: Orquestrador global de tareas para el repositorio.
* `README.md`: Documentación principal del repositorio.

## Flujo de Trabajo General

### 1. Verificación Funcional Local (Fase 1)
* Desarrolle los modelos de hardware en SystemVerilog dentro de la carpeta del sprint correspondiente aplicando la restricción de una única sentencia por línea.
* Ejecute las simulaciones funcionales locales utilizando Cocotb mediante Questa o Verilator.

### 2. Síntesis Local
* Compile los diseños utilizando Quartus Prime Lite en el entorno local.
* El script `post_flow.tcl` extrae automáticamente los reportes de temporización y Place & Route hacia la carpeta `output_files/` del sprint respectivo.

### 3. Integración Continua (Gatekeeper)
* Al abrir un *Pull Request* hacia la rama principal, el pipeline de GitHub Actions actúa como *Gatekeeper* verificando la ausencia de *latches* no intencionales, comprobando la ausencia de violaciones de temporización mediante el margen de retraso (*Slack*) y ejecutando la regresión funcional en la nube con Verilator.

## Referencias

[1] Harris, S., & Harris, D. (2015). Digital Design and Computer Architecture: ARM Edition. Morgan Kaufmann.

[2] Cocotb Documentation. Available at: https://docs.cocotb.org/

[3] Altera / Intel FPGA Design Software Documentation. Available at: https://www.altera.com/

[4] GitHub Actions Documentation. Available at: https://docs.github.com/en/actions

[5] Verilator Documentation. https://verilator.org/
