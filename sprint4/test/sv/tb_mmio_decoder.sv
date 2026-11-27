`timescale 1ns/1ps

// Testbench dirigido para mmio_decoder.sv (Questa).
// Escenarios, en orden:
//   1. Reset
//   2. Escrituras permitidas al Host vJTAG
//   3. Escrituras permitidas a la CPU
//   4. Escrituras denegadas (Write-Ignored)
//   5. Lecturas de RAM para ambos maestros (ready un ciclo despues)
//   6. Lectura de registro MMIO
//   7. Lectura sostenida: ready alterna 0,1,0,1
//   8. Direccion no mapeada (RAZ en lectura, WI en escritura)
//
// Convencion de tiempo: las entradas cambian en el flanco de bajada y las salidas
// se revisan 2 ns despues. Una lectura ocupa dos ciclos: en el primero ready=0 y en
// el segundo ready=1 con rdata valido.

module tb_mmio_decoder;

    // Orden de we_*: [8]instr [7]in [6]out [5]hist [4]ledr [3]hex [2]ctrl [1]status [0]threshold
    localparam logic [8:0] W_NONE      = 9'b000000000;
    localparam logic [8:0] W_INSTR     = 9'b100000000;
    localparam logic [8:0] W_IN        = 9'b010000000;
    localparam logic [8:0] W_OUT       = 9'b001000000;
    localparam logic [8:0] W_HIST      = 9'b000100000;
    localparam logic [8:0] W_LEDR      = 9'b000010000;
    localparam logic [8:0] W_HEX       = 9'b000001000;
    localparam logic [8:0] W_CTRL      = 9'b000000100;
    localparam logic [8:0] W_STATUS    = 9'b000000010;
    localparam logic [8:0] W_THRESHOLD = 9'b000000001;

    // Orden de re_*: [3]instr [2]in [1]out [0]hist
    localparam logic [3:0] R_NONE  = 4'b0000;
    localparam logic [3:0] R_INSTR = 4'b1000;
    localparam logic [3:0] R_IN    = 4'b0100;
    localparam logic [3:0] R_OUT   = 4'b0010;
    localparam logic [3:0] R_HIST  = 4'b0001;

    localparam int CLK_PERIOD = 10;

    // ---------------- Señales ----------------
    logic        clk = 1'b0;
    logic        rst_n = 1'b0;

    logic [31:0] addr = '0;
    logic        valid = 1'b0;
    logic        write_en = 1'b0;
    logic        is_cpu = 1'b0;
    logic        ready;
    logic [31:0] rdata;

    logic        re_instr, re_in, re_out, re_hist;
    logic        we_instr, we_in, we_out, we_hist, we_ledr, we_hex;
    logic        we_ctrl, we_status, we_threshold;

    logic [31:0] instr_rdata = 32'h1111_1111;
    logic [31:0] in_rdata    = 32'h2222_2222;
    logic [31:0] out_rdata   = 32'h3333_3333;
    logic [31:0] hist_rdata  = 32'h4444_4444;
    logic [31:0] reg_rdata   = 32'h5555_5555;

    int checks = 0;
    int errors = 0;

    always #(CLK_PERIOD/2) clk = ~clk;

    mmio_decoder dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .addr         (addr),
        .valid        (valid),
        .write_en     (write_en),
        .is_cpu       (is_cpu),
        .ready        (ready),
        .rdata        (rdata),
        .re_instr     (re_instr),
        .re_in        (re_in),
        .re_out       (re_out),
        .re_hist      (re_hist),
        .we_instr     (we_instr),
        .we_in        (we_in),
        .we_out       (we_out),
        .we_hist      (we_hist),
        .we_ledr      (we_ledr),
        .we_hex       (we_hex),
        .we_ctrl      (we_ctrl),
        .we_status    (we_status),
        .we_threshold (we_threshold),
        .instr_rdata  (instr_rdata),
        .in_rdata     (in_rdata),
        .out_rdata    (out_rdata),
        .hist_rdata   (hist_rdata),
        .reg_rdata    (reg_rdata)
    );

    // ---------------- Tareas auxiliares ----------------
    task automatic section(input string name);
        $display("\n=== %s ===", name);
    endtask

    // Aplica un ciclo de bus en el flanco de bajada
    task automatic drive(input logic [31:0] a,
                         input logic        w,
                         input logic        c,
                         input logic        v);
        @(negedge clk);
        addr     = a;
        write_en = w;
        is_cpu   = c;
        valid    = v;
        #2;
    endtask

    // Verifica las habilitaciones de escritura, que no haya lectura y el ready
    task automatic check_we(input logic [8:0] exp_we,
                            input logic       exp_ready,
                            input string      msg);
        logic [8:0] got_we;
        logic [3:0] got_re;
        got_we = {we_instr, we_in, we_out, we_hist, we_ledr, we_hex,
                  we_ctrl, we_status, we_threshold};
        got_re = {re_instr, re_in, re_out, re_hist};
        checks++;
        if (got_we !== exp_we || got_re !== R_NONE || ready !== exp_ready) begin
            errors++;
            $display("FAIL [%0t] %s", $time, msg);
            $display("     esperado: we=%b re=%b ready=%b", exp_we, R_NONE, exp_ready);
            $display("     obtenido: we=%b re=%b ready=%b", got_we, got_re, ready);
        end
    endtask

    // Primer ciclo de lectura: solo re_* correcto, ready todavia en 0
    task automatic check_read_sel(input logic [3:0] exp_re, input string msg);
        logic [3:0] got_re;
        got_re = {re_instr, re_in, re_out, re_hist};
        checks++;
        if (got_re !== exp_re || {we_instr, we_in, we_out, we_hist, we_ledr, we_hex,
                                  we_ctrl, we_status, we_threshold} !== W_NONE || ready !== 1'b0) begin
            errors++;
            $display("FAIL [%0t] %s (ciclo 1)", $time, msg);
            $display("     esperado: re=%b we=0 ready=0", exp_re);
            $display("     obtenido: re=%b we=%b ready=%b", got_re,
                     {we_instr, we_in, we_out, we_hist, we_ledr, we_hex,
                      we_ctrl, we_status, we_threshold}, ready);
        end
    endtask

    // Segundo ciclo de lectura: ready y rdata validos
    task automatic check_read_data(input logic [31:0] exp_data, input string msg);
        checks++;
        if (ready !== 1'b1 || rdata !== exp_data) begin
            errors++;
            $display("FAIL [%0t] %s (ciclo 2)", $time, msg);
            $display("     esperado: ready=1 rdata=%h", exp_data);
            $display("     obtenido: ready=%b rdata=%h", ready, rdata);
        end
    endtask

    task automatic check_ready(input logic exp_ready, input string msg);
        checks++;
        if (ready !== exp_ready) begin
            errors++;
            $display("FAIL [%0t] %s: ready esperado=%b obtenido=%b",
                     $time, msg, exp_ready, ready);
        end
    endtask

    // Escritura: ready en el mismo ciclo
    task automatic write_access(input logic [31:0] a,
                                input logic        c,
                                input logic [8:0]  exp_we,
                                input string       msg);
        drive(a, 1'b1, c, 1'b1);
        check_we(exp_we, 1'b1, msg);
        drive(32'h0, 1'b0, 1'b0, 1'b0);
    endtask

    // Lectura: dos ciclos con la misma direccion
    task automatic read_access(input logic [31:0] a,
                               input logic        c,
                               input logic [3:0]  exp_re,
                               input logic [31:0] exp_data,
                               input string       msg);
        drive(a, 1'b0, c, 1'b1);
        check_read_sel(exp_re, msg);
        drive(a, 1'b0, c, 1'b1);
        check_read_data(exp_data, msg);
        drive(32'h0, 1'b0, 1'b0, 1'b0);
    endtask

    task automatic report();
        int fd;
        string status;
        status = (errors == 0) ? "ALL_TESTS_PASSED" : "TESTS_FAILED";
        $display("\n----------------------------------------");
        $display("TB: tb_mmio_decoder");
        $display("TOTAL_CHECKS=%0d", checks);
        $display("ERRORS=%0d", errors);
        $display("WARNINGS=0");
        $display("%s", status);
        $display("----------------------------------------");

        fd = $fopen("questa_test_summary.log", "a");
        if (fd != 0) begin
            $fdisplay(fd, "tb_mmio_decoder TOTAL_CHECKS=%0d", checks);
            $fdisplay(fd, "tb_mmio_decoder ERRORS=%0d", errors);
            $fdisplay(fd, "tb_mmio_decoder WARNINGS=0");
            $fdisplay(fd, "tb_mmio_decoder %s", status);
            $fclose(fd);
        end
    endtask

    // ---------------- Secuencia principal ----------------
    initial begin
        // 1. Reset
        section("1. Reset");
        rst_n = 1'b0;
        @(negedge clk);
        #2;
        check_we(W_NONE, 1'b0, "reset activo: salidas inactivas");
        @(negedge clk);
        rst_n = 1'b1;

        // 2. Escrituras permitidas al Host vJTAG
        section("2. Escrituras permitidas al Host");
        write_access(32'h0001_0000, 1'b0, W_IN,        "Host escribe IN RAM");
        write_access(32'h0000_0000, 1'b0, W_INSTR,     "Host escribe INSTR RAM");
        write_access(32'h0005_0000, 1'b0, W_CTRL,      "Host escribe CTRL");
        write_access(32'h0005_000C, 1'b0, W_THRESHOLD, "Host escribe THRESHOLD");

        // 3. Escrituras permitidas a la CPU
        section("3. Escrituras permitidas a la CPU");
        write_access(32'h0002_0000, 1'b1, W_OUT,    "CPU escribe OUT RAM");
        write_access(32'h0003_0000, 1'b1, W_HIST,   "CPU escribe HIST RAM");
        write_access(32'h0005_0004, 1'b1, W_STATUS, "CPU escribe STATUS");
        write_access(32'h0004_0000, 1'b1, W_LEDR,   "CPU escribe LEDR");
        write_access(32'h0004_0004, 1'b1, W_HEX,    "CPU escribe HEX");

        // 4. Escrituras denegadas (Write-Ignored: ready=1 pero sin we_*)
        section("4. Escrituras denegadas");
        write_access(32'h0001_0000, 1'b1, W_NONE, "CPU no escribe IN RAM");
        write_access(32'h0000_0000, 1'b1, W_NONE, "CPU no escribe INSTR RAM");
        write_access(32'h0002_0000, 1'b0, W_NONE, "Host no escribe OUT RAM");
        write_access(32'h0005_0004, 1'b0, W_NONE, "Host no escribe STATUS");
        write_access(32'h0005_0000, 1'b1, W_NONE, "CPU no escribe CTRL");

        // 5. Lecturas de RAM para ambos maestros
        section("5. Lecturas de RAM");
        read_access(32'h0001_0000, 1'b0, R_IN,    32'h2222_2222, "Host lee IN RAM");
        read_access(32'h0000_0000, 1'b1, R_INSTR, 32'h1111_1111, "CPU lee INSTR RAM");
        read_access(32'h0002_0000, 1'b0, R_OUT,   32'h3333_3333, "Host lee OUT RAM");
        read_access(32'h0003_0000, 1'b1, R_HIST,  32'h4444_4444, "CPU lee HIST RAM");

        // 6. Lectura de registro MMIO (sin re_*)
        section("6. Lectura de registro MMIO");
        read_access(32'h0004_0000, 1'b1, R_NONE, 32'h5555_5555, "CPU lee LEDR");

        // 7. Lectura sostenida: ready alterna 0,1,0,1
        section("7. Lectura sostenida");
        drive(32'h0001_0000, 1'b0, 1'b0, 1'b1);
        check_ready(1'b0, "ciclo 1 de la lectura sostenida");
        drive(32'h0001_0000, 1'b0, 1'b0, 1'b1);
        check_ready(1'b1, "ciclo 2 de la lectura sostenida");
        drive(32'h0001_0000, 1'b0, 1'b0, 1'b1);
        check_ready(1'b0, "ciclo 3 de la lectura sostenida");
        drive(32'h0001_0000, 1'b0, 1'b0, 1'b1);
        check_ready(1'b1, "ciclo 4 de la lectura sostenida");
        drive(32'h0, 1'b0, 1'b0, 1'b0);

        // 8. Direccion no mapeada
        section("8. Direccion no mapeada");
        read_access(32'h0000_2000, 1'b0, R_NONE, 32'h0000_0000, "RAZ: lectura no mapeada");
        write_access(32'h0000_2000, 1'b1, W_NONE, "WI: escritura no mapeada");

        // Resumen
        report();
        $finish;
    end

endmodule
