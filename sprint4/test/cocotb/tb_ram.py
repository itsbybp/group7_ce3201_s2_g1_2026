import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

SIGS_IN = ["we_instr", "re_instr", "we_in", "re_in", "we_out", "re_out",
           "we_hist", "re_hist", "imem_valid"]


async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


async def init(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    for s in SIGS_IN:
        getattr(dut, s).value = 0
    dut.addr.value = 0
    dut.data_in.value = 0
    dut.imem_addr.value = 0
    dut.rst_n.value = 0
    await tick(dut)
    dut.rst_n.value = 1
    await tick(dut)


async def write(dut, we, addr, data):
    dut.addr.value = addr
    dut.data_in.value = data
    getattr(dut, we).value = 1
    await tick(dut)
    getattr(dut, we).value = 0


async def read(dut, re, rdata, addr):
    """Lectura sincronica: el dato aparece un ciclo despues del re_*."""
    dut.addr.value = addr
    getattr(dut, re).value = 1
    await tick(dut)
    getattr(dut, re).value = 0
    return int(getattr(dut, rdata).value)


MEMS = [
    ("instr", 0x1FFC),
    ("in",    0xFFFC),
    ("out",   0xFFFC),
    ("hist",  0x03FC),
]


@cocotb.test()
async def test_write_read_each_memory(dut):
    """Primera y ultima palabra de cada memoria."""
    await init(dut)
    for name, last in MEMS:
        for addr, data in ((0x0, 0xA5A5A5A5), (last, 0x5A5A5A5A)):
            await write(dut, f"we_{name}", addr, data)
            got = await read(dut, f"re_{name}", f"{name}_rdata", addr)
            assert got == data, f"{name}[{addr:#x}]: esperado {data:#x}, obtenido {got:#x}"


@cocotb.test()
async def test_memories_independent(dut):
    """Misma direccion en las 4 memorias con datos distintos: sin interferencia."""
    await init(dut)
    datos = {"instr": 0x11111111, "in": 0x22222222, "out": 0x33333333, "hist": 0x44444444}
    for name, d in datos.items():
        await write(dut, f"we_{name}", 0x40, d)
    for name, d in datos.items():
        got = await read(dut, f"re_{name}", f"{name}_rdata", 0x40)
        assert got == d, f"{name}: esperado {d:#x}, obtenido {got:#x}"


@cocotb.test()
async def test_read_latency_and_hold(dut):
    """El dato llega 1 ciclo despues y se mantiene mientras re_* esta en 0."""
    await init(dut)
    await write(dut, "we_in", 0x10, 0xCAFEF00D)
    await write(dut, "we_in", 0x14, 0x0BADBEEF)
    dut.addr.value = 0x10
    dut.re_in.value = 1
    await Timer(1, unit="ns")
    assert int(dut.in_rdata.value) != 0xCAFEF00D, "no debe haber lectura combinacional"
    await tick(dut)
    dut.re_in.value = 0
    assert int(dut.in_rdata.value) == 0xCAFEF00D
    dut.addr.value = 0x14
    await tick(dut)
    assert int(dut.in_rdata.value) == 0xCAFEF00D, "sin re_in el dato debe retenerse"


@cocotb.test()
async def test_no_write_without_we(dut):
    await init(dut)
    await write(dut, "we_out", 0x20, 0x12345678)
    dut.addr.value = 0x20
    dut.data_in.value = 0xFFFFFFFF
    await tick(dut)
    got = await read(dut, "re_out", "out_rdata", 0x20)
    assert got == 0x12345678, f"escritura sin we_out: {got:#x}"


@cocotb.test()
async def test_hist_address_mapping(dut):
    """Histograma: addr[9:2] -> 256 contadores; 0x3FC es el ultimo."""
    await init(dut)
    for i in (0, 1, 127, 255):
        await write(dut, "we_hist", i * 4, 0x1000 + i)
    for i in (0, 1, 127, 255):
        got = await read(dut, "re_hist", "hist_rdata", i * 4)
        assert got == 0x1000 + i, f"hist[{i}]: {got:#x}"


@cocotb.test()
async def test_imem_port(dut):
    """Puerto de instrucciones de la CPU: lee mem_instr, ready 1 ciclo despues."""
    await init(dut)
    prog = {0x00: 0x00500093, 0x04: 0x00A00113, 0x10: 0x002081B3, 0x1FFC: 0x0000006F}
    for a, d in prog.items():
        await write(dut, "we_instr", a, d)

    assert int(dut.imem_ready.value) == 0
    for a, d in prog.items():
        dut.imem_addr.value = a
        dut.imem_valid.value = 1
        await Timer(1, unit="ns")
        assert int(dut.imem_ready.value) == 0, "imem_ready no debe ser combinacional"
        await tick(dut)
        assert int(dut.imem_ready.value) == 1, f"imem_ready 1 ciclo despues ({a:#x})"
        assert int(dut.imem_rdata.value) == d, \
            f"instr[{a:#x}]: esperado {d:#x}, obtenido {int(dut.imem_rdata.value):#x}"
        dut.imem_valid.value = 0
        await tick(dut)
        assert int(dut.imem_ready.value) == 0, "imem_ready baja sin valid"


@cocotb.test()
async def test_imem_ready_pattern(dut):
    """Con valid sostenido imem_ready alterna 1,0,1,0 (una instruccion cada 2 ciclos)."""
    await init(dut)
    dut.imem_valid.value = 1
    seen = []
    for _ in range(4):
        await tick(dut)
        seen.append(int(dut.imem_ready.value))
    assert seen == [1, 0, 1, 0], f"patron de imem_ready: {seen}"
    dut.imem_valid.value = 0


@cocotb.test()
async def test_host_and_cpu_instr_ports_coexist(dut):
    """El Host puede escribir/leer la RAM de instrucciones mientras la CPU no hace fetch."""
    await init(dut)
    await write(dut, "we_instr", 0x08, 0xDEADBEEF)
    got = await read(dut, "re_instr", "instr_rdata", 0x08)
    assert got == 0xDEADBEEF
    dut.imem_addr.value = 0x08
    dut.imem_valid.value = 1
    await tick(dut)
    dut.imem_valid.value = 0
    assert int(dut.imem_rdata.value) == 0xDEADBEEF