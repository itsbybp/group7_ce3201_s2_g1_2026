import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

async def reset_at_start(dut):
    dut.reset_n.value = 0
    await RisingEdge(dut.clk)
    dut.reset_n.value = 1
    await RisingEdge(dut.clk)
    
@cocotb.test()
async def test_escritura_ctrl(dut):
    """Escribe en registro CTRL (0x40000)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    dut.mmio_address.value = 0x40000
    dut.write_data.value = 0x00000003  # start=1, soft_reset=1
    dut.write_en.value = 1
    await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.mmio_address.value = 0x40000
    await RisingEdge(dut.clk)
    
    assert dut.selected_register.value == 0x00000003, \
        f"Esperado CTRL=0x3, obtenido {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_escritura_status(dut):
    """Escribe en registro STATUS (0x40004)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    dut.mmio_address.value = 0x40004
    dut.write_data.value = 0x00000005  # busy=1, done=1
    dut.write_en.value = 1
    await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.mmio_address.value = 0x40004
    await RisingEdge(dut.clk)
    
    assert dut.selected_register.value == 0x00000005, \
        f"Esperado STATUS=0x5, obtenido {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_escritura_timer_limit(dut):
    """Escribe en registro TIMER_LIMIT (0x40008)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    dut.mmio_address.value = 0x40008
    dut.write_data.value = 0x000F4240  # 1 millón de ciclos
    dut.write_en.value = 1
    await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.mmio_address.value = 0x40008
    await RisingEdge(dut.clk)
    
    assert dut.selected_register.value == 0x000F4240, \
        f"Esperado TIMER_LIMIT=0xF4240, obtenido {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_escritura_threshold(dut):
    """Escribe en registro THRESHOLD (0x4000C)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    dut.mmio_address.value = 0x4000C
    dut.write_data.value = 0x00000080  # TH = 128
    dut.write_en.value = 1
    await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.mmio_address.value = 0x4000C
    await RisingEdge(dut.clk)
    
    assert dut.selected_register.value == 0x00000080, \
        f"Esperado THRESHOLD=0x80, obtenido {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_lectura_secuencial(dut):
    """Lee todos los registros secuencialmente"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    # Escribe valores distintos en cada registro
    registros = [
        (0x40000, 0xAAAAAAAA),  # CTRL
        (0x40004, 0xBBBBBBBB),  # STATUS
        (0x40008, 0xCCCCCCCC),  # TIMER_LIMIT
        (0x4000C, 0xDDDDDDDD),  # THRESHOLD
    ]
    
    for addr, data in registros:
        dut.mmio_address.value = addr
        dut.write_data.value = data
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    # Lee todos los registros
    for addr, expected in registros:
        dut.mmio_address.value = addr
        await RisingEdge(dut.clk)
        
        assert dut.selected_register.value == expected, \
            f"Addr {hex(addr)}: esperado {hex(expected)}, obtenido {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_reset(dut):
    """Verifica reset asíncrono"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    # Escribe datos en todos los registros
    for addr in [0x40000, 0x40004, 0x40008, 0x4000C]:
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
    
    # Verifica que todos los registros se limpiaron
    for addr in [0x40000, 0x40004, 0x40008, 0x4000C]:
        dut.mmio_address.value = addr
        await RisingEdge(dut.clk)
        
        assert dut.selected_register.value == 0, \
            f"Addr {hex(addr)} no fue reseteado: {hex(dut.selected_register.value)}"

@cocotb.test()
async def test_sin_escritura(dut):
    """Verifica lectura sin afectar datos (write_en=0)"""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)

    # Precarga un valor
    dut.mmio_address.value = 0x40000
    dut.write_data.value = 0x12345678
    dut.write_en.value = 1
    await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    dut.write_data.value = 0xDEADBEEF  # intenta escribir pero write_en=0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.mmio_address.value = 0x40000
    await RisingEdge(dut.clk)
    
    assert dut.selected_register.value == 0x12345678, \
        f"Valor cambio sin write_en: esperado 0x12345678, obtenido {hex(dut.selected_register.value)}"