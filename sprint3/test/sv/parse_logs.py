import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

LOG_FILES = [
    "arbiter_transcript.log",
    "fsm_transcript.log",
    "counter_transcript.log",
    "top_level_transcript.log",
    "ram_transcript.log",
    "mmio_decoder_transcript.log",
    "control_registers_transcript.log",
    "memory_mapped_register_file_transcript.log",
]

# Resultados de cocotb (make top_level, corrido en ../cocotb)
XML_FILES = [
    "../cocotb/results_top_level.xml",
]

OUTPUT_FILE = "questa_test_summary.log"


def parse_log(path):
    text = Path(path).read_text(errors="ignore")

    # vlog y vsim imprimen cada uno su "Errors: N, Warnings: M": se suman todos
    errors_all = re.findall(r"Errors:\s*(\d+)", text)
    warnings_all = re.findall(r"Warnings:\s*(\d+)", text)

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


def parse_xml(path):
    root = ET.parse(path).getroot()
    cases = list(root.iter("testcase"))
    failed = [c.get("name") for c in cases if c.find("failure") is not None or c.find("error") is not None]
    return {
        "file": path,
        "tests": len(cases),
        "failed": failed,
        "passed": len(cases) > 0 and not failed,
    }


def main():
    here = Path(__file__).parent
    results = []
    xml_results = []

    for name in LOG_FILES:
        log_path = here / name
        if not log_path.exists():
            print(f"ERROR: no se encontro {log_path}")
            sys.exit(1)
        results.append(parse_log(log_path))

    for name in XML_FILES:
        xml_path = here / name
        if not xml_path.exists():
            print(f"ERROR: no se encontro {xml_path}")
            sys.exit(1)
        xml_results.append(parse_xml(xml_path))

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

    lines.append("cocotb Test Summary")
    lines.append("=" * 60)

    for x in xml_results:
        all_passed = all_passed and x["passed"]
        lines.append(f"{x['file']}:")
        lines.append(f"  tests={x['tests']}")
        lines.append(f"  failed={len(x['failed'])}")
        for n in x["failed"]:
            lines.append(f"    FAIL {n}")
        lines.append(f"  passed={x['passed']}")
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