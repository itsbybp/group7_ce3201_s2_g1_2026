import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

async def reset_at_start(dut):
    dut.reset_n.value = 0
    await RisingEdge(dut.clk)
    dut.reset_n.value = 1
    await RisingEdge(dut.clk)
    

@cocotb.test()
async def test_escritura_registro_x1(dut):
    """Escribe en registro x1 (dirección 0x20004)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    dut.mmio_address.value = 0x20004  # x1
    dut.write_data.value = 0x12345678
    dut.write_en.value = 1
    await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    
    assert dut.selected_register.value == 0x12345678, \
        f"Esperado x1=0x12345678, obtenido {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_x0_siempre_cero(dut):
    """Verifica que x0 siempre retorna cero (hardcoded)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    dut.mmio_address.value = 0x20000  # x0
    dut.write_data.value = 0xFFFFFFFF
    dut.write_en.value = 1
    await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)
    
    assert dut.selected_register.value == 0x00000000, \
        f"x0 debería ser 0, obtenido {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_escritura_multiples_registros(dut):
    """Escribe en x1-x5 y verifica"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    registros = [
        (0x20004, 0xAAAAAAAA),  # x1
        (0x20008, 0xBBBBBBBB),  # x2
        (0x2000C, 0xCCCCCCCC),  # x3
        (0x20010, 0xDDDDDDDD),  # x4
        (0x20014, 0xEEEEEEEE),  # x5
    ]
    
    for addr, data in registros:
        dut.mmio_address.value = addr
        dut.write_data.value = data
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    for addr, expected in registros:
        dut.mmio_address.value = addr
        await RisingEdge(dut.clk)
        
        assert dut.selected_register.value == expected, \
            f"Addr {hex(addr)}: esperado {hex(expected)}, obtenido {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_lectura_sin_escritura(dut):
    """Lee registro sin modificar (write_en=0)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    dut.mmio_address.value = 0x20004  # x1
    dut.write_data.value = 0xBABABABA # valor por escribir
    dut.write_en.value = 1
    await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    dut.write_data.value = 0x11111111 # valor que no debe ser escrito
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.mmio_address.value = 0x20004
    await RisingEdge(dut.clk)
    
    assert dut.selected_register.value == 0xBABABABA, \
        f"Valor cambió sin write_en: esperado 0xBABABABA, obtenido {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_reset_asincrono(dut):
    """Verifica reset asíncrono limpia todos los registros"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    # Escribe en todos los registros
    for i in range(1, 32):  # x1 a x31
        addr = 0x20000 + (i * 4)
        dut.mmio_address.value = addr
        dut.write_data.value = 0xFFFFFFFF
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    # Reset asíncrono
    dut.reset_n.value = 0
    await RisingEdge(dut.clk)
    dut.reset_n.value = 1
    await RisingEdge(dut.clk)
    
    # Verifica que se limpiaron
    for i in range(0, 32):
        addr = 0x20000 + (i * 4)
        dut.mmio_address.value = addr
        await RisingEdge(dut.clk)
        
        assert dut.selected_register.value == 0, \
            f"Registro x{i} no fue reseteado: {hex(dut.selected_register.value)}"

