import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

async def transaccion(dut, addr, ram_rdata=0, rb_rdata=0, cr_rdata=0):
    dut.addr.value      = addr
    dut.ram_rdata.value = ram_rdata
    dut.rb_rdata.value  = rb_rdata
    dut.cr_rdata.value  = cr_rdata
    dut.valid.value     = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.valid.value = 0

@cocotb.test()
async def test_ram(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 0
    dut.valid.value = 0
    dut.addr.value = 0
    dut.ram_rdata.value = 0
    dut.rb_rdata.value = 0
    dut.cr_rdata.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    await transaccion(dut, 0x00000000, ram_rdata=0xDEADBEEF)
    assert dut.rdata.value == 0xDEADBEEF, f"esperado 0xDEADBEEF, obtenido {dut.rdata.value}"

@cocotb.test()
async def test_ram_limite(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 1
    dut.valid.value = 0
    dut.addr.value = 0
    dut.ram_rdata.value = 0
    dut.rb_rdata.value = 0
    dut.cr_rdata.value = 0
    await RisingEdge(dut.clk)

    await transaccion(dut, 0x0001FFFF, ram_rdata=0xCAFECAFE)
    assert dut.rdata.value == 0xCAFECAFE, f"esperado 0xCAFECAFE, obtenido {dut.rdata.value}"

@cocotb.test()
async def test_reg_bank(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 1
    dut.valid.value = 0
    dut.addr.value = 0
    dut.ram_rdata.value = 0
    dut.rb_rdata.value = 0
    dut.cr_rdata.value = 0
    await RisingEdge(dut.clk)

    await transaccion(dut, 0x00020004, rb_rdata=0x12345678)
    assert dut.rdata.value == 0x12345678, f"esperado 0x12345678, obtenido {dut.rdata.value}"

@cocotb.test()
async def test_ledr(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 1
    dut.valid.value = 0
    dut.addr.value = 0
    dut.ram_rdata.value = 0
    dut.rb_rdata.value = 0
    dut.cr_rdata.value = 0
    await RisingEdge(dut.clk)

    dut.addr.value  = 0x00030000
    dut.valid.value = 1
    await RisingEdge(dut.clk)
    assert dut.cs_ledr.value == 1, "cs_ledr esperado 1"
    assert dut.cs_hex.value  == 0, "cs_hex esperado 0"
    dut.valid.value = 0

@cocotb.test()
async def test_hex(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 1
    dut.valid.value = 0
    dut.addr.value = 0
    dut.ram_rdata.value = 0
    dut.rb_rdata.value = 0
    dut.cr_rdata.value = 0
    await RisingEdge(dut.clk)

    dut.addr.value  = 0x00030004
    dut.valid.value = 1
    await RisingEdge(dut.clk)
    assert dut.cs_hex.value  == 1, "cs_hex esperado 1"
    assert dut.cs_ledr.value == 0, "cs_ledr esperado 0"
    dut.valid.value = 0

@cocotb.test()
async def test_ctrl_regs(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 1
    dut.valid.value = 0
    dut.addr.value = 0
    dut.ram_rdata.value = 0
    dut.rb_rdata.value = 0
    dut.cr_rdata.value = 0
    await RisingEdge(dut.clk)

    await transaccion(dut, 0x00040000, cr_rdata=0xABCD1234)
    assert dut.rdata.value == 0xABCD1234, f"esperado 0xABCD1234, obtenido {dut.rdata.value}"

@cocotb.test()
async def test_raz(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 1
    dut.valid.value = 0
    dut.addr.value = 0
    dut.ram_rdata.value = 0
    dut.rb_rdata.value = 0
    dut.cr_rdata.value = 0
    await RisingEdge(dut.clk)

    await transaccion(dut, 0x00050000, ram_rdata=0xFFFFFFFF, rb_rdata=0xFFFFFFFF, cr_rdata=0xFFFFFFFF)
    assert dut.rdata.value == 0x0, f"RAZ: esperado 0x0, obtenido {dut.rdata.value}"

@cocotb.test()
async def test_wi(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 1
    dut.valid.value = 0
    dut.addr.value = 0
    dut.ram_rdata.value = 0
    dut.rb_rdata.value = 0
    dut.cr_rdata.value = 0
    await RisingEdge(dut.clk)

    dut.addr.value  = 0x00050000
    dut.valid.value = 1
    await RisingEdge(dut.clk)
    assert dut.cs_ram.value  == 0, "WI: cs_ram debe ser 0"
    assert dut.cs_rb.value   == 0, "WI: cs_rb debe ser 0"
    assert dut.cs_ledr.value == 0, "WI: cs_ledr debe ser 0"
    assert dut.cs_hex.value  == 0, "WI: cs_hex debe ser 0"
    assert dut.cs_cr.value   == 0, "WI: cs_cr debe ser 0"
    assert dut.ready.value   == 1, "WI: ready debe ser 1"
    dut.valid.value = 0