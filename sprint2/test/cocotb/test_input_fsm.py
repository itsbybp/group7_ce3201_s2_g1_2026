import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


# State values
STATE_0 = 0b00
STATE_1 = 0b01
STATE_2 = 0b10
STATE_3 = 0b11


async def reset_dut(dut):

    dut.reset.value = 0
    dut.nibble_input.value = 0
    dut.step.value = 0

    # Reset is asynchronous
    # Wait 1 ns for propagation.
    await Timer(1, units="ns")

    assert dut.current_state.value == STATE_3
    assert dut.out.value == 0

    dut.reset.value = 1

    await Timer(1, units="ns")


@cocotb.test()
async def test_reset(dut):

    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    assert dut.current_state.value == STATE_3
    assert dut.out.value == 0


@cocotb.test()
async def test_single_nibble(dut):

    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # First nibble is saved to the LSB registers.
    dut.nibble_input.value = 0xA
    dut.step.value = 1

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0x000A
    assert dut.current_state.value == STATE_2

# Test a full word can be stored. 
@cocotb.test()
async def test_four_nibble_assembly(dut):

    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    dut.step.value = 1

    # First nibble is an A
    dut.nibble_input.value = 0xA

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0x000A # This is the concatenation of the four nibbles, so the A is at the LSB here.
    assert dut.current_state.value == STATE_2

    # Second nibble is a B
    dut.nibble_input.value = 0xB

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0x00BA
    assert dut.current_state.value == STATE_1

    # Third nibble is  a C
    dut.nibble_input.value = 0xC

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0x0CBA
    assert dut.current_state.value == STATE_0

    # Fourth nibble is a D
    dut.nibble_input.value = 0xD

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0xDCBA
    assert dut.current_state.value == STATE_0

# Test that the FSM stops when disabled.
@cocotb.test()
async def test_step_disabled(dut):

    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    dut.nibble_input.value = 0xA
    dut.step.value = 0

    # Several clock cycles should have no effect.
    for _ in range(3):
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")

        assert dut.out.value == 0
        assert dut.current_state.value == STATE_3

# Start and stop the step input.
@cocotb.test()
async def test_step_controls_one_nibble_per_cycle(dut):

    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    dut.nibble_input.value = 0x1
    dut.step.value = 0

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0
    assert dut.current_state.value == STATE_3

    dut.step.value = 1

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0x0001
    assert dut.current_state.value == STATE_2

    dut.step.value = 0
    dut.nibble_input.value = 0x2

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0x0001  # The word was not added a new nibble (hex2)
    assert dut.current_state.value == STATE_2


@cocotb.test()
async def test_does_not_accept_input_after_finished(dut):

    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    dut.step.value = 1

    # Enter the word 0x1234. 4 is the LS nibble and 1 is the MS nibble.
    for nibble in [0x4, 0x3, 0x2, 0x1]:
        dut.nibble_input.value = nibble

        await RisingEdge(dut.clk)
        await Timer(1, units="ns")

    assert dut.out.value == 0x1234
    assert dut.current_state.value == STATE_0

    # Try to enter another nibble.
    dut.nibble_input.value = 0xF

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0x1234
    assert dut.current_state.value == STATE_0


@cocotb.test()
async def test_async_reset(dut):

    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Enter any value (A) the FSM.
    dut.step.value = 1
    dut.nibble_input.value = 0xA

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.out.value == 0x000A
    assert dut.current_state.value == STATE_2

    # The current time is 1 ns after a positive edge.
    dut.reset.value = 0

    await Timer(1, units="ns")

    # The current time is 2 ns after a positive edge, so it's still 8 ns for the negedge and 18 for the next posedge.
    assert dut.out.value == 0
    assert dut.current_state.value == STATE_3

    # Release reset.
    dut.reset.value = 1

    await Timer(1, units="ns")

    assert dut.out.value == 0
    assert dut.current_state.value == STATE_3