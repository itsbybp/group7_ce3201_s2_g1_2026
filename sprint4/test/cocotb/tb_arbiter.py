import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

IDLE, VJ, CPU = "IDLE", "VJ", "CPU"


async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


def setin(dut, vv=0, va=0, vd=0, vw=0, fv=0, fa=0, fd=0, fw=0, sr=0):
    dut.vjtag_valid.value = vv
    dut.vjtag_addr.value = va
    dut.vjtag_data.value = vd
    dut.vjtag_write_en.value = vw
    dut.fsm_valid.value = fv
    dut.fsm_addr.value = fa
    dut.fsm_data.value = fd
    dut.fsm_write_en.value = fw
    dut.subordinate_ready.value = sr


async def init(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    setin(dut)
    dut.rst_n.value = 0
    await tick(dut)
    dut.rst_n.value = 1
    await tick(dut)


def mux(dut):
    return (int(dut.mux_valid.value), int(dut.mux_addr.value), int(dut.mux_data.value),
            int(dut.mux_write_en.value), int(dut.mux_is_cpu.value))


@cocotb.test()
async def test_idle_outputs_zero(dut):
    await init(dut)
    assert mux(dut) == (0, 0, 0, 0, 0)
    assert int(dut.vjtag_ready.value) == 0 and int(dut.fsm_ready.value) == 0


@cocotb.test()
async def test_vjtag_wins_when_both_request(dut):
    await init(dut)
    setin(dut, vv=1, va=0x100, vd=0xFF, vw=1, fv=1, fa=0x200, fd=0xAA, fw=0, sr=1)
    await tick(dut)
    assert mux(dut) == (1, 0x100, 0xFF, 1, 0), "vJTAG debe ganar y is_cpu=0"
    assert int(dut.vjtag_ready.value) == 1 and int(dut.fsm_ready.value) == 0


@cocotb.test()
async def test_cpu_alone(dut):
    await init(dut)
    setin(dut, fv=1, fa=0x20000, fd=0x1234, fw=1, sr=1)
    await tick(dut)
    assert mux(dut) == (1, 0x20000, 0x1234, 1, 1), "CPU concedida, is_cpu=1"
    assert int(dut.fsm_ready.value) == 1 and int(dut.vjtag_ready.value) == 0


@cocotb.test()
async def test_vjtag_backpressure_freezes_bus(dut):
    await init(dut)
    setin(dut, vv=1, va=0x100, vd=0xFF, vw=1, sr=0)
    for _ in range(3):
        await tick(dut)
        assert int(dut.vjtag_ready.value) == 0, "vjtag_ready=0 con backpressure"
        assert mux(dut) == (1, 0x100, 0xFF, 1, 0), "bus estable"


@cocotb.test()
async def test_cpu_holds_grant_until_ready(dut):
    """Si vJTAG pide mientras la CPU espera ready, la CPU conserva el bus."""
    await init(dut)
    setin(dut, fv=1, fa=0x30000, fd=0x7, fw=0, sr=0)
    await tick(dut)
    assert int(dut.mux_is_cpu.value) == 1
    setin(dut, vv=1, va=0x10000, vd=0x9, vw=1, fv=1, fa=0x30000, fd=0x7, fw=0, sr=0)
    for _ in range(4):
        await tick(dut)
        assert mux(dut)[4] == 1 and int(dut.mux_addr.value) == 0x30000, "CPU mantiene el bus"
        assert int(dut.vjtag_ready.value) == 0 and int(dut.fsm_ready.value) == 0
    dut.subordinate_ready.value = 1
    await Timer(1, unit="ns")
    assert int(dut.fsm_ready.value) == 1 and int(dut.vjtag_ready.value) == 0, "ready para la CPU"
    await tick(dut)
    assert mux(dut)[4] == 0 and int(dut.mux_addr.value) == 0x10000, "luego pasa a vJTAG"


@cocotb.test()
async def test_cpu_released_when_valid_drops(dut):
    await init(dut)
    setin(dut, fv=1, fa=0x30000, sr=0)
    await tick(dut)
    setin(dut, vv=1, va=0x44, sr=0)
    await tick(dut)
    assert mux(dut)[4] == 0, "sin fsm_valid la CPU suelta el bus y entra vJTAG"


@cocotb.test()
async def test_reset_returns_to_idle(dut):
    await init(dut)
    setin(dut, vv=1, va=0x5, sr=1)
    await tick(dut)
    dut.rst_n.value = 0
    await Timer(1, unit="ns")
    setin(dut)
    assert mux(dut) == (0, 0, 0, 0, 0)
    dut.rst_n.value = 1
    await tick(dut)


def ref_next(state, vv, fv, sr):
    if state == IDLE:
        return VJ if vv else CPU if fv else IDLE
    if state == VJ:
        return VJ if vv else CPU if fv else IDLE
    if fv and not sr:
        return CPU
    return VJ if vv else CPU if fv else IDLE


@cocotb.test()
async def test_random_against_model(dut):
    """Estimulo aleatorio contra un modelo de referencia + invariantes."""
    await init(dut)
    rnd = random.Random(7)
    state = IDLE
    for _ in range(3000):
        vv, fv, sr = rnd.randint(0, 1), rnd.randint(0, 1), rnd.randint(0, 1)
        va, vd, fa, fd = (rnd.getrandbits(32) for _ in range(4))
        vw, fw = rnd.randint(0, 1), rnd.randint(0, 1)
        setin(dut, vv, va, vd, vw, fv, fa, fd, fw, sr)
        await Timer(1, unit="ns")

        vr, fr = int(dut.vjtag_ready.value), int(dut.fsm_ready.value)
        assert not (vr and fr), "ambos ready en el mismo ciclo"
        if state == VJ:
            exp = (vv, va, vd, vw, 0)
            assert (vr, fr) == (sr, 0)
        elif state == CPU:
            exp = (fv, fa, fd, fw, 1)
            assert (vr, fr) == (0, sr)
        else:
            exp = (0, 0, 0, 0, 0)
            assert (vr, fr) == (0, 0)
        assert mux(dut) == exp, f"estado {state}: esperado {exp}, obtenido {mux(dut)}"

        state = ref_next(state, vv, fv, sr)
        await tick(dut)