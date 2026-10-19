import argparse
import logging
import time
from pathlib import Path

import numpy as np
from PIL import Image

import jtag_fpga

IMAGE_WIDTH = 64
IMAGE_HEIGHT = 64
PIXEL_COUNT = IMAGE_WIDTH * IMAGE_HEIGHT
PIXEL_SOURCE_ADDR_REG = 0x0C
PIXEL_SOURCE_DATA_REG = 0x10
PIXEL_COUNT_REG = 0x14
PIXEL_START_REG = 0x18
PIXEL_STATUS_REG = 0x1C
PIXEL_OUTPUT_ADDR_REG = 0x20
PIXEL_OUTPUT_DATA_REG = 0x24
TRANSFER_TIMEOUT = 30.0
POLL_INTERVAL = 0.05


def pack_pixels(pixels):
    if len(pixels) != PIXEL_COUNT:
        raise ValueError(f"Expected {PIXEL_COUNT} grayscale pixels.")
    return [
        pixels[index] | (pixels[index + 1] << 8)
        for index in range(0, PIXEL_COUNT, 2)
    ]


def unpack_words(words):
    if len(words) != PIXEL_COUNT // 2:
        raise ValueError(f"Expected {PIXEL_COUNT // 2} output words.")
    pixels = []
    for word in words:
        pixels.extend((word & 0xFF, (word >> 8) & 0xFF))
    return pixels


def load_grayscale_image(image_path):
    with Image.open(image_path) as source:
        return source.convert("L").resize(
            (IMAGE_WIDTH, IMAGE_HEIGHT), Image.Resampling.LANCZOS
        )


def send_image(connection, image):
    words = pack_pixels(np.asarray(image).reshape(-1).tolist())
    upload_started = time.perf_counter()
    address_write_seconds = 0.0
    data_write_seconds = 0.0
    for address, word in enumerate(words):
        operation_started = time.perf_counter()
        jtag_fpga.write_value_to_fpga(
            connection, PIXEL_SOURCE_ADDR_REG, address, strict=True
        )
        address_write_seconds += time.perf_counter() - operation_started

        operation_started = time.perf_counter()
        jtag_fpga.write_value_to_fpga(
            connection, PIXEL_SOURCE_DATA_REG, word, strict=True
        )
        data_write_seconds += time.perf_counter() - operation_started
        if (address + 1) % 128 == 0:
            completed_words = address + 1
            elapsed = time.perf_counter() - upload_started
            address_average = address_write_seconds / completed_words
            data_average = data_write_seconds / completed_words
            print(
                f"\rUploaded {completed_words}/{len(words)} words "
                f"in {elapsed:.1f}s "
                f"(address {address_average:.3f}s/write, "
                f"data {data_average:.3f}s/write)",
                end="",
                flush=True,
            )

    print()
    print(
        f"Upload writes took {time.perf_counter() - upload_started:.1f}s total "
        f"({address_write_seconds / len(words):.3f}s/address write, "
        f"{data_write_seconds / len(words):.3f}s/data write average)."
    )
    jtag_fpga.write_value_to_fpga(
        connection, PIXEL_COUNT_REG, PIXEL_COUNT, strict=True
    )
    jtag_fpga.write_value_to_fpga(
        connection, PIXEL_START_REG, 1, strict=True
    )


def read_image(connection, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        status = jtag_fpga.read_value_from_fpga(
            connection, PIXEL_STATUS_REG, strict=True
        )
        if status & 0x8:
            raise ValueError("FPGA rejected the configured pixel count.")
        if status & 0x4:
            raise RuntimeError("FPGA rejected a source-memory write.")
        if status & 0x2:
            break
        time.sleep(POLL_INTERVAL)
    else:
        raise TimeoutError("Timed out waiting for the FPGA image processing.")

    words = []
    word_count = PIXEL_COUNT // 2
    for address in range(word_count):
        jtag_fpga.write_value_to_fpga(
            connection, PIXEL_OUTPUT_ADDR_REG, address, strict=True
        )
        words.append(
            jtag_fpga.read_value_from_fpga(
                connection, PIXEL_OUTPUT_DATA_REG, strict=True
            )
        )
        if (address + 1) % 128 == 0:
            print(f"\rRead {address + 1}/{word_count} output words", end="", flush=True)
    print()
    return unpack_words(words)


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
        (axes[0], source_image, "Input image sent to FPGA"),
        (axes[1], output_image, "Inverted image read back from FPGA"),
    ):
        axis.imshow(
            np.asarray(image),
            cmap="gray",
            vmin=0,
            vmax=255,
            interpolation="nearest",
        )
        axis.set_title(title)
        axis.set_xlabel("FPGA stores 8-bit grayscale pixels")
        axis.set_xticks([])
        axis.set_yticks([])

    figure.tight_layout()
    plt.show()


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=(
            "Send a 64x64 grayscale image to the FPGA, invert it in 20-pixel "
            "batches, read the output image back, and display both images."
        )
    )
    parser.add_argument("image", type=Path, help="input image file")
    parser.add_argument("--host", default=jtag_fpga.HOST, help="JTAG server host")
    parser.add_argument(
        "--port", type=int, default=jtag_fpga.PORT, help="JTAG server TCP port"
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=TRANSFER_TIMEOUT,
        help=f"seconds to wait for FPGA processing (default: {TRANSFER_TIMEOUT})",
    )
    parser.add_argument(
        "-c",
        "--no-display",
        action="store_true",
        help="verify the readback without opening an image display",
    )
    parser.add_argument(
        "--save-images",
        action="store_true",
        help="save the resized input and FPGA output as PNGs beside the input image",
    )
    args = parser.parse_args(argv)

    if jtag_fpga.DATA_WIDTH != 16:
        parser.error("The pixel MMIO design requires a 16-bit JTAG data width.")
    if not 1 <= args.port <= 65535:
        parser.error("port must be between 1 and 65535.")
    if args.timeout <= 0:
        parser.error("timeout must be greater than zero.")

    try:
        image = load_grayscale_image(args.image)
    except (OSError, ValueError) as exc:
        parser.error(f"could not load image {args.image}: {exc}")

    connection = jtag_fpga.open_connection(args.host, args.port)
    if connection is None:
        logging.error("Could not connect to JTAG server at %s:%s.", args.host, args.port)
        return 1

    try:
        print(f"Sending {args.image} as a {IMAGE_WIDTH}x{IMAGE_HEIGHT} grayscale image...")
        send_image(connection, image)
        print("Uploaded 4096 pixels in 2048 words; started batch processing.")
        print("Waiting for the FPGA to invert all batches...")
        output_pixels = read_image(connection, args.timeout)
        expected_pixels = [255 - value for value in np.asarray(image).reshape(-1)]
        if output_pixels != expected_pixels:
            raise RuntimeError("FPGA output did not match the expected inverted image.")
        print("Readback matches the inverted image.")
        if args.save_images:
            input_output_path, processed_output_path = save_images(
                image, output_pixels, args.image
            )
            print(f"Saved resized input image: {input_output_path}")
            print(f"Saved FPGA output image: {processed_output_path}")
        if args.no_display:
            print("Image display skipped.")
        else:
            print("Displaying input and output images.")
            display_images(image, output_pixels)
    except (ConnectionError, OSError, RuntimeError, TimeoutError, ValueError) as exc:
        logging.error("Image transfer failed: %s", exc)
        return 1
    finally:
        connection.close()
    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="|%(levelname)s| %(message)s")
    raise SystemExit(main())
