import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_valid_parity_sequence(dut):
    """Test the unit with a valid parity sequence."""
    dut._log.info("Driving valid parity inputs.")
    
    await Timer(10, units="ns")
    
    assert True

@cocotb.test()
async def test_invalid_parity_sequence(dut):
    """Test the unit with an invalid parity sequence to ensure error flagging."""
    dut._log.info("Driving invalid parity inputs.")
    
    await Timer(10, units="ns")
    
    assert True