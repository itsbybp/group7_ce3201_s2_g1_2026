import cocotb
from cocotb.triggers import Timer

# 7-segment display numbers (active low, abcdefg)
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
    # cocotb.log.info(f"value = {value}")
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
    dut.local_menu.value = 0
    dut.immediate.value = 0
    dut.rd.value = 0
    dut.rs1.value = 0
    dut.rs2.value = 0
    dut.opcode.value = 0
    dut.alu_result_freeze.value = 0



@cocotb.test()
async def test_menu00_immediate(dut):
    apply_defaults(dut)

    # Test a positive number
    dut.local_menu.value = 0b00
    dut.immediate.value = 0x7123
    await Timer(1, unit="ns")
    assert_displayed_value(dut, 0x7123)

    # Test a negative number
    dut.immediate.value = 0xfabc
    await Timer(1, unit="ns")
    assert_displayed_value(dut, 0xfabc)

    # Test that alu result is not used instead
    dut.immediate.value = 0x1111
    dut.alu_result_freeze.value = 0x5555
    await Timer(1, unit="ns")
    assert_displayed_value(dut, 0x1111)

        

@cocotb.test()
async def test_menu01_register_display(dut):
    apply_defaults(dut)

    dut.local_menu.value = 0b01
    # The register bank has four registers.
    # Assert with reg 0 as source and destination.
    # The purpose of the registers should not be handled by this module, so 0 should behave as any other address.
    dut.rd.value = 0
    dut.rs1.value = 0
    dut.rs2.value = 0
    await Timer(1, unit="ns")

    assert dut.HEX0.value == SEG[0]
    assert dut.HEX1.value == SEG[0]
    assert dut.HEX2.value == SEG[0]
    assert dut.HEX3.value == OFF
    assert dut.HEX4.value == OFF
    assert dut.HEX5.value == OFF

    # Test the other three possible addresses
    dut.rd.value = 1
    dut.rs1.value = 2
    dut.rs2.value = 3
    await Timer(1, unit="ns")

    assert dut.HEX0.value == SEG[1]
    assert dut.HEX1.value == SEG[2]
    assert dut.HEX2.value == SEG[3]
    assert dut.HEX3.value == OFF
    assert dut.HEX4.value == OFF
    assert dut.HEX5.value == OFF

# The opcode should be displayed as two digit decimal number [0, 15]
@cocotb.test()
async def test_menu10_opcode_display(dut):
    apply_defaults(dut)

    dut.local_menu.value = 0b10
    dut.opcode.value = 0xA
    await Timer(1, unit="ns")

    assert dut.HEX0.value == SEG[0]
    assert dut.HEX1.value == SEG[1]
    assert dut.HEX2.value == OFF
    assert dut.HEX3.value == OFF
    assert dut.HEX4.value == OFF
    assert dut.HEX5.value == OFF

    dut.opcode.value = 0xF
    await Timer(1, unit="ns")

    assert dut.HEX0.value == SEG[5]
    assert dut.HEX1.value == SEG[1]
    assert dut.HEX2.value == OFF
    assert dut.HEX3.value == OFF
    assert dut.HEX4.value == OFF
    assert dut.HEX5.value == OFF

    dut.opcode.value = 0x0
    await Timer(1, unit="ns")

    assert dut.HEX0.value == SEG[0]
    assert dut.HEX1.value == SEG[0]
    assert dut.HEX2.value == OFF
    assert dut.HEX3.value == OFF
    assert dut.HEX4.value == OFF
    assert dut.HEX5.value == OFF

    dut.opcode.value = 0x3
    await Timer(1, unit="ns")

    assert dut.HEX0.value == SEG[3]
    assert dut.HEX1.value == SEG[0]
    assert dut.HEX2.value == OFF
    assert dut.HEX3.value == OFF
    assert dut.HEX4.value == OFF
    assert dut.HEX5.value == OFF



@cocotb.test()
async def test_menu11_alu_res(dut):
    apply_defaults(dut)

    # Test a positive number
    dut.local_menu.value = 0b11
    dut.alu_result_freeze.value = 0x1234
    await Timer(1, unit="ns")
    assert_displayed_value(dut, 0x1234)

    # Test a negative number
    dut.alu_result_freeze.value = 0xffff
    await Timer(1, unit="ns")
    assert_displayed_value(dut, 0xffff)

    # Test that the immediate is not used instead
    dut.alu_result_freeze.value = 0x8888
    dut.immediate.value = 0x3333
    await Timer(1, unit="ns")
    assert_displayed_value(dut, 0x8888)
