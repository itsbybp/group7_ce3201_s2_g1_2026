"""Consola Python (AC 9) del Sprint 4: carga firmware.hex + imagen a la FPGA via
vJTAG (jtag_server.tcl), inicia el CPU RV32I, espera STATUS.done y descarga el
histograma y la imagen binarizada para verificarlos y mostrarlos."""
import argparse
import logging
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

# jtag_fpga.py no cambio respecto al Sprint 3: se reutiliza desde sprint3/scripts/.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "sprint3" / "scripts"))
import jtag_fpga  # noqa: E402

# Bus MMIO de 32 bits (jtag_fpga.py arranca en 16 por defecto).
jtag_fpga.DATA_WIDTH = 32
jtag_fpga.MAX_VAL = (1 << 32) - 1
jtag_fpga.HEX_PADDING = 8

IMAGE_WIDTH = 128
IMAGE_HEIGHT = 128
PIXEL_COUNT = IMAGE_WIDTH * IMAGE_HEIGHT  # 16384
HIST_BINS = 256

# Mapa de memoria del Sprint 4 (Tabla 2 del enunciado)
BASE_PROG = 0x00000       # RAM de instrucciones (2048 palabras)
PROG_WORDS = 2048
BASE_IN = 0x10000         # imagen de entrada, 1 pixel por palabra
BASE_OUT = 0x20000        # imagen binarizada (solo lectura para el host)
BASE_HIST = 0x30000       # histograma, 256 contadores (solo lectura para el host)
ADDR_CTRL = 0x50000       # bit0 = start
ADDR_STATUS = 0x50004     # bit0 = busy, bit1 = done
ADDR_THRESHOLD = 0x5000C  # umbral de binarizacion

DEFAULT_THRESHOLD = 128
DEFAULT_FIRMWARE = Path(__file__).resolve().parent.parent / "firmware" / "firmware.hex"
TRANSFER_TIMEOUT = 60.0
POLL_INTERVAL = 0.05


def load_firmware(path):
    words = []
    for number, line in enumerate(Path(path).read_text().splitlines(), 1):
        text = line.strip()
        if not text:
            continue
        try:
            words.append(int(text, 16))
        except ValueError:
            raise ValueError(f"{path}:{number}: '{text}' no es una palabra hexadecimal")
    if not words:
        raise ValueError(f"{path} esta vacio")
    if len(words) > PROG_WORDS:
        raise ValueError(f"firmware de {len(words)} palabras; la RAM de instrucciones tiene {PROG_WORDS}")
    return words


def load_grayscale_image(image_path):
    with Image.open(image_path) as source:
        return source.convert("L").resize((IMAGE_WIDTH, IMAGE_HEIGHT), Image.Resampling.LANCZOS)


def write_block(connection, base, values, label):
    started = time.perf_counter()
    for index, value in enumerate(values):
        jtag_fpga.write_value_to_fpga(connection, base + index * 4, int(value), strict=True)
        if (index + 1) % 512 == 0:
            print(f"\r{label}: {index + 1}/{len(values)}", end="", flush=True)
    print(f"\r{label}: {len(values)}/{len(values)} en {time.perf_counter() - started:.1f}s")


def read_block(connection, base, count, label):
    values = []
    started = time.perf_counter()
    for index in range(count):
        values.append(jtag_fpga.read_value_from_fpga(connection, base + index * 4, strict=True))
        if (index + 1) % 512 == 0:
            print(f"\r{label}: {index + 1}/{count}", end="", flush=True)
    print(f"\r{label}: {count}/{count} en {time.perf_counter() - started:.1f}s")
    return values


def load_program(connection, words):
    write_block(connection, BASE_PROG, words, "Programa")
    back = read_block(connection, BASE_PROG, len(words), "Verificando programa")
    if back != words:
        bad = sum(1 for a, b in zip(back, words) if a != b)
        raise RuntimeError(f"El programa leido no coincide con firmware.hex ({bad} palabras distintas).")


def start_cpu(connection, pixels, threshold):
    write_block(connection, BASE_IN, pixels, "Imagen")
    jtag_fpga.write_value_to_fpga(connection, ADDR_THRESHOLD, threshold, strict=True)
    jtag_fpga.write_value_to_fpga(connection, ADDR_CTRL, 0x1, strict=True)  # pulso start


def wait_done(connection, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        status = jtag_fpga.read_value_from_fpga(connection, ADDR_STATUS, strict=True)
        if status & 0x2:
            return
        time.sleep(POLL_INTERVAL)
    raise TimeoutError("Se agoto el tiempo de espera: STATUS.done nunca se activo.")


def save_images(source_image, output_pixels, input_path):
    output_image = Image.new("L", (IMAGE_WIDTH, IMAGE_HEIGHT))
    output_image.putdata(output_pixels)
    in_path = input_path.with_name(f"{input_path.stem}_input_{IMAGE_WIDTH}x{IMAGE_HEIGHT}.png")
    out_path = input_path.with_name(f"{input_path.stem}_output_{IMAGE_WIDTH}x{IMAGE_HEIGHT}.png")
    source_image.save(in_path)
    output_image.save(out_path)
    return in_path, out_path


def display_results(source_image, histogram, output_pixels, threshold):
    import matplotlib.pyplot as plt

    output = np.array(output_pixels, dtype=np.uint8).reshape(IMAGE_HEIGHT, IMAGE_WIDTH)
    figure, axes = plt.subplots(1, 3, figsize=(15, 5))
    axes[0].imshow(np.asarray(source_image), cmap="gray", vmin=0, vmax=255, interpolation="nearest")
    axes[0].set_title("Imagen enviada a la FPGA")
    axes[1].bar(range(HIST_BINS), histogram, width=1.0)
    axes[1].axvline(threshold, color="red", linestyle="--", label=f"umbral = {threshold}")
    axes[1].set_title("Histograma leido de la FPGA")
    axes[1].set_xlabel("Intensidad")
    axes[1].set_ylabel("Pixeles")
    axes[1].legend()
    axes[2].imshow(output, cmap="gray", vmin=0, vmax=255, interpolation="nearest")
    axes[2].set_title("Imagen binarizada leida de la FPGA")
    for axis in (axes[0], axes[2]):
        axis.set_xticks([])
        axis.set_yticks([])
    figure.tight_layout()
    plt.show()


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Carga firmware.hex y una imagen 128x128 a la FPGA, ejecuta el CPU RV32I "
                    "y recoge el histograma y la imagen binarizada.")
    parser.add_argument("image", type=Path, help="archivo de imagen de entrada")
    parser.add_argument("--firmware", type=Path, default=DEFAULT_FIRMWARE, help="firmware.hex a cargar")
    parser.add_argument("--host", default=jtag_fpga.HOST)
    parser.add_argument("--port", type=int, default=jtag_fpga.PORT)
    parser.add_argument("--threshold", type=int, default=DEFAULT_THRESHOLD,
                        help=f"umbral 0-255 (default: {DEFAULT_THRESHOLD})")
    parser.add_argument("--timeout", type=float, default=TRANSFER_TIMEOUT,
                        help=f"segundos que espera el host por done (default: {TRANSFER_TIMEOUT})")
    parser.add_argument("-c", "--no-display", action="store_true", help="verificar sin abrir ventanas")
    parser.add_argument("--save-images", action="store_true", help="guardar entrada y salida como PNG")
    args = parser.parse_args(argv)

    if not 0 <= args.threshold <= 255:
        parser.error("--threshold debe estar entre 0 y 255.")
    if not 1 <= args.port <= 65535:
        parser.error("port debe estar entre 1 y 65535.")
    if args.timeout <= 0:
        parser.error("timeout debe ser mayor que cero.")
    try:
        firmware = load_firmware(args.firmware)
        image = load_grayscale_image(args.image)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))

    connection = jtag_fpga.open_connection(args.host, args.port)
    if connection is None:
        logging.error("No se pudo conectar al servidor JTAG en %s:%s.", args.host, args.port)
        return 1

    try:
        pixels = np.asarray(image).reshape(-1).tolist()
        print(f"Firmware: {args.firmware} ({len(firmware)} instrucciones)")
        load_program(connection, firmware)
        start_cpu(connection, pixels, args.threshold)
        print(f"CPU iniciado (umbral={args.threshold}). Esperando STATUS.done...")
        wait_done(connection, args.timeout)

        output_pixels = [v & 0xFF for v in read_block(connection, BASE_OUT, PIXEL_COUNT, "Imagen de salida")]
        histogram = read_block(connection, BASE_HIST, HIST_BINS, "Histograma")

        expected_out = [255 if v >= args.threshold else 0 for v in pixels]
        expected_hist = np.bincount(pixels, minlength=HIST_BINS).tolist()
        if output_pixels != expected_out:
            bad = sum(1 for a, b in zip(output_pixels, expected_out) if a != b)
            raise RuntimeError(f"La imagen binarizada no coincide ({bad} pixeles distintos).")
        if histogram != expected_hist:
            bad = sum(1 for a, b in zip(histogram, expected_hist) if a != b)
            raise RuntimeError(f"El histograma no coincide ({bad} contadores distintos).")
        print("OK: histograma e imagen binarizada coinciden con lo esperado.")

        if args.save_images:
            in_path, out_path = save_images(image, output_pixels, args.image)
            print(f"Guardadas: {in_path} y {out_path}")
        if args.no_display:
            print("Visualizacion omitida.")
        else:
            display_results(image, histogram, output_pixels, args.threshold)
    except (ConnectionError, OSError, RuntimeError, TimeoutError, ValueError) as exc:
        logging.error("Fallo la ejecucion: %s", exc)
        return 1
    finally:
        connection.close()
    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="|%(levelname)s| %(message)s")
    raise SystemExit(main())