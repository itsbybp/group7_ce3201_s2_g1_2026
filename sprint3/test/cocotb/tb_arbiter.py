import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_arbiter(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    # Reset
    dut.rst_n.value = 0
    dut.vjtag_valid.value = 0
    dut.fsm_valid.value = 0
    dut.subordinate_ready.value = 0
    dut.vjtag_addr.value = 0
    dut.vjtag_data.value = 0
    dut.fsm_addr.value = 0
    dut.fsm_data.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    # vJTAG gana cuando ambos solicitan al mismo tiempo
    dut.vjtag_valid.value = 1
    dut.fsm_valid.value = 1
    dut.vjtag_addr.value = 0x100
    dut.vjtag_data.value = 0xFF
    dut.fsm_addr.value = 0x200
    dut.fsm_data.value = 0xAA
    dut.subordinate_ready.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.mux_addr.value == 0x100, "vJTAG debe ganar arbitraje"
    assert dut.vjtag_ready.value == 1,  "vjtag_ready debe ser 1"
    assert dut.fsm_ready.value == 0,    "fsm_ready debe ser 0"

    # Bus se congela cuando subordinado no está listo
    dut.vjtag_valid.value = 1
    dut.fsm_valid.value = 0
    dut.subordinate_ready.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.vjtag_ready.value == 0,  "vjtag_ready debe ser 0 con backpressure"
    assert dut.mux_addr.value == 0x100, "addr debe mantenerse estable"