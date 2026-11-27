"""Prueba end-to-end del sistema (CPU + arbiter + MMIO + RAM + registros de control).

El Host (vJTAG) hace lo mismo que en la placa:
  1. carga firmware.hex en la RAM de instrucciones,
  2. carga la imagen de entrada y escribe THRESHOLD,
  3. pone CTRL[0] = 1 (start),
  4. espera STATUS.done,
  5. lee el histograma y la imagen de salida y los compara contra Python.

Variables de entorno:
  N_PIXELS=64     pixeles de la imagen reducida (maximo 511). Por defecto 64.
  FULL_IMAGE=1    firmware sin modificar y 16384 pixeles (lento).
"""

import os
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer

SPRINT4 = Path(__file__).resolve().parents[2]
FIRMWARE_HEX = SPRINT4 / "firmware" / "firmware.hex"

INSTR_BASE = 0x00000
IN_BASE = 0x10000
OUT_BASE = 0x20000
HIST_BASE = 0x30000
HEX_ADDR = 0x40004
CTRL_ADDR = 0x50000
STATUS_ADDR = 0x50004
THR_ADDR = 0x5000C

FULL_IMAGE = os.environ.get("FULL_IMAGE", "0") == "1"
N_PIXELS = 16384 if FULL_IMAGE else int(os.environ.get("N_PIXELS", "64"))
THRESHOLD = 100


async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


async def init(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.vjtag_valid.value = 0
    dut.vjtag_addr.value = 0
    dut.vjtag_data.value = 0
    dut.vjtag_write_en.value = 0
    dut.rst_n.value = 0
    await tick(dut)
    await tick(dut)
    dut.rst_n.value = 1
    await tick(dut)


async def host_write(dut, addr, data):
    """Escritura del Host: mantiene valid hasta ready; el flanco siguiente la ejecuta."""
    dut.vjtag_addr.value = addr
    dut.vjtag_data.value = data
    dut.vjtag_write_en.value = 1
    dut.vjtag_valid.value = 1
    while True:
        await tick(dut)
        if int(dut.vjtag_ready.value):
            await tick(dut)
            break
    dut.vjtag_valid.value = 0
    dut.vjtag_write_en.value = 0


async def host_read(dut, addr):
    """Lectura del Host: ready sube un ciclo despues de ser concedido y rdata es valido ahi."""
    dut.vjtag_addr.value = addr
    dut.vjtag_write_en.value = 0
    dut.vjtag_valid.value = 1
    while True:
        await tick(dut)
        if int(dut.vjtag_ready.value):
            data = int(dut.vjtag_rdata.value)
            await tick(dut)
            break
    dut.vjtag_valid.value = 0
    return data


def load_firmware():
    """Devuelve las palabras de firmware.hex (una por linea, en hexadecimal)."""
    words = []
    for line in FIRMWARE_HEX.read_text().splitlines():
        line = line.strip()
        if line:
            words.append(int(line, 16))
    return words


def shorten_loop(words, n_pixels):
    """Solo para la imagen reducida: el firmware recorre IN hasta s1 (0x20000).

    Se cambian dos palabras para que termine tras n_pixels sin tocar el resto:
      - 'addi t0, zero, 1' (STATUS.busy, sin efecto: busy ahora se calcula)
            -> 'addi a1, s0, 4*n_pixels'   (a1 = fin de la imagen reducida)
      - 'bne t0, s1, loop'                 -> 'bne t0, a1, loop'
    """
    assert 1 <= n_pixels <= 511, "4*N_PIXELS debe caber en un inmediato de 12 bits"
    out = list(words)

    busy_idx = [i for i, w in enumerate(out) if w == 0x00100293]
    assert len(busy_idx) == 1, "no encuentro 'addi t0, zero, 1' en firmware.hex"
    out[busy_idx[0]] = ((4 * n_pixels) << 20) | (8 << 15) | (11 << 7) | 0x13

    bne_idx = [i for i, w in enumerate(out)
               if (w & 0x7F) == 0x63 and ((w >> 20) & 0x1F) == 9]
    assert len(bne_idx) == 1, "no encuentro 'bne t0, s1, loop' en firmware.hex"
    out[bne_idx[0]] = (out[bne_idx[0]] & ~(0x1F << 20)) | (11 << 20)
    return out


async def load_system(dut, pixels):
    """Carga firmware, imagen y umbral. Deja CTRL[0] en 0."""
    words = load_firmware()
    if not FULL_IMAGE:
        words = shorten_loop(words, len(pixels))
    for i, w in enumerate(words):
        await host_write(dut, INSTR_BASE + 4 * i, w)
    for i, p in enumerate(pixels):
        await host_write(dut, IN_BASE + 4 * i, p)
    await host_write(dut, THR_ADDR, THRESHOLD)
    assert await host_read(dut, THR_ADDR) == THRESHOLD, "THRESHOLD no quedo escrito"


async def host_noise(dut, ctl, seed):
    """Lecturas del Host en momentos aleatorios: obliga al CPU a esperar por el bus de datos."""
    rnd = random.Random(seed)
    addrs = [IN_BASE, IN_BASE + 4, OUT_BASE, HIST_BASE, HIST_BASE + 8,
             0x40000, STATUS_ADDR, CTRL_ADDR, THR_ADDR, 0x2FFFC, 0x60000]
    ctl["reads"] = 0
    while ctl["run"]:
        await ClockCycles(dut.clk, rnd.randint(1, 6))
        if not ctl["run"]:
            break
        await host_read(dut, rnd.choice(addrs))
        ctl["reads"] += 1
    ctl["stopped"] = True


async def watch_illegal(dut, flag):
    while True:
        await RisingEdge(dut.illegal)
        flag["illegal"] = True


async def run_to_done(dut, max_cycles):
    """Espera a que el firmware marque done. Devuelve los ciclos aproximados."""
    waited = 0
    while waited < max_cycles:
        await ClockCycles(dut.clk, 64)
        waited += 64
        if int(dut.done.value):
            return waited
    raise AssertionError(
        f"El firmware no marco done en {max_cycles} ciclos: "
        f"pc={int(dut.pc.value):#x} instruccion={int(dut.instruction.value):#010x} "
        f"illegal={int(dut.illegal.value)}"
    )


async def check_results(dut, pixels):
    exp_hist = [0] * 256
    for p in pixels:
        exp_hist[p] += 1
    exp_out = [255 if p >= THRESHOLD else 0 for p in pixels]

    status = await host_read(dut, STATUS_ADDR)
    assert status == 0b10, f"STATUS esperado 0b10 (done=1, busy=0), obtenido {status:#b}"

    got_hist = [await host_read(dut, HIST_BASE + 4 * i) for i in range(256)]
    bad = [i for i in range(256) if got_hist[i] != exp_hist[i]]
    assert not bad, f"histograma distinto en los bins {bad[:8]}: " \
                    f"esperado {[exp_hist[i] for i in bad[:8]]}, obtenido {[got_hist[i] for i in bad[:8]]}"
    assert sum(got_hist) == len(pixels), "la suma del histograma debe ser el numero de pixeles"

    got_out = [await host_read(dut, OUT_BASE + 4 * i) for i in range(len(pixels))]
    bad = [i for i in range(len(pixels)) if got_out[i] != exp_out[i]]
    assert not bad, f"imagen de salida distinta en {bad[:8]}"

    assert int(dut.hex.value) == len(pixels), "HEX debe terminar en el numero de pixeles"
    if len(pixels) < 16384:
        assert await host_read(dut, OUT_BASE + 4 * len(pixels)) == 0, "no debe escribir fuera de la imagen"


def make_pixels(seed):
    rnd = random.Random(seed)
    pixels = [rnd.randint(0, 255) for _ in range(N_PIXELS)]
    pixels[0] = THRESHOLD        # justo en el umbral: debe dar 255
    if N_PIXELS > 1:
        pixels[1] = THRESHOLD - 1    # justo debajo: debe dar 0
    return pixels


async def collect_fetches(dut, out, cycles):
    """Guarda el PC de cada busqueda de instruccion (ciclo con handshake de instrucciones)."""
    for _ in range(cycles):
        await tick(dut)
        if int(dut.handshake_instr.value):
            out.append(int(dut.pc.value))


@cocotb.test()
async def test_fetch_secuencial(dut):
    """Diagnostico: cada instruccion se busca una sola vez y en orden (0x0, 0x4, 0x8, ...)."""
    await init(dut)
    await load_system(dut, make_pixels(1))
    assert int(dut.pc.value) == 0, "antes de start el PC debe estar en 0"
    fetches = []
    cocotb.start_soon(collect_fetches(dut, fetches, 400))
    await host_write(dut, CTRL_ADDR, 1)
    await ClockCycles(dut.clk, 300)
    dut._log.info(f"Busquedas de instruccion: {[hex(p) for p in fetches[:14]]}")
    esperado = [4 * i for i in range(10)]    # 0x00 a 0x24: las 10 primeras instrucciones del firmware
    assert fetches[:10] == esperado, (
        f"el PC no avanza de 4 en 4: {[hex(p) for p in fetches[:10]]} "
        f"(revisar alu_src_a en FETCH: debe ser 00 = pc)"
    )
    assert not int(dut.illegal.value)


@cocotb.test()
async def test_firmware_end_to_end(dut):
    """TP-13: firmware.hex + imagen reducida -> histograma e imagen de salida exactos."""
    await init(dut)
    flag = {"illegal": False}
    cocotb.start_soon(watch_illegal(dut, flag))
    pixels = make_pixels(2)
    await load_system(dut, pixels)

    assert int(dut.done.value) == 0 and int(dut.busy.value) == 0
    await host_write(dut, CTRL_ADDR, 1)
    assert int(dut.busy.value) == 1, "con start=1 y sin done, busy debe ser 1"

    cycles = await run_to_done(dut, 200 * N_PIXELS + 30000)
    assert int(dut.busy.value) == 0 and int(dut.done.value) == 1
    await check_results(dut, pixels)
    assert not flag["illegal"], "el CPU marco una instruccion ilegal"
    dut._log.info(f"OK: {N_PIXELS} pixeles, ~{cycles} ciclos hasta done")


@cocotb.test()
async def test_firmware_with_bus_stalls(dut):
    """Mismo firmware con el Host leyendo al azar: el CPU espera por el bus y no pierde datos."""
    await init(dut)
    flag = {"illegal": False}
    cocotb.start_soon(watch_illegal(dut, flag))
    pixels = make_pixels(3)
    await load_system(dut, pixels)

    await host_write(dut, CTRL_ADDR, 1)
    ctl = {"run": True, "stopped": False, "reads": 0}
    cocotb.start_soon(host_noise(dut, ctl, seed=11))
    cycles = await run_to_done(dut, 400 * N_PIXELS + 60000)
    ctl["run"] = False
    for _ in range(100):
        if ctl["stopped"]:
            break
        await ClockCycles(dut.clk, 1)
    assert ctl["stopped"], "el ruido del Host no termino"
    assert ctl["reads"] > 0, "el Host no logro leer durante la ejecucion"

    await check_results(dut, pixels)
    assert not flag["illegal"], "el CPU marco una instruccion ilegal"
    dut._log.info(f"OK con stalls: {ctl['reads']} lecturas del Host, ~{cycles} ciclos hasta done")


@cocotb.test()
async def test_fetch_fuera_de_rango_lee_cero(dut):
    """Fetch fuera de la RAM de instrucciones (Tabla 2): instruccion = 0 (RAZ) y no bloquea."""
    await init(dut)
    await host_write(dut, INSTR_BASE, 0x0000206F)    # jal x0, 0x2000: salta fuera de rango
    flag = {"illegal": False}
    cocotb.start_soon(watch_illegal(dut, flag))
    fetches = []
    cocotb.start_soon(collect_fetches(dut, fetches, 200))
    await host_write(dut, CTRL_ADDR, 1)
    await ClockCycles(dut.clk, 150)
    dut._log.info(f"Busquedas: {[hex(p) for p in fetches[:8]]}")
    assert 0x2000 in fetches, "la CPU debia saltar a 0x2000"
    assert flag["illegal"], "una instruccion leida como 0 debe decodificar como ilegal"
    assert int(dut.instruction.value) == 0, "fuera de rango debe leer 0 (RAZ)"
    assert 0x2004 in fetches, "la CPU no debe bloquearse tras leer fuera de rango"