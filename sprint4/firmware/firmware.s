# firmware.s - Histograma + binarizacion (RV32I, 1 pixel por palabra)
# Mapa: IN 0x10000 | OUT 0x20000 | HIST 0x30000 | HEX 0x40004
#       STATUS 0x50004 (bit0 busy, bit1 done) | THRESHOLD 0x5000C

        .text
        .globl _start
_start:
        lui   s0, 0x10          # s0 = IN   (0x10000)
        lui   s1, 0x20          # s1 = OUT  (0x20000) tambien fin de IN
        lui   s2, 0x30          # s2 = HIST (0x30000)
        lui   s3, 0x40          # s3 = periféricos (HEX en 4(s3))
        lui   s4, 0x50          # s4 = CTRL/STATUS/THRESHOLD

        addi  t0, zero, 1
        sw    t0, 4(s4)         # STATUS.busy = 1

# ---- Etapa A: limpiar histograma (256 palabras) ----
        mv    t0, s2
        addi  t1, s2, 1024      # fin = HIST + 256*4
clear:
        sw    zero, 0(t0)
        addi  t0, t0, 4
        bne   t0, t1, clear

# ---- Etapas B y C fusionadas: un solo recorrido ----
        lw    s5, 12(s4)        # s5 = THRESHOLD
        mv    t0, s0            # puntero IN
        mv    t1, s1            # puntero OUT
        mv    a0, zero          # indice (para HEX)
loop:
        lw    t3, 0(t0)         # pixel
        # hist[pixel]++
        slli  t4, t3, 2
        add   t4, t4, s2
        lw    t5, 0(t4)
        addi  t5, t5, 1
        sw    t5, 0(t4)
        # binarizar: 255 si pixel >= TH, 0 si no (sin saltos)
        slt   t2, t3, s5        # 1 si pixel < TH
        addi  t2, t2, -1        # 0 si <TH, 0xFFFFFFFF si >=TH
        andi  t2, t2, 255
        sw    t2, 0(t1)
        # avanzar y mostrar indice
        addi  t0, t0, 4
        addi  t1, t1, 4
        addi  a0, a0, 1
        sw    a0, 4(s3)         # HEX = indice
        bne   t0, s1, loop      # IN termina donde empieza OUT

# ---- Fin ----
        addi  t0, zero, 2
        sw    t0, 4(s4)         # STATUS: busy=0, done=1
halt:
        j     halt
        