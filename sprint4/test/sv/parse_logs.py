import re
import sys
from pathlib import Path

# Transcripts de Questa de Sprint 4 (generados en sprint4/test/sv/)
LOG_FILES = [
    "multicycle_rv_control_fsm_transcript.log",
    "mmio_decoder_transcript.log",
    "arbiter_transcript.log",
]


OUTPUT_FILE = "questa_test_summary.log"


def parse_log(path):
    text = Path(path).read_text(errors="ignore")

    # vlog y vsim imprimen cada uno su "Errors: N, Warnings: M": se suman todos
    errors_all = re.findall(r"Errors:\s*(\d+)", text)
    warnings_all = re.findall(r"(?<!Suppressed )Warnings:\s*(\d+)", text)

    # arbiter/fsm/top_level imprimen "Pruebas completadas exitosamente";
    # counter imprime "ALL_TESTS_PASSED" (tb_counter.sv usa otro formato)
    passed = (
        ("Pruebas completadas exitosamente" in text or "ALL_TESTS_PASSED" in text)
        and "PRUEBAS FALLIDAS" not in text
        and "TESTS_FAILED" not in text
    )

    errors = sum(int(x) for x in errors_all) if errors_all else None
    warnings = sum(int(x) for x in warnings_all) if warnings_all else None

    return {
        "file": path,
        "errors": errors,
        "warnings": warnings,
        "passed": passed,
    }




def main():
    here = Path(__file__).parent
    results = []

    for name in LOG_FILES:
        log_path = here / name
        if not log_path.exists():
            print(f"ERROR: no se encontro {log_path}")
            sys.exit(1)
        results.append(parse_log(log_path))

    total_errors = 0
    total_warnings = 0
    all_passed = True

    lines = []
    lines.append("Questa Test Summary")
    lines.append("=" * 60)

    for r in results:
        if r["errors"] is None or r["warnings"] is None:
            print(f"ERROR: no se pudo parsear {r['file']}")
            sys.exit(1)

        total_errors += r["errors"]
        total_warnings += r["warnings"]
        all_passed = all_passed and r["passed"]

        lines.append(f"{r['file']}:")
        lines.append(f"  errors={r['errors']}")
        lines.append(f"  warnings={r['warnings']}")
        lines.append(f"  passed={r['passed']}")
        lines.append("")


    
    lines.append("=" * 60)
    lines.append(f"ERRORS={total_errors}")
    lines.append(f"WARNINGS={total_warnings}")
    lines.append("ALL_TESTS_PASSED" if (all_passed and total_errors == 0) else "TESTS_FAILED")

    output_path = here / OUTPUT_FILE
    output_path.write_text("\n".join(lines) + "\n")

    print(f"Resumen generado en {output_path}")
    if not (all_passed and total_errors == 0):
        sys.exit(1)


if __name__ == "__main__":
    main()
