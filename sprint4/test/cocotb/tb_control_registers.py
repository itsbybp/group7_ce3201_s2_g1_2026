import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

LEDR, HEX, CTRL, STATUS, THR = 0x40000, 0x40004, 0x50000, 0x50004, 0x5000C
WES = ["we_ledr", "we_hex", "we_ctrl", "we_status", "we_threshold"]


async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


async def init(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    for s in WES:
        getattr(dut, s).value = 0
    dut.write_data.value = 0
    dut.mmio_address.value = 0
    dut.reset_n.value = 0
    await tick(dut)
    dut.reset_n.value = 1
    await tick(dut)


async def wr(dut, we, addr, data):
    dut.mmio_address.value = addr
    dut.write_data.value = data
    getattr(dut, we).value = 1
    await tick(dut)
    getattr(dut, we).value = 0


async def rd(dut, addr):
    """Lectura registrada: el dato aparece un ciclo despues de la direccion."""
    dut.mmio_address.value = addr
    await tick(dut)
    return int(dut.selected_register.value)


@cocotb.test()
async def test_reset_values(dut):
    await init(dut)
    for a in (LEDR, HEX, CTRL, STATUS, THR):
        assert await rd(dut, a) == 0, f"reset: {a:#x} != 0"
    assert int(dut.start.value) == 0 and int(dut.done.value) == 0
    assert int(dut.busy.value) == 0 and int(dut.cpu_enable.value) == 0


@cocotb.test()
async def test_ledr_hex_threshold_rw_and_width(dut):
    await init(dut)
    await wr(dut, "we_ledr", LEDR, 0xFFFFFFFF)
    assert await rd(dut, LEDR) == 0x3FF and int(dut.ledr.value) == 0x3FF, "LEDR de 10 bits"
    await wr(dut, "we_hex", HEX, 0xFFFFFFFF)
    assert await rd(dut, HEX) == 0xFFFFFF and int(dut.hex.value) == 0xFFFFFF, "HEX de 24 bits"
    await wr(dut, "we_threshold", THR, 0xFFFFFF80)
    assert await rd(dut, THR) == 0x80 and int(dut.threshold.value) == 0x80, "THRESHOLD de 8 bits"
    await wr(dut, "we_ledr", LEDR, 0x155)
    assert await rd(dut, LEDR) == 0x155
    assert await rd(dut, HEX) == 0xFFFFFF, "HEX no debe cambiar al escribir LEDR"


@cocotb.test()
async def test_ctrl_start_busy_enable(dut):
    await init(dut)
    await wr(dut, "we_ctrl", CTRL, 0xFFFFFFFF)
    assert await rd(dut, CTRL) == 1, "CTRL solo guarda bit 0"
    assert int(dut.start.value) == 1 and int(dut.busy.value) == 1 and int(dut.cpu_enable.value) == 1
    assert await rd(dut, STATUS) == 0b01, "STATUS: busy=1, done=0"


@cocotb.test()
async def test_status_done_and_enable_off(dut):
    """La CPU escribe done=1: busy y cpu_enable bajan, start queda en 1."""
    await init(dut)
    await wr(dut, "we_ctrl", CTRL, 1)
    await wr(dut, "we_status", STATUS, 0b10)
    assert int(dut.done.value) == 1 and int(dut.start.value) == 1
    assert int(dut.busy.value) == 0 and int(dut.cpu_enable.value) == 0
    assert await rd(dut, STATUS) == 0b10, "STATUS: done=1, busy=0"
    assert await rd(dut, CTRL) == 1, "CTRL[0] se mantiene hasta que el Host lo baje"


@cocotb.test()
async def test_status_write_ignored_when_idle(dut):
    await init(dut)
    await wr(dut, "we_status", STATUS, 0b10)
    assert int(dut.done.value) == 0, "done no se activa con start=0"
    assert await rd(dut, STATUS) == 0


@cocotb.test()
async def test_done_clears_and_rearm(dut):
    """El Host baja CTRL[0]: done se limpia solo; subirlo re-arma (busy=1, done=0)."""
    await init(dut)
    await wr(dut, "we_ctrl", CTRL, 1)
    await wr(dut, "we_status", STATUS, 0b10)
    await wr(dut, "we_ctrl", CTRL, 0)
    await tick(dut)
    assert int(dut.start.value) == 0 and int(dut.done.value) == 0
    await wr(dut, "we_ctrl", CTRL, 1)
    assert int(dut.start.value) == 1 and int(dut.done.value) == 0
    assert int(dut.busy.value) == 1 and int(dut.cpu_enable.value) == 1


@cocotb.test()
async def test_no_write_without_we(dut):
    """Cambiar write_data/mmio_address sin we_* no modifica nada."""
    await init(dut)
    await wr(dut, "we_ledr", LEDR, 0x123)
    await wr(dut, "we_threshold", THR, 0x42)
    for a in (LEDR, HEX, CTRL, STATUS, THR):
        dut.mmio_address.value = a
        dut.write_data.value = 0xFFFFFFFF
        await tick(dut)
    assert int(dut.ledr.value) == 0x123 and int(dut.threshold.value) == 0x42
    assert int(dut.start.value) == 0 and int(dut.done.value) == 0 and int(dut.hex.value) == 0


@cocotb.test()
async def test_unmapped_reads_zero(dut):
    """0x50008 (sin registro) y otras direcciones sin mapear leen 0."""
    await init(dut)
    await wr(dut, "we_ledr", LEDR, 0x3FF)
    await wr(dut, "we_hex", HEX, 0xFFFFFF)
    await wr(dut, "we_threshold", THR, 0xFF)
    for a in (0x50008, 0x40008, 0x4000C, 0x40018):
        assert await rd(dut, a) == 0, f"{a:#x} debe leer 0"


@cocotb.test()
async def test_read_latency(dut):
    await init(dut)
    await wr(dut, "we_threshold", THR, 0x77)
    dut.mmio_address.value = LEDR
    await tick(dut)
    dut.mmio_address.value = THR
    await Timer(1, unit="ns")
    assert int(dut.selected_register.value) == 0, "lectura registrada: no cambia en el mismo ciclo"
    await tick(dut)
    assert int(dut.selected_register.value) == 0x77


@cocotb.test()
async def test_async_reset(dut):
    await init(dut)
    await wr(dut, "we_ledr", LEDR, 0x3FF)
    await wr(dut, "we_hex", HEX, 0xABCDEF)
    await wr(dut, "we_threshold", THR, 0xFF)
    await wr(dut, "we_ctrl", CTRL, 1)
    await wr(dut, "we_status", STATUS, 0b10)
    dut.reset_n.value = 0
    await Timer(1, unit="ns")
    assert int(dut.start.value) == 0 and int(dut.done.value) == 0
    assert int(dut.ledr.value) == 0 and int(dut.hex.value) == 0 and int(dut.threshold.value) == 0
    dut.reset_n.value = 1
    await tick(dut)
    for a in (LEDR, HEX, CTRL, STATUS, THR):
        assert await rd(dut, a) == 0, f"post-reset {a:#x}"