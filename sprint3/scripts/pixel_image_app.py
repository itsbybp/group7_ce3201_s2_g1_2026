import argparse
import logging
import time
from pathlib import Path

import numpy as np
from PIL import Image

import jtag_fpga

# Este diseno usa un bus MMIO de 32 bits, aunque jtag_fpga.py por
# default arranca en 16. Lo forzamos aqui porque pixel_image_app.py
# importa jtag_fpga como modulo (no pasa por su bloque __main__,
# que es el unico lugar donde normalmente se fija -dw).
jtag_fpga.DATA_WIDTH = 32
jtag_fpga.MAX_VAL = (1 << 32) - 1
jtag_fpga.HEX_PADDING = 8

IMAGE_WIDTH = 128
IMAGE_HEIGHT = 128
PIXEL_COUNT = IMAGE_WIDTH * IMAGE_HEIGHT  # 16384

# Mapa MMIO real (ver architecture.md / fsm.sv)
BASE_IN         = 0x00000  # buffer de entrada, 1 pixel por palabra de 32 bits
BASE_OUT        = 0x10000  # buffer de salida
ADDR_CTRL       = 0x40000  # bit0 = start, bit1 = soft_reset
ADDR_STATUS     = 0x40004  # bit0 = busy, bit1 = done, bit2 = timeout
ADDR_TIMER_LIM  = 0x40008  # ciclos de reloj (@50MHz) antes de timeout
ADDR_THRESHOLD  = 0x4000C  # umbral de binarizacion

DEFAULT_THRESHOLD   = 128
DEFAULT_TIMER_LIMIT = 0xFFFFFFFF  # practicamente sin timeout salvo que se pida uno
TRANSFER_TIMEOUT = 60.0  # segundos de espera del lado del host (no confundir con TIMER_LIMIT del hw)
POLL_INTERVAL = 0.05


def load_grayscale_image(image_path):
    with Image.open(image_path) as source:
        return source.convert("L").resize(
            (IMAGE_WIDTH, IMAGE_HEIGHT), Image.Resampling.LANCZOS
        )


def send_image(connection, pixels, threshold, timer_limit):
    if len(pixels) != PIXEL_COUNT:
        raise ValueError(f"Expected {PIXEL_COUNT} grayscale pixels.")

    upload_started = time.perf_counter()
    for index, value in enumerate(pixels):
        jtag_fpga.write_value_to_fpga(
            connection, BASE_IN + index * 4, int(value), strict=True
        )
        if (index + 1) % 512 == 0:
            elapsed = time.perf_counter() - upload_started
            print(
                f"\rUploaded {index + 1}/{PIXEL_COUNT} pixeles en {elapsed:.1f}s",
                end="",
                flush=True,
            )
    print()
    print(f"Carga de imagen tomo {time.perf_counter() - upload_started:.1f}s total.")

    # soft_reset antes de arrancar, para limpiar STATUS/timer de una corrida previa
    jtag_fpga.write_value_to_fpga(connection, ADDR_CTRL, 0x2, strict=True)
    jtag_fpga.write_value_to_fpga(connection, ADDR_TIMER_LIM, timer_limit, strict=True)
    jtag_fpga.write_value_to_fpga(connection, ADDR_THRESHOLD, threshold, strict=True)
    jtag_fpga.write_value_to_fpga(connection, ADDR_CTRL, 0x1, strict=True)  # start


def read_image(connection, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        status = jtag_fpga.read_value_from_fpga(connection, ADDR_STATUS, strict=True)
        if status & 0x4:
            raise RuntimeError("La FPGA reporto timeout (STATUS bit2) antes de terminar.")
        if status & 0x2:
            break
        time.sleep(POLL_INTERVAL)
    else:
        raise TimeoutError("Se agoto el tiempo de espera del host para el procesamiento.")

    pixels = []
    for index in range(PIXEL_COUNT):
        value = jtag_fpga.read_value_from_fpga(
            connection, BASE_OUT + index * 4, strict=True
        )
        pixels.append(value & 0xFF)
        if (index + 1) % 512 == 0:
            print(f"\rLeidos {index + 1}/{PIXEL_COUNT} pixeles", end="", flush=True)
    print()
    return pixels


def save_images(source_image, output_pixels, input_path):
    output_image = Image.new("L", (IMAGE_WIDTH, IMAGE_HEIGHT))
    output_image.putdata(output_pixels)
    input_output_path = input_path.with_name(
        f"{input_path.stem}_input_{IMAGE_WIDTH}x{IMAGE_HEIGHT}.png"
    )
    processed_output_path = input_path.with_name(
        f"{input_path.stem}_output_{IMAGE_WIDTH}x{IMAGE_HEIGHT}.png"
    )
    source_image.save(input_output_path)
    output_image.save(processed_output_path)
    return input_output_path, processed_output_path


def display_images(source_image, output_pixels):
    import matplotlib.pyplot as plt

    output_image = Image.new("L", (IMAGE_WIDTH, IMAGE_HEIGHT))
    output_image.putdata(output_pixels)

    figure, axes = plt.subplots(1, 2, figsize=(12, 6))
    for axis, image, title in (
        (axes[0], source_image, "Imagen enviada a la FPGA"),
        (axes[1], output_image, "Imagen binarizada leida de la FPGA"),
    ):
        axis.imshow(np.asarray(image), cmap="gray", vmin=0, vmax=255, interpolation="nearest")
        axis.set_title(title)
        axis.set_xticks([])
        axis.set_yticks([])

    figure.tight_layout()
    plt.show()


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=(
            "Envia una imagen 128x128 en escala de grises a la FPGA, la binariza "
            "con un umbral configurable, lee el resultado y lo muestra/guarda."
        )
    )
    parser.add_argument("image", type=Path, help="archivo de imagen de entrada")
    parser.add_argument("--host", default=jtag_fpga.HOST, help="host del servidor JTAG")
    parser.add_argument("--port", type=int, default=jtag_fpga.PORT, help="puerto TCP del servidor JTAG")
    parser.add_argument("--threshold", type=int, default=DEFAULT_THRESHOLD,
                         help=f"umbral de binarizacion 0-255 (default: {DEFAULT_THRESHOLD})")
    parser.add_argument("--timer-limit", type=lambda v: int(v, 0), default=DEFAULT_TIMER_LIMIT,
                         help="ciclos @50MHz antes de timeout del hardware (default: sin limite practico)")
    parser.add_argument("--timeout", type=float, default=TRANSFER_TIMEOUT,
                         help=f"segundos que espera el host (default: {TRANSFER_TIMEOUT})")
    parser.add_argument("-c", "--no-display", action="store_true",
                         help="verificar sin abrir ventana de imagenes")
    parser.add_argument("--save-images", action="store_true",
                         help="guardar la entrada y salida como PNG junto a la imagen original")
    args = parser.parse_args(argv)

    if jtag_fpga.DATA_WIDTH != 32:
        parser.error("Este diseno usa un bus MMIO de 32 bits; correr jtag_fpga con -dw 32.")
    if not 0 <= args.threshold <= 255:
        parser.error("--threshold debe estar entre 0 y 255.")
    if not 0 <= args.timer_limit <= 0xFFFFFFFF:
        parser.error("--timer-limit debe caber en 32 bits (0-4294967295).")
    if not 1 <= args.port <= 65535:
        parser.error("port debe estar entre 1 y 65535.")
    if args.timeout <= 0:
        parser.error("timeout debe ser mayor que cero.")

    try:
        image = load_grayscale_image(args.image)
    except (OSError, ValueError) as exc:
        parser.error(f"no se pudo cargar la imagen {args.image}: {exc}")

    connection = jtag_fpga.open_connection(args.host, args.port)
    if connection is None:
        logging.error("No se pudo conectar al servidor JTAG en %s:%s.", args.host, args.port)
        return 1

    try:
        pixels = np.asarray(image).reshape(-1).tolist()
        print(f"Enviando {args.image} como imagen {IMAGE_WIDTH}x{IMAGE_HEIGHT} (umbral={args.threshold})...")
        send_image(connection, pixels, args.threshold, args.timer_limit)
        print("Imagen cargada y procesamiento iniciado. Esperando a que la FPGA termine...")
        output_pixels = read_image(connection, args.timeout)

        expected_pixels = [255 if value >= args.threshold else 0 for value in pixels]
        if output_pixels != expected_pixels:
            mismatches = sum(1 for a, b in zip(output_pixels, expected_pixels) if a != b)
            raise RuntimeError(f"La salida de la FPGA no coincide con lo esperado ({mismatches} pixeles distintos).")
        print("La lectura coincide con la binarizacion esperada.")

        if args.save_images:
            input_path, output_path = save_images(image, output_pixels, args.image)
            print(f"Imagen de entrada guardada: {input_path}")
            print(f"Imagen de salida guardada: {output_path}")

        if args.no_display:
            print("Visualizacion omitida.")
        else:
            display_images(image, output_pixels)
    except (ConnectionError, OSError, RuntimeError, TimeoutError, ValueError) as exc:
        logging.error("Fallo la transferencia de imagen: %s", exc)
        return 1
    finally:
        connection.close()
    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="|%(levelname)s| %(message)s")
    raise SystemExit(main())