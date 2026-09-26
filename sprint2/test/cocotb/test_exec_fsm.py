import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Enum for the states.
IDLE = 0b11
WAIT_1 = 0b10
WRITE = 0b01
WAIT_2 = 0b00


async def reset_dut(dut):

    dut.reset.value = 0 # Reset happens here.
    dut.start_execute.value = 0
    dut.step.value = 0
    dut.stepping_mode.value = 0

    await Timer(1, unit="ns")

    assert dut.current_state.value == IDLE
    assert dut.write_enable.value == 0

    dut.reset.value = 1

    await Timer(1, unit="ns")


@cocotb.test()
async def test_reset(dut):

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    assert dut.current_state.value == IDLE
    assert dut.write_enable.value == 0


@cocotb.test()
async def test_normal_execution(dut):

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Start execution.
    dut.start_execute.value = 1

    # IDLE -> WAIT_1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WAIT_1
    assert dut.write_enable.value == 0

    # This signal is a pulse. This is manually handled here.
    dut.start_execute.value = 0

    # WAIT_1 -> WRITE
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WRITE
    assert dut.write_enable.value == 1

    # WRITE -> WAIT_2
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WAIT_2
    assert dut.write_enable.value == 0

    # complete the full cycle back to IDLE (2'b11)
    # WAIT_2 -> IDLE
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == IDLE
    assert dut.write_enable.value == 0


@cocotb.test()
async def test_write_enable_pulse(dut):
    
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    dut.start_execute.value = 1

    # IDLE -> WAIT_1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WAIT_1
    assert dut.write_enable.value == 0

    dut.start_execute.value = 0

    # WAIT_1 -> WRITE
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WRITE
    assert dut.write_enable.value == 1

    # WRITE -> WAIT_2
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WAIT_2
    assert dut.write_enable.value == 0


@cocotb.test()
async def test_stepping_mode_pauses(dut):

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    dut.stepping_mode.value = 1
    dut.start_execute.value = 1

    # IDLE -> WAIT_1
    dut.step.value = 1

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WAIT_1

    # step = 0.
    dut.step.value = 0
    dut.start_execute.value = 0

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WAIT_1
    assert dut.write_enable.value == 0

    # Still paused.
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WAIT_1
    assert dut.write_enable.value == 0

    # Advance one step.
    dut.step.value = 1

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WRITE
    assert dut.write_enable.value == 1


# Verify that write enable lasts for a single cycle.
@cocotb.test()
async def test_write_state_holds_in_stepping_mode(dut):


    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    dut.stepping_mode.value = 1
    dut.step.value = 1
    dut.start_execute.value = 1

    # IDLE -> WAIT_1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    dut.start_execute.value = 0

    # WAIT_1 -> WRITE
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WRITE
    assert dut.write_enable.value == 1

    # Stop stepping.
    dut.step.value = 0

    # WRITE should remain WRITE.
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WRITE

    # write_enable must now be LOW.
    assert dut.write_enable.value == 0

    # Remain in WRITE for another cycle.
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WRITE
    assert dut.write_enable.value == 0

    # Advance.
    dut.step.value = 1

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WAIT_2
    assert dut.write_enable.value == 0

# Verify async reset.
@cocotb.test()
async def test_async_reset(dut):

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    dut.stepping_mode.value = 0
    dut.start_execute.value = 1

    # WAIT_1.
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert dut.current_state.value == WAIT_1

    # Assert reset between clock edges.
    dut.reset.value = 0

    await Timer(1, unit="ns")

    # Immediate assertion.
    assert dut.current_state.value == IDLE
    assert dut.write_enable.value == 0

    # Release reset.
    dut.reset.value = 1

    await Timer(1, unit="ns")

    assert dut.current_state.value == IDLE