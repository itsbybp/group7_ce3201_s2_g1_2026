import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def start_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())


@cocotb.test()
async def test_reset_asserted_while_key0_low(dut):
    await start_clock(dut)
    dut.key_raw.value = 0
    dut.key0_raw.value = 0
    await Timer(5, units="ns")
    assert dut.reset_n.value == 0


@cocotb.test()
async def test_reset_released_after_key0_high(dut):
    await start_clock(dut)
    dut.key_raw.value = 0
    dut.key0_raw.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)

    dut.key0_raw.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)

    assert dut.reset_n.value == 1


@cocotb.test()
async def test_key_pulse_single_cycle(dut):
    await start_clock(dut)
    dut.key_raw.value = 0
    dut.key0_raw.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)

    dut.key_raw.value = 1

    pulses = 0
    for _ in range(6):
        await RisingEdge(dut.clk)
        if dut.key_pulse.value == 1:
            pulses += 1

    assert pulses == 1


@cocotb.test()
async def test_key_pulse_not_repeated_while_held(dut):
    await start_clock(dut)
    dut.key_raw.value = 0
    dut.key0_raw.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)

    dut.key_raw.value = 1

    pulses = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.key_pulse.value == 1:
            pulses += 1

    assert pulses == 1


@cocotb.test()
async def test_key_pulse_fires_again_on_second_press(dut):
    await start_clock(dut)
    dut.key_raw.value = 0
    dut.key0_raw.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)

    dut.key_raw.value = 1
    for _ in range(6):
        await RisingEdge(dut.clk)

    dut.key_raw.value = 0
    for _ in range(6):
        await RisingEdge(dut.clk)

    dut.key_raw.value = 1

    pulses = 0
    for _ in range(6):
        await RisingEdge(dut.clk)
        if dut.key_pulse.value == 1:
            pulses += 1

    assert pulses == 1
