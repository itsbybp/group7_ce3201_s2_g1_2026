import os

import cocotb
from cocotb.triggers import Timer

OPS = {0: "ADD", 1: "SUB", 2: "AND", 3: "OR", 4: "XOR", 5: "SLL", 6: "SRL", 7: "SRA"}
WIDTH = int(os.environ.get("WIDTH", 8))
MASK = (1 << WIDTH) - 1
MAX_POS = (1 << (WIDTH - 1)) - 1
MIN_NEG = -(1 << (WIDTH - 1))


def to_signed(v, w=WIDTH):
    v &= (1 << w) - 1
    return v - (1 << w) if v & (1 << (w - 1)) else v


def get_flags(dut):
    v = int(dut.flags.value)
    return {
        "zero": (v >> 3) & 1,
        "carry": (v >> 2) & 1,
        "negative": (v >> 1) & 1,
        "overflow": v & 1,
    }


async def apply(dut, op, a, b):
    dut.code.value = op
    dut.a.value = a & MASK
    dut.b.value = b & MASK
    await Timer(1, units="ns")


@cocotb.test(skip=(WIDTH != 8))
async def test_table2_constants(dut):
    # Entradas: a=0x7A fijo, b = cada constante de la Tabla 2 (uno por opcode).
    # Salida esperada: result == operación matemática/lógica equivalente en Python.
    # Tipo: funcional, cobertura de los 8 opcodes contra su vector de validación.
    # Nota: la Tabla 2 es específica de un ALU de 8 bits; se omite (skip) si WIDTH != 8.
    vectors = {
        "ADD": 0xFF, "SUB": 0x01, "AND": 0xAA, "OR": 0x55,
        "XOR": 0x0F, "SLL": 0x04, "SRL": 0x02, "SRA": 0x03,
    }
    rev = {v: k for k, v in OPS.items()}
    for name, const in vectors.items():
        op = rev[name]
        a = 0x7A
        await apply(dut, op, a, const)
        result = int(dut.result.value)
        if name == "ADD":
            exp = (a + const) & MASK
        elif name == "SUB":
            exp = (a - const) & MASK
        elif name == "AND":
            exp = a & const
        elif name == "OR":
            exp = a | const
        elif name == "XOR":
            exp = a ^ const
        elif name == "SLL":
            exp = (a << const) & MASK
        elif name == "SRL":
            exp = (a >> const) & MASK
        elif name == "SRA":
            exp = (to_signed(a) >> const) & MASK
        assert result == exp, f"{name}: a={a:#x} b={const:#x} got={result:#x} exp={exp:#x}"


@cocotb.test()
async def test_overflow_opposite_signs_add(dut):
    # Entradas: pares (a,b) con signos opuestos (incluye el caso extremo MIN_NEG+MAX_POS),
    # luego el par MAX_POS+MAX_POS y MIN_NEG+MIN_NEG (signos iguales, desbordan siempre
    # sin importar WIDTH porque 2*MAX_POS > MAX_POS y 2*MIN_NEG < MIN_NEG por definición).
    # Salida esperada: overflow=0 con signos opuestos; overflow=1 con signos iguales.
    # Tipo: funcional, edge case pedido explícitamente por el backlog (AC 3.1.1).
    # Se corre a WIDTH=8 y WIDTH=32 (requisito de DoD del Epic 3).
    ADD = 0
    for a, b in [(100, -50), (-100, 50), (1, -1), (MIN_NEG, MAX_POS)]:
        await apply(dut, ADD, a, b)
        assert get_flags(dut)["overflow"] == 0, f"Falso positivo ADD a={a} b={b}"
    await apply(dut, ADD, MAX_POS, MAX_POS)
    assert get_flags(dut)["overflow"] == 1
    await apply(dut, ADD, MIN_NEG, MIN_NEG)
    assert get_flags(dut)["overflow"] == 1


@cocotb.test()
async def test_overflow_sub_rule(dut):
    # Entradas: pares (a,b) con signos iguales (nunca desborda en resta), luego el caso
    # extremo MAX_POS - MIN_NEG (signos distintos, desborda siempre sin importar WIDTH
    # porque equivale a sumar dos magnitudes máximas), y un par con signos distintos que
    # no desborda.
    # Salida esperada: overflow=0 con signos iguales; overflow=1 en el caso extremo de
    # signos distintos; overflow=0 con signos distintos si no excede el rango.
    # Tipo: funcional, edge case de overflow en resta (AC 3.1.1).
    # Se corre a WIDTH=8 y WIDTH=32 (requisito de DoD del Epic 3).
    SUB = 1
    for a, b in [(100, 50), (-100, -50), (10, 5), (-10, -5)]:
        await apply(dut, SUB, a, b)
        assert get_flags(dut)["overflow"] == 0, f"Falso positivo SUB a={a} b={b}"
    await apply(dut, SUB, MAX_POS, MIN_NEG)
    assert get_flags(dut)["overflow"] == 1
    await apply(dut, SUB, 10, -5)
    assert get_flags(dut)["overflow"] == 0


@cocotb.test()
async def test_sra_sign_extension(dut):
    # Entradas: a=MIN_NEG (MSB=1, el valor negativo más extremo del ancho actual),
    # corrimientos SRA de 1,2,3 y WIDTH-1 bits; y un SRL como contraste.
    # Salida esperada: SRA replica el bit de signo (MSB del resultado siempre 1); SRL
    # inserta cero en el MSB en el mismo caso.
    # Tipo: funcional, retención del bit de signo en corrimientos aritméticos (AC 1.2.2).
    # Se corre a WIDTH=8 y WIDTH=32 (requisito de DoD del Epic 3).
    SRA = 7
    SRL = 6
    a = MIN_NEG
    for shift in (1, 2, 3, WIDTH - 1):
        await apply(dut, SRA, a, shift)
        exp = (to_signed(a) >> shift) & MASK
        result = int(dut.result.value)
        assert result == exp, f"SRA shift={shift} got={result:#x} exp={exp:#x}"
        assert (result >> (WIDTH - 1)) & 1 == 1, "SRA debe conservar el MSB=1 (signo negativo)"

    await apply(dut, SRL, a, 3)
    result_srl = int(dut.result.value)
    assert (result_srl >> (WIDTH - 1)) & 1 == 0, "SRL debe insertar 0 en el MSB, no replicar signo"


@cocotb.test()
async def test_zero_and_negative_flags(dut):
    # Entradas: ADD(5,-5) -> resultado 0; ADD(0,-1) -> resultado negativo.
    # Salida esperada: zero=1/negative=0 en el primer caso; zero=0/negative=1 en el segundo.
    # Tipo: funcional, banderas clásicas Zero y Negative (US 1.3).
    # Se corre a WIDTH=8 y WIDTH=32 (requisito de DoD del Epic 3).
    ADD = 0
    await apply(dut, ADD, 5, -5)
    assert get_flags(dut)["zero"] == 1
    assert get_flags(dut)["negative"] == 0
    await apply(dut, ADD, 0, -1)
    assert get_flags(dut)["zero"] == 0
    assert get_flags(dut)["negative"] == 1


@cocotb.test()
async def test_carry_unsigned(dut):
    # Entradas: ADD(MASK, 1) -> todos los bits en 1 más 1, genera acarreo sin signo real
    # sin importar WIDTH; SUB(0, 1) -> genera préstamo.
    # Salida esperada: carry=1 en el ADD (acarreo real fuera del bus). El caso SUB queda
    # sin assert porque la polaridad de carry en resta (present/absent como borrow) aún
    # no está documentada como convención del equipo; verificar y agregar el assert cuando
    # se decida.
    # Tipo: funcional, bandera Carry sin signo (US 1.3, AC 1).
    # Se corre a WIDTH=8 y WIDTH=32 (requisito de DoD del Epic 3).
    ADD = 0
    SUB = 1
    await apply(dut, ADD, MASK, 1)
    assert get_flags(dut)["carry"] == 1
    await apply(dut, SUB, 0, 1)