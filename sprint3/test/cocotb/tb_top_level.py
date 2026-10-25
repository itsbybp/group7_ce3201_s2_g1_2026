import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer, ClockCycles

HALF = 40  # ns, medio periodo de tck (tck = 4 ciclos de clk)
IR_BYPASS, IR_WRITE, IR_READ, IR_SET_ADDR = 0, 1, 2, 3
RAM_IN, RAM_OUT, RB, LEDR_A, HEX_A = 0x00000, 0x10000, 0x20000, 0x30000, 0x30004
CTRL, STATUS, TLIM, THR = 0x40000, 0x40004, 0x40008, 0x4000C
N_PIX = 16384


def vj(dut):
    return dut.vjtag_inst


async def tck_pulse(dut):
    await Timer(HALF, "ns")
    vj(dut).sim_tck.value = 1
    await Timer(HALF, "ns")
    vj(dut).sim_tck.value = 0


async def jtag_dr(dut, ir, value=0):
    v = vj(dut)
    v.sim_ir_in.value = ir
    v.sim_v_cdr.value = 1
    await tck_pulse(dut)
    v.sim_v_cdr.value = 0
    v.sim_v_sdr.value = 1
    out = 0
    for i in range(32):
        v.sim_tdi.value = (value >> i) & 1
        await Timer(HALF, "ns")
        if int(dut.tdo_w.value):
            out |= 1 << i
        v.sim_tck.value = 1
        await Timer(HALF, "ns")
        v.sim_tck.value = 0
    v.sim_v_sdr.value = 0
    v.sim_v_udr.value = 1
    await tck_pulse(dut)
    v.sim_v_udr.value = 0
    return out


async def jwrite(dut, addr, data):
    await jtag_dr(dut, IR_SET_ADDR, addr)
    await jtag_dr(dut, IR_WRITE, data)
    await ClockCycles(dut.CLOCK_50, 8)


async def jread(dut, addr):
    await jtag_dr(dut, IR_SET_ADDR, addr)
    await ClockCycles(dut.CLOCK_50, 12)
    return await jtag_dr(dut, IR_READ)


async def init(dut):
    cocotb.start_soon(Clock(dut.CLOCK_50, 20, "ns").start())
    v = vj(dut)
    for s in (v.sim_tck, v.sim_tdi, v.sim_v_cdr, v.sim_v_sdr, v.sim_v_udr):
        s.value = 0
    v.sim_ir_in.value = IR_BYPASS
    dut.SW.value = 0
    dut.KEY.value = 0
    await ClockCycles(dut.CLOCK_50, 6)
    dut.KEY.value = 1
    await ClockCycles(dut.CLOCK_50, 6)


async def soft_reset(dut):
    await jwrite(dut, CTRL, 2)
    await ClockCycles(dut.CLOCK_50, 4)


async def start_proc(dut, th, tlim=0x0FFFFFFF, px=None):
    for i, val in (px or {}).items():
        await jwrite(dut, RAM_IN + 4 * i, val)
    await jwrite(dut, THR, th)
    await jwrite(dut, TLIM, tlim)
    await jwrite(dut, CTRL, 1)
    for _ in range(100):
        if int(dut.fsm_busy_w.value):
            return
        await ClockCycles(dut.CLOCK_50, 1)
    assert False, "FSM no arranco tras CTRL.start"


async def wait_done(dut, max_cycles=400000):
    n = 0
    while int(dut.status_q.value) == 0:
        await ClockCycles(dut.CLOCK_50, 200)
        n += 200
        assert n < max_cycles, "timeout del TB esperando done/timeout"


def hexes(dut):
    return [int(getattr(dut, f"HEX{k}").value) for k in range(6)]


async def learn_segs(dut):
    dut.SW.value = 3
    tab = {}
    for base in (0x543210, 0xBA9876, 0x00FEDC):
        await jwrite(dut, HEX_A, base)
        await ClockCycles(dut.CLOCK_50, 2)
        h = hexes(dut)
        for k in range(6):
            d = (base >> (4 * k)) & 0xF
            tab.setdefault(d, h[k])
    assert len(set(tab.values())) == 16 and 0x7F not in tab.values(), "7seg invalido"
    return tab


async def bus_monitor(dut, st):
    prev = None
    held = 0
    while True:
        await FallingEdge(dut.CLOCK_50)
        fv, fr = int(dut.fsm_valid.value), int(dut.fsm_ready.value)
        vv, vr = int(dut.vjtag_valid.value), int(dut.vjtag_ready.value)
        corex = int(dut.core_rst_n.value) == 0  # soft_reset en curso: exime AC1 de la FSM
        cur = (int(dut.fsm_addr.value), int(dut.fsm_data.value), int(dut.fsm_write_en.value),
               int(dut.jtag_addr_q.value), int(dut.jtag_wdata_q.value), int(dut.vjtag_write_en.value))
        if prev is not None:
            pfv, pfr, pvv, pvr, pcur, pcorex = prev
            if pfv and not pfr and not (pcorex or corex):
                assert cur[0:3] == pcur[0:3], "AC1: FSM cambio bus con ready=0"
            if pvv and not pvr:
                assert cur[3:6] == pcur[3:6], "AC1: vJTAG cambio bus con ready=0"
        assert not (fr and vr), "AC2: ambos ready en el mismo ciclo"
        if fv and vv:
            st["collisions"] += 1
        held = held + 1 if (vv and not vr) else 0
        assert held <= 2, "vJTAG inanicion: valid sin ready >2 ciclos"
        prev = (fv, fr, vv, vr, cur, corex)


@cocotb.test()
async def test_reset_and_no_spurious_start(dut):
    await init(dut)
    assert int(dut.LEDR.value) == 0 and int(dut.fsm_busy_w.value) == 0
    for a in (CTRL, STATUS, TLIM, THR, LEDR_A, HEX_A, RB + 4):
        assert await jread(dut, a) == 0, f"reset: {a:#x} != 0"
    # un dato con bit0=1 en RAM/regfile no debe disparar la FSM (solo CTRL[0] arranca)
    await jwrite(dut, RAM_IN, 0xFF)
    await jwrite(dut, RB + 8, 0x1)
    # lee de vuelta: si la FSM capturara basura de estas transacciones, esto lo detecta
    assert await jread(dut, RAM_IN) == 0xFF
    assert await jread(dut, RB + 8) == 0x1
    await ClockCycles(dut.CLOCK_50, 100)
    assert int(dut.fsm_busy_w.value) == 0, "arranque espurio de la FSM"
    assert await jread(dut, RAM_IN) == 0xFF, "RAM se corrompio"


@cocotb.test()
async def test_vjtag_interface(dut):
    await init(dut)
    wt, at = lambda: int(dut.jtag_write_toggle.value), lambda: int(dut.jtag_addr_toggle.value)
    w0, a0 = wt(), at()
    await jtag_dr(dut, IR_SET_ADDR, 0x00000ABC)
    assert at() == a0 ^ 1 and wt() == w0 and int(dut.jtag_addr_out.value) == 0xABC
    w0, a0 = wt(), at()
    await jtag_dr(dut, IR_WRITE, 0xCAFEF00D)
    assert wt() == w0 ^ 1 and at() == a0 and int(dut.jtag_data_out.value) == 0xCAFEF00D
    await ClockCycles(dut.CLOCK_50, 8)
    w0, a0 = wt(), at()
    await jtag_dr(dut, IR_READ)
    r = await jtag_dr(dut, IR_BYPASS, 0xA5C3F00F)
    assert wt() == w0 and at() == a0, "READ/BYPASS no deben togglear"
    assert r == (0xA5C3F00F << 1) & 0xFFFFFFFF, "BYPASS: 1 bit de retardo"
    await jtag_dr(dut, IR_SET_ADDR, 0x00000010)
    assert int(dut.jtag_addr_out.value) == 0x10, "SET_ADDR reemplaza"
    await ClockCycles(dut.CLOCK_50, 12)
    n = 0
    await jtag_dr(dut, IR_WRITE, 0x1)
    while not int(dut.vjtag_valid.value):
        await ClockCycles(dut.CLOCK_50, 1)
        n += 1
        assert n <= 12, "CDC: vjtag_valid tarda demasiado"
    await jwrite(dut, RAM_IN + 0x20, 0x12345678)
    assert await jread(dut, RAM_IN + 0x20) == 0x12345678


@cocotb.test()
async def test_mmio_map(dut):
    await init(dut)
    # RAM: ambos buffers, independientes
    for a, d in ((RAM_IN, 0x11), (RAM_IN + 4, 0x22), (RAM_OUT, 0x33), (RAM_OUT + 4, 0x44)):
        await jwrite(dut, a, d)
    for a, d in ((RAM_IN, 0x11), (RAM_IN + 4, 0x22), (RAM_OUT, 0x33), (RAM_OUT + 4, 0x44)):
        assert await jread(dut, a) == d, f"RAM {a:#x}"
    # regfile: x0 fijo en cero, resto libre
    await jwrite(dut, RB, 0xFFFFFFFF)
    assert await jread(dut, RB) == 0, "x0 debe ser cero"
    await jwrite(dut, RB + 4, 0xDEADBEEF)
    assert await jread(dut, RB + 4) == 0xDEADBEEF
    # CTRL/STATUS/TIMER_LIMIT/THRESHOLD y sus sombras
    await jwrite(dut, TLIM, 0x1234)
    await jwrite(dut, THR, 0x80)
    await jwrite(dut, STATUS, 0x6)
    assert await jread(dut, TLIM) == 0x1234 and await jread(dut, THR) == 0x80
    assert await jread(dut, STATUS) == 0x6
    assert int(dut.timer_limit_q.value) == 0x1234 and int(dut.threshold_q.value) == 0x80
    assert int(dut.status_q.value) == 0x3
    # RAZ/WI fuera de rango, sin tocar lo demas
    for a in (0x20080, 0x30008, 0x40010, 0xFFFFFFFC):
        await jwrite(dut, a, 0xFFFFFFFF)
        assert await jread(dut, a) == 0, f"RAZ {a:#x}"
    # Nota: no se revisa mux_valid=0 aqui: la FSM en reposo pide el bus
    # (fsm_valid=1) todo el tiempo leyendo CTRL, asi que mux_valid=1 es normal.
    assert await jread(dut, RAM_IN) == 0x11, "WI modifico la RAM"


@cocotb.test()
async def test_display_modes(dut):
    await init(dut)
    tab = await learn_segs(dut)
    await jwrite(dut, LEDR_A, 0x3FF)
    await jwrite(dut, HEX_A, 0x123456)
    await ClockCycles(dut.CLOCK_50, 2)
    assert int(dut.LEDR.value) == 0x3FF, "SW=11: LEDR = ledr_q"
    assert hexes(dut) == [tab[d] for d in (6, 5, 4, 3, 2, 1)], "SW=11: HEX = hex_q"
    dut.SW.value = 0
    await ClockCycles(dut.CLOCK_50, 2)
    assert int(dut.LEDR.value) == 0, "SW=00: LEDR = {status,busy} en reposo"
    assert hexes(dut) == [tab[0]] * 6, "SW=00: HEX5=estado, HEX4..0=contador en 0"
    await jwrite(dut, THR, 7)
    dut.SW.value = 1
    await ClockCycles(dut.CLOCK_50, 2)
    assert hexes(dut) == [tab[7], tab[0], tab[0], 0x7F, 0x7F, 0x7F], "SW=01: threshold"
    dut.SW.value = 2
    await ClockCycles(dut.CLOCK_50, 2)
    assert hexes(dut) == [tab[0]] * 6, "SW=10: pixel/resultado en reposo"


@cocotb.test()
async def test_pixel_flow_and_arbitration(dut):
    await init(dut)
    st = {"collisions": 0}
    cocotb.start_soon(bus_monitor(dut, st))
    th = 128
    px = {0: 0, 1: 127, 2: 128, 3: 255, N_PIX - 1: 200}
    await start_proc(dut, th, px=px)
    assert int(dut.LEDR.value) & 1 == 1, "busy en LEDR[0]"
    await ClockCycles(dut.CLOCK_50, 50)
    for k in range(20):  # trafico vJTAG concurrente: backpressure + prioridad (AC1/AC2)
        await jwrite(dut, RAM_IN + 0x2000 + 4 * k, k)
        assert await jread(dut, RAM_IN + 0x2000 + 4 * k) == k
        assert await jread(dut, STATUS) & 1 == 1, "busy visible en STATUS[0]"
    assert st["collisions"] > 0, "el TB no genero colisiones vJTAG/FSM"
    await wait_done(dut)
    await ClockCycles(dut.CLOCK_50, 20)
    assert int(dut.fsm_busy_w.value) == 0 and int(dut.pixel_count_w.value) == N_PIX - 1
    assert int(dut.LEDR.value) == 0b010 and await jread(dut, STATUS) == 0x2, "STATUS/LEDR = done"
    assert await jread(dut, CTRL) == 0, "CTRL se limpia al arrancar"
    for i, v in px.items():
        exp = 255 if v >= th else 0
        assert await jread(dut, RAM_OUT + 4 * i) == exp, f"pixel {i}={v} -> esperado {exp}"
    assert await jread(dut, RB + 4) == 200, "x1 guarda el ultimo pixel"


@cocotb.test()
async def test_timeout(dut):
    await init(dut)
    await start_proc(dut, 128, tlim=50)
    await wait_done(dut)
    await ClockCycles(dut.CLOCK_50, 20)
    assert int(dut.fsm_busy_w.value) == 0 and int(dut.pixel_count_w.value) < N_PIX - 1
    assert await jread(dut, STATUS) == 0x4, "STATUS=timeout (bit2, sin done)"
    assert int(dut.LEDR.value) == 0b100


@cocotb.test()
async def test_soft_reset(dut):
    await init(dut)
    await jwrite(dut, RAM_IN + 0x40, 0x55)
    await jwrite(dut, RAM_OUT + 0x3000, 0x66)  # offset lejos de lo que procesan otras pruebas
    await jwrite(dut, LEDR_A, 0x15)
    await start_proc(dut, 77, tlim=999999)
    await ClockCycles(dut.CLOCK_50, 200)
    await soft_reset(dut)
    assert int(dut.fsm_state_w.value) == 0 and int(dut.fsm_busy_w.value) == 0, "FSM no volvio a idle"
    assert int(dut.LEDR.value) == 0, "ledr_q no se limpio"
    for a in (CTRL, STATUS, TLIM, THR):
        assert await jread(dut, a) == 0, f"soft_reset: {a:#x} != 0"
    assert await jread(dut, RAM_IN + 0x40) == 0x55 and await jread(dut, RAM_OUT + 0x3000) == 0x66, "RAM debe conservarse"
    await start_proc(dut, 5)  # puede re-arrancar tras el soft_reset
    assert int(dut.fsm_busy_w.value) == 1


@cocotb.test()
async def test_key_reset(dut):
    await init(dut)
    await jwrite(dut, RAM_IN + 0x80, 0x99)
    await jwrite(dut, RB + 4, 0x1234)
    await start_proc(dut, 50, tlim=500000)
    await ClockCycles(dut.CLOCK_50, 200)
    dut.KEY.value = 0
    await ClockCycles(dut.CLOCK_50, 6)
    assert int(dut.fsm_busy_w.value) == 0 and int(dut.pixel_count_w.value) == 0, "KEY no reinicio la FSM"
    dut.KEY.value = 1
    await ClockCycles(dut.CLOCK_50, 6)
    for a in (CTRL, STATUS, TLIM, THR, LEDR_A, RB + 4):
        assert await jread(dut, a) == 0, f"KEY reset: {a:#x}"
    assert await jread(dut, RAM_IN + 0x80) == 0x99, "RAM no se reinicia con KEY"