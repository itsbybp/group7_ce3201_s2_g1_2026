import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

ADDR_CTRL      = 0x00040000
ADDR_STATUS    = 0x00040004
ADDR_THRESHOLD = 0x0004000C
BASE_IN        = 0x00000000
BASE_OUT       = 0x00010000

NUM_PIXELS = 8
THRESHOLD  = 100


def read_mux(addr, mem_in, start_flag):
    if addr == ADDR_CTRL:
        return int(start_flag)
    if addr == ADDR_THRESHOLD:
        return THRESHOLD
    if BASE_IN <= addr < BASE_IN + NUM_PIXELS * 4:
        return mem_in[(addr - BASE_IN) // 4]
    return 0


async def bus_model(dut, mem_in, mem_out, status, start_flag_box):
    dut.fsm_ready.value = 0
    dut.fsm_rdata.value = 0

    while True:
        await RisingEdge(dut.clk)
        dut.fsm_ready.value = int(dut.fsm_valid.value)

        if dut.fsm_valid.value and dut.fsm_write_en.value:
            addr = int(dut.fsm_addr.value)
            data = int(dut.fsm_data.value)
            if addr == ADDR_STATUS:
                status[0] = data
            elif BASE_OUT <= addr < BASE_OUT + NUM_PIXELS * 4:
                mem_out[(addr - BASE_OUT) // 4] = data

        dut.fsm_rdata.value = read_mux(int(dut.fsm_addr.value), mem_in, start_flag_box[0])


async def alu_model(dut):
    dut.alu_done.value = 0
    dut.alu_n.value = 0

    while True:
        await RisingEdge(dut.clk)
        dut.alu_done.value = 0

        if dut.alu_start.value:
            a = int(dut.alu_a.value)
            b = int(dut.alu_b.value)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.alu_done.value = 1
            dut.alu_n.value = 1 if (a - b) < 0 else 0


@cocotb.test()
async def test_fsm(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    mem_in  = [50, 150, 99, 100, 255, 0, 200, 1]
    mem_out = [0] * NUM_PIXELS
    status  = [0]
    start_flag_box = [0]

    dut.rst_n.value = 0
    dut.timer_timeout.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    cocotb.start_soon(bus_model(dut, mem_in, mem_out, status, start_flag_box))
    cocotb.start_soon(alu_model(dut))

    start_flag_box[0] = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    start_flag_box[0] = 0

    for _ in range(5000):
        if status[0] == 1:
            break
        await RisingEdge(dut.clk)
    else:
        assert False, "La FSM nunca terminó (status nunca llegó a 1)"

    for i, pixel in enumerate(mem_in):
        expected = 0 if pixel < THRESHOLD else 255
        assert mem_out[i] == expected, f"Pixel {i}: esperado={expected} obtenido={mem_out[i]}"