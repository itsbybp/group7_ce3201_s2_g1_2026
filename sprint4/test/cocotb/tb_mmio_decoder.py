import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

WE = ["we_instr", "we_in", "we_out", "we_hist", "we_ledr",
      "we_hex", "we_ctrl", "we_status", "we_threshold"]
RE = ["re_instr", "re_in", "re_out", "re_hist"]

# (direccion, we_*, permitido Host, permitido CPU)
WRITE_MAP = [
    (0x00000000, "we_instr",     True,  False),
    (0x00001FFC, "we_instr",     True,  False),
    (0x00010000, "we_in",        True,  False),
    (0x0001FFFC, "we_in",        True,  False),
    (0x00020000, "we_out",       False, True),
    (0x0002FFFC, "we_out",       False, True),
    (0x00030000, "we_hist",      False, True),
    (0x000303FC, "we_hist",      False, True),
    (0x00040000, "we_ledr",      True,  True),
    (0x00040004, "we_hex",       True,  True),
    (0x00050000, "we_ctrl",      True,  False),
    (0x00050004, "we_status",    False, True),
    (0x0005000C, "we_threshold", True,  False),
]

# (direccion, re_*) para RAM; los registros no tienen re_*
READ_MAP = [
    (0x00000000, "re_instr", "instr_rdata"),
    (0x00001FFC, "re_instr", "instr_rdata"),
    (0x00010000, "re_in",    "in_rdata"),
    (0x0001FFFC, "re_in",    "in_rdata"),
    (0x00020000, "re_out",   "out_rdata"),
    (0x0002FFFC, "re_out",   "out_rdata"),
    (0x00030000, "re_hist",  "hist_rdata"),
    (0x000303FC, "re_hist",  "hist_rdata"),
    (0x00040000, None,       "reg_rdata"),
    (0x00040004, None,       "reg_rdata"),
    (0x00050000, None,       "reg_rdata"),
    (0x00050004, None,       "reg_rdata"),
    (0x0005000C, None,       "reg_rdata"),
]

UNMAPPED = [0x00002000, 0x0000FFFC, 0x00030400, 0x00040008, 0x0004000C,
            0x00040010, 0x00050008, 0x00050010, 0x00060000, 0xFFFFFFFC]

RDATA = {
    "instr_rdata": 0x11111111,
    "in_rdata":    0x22222222,
    "out_rdata":   0x33333333,
    "hist_rdata":  0x44444444,
    "reg_rdata":   0x55555555,
}


async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


async def init(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 0
    dut.valid.value = 0
    dut.write_en.value = 0
    dut.is_cpu.value = 0
    dut.addr.value = 0
    for k, v in RDATA.items():
        getattr(dut, k).value = v
    await tick(dut)
    dut.rst_n.value = 1
    await tick(dut)


async def drive(dut, addr, write, cpu):
    dut.addr.value = addr
    dut.write_en.value = int(write)
    dut.is_cpu.value = int(cpu)
    dut.valid.value = 1
    await Timer(1, unit="ns")


async def release(dut):
    dut.valid.value = 0
    dut.write_en.value = 0
    await tick(dut)


def active(dut, names):
    return {n for n in names if int(getattr(dut, n).value)}


@cocotb.test()
async def test_write_permissions(dut):
    """Tabla 2: cada we_* solo se activa para el maestro permitido."""
    await init(dut)
    for addr, we, host_ok, cpu_ok in WRITE_MAP:
        for cpu, ok in ((False, host_ok), (True, cpu_ok)):
            await drive(dut, addr, True, cpu)
            exp = {we} if ok else set()
            got = active(dut, WE)
            who = "CPU" if cpu else "Host"
            assert got == exp, f"{who} escribe {addr:#x}: esperado {exp}, obtenido {got}"
            assert not active(dut, RE), "una escritura no debe activar re_*"
            assert int(dut.ready.value) == 1, f"{who} {addr:#x}: ready de escritura en el mismo ciclo"
            await release(dut)


@cocotb.test()
async def test_read_selects(dut):
    """Las lecturas activan el re_* de la RAM correcta, para ambos maestros."""
    await init(dut)
    for addr, re, _ in READ_MAP:
        for cpu in (False, True):
            await drive(dut, addr, False, cpu)
            exp = {re} if re else set()
            assert active(dut, RE) == exp, f"lectura {addr:#x}: re_* esperado {exp}"
            assert not active(dut, WE), "una lectura no debe activar we_*"
            await release(dut)


@cocotb.test()
async def test_read_data_and_latency(dut):
    """rdata valido junto con ready, un ciclo despues de la direccion."""
    await init(dut)
    for addr, _, src in READ_MAP:
        for cpu in (False, True):
            await drive(dut, addr, False, cpu)
            assert int(dut.ready.value) == 0, f"{addr:#x}: ready no debe subir en el mismo ciclo"
            await tick(dut)
            assert int(dut.ready.value) == 1, f"{addr:#x}: ready debe subir un ciclo despues"
            assert int(dut.rdata.value) == RDATA[src], \
                f"{addr:#x}: rdata esperado {RDATA[src]:#x}, obtenido {int(dut.rdata.value):#x}"
            await release(dut)
            assert int(dut.ready.value) == 0, "sin valid, ready debe ser 0"


@cocotb.test()
async def test_raz_unmapped(dut):
    """Lecturas fuera de mapa devuelven 0 aunque los subordinados tengan datos."""
    await init(dut)
    for k in RDATA:
        getattr(dut, k).value = 0xFFFFFFFF
    for addr in UNMAPPED:
        for cpu in (False, True):
            await drive(dut, addr, False, cpu)
            assert not active(dut, RE), f"{addr:#x}: no debe seleccionar RAM"
            await tick(dut)
            assert int(dut.ready.value) == 1, f"{addr:#x}: ready tambien en no mapeadas"
            assert int(dut.rdata.value) == 0, f"RAZ {addr:#x}: rdata={int(dut.rdata.value):#x}"
            await release(dut)


@cocotb.test()
async def test_wi_unmapped(dut):
    """Escrituras fuera de mapa se ignoran (WI) pero completan con ready."""
    await init(dut)
    for addr in UNMAPPED:
        for cpu in (False, True):
            await drive(dut, addr, True, cpu)
            assert not active(dut, WE), f"WI {addr:#x}: no debe activar we_*"
            assert not active(dut, RE)
            assert int(dut.ready.value) == 1, f"WI {addr:#x}: ready debe ser 1"
            await release(dut)


@cocotb.test()
async def test_valid_gating(dut):
    """Con valid=0 no hay we_*, re_* ni ready."""
    await init(dut)
    for addr, _, _, _ in WRITE_MAP:
        for wr in (False, True):
            dut.addr.value = addr
            dut.write_en.value = int(wr)
            dut.is_cpu.value = 1
            dut.valid.value = 0
            await Timer(1, unit="ns")
            assert not active(dut, WE) and not active(dut, RE) and int(dut.ready.value) == 0


@cocotb.test()
async def test_read_handshake_sequence(dut):
    """Con valid sostenido en lectura, ready alterna 0,1,0,1 (cada lectura = 2 ciclos)."""
    await init(dut)
    await drive(dut, 0x00010000, False, False)
    seen = []
    for _ in range(4):
        seen.append(int(dut.ready.value))
        await tick(dut)
    assert seen == [0, 1, 0, 1], f"patron de ready: {seen}"
    await release(dut)