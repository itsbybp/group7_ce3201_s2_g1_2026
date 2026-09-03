import os

import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

WIDTH = int(os.environ.get("WIDTH", 8))


@cocotb.test()
async def test_x_on_opcode_forces_defined_zero(dut):
    # Entradas: a=0x2A, b=0x11 fijos; code forzado a distintos patrones con bits 'x'/'z'
    # (xxx, x1x, 1xx, xx1, zzz), que no corresponden a ningún literal válido del enum.
    # Salida esperada: result definido (sin 'x' ni 'z') y en 0, por el branch default del case.
    # Tipo: negativa, inyección de indeterminado en el bus de control (AC 3.2.1).
    dut.a.value = 0x2A
    dut.b.value = 0x11

    for pattern in ("xxx", "x1x", "1xx", "xx1", "zzz"):
        dut.code.value = BinaryValue(pattern, n_bits=3, binaryRepresentation=2)
        await Timer(1, units="ns")
        result_bv = dut.result.value
        assert "x" not in result_bv.binstr.lower() and "z" not in result_bv.binstr.lower(), \
            f"result propago indeterminado con code={pattern}: {result_bv.binstr}"
        assert int(result_bv) == 0, f"code={pattern} deberia forzar result=0, obtuvo {result_bv.binstr}"


@cocotb.test()
async def test_x_on_operand_does_not_hang_flags(dut):
    # Entradas: code=ADD fijo; a forzado a 'x' (todos los bits), b=0x01. Luego a se restaura a
    # un valor válido (0x00) sin cambiar code ni b.
    # Salida esperada: mientras a='x' las flags pueden quedar en 'x' (esperado, dato basura
    # entra, dato basura sale). Al restaurar a a un valor válido, las flags deben volver a un
    # valor definido de inmediato, sin quedar "pegadas" en x (lo cual indicaría un latch).
    # Tipo: negativa, comprobación de ausencia de latch tras recuperar datos válidos (AC 3.2.1).
    ADD = 0
    dut.code.value = ADD
    dut.a.value = BinaryValue("x" * WIDTH, n_bits=WIDTH, binaryRepresentation=2)
    dut.b.value = 0x01
    await Timer(1, units="ns")
    dut.a.value = 0x00
    await Timer(1, units="ns")
    flags_bv = dut.flags.value
    assert "x" not in flags_bv.binstr.lower(), "Las flags quedaron en x tras recuperar datos validos (posible latch)"