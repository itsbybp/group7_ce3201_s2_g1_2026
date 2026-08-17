import cocotb
from cocotb.triggers import Timer


def calculate_expected(data, p_even, p_odd):
    error_even = (
        ((data >> 0) & 1)
        ^ ((data >> 2) & 1)
        ^ p_even
    )

    error_odd = ~(
        ((data >> 1) & 1)
        ^ ((data >> 3) & 1)
        ^ p_odd
    ) & 1

    valid = int(
        error_even == 0
        and error_odd == 0
    )

    return error_even, error_odd, valid


@cocotb.test()
async def test_all_binary_combinations(dut):
    """Test all possible binary combinations."""

    for data in range(16):
        for p_even in range(2):
            for p_odd in range(2):

                dut.data.value = data
                dut.p_even.value = p_even
                dut.p_odd.value = p_odd

                await Timer(1, unit="ns")

                expected_even, expected_odd, expected_valid = (
                    calculate_expected(data, p_even, p_odd)
                )

                assert int(dut.error_even.value) == expected_even, (
                    f"error_even FAIL: "
                    f"data={data:04b}, "
                    f"p_even={p_even}, "
                    f"p_odd={p_odd}"
                )

                assert int(dut.error_odd.value) == expected_odd, (
                    f"error_odd FAIL: "
                    f"data={data:04b}, "
                    f"p_even={p_even}, "
                    f"p_odd={p_odd}"
                )

                assert int(dut.valid.value) == expected_valid, (
                    f"valid FAIL: "
                    f"data={data:04b}, "
                    f"p_even={p_even}, "
                    f"p_odd={p_odd}"
                )