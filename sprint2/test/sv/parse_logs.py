import re
import sys
from pathlib import Path

LOG_FILES = [
    "register_bank_transcript.log",
    "key_sync_transcript.log",
    "input_fsm_transcript.log",
    "exec_fsm_transcript.log",
    "top_level_transcript.log"
]

OUTPUT_FILE = "questa_test_summary.log"


def parse_log(path):
    text = Path(path).read_text(errors="ignore")

    errors_match = re.search(r"ERRORS=(\d+)", text)
    warnings_match = re.search(r"WARNINGS=(\d+)", text)
    passed = "ALL_TESTS_PASSED" in text

    errors = int(errors_match.group(1)) if errors_match else None
    warnings = int(warnings_match.group(1)) if warnings_match else None

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
    print(f"ERRORS={total_errors} WARNINGS={total_warnings} ALL_PASSED={all_passed}")

    if not (all_passed and total_errors == 0):
        sys.exit(1)


if __name__ == "__main__":
    main()
