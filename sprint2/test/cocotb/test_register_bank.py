import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


async def start_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())


async def reset_dut(dut):
    dut.reset_n.value = 0
    dut.rd.value = 0
    dut.rs1.value = 0
    dut.rs2.value = 0
    dut.write_en.value = 0
    dut.write_data.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.reset_n.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_reset_values(dut):
    await start_clock(dut)
    await reset_dut(dut)

    dut.rs1.value = 1
    dut.rs2.value = 2
    await RisingEdge(dut.clk)
    assert dut.rs1_data.value == 0
    assert dut.rs2_data.value == 0


@cocotb.test()
async def test_x0_always_zero(dut):
    await start_clock(dut)
    await reset_dut(dut)

    dut.rd.value = 0
    dut.write_en.value = 1
    dut.write_data.value = 0xBEEF
    await RisingEdge(dut.clk)
    dut.write_en.value = 0

    dut.rs1.value = 0
    await RisingEdge(dut.clk)
    assert dut.rs1_data.value == 0


@cocotb.test()
async def test_write_x1_and_read_rs1(dut):
    await start_clock(dut)
    await reset_dut(dut)

    dut.rd.value = 1
    dut.write_en.value = 1
    dut.write_data.value = 0x1234
    await RisingEdge(dut.clk)
    dut.write_en.value = 0

    dut.rs1.value = 1
    await RisingEdge(dut.clk)
    assert dut.rs1_data.value == 0x1234


@cocotb.test()
async def test_write_disabled_does_not_write(dut):
    await start_clock(dut)
    await reset_dut(dut)

    dut.rd.value = 2
    dut.write_en.value = 0
    dut.write_data.value = 0x5555
    await RisingEdge(dut.clk)

    dut.rs1.value = 2
    await RisingEdge(dut.clk)
    assert dut.rs1_data.value == 0


@cocotb.test()
async def test_individual_write_enables(dut):
    await start_clock(dut)
    await reset_dut(dut)

    dut.rd.value = 2
    dut.write_en.value = 1
    dut.write_data.value = 0xAAAA
    await RisingEdge(dut.clk)

    dut.rd.value = 3
    dut.write_data.value = 0xBBBB
    await RisingEdge(dut.clk)
    dut.write_en.value = 0

    dut.rs1.value = 2
    dut.rs2.value = 3
    await RisingEdge(dut.clk)
    assert dut.rs1_data.value == 0xAAAA
    assert dut.rs2_data.value == 0xBBBB


@cocotb.test()
async def test_reset_clears_registers(dut):
    await start_clock(dut)
    await reset_dut(dut)

    dut.rd.value = 1
    dut.write_en.value = 1
    dut.write_data.value = 0x4242
    await RisingEdge(dut.clk)
    dut.write_en.value = 0

    dut.reset_n.value = 0
    await RisingEdge(dut.clk)
    dut.reset_n.value = 1
    await RisingEdge(dut.clk)

    dut.rs1.value = 1
    await RisingEdge(dut.clk)
    assert dut.rs1_data.value == 0
