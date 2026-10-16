import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset_at_start(dut):
    dut.reset_n.value = 0
    await RisingEdge(dut.clk)
    dut.reset_n.value = 1
    await RisingEdge(dut.clk)

async def set_defaults(dut):
    await Timer(1, unit="ns")
    dut.clear.value = 0
    dut.increase.value = 0
    dut.timer_limit.value = 0
    await Timer(1, unit="ns")


# DUT signals
# module counter
# (
#     input  logic clk,
#     input  logic reset_n,

#     input logic clear,
#     input logic increase,
#     input logic [31:0] timer_limit,
#     output logic timeout
# );
    # logic [31:0] count;



@cocotb.test()
async def test_use_case_and_clear(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)
    await set_defaults(dut)
    current_test_timer_limit = 123
    dut.timer_limit.value = current_test_timer_limit
    await RisingEdge(dut.clk)

    # Assert count up to timer_limit
    await Timer(1, unit="ns")
    dut.increase.value = 1
    for i in range(current_test_timer_limit):
        assert dut.timeout.value == 0, \
            f"Esperado timeout=0, obtenido {hex(dut.timeout.value)}"
        await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.timeout.value == 1, \
        f"Esperado timeout=1, obtenido {hex(dut.timeout.value)}"

    # Assert timeout signal stays up
    for i in range(current_test_timer_limit):
        await RisingEdge(dut.clk)
        assert dut.timeout.value == 1, \
            f"Esperado timeout=1, obtenido {hex(dut.timeout.value)}"
    await RisingEdge(dut.clk)



    # Restart the test with soft reset (clear).
    dut.increase.value = 0
    dut.clear.value = 1
    
    await RisingEdge(dut.clk)
    current_test_timer_limit = 321
    dut.timer_limit.value = current_test_timer_limit
    await RisingEdge(dut.clk)

    # Assert count up to timer_limit
    await Timer(1, unit="ns")
    dut.increase.value = 1
    dut.clear.value = 0
    for i in range(current_test_timer_limit):
        assert dut.timeout.value == 0, \
            f"Esperado timeout=0, obtenido {hex(dut.timeout.value)}"
        await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


    assert dut.timeout.value == 1, \
        f"Esperado timeout=1, obtenido {hex(dut.timeout.value)}"

    # Assert timout signal stays up
    for i in range(current_test_timer_limit):
        await RisingEdge(dut.clk)
        assert dut.timeout.value == 1, \
            f"Esperado timeout=1, obtenido {hex(dut.timeout.value)}"
    


@cocotb.test()
async def test_lower_timer_limit_mid_count(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_at_start(dut)
    await RisingEdge(dut.clk)
    await set_defaults(dut)
    current_test_timer_limit = 333
    dut.timer_limit.value = current_test_timer_limit
    await RisingEdge(dut.clk)

    # Count up to half the timer_limit
    await Timer(1, unit="ns")
    dut.increase.value = 1
    for i in range(current_test_timer_limit//2):
        assert dut.timeout.value == 0, \
            f"Esperado timeout=0, obtenido {hex(dut.timeout.value)}"
        await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
        
    assert dut.timeout.value == 0, \
        f"Esperado timeout=1, obtenido {hex(dut.timeout.value)}"

    await Timer(1, unit="ns")
    dut.timer_limit.value = 10
    await RisingEdge(dut.clk)
    assert dut.timeout.value == 1, \
            f"Esperado timeout=1, obtenido {hex(dut.timeout.value)}"
    