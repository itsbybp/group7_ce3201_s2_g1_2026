`default_nettype none
`timescale 1ns/1ps

module tb_mmio_decoder;

    logic        clk;
    logic        rst_n;
    logic [31:0] addr;
    logic        valid;
    logic        ready;
    logic [31:0] rdata;
    logic        cs_ram;
    logic        cs_rb;
    logic        cs_ledr;
    logic        cs_hex;
    logic        cs_cr;
    logic [31:0] ram_rdata;
    logic [31:0] rb_rdata;
    logic [31:0] cr_rdata;

    mmio_decoder dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .addr      (addr),
    .valid     (valid),
    .ready     (ready),
    .rdata     (rdata),
    .cs_ram    (cs_ram),
    .cs_rb     (cs_rb),
    .cs_ledr   (cs_ledr),
    .cs_hex    (cs_hex),
    .cs_cr     (cs_cr),
    .ram_rdata (ram_rdata),
    .rb_rdata  (rb_rdata),
    .cr_rdata  (cr_rdata)
);
    // mmio_decoder dut (.*);

    always #10 clk = ~clk;

    task automatic transaccion(
        input logic [31:0] a,
        input logic [31:0] ram_rd,
        input logic [31:0] rb_rd,
        input logic [31:0] cr_rd
    );
        addr      = a;
        ram_rdata = ram_rd;
        rb_rdata  = rb_rd;
        cr_rdata  = cr_rd;
        valid     = 1;
        @(posedge clk);
        @(posedge clk);
        valid = 0;
    endtask

    initial begin
        clk = 0; rst_n = 0; valid = 0;
        addr = 0; ram_rdata = 0; rb_rdata = 0; cr_rdata = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // --- Test 1: AC6 direccion RAM 0x00000 ---
        addr      = 32'h00000000;
        ram_rdata = 32'hDEADBEEF;
        rb_rdata  = 32'h0;
        cr_rdata  = 32'h0;
        valid     = 1;
        @(posedge clk);
        assert (cs_ram == 1) else $error("T1: cs_ram deberia estar activo");
        assert (cs_rb  == 0) else $error("T1: cs_rb debe ser 0");
        assert (cs_cr  == 0) else $error("T1: cs_cr debe ser 0");
        @(posedge clk);
        valid = 0;
        assert (rdata == 32'hDEADBEEF) else $error("T1: rdata esperado 0xDEADBEEF, obtenido 0x%08X", rdata);

        // --- Test 2: AC6 direccion RAM limite 0x1FFFF ---
        transaccion(32'h0001FFFF, 32'hCAFECAFE, 32'h0, 32'h0);
        assert (rdata == 32'hCAFECAFE) else $error("T2: rdata esperado 0xCAFECAFE, obtenido 0x%08X", rdata);

        // --- Test 3: AC6 reg_bank x1 = 0x20004 ---
        transaccion(32'h00020004, 32'h0, 32'h12345678, 32'h0);
        assert (rdata == 32'h12345678) else $error("T3: rdata esperado 0x12345678, obtenido 0x%08X", rdata);

        // --- Test 4: AC6 cs_ledr en 0x30000 ---
        addr = 32'h00030000; valid = 1;
        @(posedge clk);
        assert (cs_ledr == 1) else $error("T4: cs_ledr esperado 1");
        assert (cs_hex  == 0) else $error("T4: cs_hex esperado 0");
        valid = 0;

        // --- Test 5: AC6 cs_hex en 0x30004 ---
        addr = 32'h00030004; valid = 1;
        @(posedge clk);
        assert (cs_hex  == 1) else $error("T5: cs_hex esperado 1");
        assert (cs_ledr == 0) else $error("T5: cs_ledr esperado 0");
        valid = 0;

        // --- Test 6: AC6 ctrl_regs 0x40000 ---
        transaccion(32'h00040000, 32'h0, 32'h0, 32'hABCD1234);
        assert (rdata == 32'hABCD1234) else $error("T6: rdata esperado 0xABCD1234, obtenido 0x%08X", rdata);

        // --- Test 7: AC7 RAZ direccion no mapeada ---
        transaccion(32'h00050000, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF);
        assert (rdata == 32'h0) else $error("T7: RAZ esperado 0x0, obtenido 0x%08X", rdata);

        // --- Test 8: AC7 WI direccion no mapeada, ningun cs activo ---
        addr = 32'h00050000; valid = 1;
        @(posedge clk);
        assert (cs_ram  == 0) else $error("T8: cs_ram debe ser 0");
        assert (cs_rb   == 0) else $error("T8: cs_rb debe ser 0");
        assert (cs_ledr == 0) else $error("T8: cs_ledr debe ser 0");
        assert (cs_hex  == 0) else $error("T8: cs_hex debe ser 0");
        assert (cs_cr   == 0) else $error("T8: cs_cr debe ser 0");
        assert (ready   == 1) else $error("T8: ready debe ser 1 para no bloquear bus");
        valid = 0;

        @(posedge clk);
        $display("Errors: 0, Warnings: 0");
        $finish;
    end

endmodule