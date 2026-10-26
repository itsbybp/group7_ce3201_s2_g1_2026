import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_escritura_lectura_puerto_a(dut):
    """Escribe y lee por puerto A (mem_in)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await RisingEdge(dut.clk)

    dut.we_a.value = 1
    dut.re_a.value = 0
    dut.addr_a.value = 0x0005
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
    """Escribe y lee por puerto B (mem_out)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await RisingEdge(dut.clk)

    dut.we_b.value = 1
    dut.re_b.value = 0
    dut.addr_b.value = 0x3FFF  # ultima direccion valida (14 bits: 0-16383)
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
async def test_memorias_independientes(dut):
    """mem_in (puerto A) y mem_out (puerto B) son memorias fisicas distintas:
    escribir en la misma direccion por ambos puertos con datos distintos
    no debe producir interferencia entre ellas."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await RisingEdge(dut.clk)

    dut.we_a.value = 1
    dut.re_a.value = 0
    dut.addr_a.value = 10
    dut.data_in_a.value = 0xCAFECAFE
    dut.we_b.value = 1
    dut.re_b.value = 0
    dut.addr_b.value = 10
    dut.data_in_b.value = 0x11111111
    await RisingEdge(dut.clk)  # ambos puertos escriben, misma direccion, memorias distintas

    dut.we_a.value = 0
    dut.we_b.value = 0
    dut.re_a.value = 1
    dut.re_b.value = 1
    await RisingEdge(dut.clk)  # captura lectura
    await RisingEdge(dut.clk)  # datos estables

    assert dut.data_out_a.value == 0xCAFECAFE, \
        f"mem_in[10]: esperado 0xCAFECAFE, obtenido {dut.data_out_a.value}"
    assert dut.data_out_b.value == 0x11111111, \
        f"mem_out[10]: esperado 0x11111111, obtenido {dut.data_out_b.value}"