`timescale 1ns/1ps

// Testbench dirigido para arbiter.sv (Questa).
// Escenarios, en orden:
//   1. Reset
//   2. vJTAG solo: escritura con subordinado listo
//   3. CPU sola: lectura
//   4. Ambos piden: gana vJTAG y luego entra la CPU
//   5. Backpressure de vJTAG (subordinate_ready = 0)
//   6. La CPU conserva el bus mientras espera ready aunque vJTAG pida
//   7. La CPU suelta el bus cuando fsm_valid baja
//   8. Reset en medio de un acceso de vJTAG
//
// Convencion de tiempo: las entradas cambian en el flanco de bajada y las
// salidas se revisan 2 ns despues, antes del siguiente flanco de subida.

module tb_arbiter;

    localparam logic [1:0] S_IDLE  = 2'b00;
    localparam logic [1:0] S_VJTAG = 2'b01;
    localparam logic [1:0] S_FSM   = 2'b10;

    localparam int CLK_PERIOD = 10;

    // ---------------- Señales ----------------
    logic        clk = 1'b0;
    logic        rst_n = 1'b0;

    logic        vjtag_valid = 1'b0;
    logic [31:0] vjtag_addr = '0;
    logic [31:0] vjtag_data = '0;
    logic        vjtag_write_en = 1'b0;
    logic        vjtag_ready;

    logic        fsm_valid = 1'b0;
    logic [31:0] fsm_addr = '0;
    logic [31:0] fsm_data = '0;
    logic        fsm_write_en = 1'b0;
    logic        fsm_ready;

    logic        subordinate_ready = 1'b0;

    logic [31:0] mux_addr;
    logic [31:0] mux_data;
    logic        mux_write_en;
    logic        mux_valid;
    logic        mux_is_cpu;

    int checks = 0;
    int errors = 0;

    always #(CLK_PERIOD/2) clk = ~clk;

    arbiter dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .vjtag_valid      (vjtag_valid),
        .vjtag_addr       (vjtag_addr),
        .vjtag_data       (vjtag_data),
        .vjtag_write_en   (vjtag_write_en),
        .vjtag_ready      (vjtag_ready),
        .fsm_valid        (fsm_valid),
        .fsm_addr         (fsm_addr),
        .fsm_data         (fsm_data),
        .fsm_write_en     (fsm_write_en),
        .fsm_ready        (fsm_ready),
        .subordinate_ready(subordinate_ready),
        .mux_addr         (mux_addr),
        .mux_data         (mux_data),
        .mux_write_en     (mux_write_en),
        .mux_valid        (mux_valid),
        .mux_is_cpu       (mux_is_cpu)
    );

    // ---------------- Tareas auxiliares ----------------
    task automatic section(input string name);
        $display("\n=== %s ===", name);
    endtask

    // Aplica las entradas en el flanco de bajada y espera a que las salidas se asienten
    task automatic drive(input logic        vv,
                         input logic [31:0] va,
                         input logic [31:0] vd,
                         input logic        vw,
                         input logic        fv,
                         input logic [31:0] fa,
                         input logic [31:0] fd,
                         input logic        fw,
                         input logic        sr);
        @(negedge clk);
        vjtag_valid      = vv;
        vjtag_addr       = va;
        vjtag_data       = vd;
        vjtag_write_en   = vw;
        fsm_valid        = fv;
        fsm_addr         = fa;
        fsm_data         = fd;
        fsm_write_en     = fw;
        subordinate_ready = sr;
        #2;
    endtask

    task automatic check_state(input logic [1:0] exp, input string msg);
        checks++;
        if (dut.state !== exp) begin
            errors++;
            $display("FAIL [%0t] %s: estado esperado=%b obtenido=%b",
                     $time, msg, exp, dut.state);
        end
    endtask

    task automatic check_bus(input logic        ev,
                             input logic [31:0] ea,
                             input logic [31:0] ed,
                             input logic        ew,
                             input logic        ec,
                             input logic        evr,
                             input logic        efr,
                             input string       msg);
        logic [68:0] exp_vec, got_vec;
        exp_vec = {ev, ea, ed, ew, ec, evr, efr};
        got_vec = {mux_valid, mux_addr, mux_data, mux_write_en, mux_is_cpu,
                   vjtag_ready, fsm_ready};
        checks++;
        if (got_vec !== exp_vec) begin
            errors++;
            $display("FAIL [%0t] %s", $time, msg);
            $display("     esperado: valid=%b addr=%h data=%h we=%b cpu=%b vready=%b fready=%b",
                     ev, ea, ed, ew, ec, evr, efr);
            $display("     obtenido: valid=%b addr=%h data=%h we=%b cpu=%b vready=%b fready=%b",
                     mux_valid, mux_addr, mux_data, mux_write_en, mux_is_cpu,
                     vjtag_ready, fsm_ready);
        end
    endtask

    task automatic report();
        int fd;
        string status;
        status = (errors == 0) ? "ALL_TESTS_PASSED" : "TESTS_FAILED";
        $display("\n----------------------------------------");
        $display("TB: tb_arbiter");
        $display("TOTAL_CHECKS=%0d", checks);
        $display("ERRORS=%0d", errors);
        $display("WARNINGS=0");
        $display("%s", status);
        $display("----------------------------------------");

        fd = $fopen("questa_test_summary.log", "a");
        if (fd != 0) begin
            $fdisplay(fd, "tb_arbiter TOTAL_CHECKS=%0d", checks);
            $fdisplay(fd, "tb_arbiter ERRORS=%0d", errors);
            $fdisplay(fd, "tb_arbiter WARNINGS=0");
            $fdisplay(fd, "tb_arbiter %s", status);
            $fclose(fd);
        end
    endtask

    // ---------------- Secuencia principal ----------------
    initial begin
        // 1. Reset
        section("1. Reset");
        rst_n = 1'b0;
        drive(0, 0, 0, 0,  0, 0, 0, 0,  0);
        check_state(S_IDLE, "reset activo");
        check_bus(0, 0, 0, 0, 0, 0, 0, "reset: todas las salidas en cero");
        @(negedge clk);
        rst_n = 1'b1;

        // 2. vJTAG solo: escritura con subordinado listo
        section("2. vJTAG solo: escritura");
        drive(1, 32'h100, 32'hA5, 1,  0, 0, 0, 0,  1);
        check_state(S_IDLE, "IDLE con vJTAG pidiendo");
        check_bus(0, 0, 0, 0, 0, 0, 0, "IDLE: aun sin concesion");
        drive(1, 32'h100, 32'hA5, 1,  0, 0, 0, 0,  1);
        check_state(S_VJTAG, "vJTAG concedido");
        check_bus(1, 32'h100, 32'hA5, 1, 0, 1, 0, "vJTAG: bus activo, vjtag_ready=1");
        drive(0, 32'h100, 32'hA5, 1,  0, 0, 0, 0,  1);
        check_state(S_VJTAG, "vJTAG termina su solicitud");
        check_bus(0, 32'h100, 32'hA5, 1, 0, 1, 0, "vJTAG: valid bajo, sin transaccion");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  1);
        check_state(S_IDLE, "regreso a IDLE");
        check_bus(0, 0, 0, 0, 0, 0, 0, "IDLE: salidas en cero");

        // 3. CPU sola: lectura
        section("3. CPU sola: lectura");
        drive(0, 0, 0, 0,  1, 32'h20000, 0, 0,  1);
        check_state(S_IDLE, "IDLE con CPU pidiendo");
        check_bus(0, 0, 0, 0, 0, 0, 0, "IDLE: aun sin concesion");
        drive(0, 0, 0, 0,  1, 32'h20000, 0, 0,  1);
        check_state(S_FSM, "CPU concedida");
        check_bus(1, 32'h20000, 0, 0, 1, 0, 1, "CPU: bus activo, fsm_ready=1");
        drive(0, 0, 0, 0,  0, 32'h20000, 0, 0,  1);
        check_state(S_FSM, "CPU suelta fsm_valid");
        check_bus(0, 32'h20000, 0, 0, 1, 0, 1, "CPU: valid bajo");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  1);
        check_state(S_IDLE, "regreso a IDLE");
        check_bus(0, 0, 0, 0, 0, 0, 0, "IDLE: salidas en cero");

        // 4. Ambos piden: gana vJTAG y luego entra la CPU
        section("4. Ambos piden: gana vJTAG");
        drive(1, 32'h100, 32'hFF, 1,  1, 32'h200, 32'hAA, 0,  1);
        check_state(S_IDLE, "IDLE con ambos pidiendo");
        check_bus(0, 0, 0, 0, 0, 0, 0, "IDLE: sin concesion");
        drive(1, 32'h100, 32'hFF, 1,  1, 32'h200, 32'hAA, 0,  1);
        check_state(S_VJTAG, "vJTAG concedido primero");
        check_bus(1, 32'h100, 32'hFF, 1, 0, 1, 0, "vJTAG gana, CPU espera");
        drive(0, 32'h100, 32'hFF, 1,  1, 32'h200, 32'hAA, 0,  1);
        check_state(S_VJTAG, "vJTAG termina, CPU sigue pidiendo");
        check_bus(0, 32'h100, 32'hFF, 1, 0, 1, 0, "vJTAG: valid bajo");
        drive(0, 0, 0, 0,  1, 32'h200, 32'hAA, 0,  1);
        check_state(S_FSM, "CPU concedida despues de vJTAG");
        check_bus(1, 32'h200, 32'hAA, 0, 1, 0, 1, "CPU: bus activo tras vJTAG");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  1);
        check_state(S_FSM, "CPU termina");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  1);
        check_state(S_IDLE, "regreso a IDLE");

        // 5. Backpressure de vJTAG
        section("5. Backpressure de vJTAG");
        drive(1, 32'h100, 32'h55, 0,  0, 0, 0, 0,  0);
        check_state(S_IDLE, "IDLE con vJTAG pidiendo");
        check_bus(0, 0, 0, 0, 0, 0, 0, "IDLE: sin concesion");
        drive(1, 32'h100, 32'h55, 0,  0, 0, 0, 0,  0);
        check_state(S_VJTAG, "vJTAG concedido");
        check_bus(1, 32'h100, 32'h55, 0, 0, 0, 0, "subordinado no listo: vjtag_ready=0");
        drive(1, 32'h100, 32'h55, 0,  0, 0, 0, 0,  0);
        check_state(S_VJTAG, "sigue esperando");
        check_bus(1, 32'h100, 32'h55, 0, 0, 0, 0, "bus estable con backpressure");
        drive(1, 32'h100, 32'h55, 0,  0, 0, 0, 0,  0);
        check_state(S_VJTAG, "sigue esperando");
        check_bus(1, 32'h100, 32'h55, 0, 0, 0, 0, "bus estable con backpressure");
        drive(1, 32'h100, 32'h55, 0,  0, 0, 0, 0,  1);
        check_state(S_VJTAG, "subordinado listo");
        check_bus(1, 32'h100, 32'h55, 0, 0, 1, 0, "vjtag_ready=1 al completar");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  0);
        check_state(S_VJTAG, "vJTAG suelta valid");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  0);
        check_state(S_IDLE, "regreso a IDLE");

        // 6. La CPU conserva el bus mientras espera ready
        section("6. CPU conserva el bus mientras vJTAG pide");
        drive(0, 0, 0, 0,  1, 32'h30000, 32'h7, 0,  0);
        check_state(S_IDLE, "IDLE con CPU pidiendo");
        drive(0, 0, 0, 0,  1, 32'h30000, 32'h7, 0,  0);
        check_state(S_FSM, "CPU concedida");
        check_bus(1, 32'h30000, 32'h7, 0, 1, 0, 0, "CPU: sin ready aun");
        drive(1, 32'h10000, 32'h9, 1,  1, 32'h30000, 32'h7, 0,  0);
        check_state(S_FSM, "vJTAG pide, CPU retiene el bus (1)");
        check_bus(1, 32'h30000, 32'h7, 0, 1, 0, 0, "CPU retiene bus");
        drive(1, 32'h10000, 32'h9, 1,  1, 32'h30000, 32'h7, 0,  0);
        check_state(S_FSM, "vJTAG pide, CPU retiene el bus (2)");
        check_bus(1, 32'h30000, 32'h7, 0, 1, 0, 0, "CPU retiene bus");
        drive(1, 32'h10000, 32'h9, 1,  1, 32'h30000, 32'h7, 0,  0);
        check_state(S_FSM, "vJTAG pide, CPU retiene el bus (3)");
        check_bus(1, 32'h30000, 32'h7, 0, 1, 0, 0, "CPU retiene bus");
        drive(1, 32'h10000, 32'h9, 1,  1, 32'h30000, 32'h7, 0,  1);
        check_state(S_FSM, "subordinado listo para la CPU");
        check_bus(1, 32'h30000, 32'h7, 0, 1, 0, 1, "fsm_ready=1, vjtag_ready=0");
        drive(1, 32'h10000, 32'h9, 1,  1, 32'h30000, 32'h7, 0,  1);
        check_state(S_VJTAG, "luego pasa a vJTAG");
        check_bus(1, 32'h10000, 32'h9, 1, 0, 1, 0, "vJTAG recibe el bus");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  0);
        check_state(S_VJTAG, "vJTAG termina");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  0);
        check_state(S_IDLE, "regreso a IDLE");

        // 7. La CPU suelta el bus cuando fsm_valid baja
        section("7. CPU suelta el bus cuando fsm_valid baja");
        drive(0, 0, 0, 0,  1, 32'h30000, 0, 0,  0);
        check_state(S_IDLE, "IDLE con CPU pidiendo");
        drive(0, 0, 0, 0,  1, 32'h30000, 0, 0,  0);
        check_state(S_FSM, "CPU concedida");
        drive(1, 32'h44, 0, 0,  0, 32'h30000, 0, 0,  0);
        check_state(S_FSM, "fsm_valid baja, vJTAG pide");
        check_bus(0, 32'h30000, 0, 0, 1, 0, 0, "CPU sin valid, aun en el bus");
        drive(1, 32'h44, 0, 0,  0, 32'h30000, 0, 0,  1);
        check_state(S_VJTAG, "vJTAG recibe el bus");
        check_bus(1, 32'h44, 0, 0, 0, 1, 0, "vJTAG: bus activo, vjtag_ready=1");

        // Cierre de la seccion
        drive(0, 0, 0, 0,  0, 0, 0, 0,  0);
        check_state(S_VJTAG, "vJTAG termina");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  0);
        check_state(S_IDLE, "regreso a IDLE");

        // 8. Reset en medio de un acceso
        section("8. Reset en medio de un acceso");
        drive(1, 32'h5, 0, 0,  0, 0, 0, 0,  1);
        check_state(S_IDLE, "IDLE con vJTAG pidiendo");
        drive(1, 32'h5, 0, 0,  0, 0, 0, 0,  1);
        check_state(S_VJTAG, "vJTAG concedido");
        check_bus(1, 32'h5, 0, 0, 0, 1, 0, "vJTAG: bus activo");
        @(negedge clk);
        rst_n = 1'b0;
        #2;
        check_state(S_IDLE, "reset asincrono: vuelve a IDLE");
        check_bus(0, 0, 0, 0, 0, 0, 0, "reset: salidas en cero");
        drive(0, 0, 0, 0,  0, 0, 0, 0,  0);   // baja las entradas mientras rst_n sigue en 0
        @(negedge clk);
        rst_n = 1'b1;
        drive(0, 0, 0, 0,  0, 0, 0, 0,  0);
        check_state(S_IDLE, "tras liberar reset");

        // Resumen
        report();
        $finish;
    end

endmodule
