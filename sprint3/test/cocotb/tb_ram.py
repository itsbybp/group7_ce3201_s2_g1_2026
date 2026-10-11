import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_escritura_lectura_puerto_a(dut):
    """Escribe y lee por puerto A"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await RisingEdge(dut.clk)

    dut.we_a.value = 1
    dut.re_a.value = 0
    dut.addr_a.value = 0x00005
    dut.data_in_a.value = 0xDEADBEEF
    dut.we_b.value = 0
    dut.re_b.value = 0
    dut.addr_b.value = 0
    dut.data_in_b.value = 0
    await RisingEdge(dut.clk)  # escribe

    dut.we_a.value = 0
    dut.re_a.value = 1
    await RisingEdge(dut.clk)  # captura lectura
    await RisingEdge(dut.clk)  # data_out_a estable

    assert dut.data_out_a.value == 0xDEADBEEF, \
        f"Esperado 0xDEADBEEF, obtenido {dut.data_out_a.value}"

@cocotb.test()
async def test_escritura_lectura_puerto_b(dut):
    """Escribe y lee por puerto B"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await RisingEdge(dut.clk)

    dut.we_b.value = 1
    dut.re_b.value = 0
    dut.addr_b.value = 0x4000
    dut.data_in_b.value = 0x000000FF
    dut.we_a.value = 0
    dut.re_a.value = 0
    dut.addr_a.value = 0
    dut.data_in_a.value = 0
    await RisingEdge(dut.clk)  # escribe

    dut.we_b.value = 0
    dut.re_b.value = 1
    await RisingEdge(dut.clk)  # captura lectura
    await RisingEdge(dut.clk)  # data_out_b estable

    assert dut.data_out_b.value == 0x000000FF, \
        f"Esperado 0x000000FF, obtenido {dut.data_out_b.value}"

@cocotb.test()
async def test_puertos_independientes(dut):
    """A escribe y B lee al mismo tiempo en direcciones distintas"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await RisingEdge(dut.clk)

    dut.we_a.value = 1
    dut.re_a.value = 0
    dut.addr_a.value = 10
    dut.data_in_a.value = 0xCAFECAFE
    dut.we_b.value = 0
    dut.re_b.value = 0
    dut.addr_b.value = 0
    dut.data_in_b.value = 0
    await RisingEdge(dut.clk)  # precarga addr 10

    dut.we_a.value = 1
    dut.addr_a.value = 20
    dut.data_in_a.value = 0x12345678
    dut.re_b.value = 1
    dut.addr_b.value = 10
    await RisingEdge(dut.clk)  # A escribe 20, B captura lectura de 10
    await RisingEdge(dut.clk)  # data_out_b estable

    dut.we_a.value = 0
    dut.re_b.value = 0

    assert dut.data_out_b.value == 0xCAFECAFE, \
        f"Esperado 0xCAFECAFE, obtenido {dut.data_out_b.value}"