module tb_control_registers;

    localparam int CLK_PERIOD = 20;

    logic        clk;
    logic        reset_n;
    logic [31:0] mmio_address;
    logic [31:0] write_data;
    logic        write_en;
    logic [31:0] selected_register;

    int errors;
    int checks;

    control_registers dut (
        .clk               (clk),
        .reset_n           (reset_n),
        .mmio_address      (mmio_address),
        .write_data        (write_data),
        .write_en          (write_en),
        .selected_register (selected_register)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Check task
    task automatic check(string name, logic [31:0] actual, logic [31:0] expected);
        checks++;
        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%08h actual=%08h", name, expected, actual);
        end else begin
            $display("PASS: %s", name);
        end
    endtask

    // Helper tasks
    task automatic apply_defaults();
        begin
            mmio_address = 32'h0;
            write_data   = 32'h0;
            write_en     = 1'b0;
        end
    endtask

    task automatic wait_x_cycles(input int x);
        repeat (x)
            @(posedge clk);
    endtask

    task automatic wait_past_rising_edge();
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic write_register(input logic [31:0] addr, input logic [31:0] data);
        begin
            mmio_address = addr;
            write_data   = data;
            write_en     = 1'b1;
            @(posedge clk);
            write_en     = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    task automatic read_register(input logic [31:0] addr);
        begin
            mmio_address = addr;
            @(posedge clk);
            #1;
        end
    endtask

    // Test cases
    initial begin
        errors = 0;
        checks = 0;

        $display("----------------------------------------");
        $display("Control Registers Testbench");
        $display("----------------------------------------");

        // Reset inicial
        reset_n = 1'b0;
        apply_defaults();
        @(posedge clk);
        reset_n = 1'b1;
        @(posedge clk);

        // Test 1: Escribir en CTRL (0x40000)
        $display("\n--- Test 1: CTRL Register ---");
        write_register(32'h40000, 32'h00000003);
        read_register(32'h40000);
        check("CTRL write/read", selected_register, 32'h00000003);

        // Test 2: Escribir en STATUS (0x40004)
        $display("\n--- Test 2: STATUS Register ---");
        write_register(32'h40004, 32'h00000005);
        read_register(32'h40004);
        check("STATUS write/read", selected_register, 32'h00000005);

        // Test 3: Escribir en TIMER_LIMIT (0x40008)
        $display("\n--- Test 3: TIMER_LIMIT Register ---");
        write_register(32'h40008, 32'h000F4240);
        read_register(32'h40008);
        check("TIMER_LIMIT write/read", selected_register, 32'h000F4240);

        // Test 4: Escribir en THRESHOLD (0x4000C)
        $display("\n--- Test 4: THRESHOLD Register ---");
        write_register(32'h4000C, 32'h00000080);
        read_register(32'h4000C);
        check("THRESHOLD write/read", selected_register, 32'h00000080);

        // Test 5: Lectura secuencial
        $display("\n--- Test 5: Sequential Read ---");
        apply_defaults();
        write_register(32'h40000, 32'hAAAAAAAA);
        write_register(32'h40004, 32'hBBBBBBBB);
        write_register(32'h40008, 32'hCCCCCCCC);
        write_register(32'h4000C, 32'hDDDDDDDD);
        
        read_register(32'h40000);
        check("CTRL sequential", selected_register, 32'hAAAAAAAA);
        read_register(32'h40004);
        check("STATUS sequential", selected_register, 32'hBBBBBBBB);
        read_register(32'h40008);
        check("TIMER_LIMIT sequential", selected_register, 32'hCCCCCCCC);
        read_register(32'h4000C);
        check("THRESHOLD sequential", selected_register, 32'hDDDDDDDD);
        // Test 6: Reset asíncrono
        $display("\n--- Test 6: Async Reset ---");
        apply_defaults();
        write_register(32'h40000, 32'hFFFFFFFF);
        write_register(32'h40004, 32'hFFFFFFFF);
        write_register(32'h40008, 32'hFFFFFFFF);
        write_register(32'h4000C, 32'hFFFFFFFF);
        
        reset_n = 1'b0;
        @(posedge clk);
        reset_n = 1'b1;
        @(posedge clk);

        read_register(32'h40000);
        check("CTRL after reset", selected_register, 32'h00000000);
        read_register(32'h40004);
        check("STATUS after reset", selected_register, 32'h00000000);
        read_register(32'h40008);
        check("TIMER_LIMIT after reset", selected_register, 32'h00000000);
        read_register(32'h4000C);
        check("THRESHOLD after reset", selected_register, 32'h00000000);

        // Test 7: Lectura sin escritura (write_en=0)
        $display("\n--- Test 7: Read Without Write ---");
        apply_defaults();
        write_register(32'h40000, 32'h12345678);
        write_en = 1'b0;
        write_data = 32'hDEADBEEF;  // Intenta escribir
        @(posedge clk);
        @(posedge clk);
        read_register(32'h40000);
        check("No overwrite without write_en", selected_register, 32'h12345678);

        // Test 8: Sobreescritura
        $display("\n--- Test 8: Overwrite ---");
        apply_defaults();
        write_register(32'h40008, 32'h11111111);
        write_register(32'h40008, 32'h22222222);
        read_register(32'h40008);
        check("Overwrite value", selected_register, 32'h22222222);

        // Final report
        $display("\n----------------------------------------");
        $display("TOTAL_CHECKS=%0d", checks);
        $display("ERRORS=%0d", errors);
        $display("WARNINGS=0");
        if (errors == 0) begin
            $display("Pruebas completadas exitosamente");
        end else begin
            $display("TESTS_FAILED");
        end
        $display("----------------------------------------");

        $finish;
    end

endmodule