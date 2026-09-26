import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# 7-segment display encodings (active low, abcdefg)
# SEG = {
#     0: 0b1000000,
#     1: 0b1111001,
#     2: 0b0100100,
#     3: 0b0110000,
#     4: 0b0011001,
#     5: 0b0010010,
#     6: 0b0000010,
#     7: 0b1111000,
#     8: 0b0000000,
#     9: 0b0011000
# }
SEG = {
    0: 0b0000001,
    1: 0b1001111,
    2: 0b0010010,
    3: 0b0000110,
    4: 0b1001100,
    5: 0b0100100,
    6: 0b0100000,
    7: 0b0001111,
    8: 0b0000000,
    9: 0b0001100
}
OFF = 0b1111111
MINUS = 0b0111111


# From a number, create a list of its first five digits.
def get_as_5_digits(num):
    res = [num%10]
    for i in range(4):
        num //= 10
        res += [num%10]
    return res


def value_is_negative(value):
    return (value & (1 << 15)) > 0
def absolute_value_16b(value):
    if value_is_negative(value):
        return 2**16 - value
    return value

# Assert number in the BCD displays for modes 00 and 11 that display 16 bit numbers.
def assert_displayed_value(dut, value):
    abs_value = absolute_value_16b(value)
    digits = get_as_5_digits(abs_value)
    assert dut.HEX0.value == SEG[digits[0]]
    assert dut.HEX1.value == SEG[digits[1]]
    assert dut.HEX2.value == SEG[digits[2]]
    assert dut.HEX3.value == SEG[digits[3]]
    assert dut.HEX4.value == SEG[digits[4]]
    if (value_is_negative(value)):
        assert dut.HEX5.value == MINUS
    else:
        assert dut.HEX5.value == OFF


def apply_defaults(dut):
    dut.SW.value = int(dut.SW.value) & 0b1100000000 # All data and menu switches off. Leave the aux switches as is.
    dut.KEY.value = 0b1111  # No buttons pressed.

async def wait_x_cycles(dut, x):
    for i in range(x):
        await RisingEdge(dut.CLOCK_50)
async def wait_past_rising_edge(dut):
    await RisingEdge(dut.CLOCK_50)
    await Timer(1, unit="ns")

def set_config_aux(dut, sw9_8):
    if (sw9_8 > 0b11):
        cocotb.log.info(f"At set_SW input out of range (0b11). sw9_8 = {sw9_8}")
    dut.SW.value = (int(dut.SW.value) & 0b0011111111) | (sw9_8 << 8)

def set_menu(dut, sw7_6):
    if (sw7_6 > 0b11):
        cocotb.log.info(f"At set_SW input out of range (0b11). sw7_6 = {sw7_6}")
    dut.SW.value = (int(dut.SW.value) & 0b1100111111) | (sw7_6 << 6)

def set_registers(dut, sw5_0):
    if (sw5_0 > 0b111111):
        cocotb.log.info(f"At set_SW input out of range (0b111111). sw5_0 = {sw5_0}")
    dut.SW.value = (int(dut.SW.value) & 0b1111000000) | sw5_0

def set_alu_control_or_nibble(dut, sw3_0):
    if (sw3_0 > 0b1111):
        cocotb.log.info(f"At set_SW input out of range (0b1111). sw3_0 = {sw3_0}")
    dut.SW.value = (int(dut.SW.value) & 0b1111110000) | sw3_0


def set_key_reset(dut, key0):
    if (key0 > 1):
        cocotb.log.info(f"At set_KEY input is not boolean. key0 = {key0}")
    dut.KEY.value = (int(dut.KEY.value) & 0b1110) | key0
async def set_key_reset_and_wait(dut, key0):
    set_key_reset(dut, key0)
    await wait_x_cycles(dut, 3)


def set_key_step(dut, key1):
    if (key1 > 1):
        cocotb.log.info(f"At set_KEY input is not boolean. key1 = {key1}")
    dut.KEY.value = (int(dut.KEY.value) & 0b1101) | (key1 << 1)
async def set_key_step_and_wait(dut, key1):
    set_key_step(dut, key1)
    await wait_x_cycles(dut, 3)
async def set_key_step_button_tap(dut):
    await set_key_step_and_wait(dut, 0)
    await set_key_step_and_wait(dut, 1)
    await Timer(1, unit="ns")


def set_key_load(dut, key2):
    if (key2 > 1):
        cocotb.log.info(f"At set_KEY input is not boolean. key2 = {key2}")
    dut.KEY.value = (int(dut.KEY.value) & 0b1011) | (key2 << 2)
async def set_key_load_and_wait(dut, key2):
    set_key_load(dut, key2)
    await wait_x_cycles(dut, 3)
async def set_key_load_button_tap(dut):
    await set_key_load_and_wait(dut, 0)
    await set_key_load_and_wait(dut, 1)
    await Timer(1, unit="ns")



def set_key_stepping_mode(dut, key3):
    if (key3 > 1):
        cocotb.log.info(f"At set_KEY input is not boolean. key3 = {key3}")
    dut.KEY.value = (int(dut.KEY.value) & 0b0111) | (key3 << 3)
async def set_key_stepping_mode_and_wait(dut, key3):
    set_key_stepping_mode(dut, key3)
    await wait_x_cycles(dut, 3)
async def set_key_stepping_mode_button_tap(dut):
    await set_key_stepping_mode_and_wait(dut, 0)
    await set_key_stepping_mode_and_wait(dut, 1)
    await Timer(1, unit="ns")



# Simulate a test scenario while asserting all outputs.
# Simulate continuously to retain the data inside reg file.
@cocotb.test()
async def test_use_case(dut):

    cocotb.start_soon(
        Clock(dut.CLOCK_50, 20, unit="ns").start()
    )

    # Initialize SW/KEY to a defined value before any apply_defaults()
    # reads them back with int(), since Icarus starts nets as X.
    # A Timer is needed so the write propagates before it's read back.
    dut.SW.value = 0
    dut.KEY.value = 0b1111
    await Timer(1, unit="ns")

    # First Test

    apply_defaults(dut) # This sets the local menu to "enter immediate" and the output of input_fsm to 16'b0
    await set_key_reset_and_wait(dut, 0)

    assert dut.LEDR.value == 0b0001000000   # All off except the zero flag.

    assert_displayed_value(dut, 0)  # Assert the immediate shown is 0.

    await set_key_reset_and_wait(dut, 1)

    # Menu 00 Enter immediate
    # Enter A
    apply_defaults(dut)
    set_alu_control_or_nibble(dut, 0xA)
    await wait_past_rising_edge(dut)
    assert_displayed_value(dut, 0x0)

    await set_key_load_button_tap(dut) # 0 is a button press. Send A
    assert_displayed_value(dut, 0xA)
    await wait_past_rising_edge(dut)

    # Enter B
    set_alu_control_or_nibble(dut, 0xB)
    await wait_x_cycles(dut, 3)
    assert_displayed_value(dut, 0xA)

    await set_key_load_button_tap(dut) # Send B
    assert_displayed_value(dut, 0xBA)
    await wait_past_rising_edge(dut)

    # Enter C
    set_alu_control_or_nibble(dut, 0xC)
    await wait_x_cycles(dut, 3)
    assert_displayed_value(dut, 0xBA)

    await set_key_load_button_tap(dut) # Send C
    assert_displayed_value(dut, 0xCBA)
    await wait_past_rising_edge(dut)

    # Enter D
    set_alu_control_or_nibble(dut, 0xD)
    await wait_x_cycles(dut, 3)
    assert_displayed_value(dut, 0xCBA)

    await set_key_load_button_tap(dut) # Send D
    assert_displayed_value(dut, 0xDCBA)

    # Try to enter a fifth value.
    set_alu_control_or_nibble(dut, 0xF)
    await wait_x_cycles(dut, 3)
    assert_displayed_value(dut, 0xDCBA)

    await set_key_load_button_tap(dut) # Try to send F
    assert_displayed_value(dut, 0xDCBA)



    # Menu 01 Enter destination and source registers
    await wait_past_rising_edge(dut)
    await wait_past_rising_edge(dut)

    set_registers(dut, 0b100100) # rd = 10; rs1 = 01; rs2 = 00
    await Timer(1, unit="ns")
    set_menu(dut, 0b01)
    await Timer(1, unit="ns")
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)
    await Timer(1, unit="ns")
    assert dut.HEX0.value == SEG[2]
    assert dut.HEX1.value == SEG[1]
    assert dut.HEX2.value == SEG[0]



    # Menu 10 Enter ALU opcode
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_alu_control_or_nibble(dut, 0b0001) # opcode = 0001, i.e. SUB
    await Timer(1, unit="ns")
    set_menu(dut, 0b10)
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)

    # Chose operands
    set_config_aux(dut, 0b00)   # 00 sets the operands a and b to rs1 and the immediate, respectively.
    await wait_past_rising_edge(dut)

    # Check ALU Flags
    # The current operation is rs1 - immediate
    # == 16'b0 - 16'hDCBA
    # == 16'h2346
    assert dut.LEDR.value[4] == 0   # overflow
    assert dut.LEDR.value[5] == 0   # carry
    assert dut.LEDR.value[6] == 0   # zero
    assert dut.LEDR.value[7] == 0   # negative



    # Menu 11 Start execution. Use automatic stepping.
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_menu(dut, 0b11)
    await Timer(1, unit="ns")
    await wait_past_rising_edge(dut)
    assert_displayed_value(dut, 0x2346) # Assert display of ALU result
    await Timer(1, unit="ns")
    assert dut.LEDR.value[9] == 0   # stepping_mode_is_on
    assert dut.LEDR.value[3:2] == 0   # exec_FSM_show_state
    await set_key_load_and_wait(dut, 0)    # Launch exec_fsm

    assert dut.LEDR.value[3:2] == 0b0
    await wait_past_rising_edge(dut)
    assert dut.LEDR.value[3:2] == 0b1
    await wait_past_rising_edge(dut)
    assert dut.LEDR.value[3:2] == 0b10
    await wait_past_rising_edge(dut)
    assert dut.LEDR.value[3:2] == 0b11
    await wait_past_rising_edge(dut)
    assert dut.LEDR.value[3:2] == 0b0
    await wait_past_rising_edge(dut)

    # After using the execute fsm, alu result should have been stored to reg10

    # Second Test
    # Use manual stepping mode.
    # Assert alu result using reg10 as an operand.
    # This test will also write to a source register.
    # For this, execute reg10 = reg10 + reg10
    # == 0x2346 + 0x2346
    # == 0x468C
    # Skip menu 00 because no immediate will be used.

    # Menu 01 Enter destination and source registers
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_registers(dut, 0b101010) # rd = 10; rs1 = 10; rs2 = 10
    await Timer(1, unit="ns")
    set_menu(dut, 0b01)
    await Timer(1, unit="ns")
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)

    # Menu 10 Enter ALU opcode
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_alu_control_or_nibble(dut, 0b0000) # opcode = 0000, i.e. ADD
    await Timer(1, unit="ns")
    set_menu(dut, 0b10)
    await Timer(1, unit="ns")
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)

    set_config_aux(dut, 0b01)   # 01 sets the operands a and b to rs1 and rs2, respectively.
    await wait_past_rising_edge(dut)

    # Menu 11 Start execution. Use manual stepping.
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_menu(dut, 0b11)
    await set_key_stepping_mode_button_tap(dut)
    assert_displayed_value(dut, 0x468C) # Assert display of ALU result with both operands as registers.
    assert dut.LEDR.value[9] == 1   # stepping_mode_is_on
    assert dut.LEDR.value[3:2] == 0   # exec_FSM_show_state
    await set_key_load_button_tap(dut)
    await wait_x_cycles(dut, 10)    # Wait for a long time to see if the fsm advances by it's own

    assert dut.LEDR.value[3:2] == 0b0
    await set_key_step_button_tap(dut)
    await wait_x_cycles(dut, 10)

    assert dut.LEDR.value[3:2] == 0b1
    await set_key_step_button_tap(dut)
    assert dut.LEDR.value[3:2] == 0b10
    await set_key_step_button_tap(dut)
    assert dut.LEDR.value[3:2] == 0b11
    await set_key_step_button_tap(dut)
    assert dut.LEDR.value[3:2] == 0b0



    # Third Test
    # Change the immediate during the cycle of exec_fsm using manual stepping mode.
    # For this, execute reg01 = reg10 >> 4
    # == 0x468C >> 4
    # == 0x0468

    apply_defaults(dut)
    await Timer(1, unit="ns")

    # Menu 00 Enter immediate
    # Enter 4
    set_alu_control_or_nibble(dut, 0x4)
    await Timer(1, unit="ns")
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)
    # Enter 0
    set_alu_control_or_nibble(dut, 0x0)
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)
    # Enter 0
    set_alu_control_or_nibble(dut, 0x0)
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)
    # Enter 0
    set_alu_control_or_nibble(dut, 0x0)
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)

    # Menu 01 Enter destination and source registers
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_registers(dut, 0b011000) # rd = 01; rs1 = 10; rs2 = 00
    await Timer(1, unit="ns")
    set_menu(dut, 0b01)
    await Timer(1, unit="ns")
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)

    # Menu 10 Enter ALU opcode
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_alu_control_or_nibble(dut, 0b0110) # opcode = 0110, i.e. SRL
    await Timer(1, unit="ns")
    set_menu(dut, 0b10)
    await Timer(1, unit="ns")
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)
    await wait_past_rising_edge(dut)


    set_config_aux(dut, 0b00)   # 00 sets the operands a and b to rs1 and the immediate, respectively.
    await wait_past_rising_edge(dut)

    # Menu 11 Start execution. Use manual stepping.
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_menu(dut, 0b11)
    await Timer(1, unit="ns")
    assert_displayed_value(dut, 0x0468)
    assert dut.LEDR.value[9] == 1   # stepping_mode_is_on
    assert dut.LEDR.value[3:2] == 0   # exec_FSM_show_state
    await set_key_load_button_tap(dut)
    await wait_x_cycles(dut, 10)

    assert dut.LEDR.value[3:2] == 0b0
    await set_key_step_button_tap(dut)
    assert dut.LEDR.value[3:2] == 0b1
    # Change the immediate during the execution of exec_fsm.
    set_menu(dut, 0b0)
    set_alu_control_or_nibble(dut, 0xF) # This would enter the value 0x00F4,
    # which would go out of bounds for SRL and null the value.
    await RisingEdge(dut.CLOCK_50)
    await set_key_load_button_tap(dut)
    set_menu(dut, 0b11)
    await RisingEdge(dut.CLOCK_50)

    await set_key_step_button_tap(dut)
    assert dut.LEDR.value[3:2] == 0b10
    await set_key_step_button_tap(dut)
    assert dut.LEDR.value[3:2] == 0b11
    await set_key_step_button_tap(dut)
    assert dut.LEDR.value[3:2] == 0b0



    # Fourth Test
    # Try to write to reg0
    # Assert that reg01 contains the expected value after SRL
    # For this, execute reg00 = reg01 + reg11
    # == 0x0468 + 0
    # == 0x0468
    # Skip menu 00 because no immediate will be used.

    # Menu 01 Enter destination and source registers
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_registers(dut, 0b000111) # rd = 00; rs1 = 01; rs2 = 11
    await Timer(1, unit="ns")
    set_menu(dut, 0b01)
    await Timer(1, unit="ns")
    await RisingEdge(dut.CLOCK_50)
    await set_key_load_button_tap(dut)

    # Menu 10 Enter ALU opcode
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_alu_control_or_nibble(dut, 0b0)
    await Timer(1, unit="ns")
    set_menu(dut, 0b10)
    await Timer(1, unit="ns")
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)

    set_config_aux(dut, 0b11)   # 11 sets the operands a and b to rs2 and rs1, respectively.
    await RisingEdge(dut.CLOCK_50)

    # Menu 11 Start execution. Use automatic stepping.
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_menu(dut, 0b11)
    await Timer(1, unit="ns")
    await set_key_stepping_mode_button_tap(dut)
    assert_displayed_value(dut, 0x0468) # This confirms that the value was stored in reg01.
    assert dut.LEDR.value[9] == 0   # stepping_mode_is_on
    assert dut.LEDR.value[3:2] == 0   # exec_FSM_show_state
    await set_key_load_and_wait(dut, 0) # Launch exec_fsm
    assert dut.LEDR.value[3:2] == 0b0
    await wait_past_rising_edge(dut)
    assert dut.LEDR.value[3:2] == 0b1
    await wait_past_rising_edge(dut)
    assert dut.LEDR.value[3:2] == 0b10
    await wait_past_rising_edge(dut)
    assert dut.LEDR.value[3:2] == 0b11
    await wait_past_rising_edge(dut)
    assert dut.LEDR.value[3:2] == 0b0
    await wait_past_rising_edge(dut)

    # Fifth Test
    # Assert reg0 == 0
    # For this, set alu as reg00 = reg00 + reg00
    # Show alu result with mode 11
    # Skip menu 00 because no immediate will be used.

    # Menu 01 Enter destination and source registers
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_registers(dut, 0b000000) # rd = 00; rs1 = 00; rs2 = 00
    await Timer(1, unit="ns")
    set_menu(dut, 0b01)
    await Timer(1, unit="ns")
    await RisingEdge(dut.CLOCK_50)
    await set_key_load_button_tap(dut)

    # Menu 10 Enter ALU opcode
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_alu_control_or_nibble(dut, 0b0)
    await Timer(1, unit="ns")
    set_menu(dut, 0b10)
    await Timer(1, unit="ns")
    await wait_past_rising_edge(dut)
    await set_key_load_button_tap(dut)

    set_config_aux(dut, 0b00)
    await RisingEdge(dut.CLOCK_50)

    # Menu 11 Start execution. # Show and assert ALU result
    apply_defaults(dut)
    await Timer(1, unit="ns")
    set_menu(dut, 0b11)
    await Timer(1, unit="ns")
    assert_displayed_value(dut, 0) # This confirms that the value of reg0 is still 0 after a writing attempt.