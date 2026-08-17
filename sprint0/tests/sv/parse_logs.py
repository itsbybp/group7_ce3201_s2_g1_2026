import re
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 2:
        print("Uso: python3 parse_logs.py <transcript.log>")
        sys.exit(1)

    log_path = Path(sys.argv[1])
    summary_path = Path("questa_test_summary.log")

    if not log_path.exists():
        print(f"ERROR: No existe el archivo {log_path}")
        sys.exit(1)

    content = log_path.read_text(encoding="utf-8", errors="ignore")

    matches = re.findall(
        r"Errors:\s*(\d+),\s*Warnings:\s*(\d+)",
        content,
    )

    if not matches:
        print("ERROR: No se encontraron resultados de Questa en el log.")
        sys.exit(1)

    errors = max(int(error) for error, _ in matches)
    warnings = max(int(warning) for _, warning in matches)

    if errors == 0:
        result = "ALL_TESTS_PASSED"
    else:
        result = "TESTS_FAILED"

    summary = (
        f"ERRORS={errors}\n"
        f"WARNINGS={warnings}\n"
        f"{result}\n"
    )

    summary_path.write_text(summary, encoding="utf-8")

    print(summary, end="")


if __name__ == "__main__":
    main()