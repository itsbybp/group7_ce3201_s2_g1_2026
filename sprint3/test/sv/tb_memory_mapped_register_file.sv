module tb_memory_mapped_register_file;

    localparam int CLK_PERIOD = 20;

    logic        clk;
    logic        reset_n;
    logic [31:0] mmio_address;
    logic        write_en;
    logic [31:0] write_data;
    logic [31:0] selected_register;

    int errors;
    int checks;

    memory_mapped_register_file dut (
        .clk               (clk),
        .reset_n           (reset_n),
        .mmio_address      (mmio_address),
        .write_en          (write_en),
        .write_data        (write_data),
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
            @(posedge clk);
            mmio_address = 32'h0;
            write_data   = 32'h0;
            write_en     = 1'b0;
            #1;
        end
    endtask

    task automatic wait_x_cycles(input int x);
        repeat (x)
            @(posedge clk);
            #1;
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
        $display("Memory Mapped Register File Testbench");
        $display("----------------------------------------");

        // Reset inicial
        reset_n = 1'b0;
        apply_defaults();
        @(posedge clk);
        reset_n = 1'b1;
        @(posedge clk);

        // Test 1: x0 siempre retorna 0
        $display("\n--- Test 1: x0 Always Zero ---");
        write_register(32'h20000, 32'hFFFFFFFF);
        read_register(32'h20000);
        check("x0 write returns 0", selected_register, 32'h00000000);

        // Test 2: Escribir en x1 (0x20004)
        $display("\n--- Test 2: x1 Register ---");
        write_register(32'h20004, 32'h12345678);
        read_register(32'h20004);
        check("x1 write/read", selected_register, 32'h12345678);

        // Test 3: Escribir en x2 (0x20008)
        $display("\n--- Test 3: x2 Register ---");
        write_register(32'h20008, 32'hAAAAAAAA);
        read_register(32'h20008);
        check("x2 write/read", selected_register, 32'hAAAAAAAA);

        // Test 4: Escribir en x5 (0x20014)
        $display("\n--- Test 4: x5 Register ---");
        write_register(32'h20014, 32'hDEADBEEF);
        read_register(32'h20014);
        check("x5 write/read", selected_register, 32'hDEADBEEF);

        // Test 5: Escribir en x31 (0x2007C - dirección máxima)
        $display("\n--- Test 5: x31 Register (Max Address) ---");
        write_register(32'h2007C, 32'h12345ABC);
        read_register(32'h2007C);
        check("x31 write/read", selected_register, 32'h12345ABC);

        // Test 6: Lectura secuencial múltiples registros
        $display("\n--- Test 6: Sequential Write/Read ---");
        apply_defaults();
        write_register(32'h20004, 32'hBBBBBBBB);  // x1
        write_register(32'h20008, 32'hCCCCCCCC);  // x2
        write_register(32'h2000C, 32'hDDDDDDDD);  // x3
        write_register(32'h20010, 32'hEEEEEEEE);  // x4
        
        read_register(32'h20004);
        check("x1 sequential", selected_register, 32'hBBBBBBBB);
        read_register(32'h20008);
        check("x2 sequential", selected_register, 32'hCCCCCCCC);
        read_register(32'h2000C);
        check("x3 sequential", selected_register, 32'hDDDDDDDD);
        read_register(32'h20010);
        check("x4 sequential", selected_register, 32'hEEEEEEEE);

        // Test 7: Reset asíncrono
        $display("\n--- Test 7: Async Reset ---");
        apply_defaults();
        for (int i = 1; i < 32; i++) begin
            write_register(32'h20000 + (i << 2), 32'hFFFFFFFF);
        end
        
        reset_n = 1'b0;
        @(posedge clk);
        reset_n = 1'b1;
        @(posedge clk);
        #1;

        for (int i = 1; i < 32; i++) begin
            read_register(32'h20000 + (i << 2));
            if (selected_register !== 32'h00000000) begin
                errors++;
                checks++;
                $display("FAIL: Register x%0d not reset | expected=00000000 actual=%08h", i, selected_register);
            end else begin
                checks++;
                $display("PASS: Register x%0d reset", i);
            end
        end

        // Test 8: Lectura sin escritura (write_en=0)
        $display("\n--- Test 8: Read Without Write ---");
        apply_defaults();
        write_register(32'h20008, 32'h11111111);
        write_en = 1'b0;
        write_data = 32'h22222222;
        @(posedge clk);
        @(posedge clk);
        #1;
        read_register(32'h20008);
        check("No overwrite without write_en", selected_register, 32'h11111111);

        // Test 9: Sobreescritura en mismo registro
        $display("\n--- Test 9: Overwrite Register ---");
        apply_defaults();
        write_register(32'h2000C, 32'h44444444);
        write_register(32'h2000C, 32'h55555555);
        read_register(32'h2000C);
        check("Overwrite value", selected_register, 32'h55555555);

        // Test 10: Lectura de x0 tras intentarlo escribir
        $display("\n--- Test 10: x0 Remains Zero After Attempted Write ---");
        apply_defaults();
        write_en = 1'b1;
        mmio_address = 32'h20000;
        write_data = 32'hFFFFFFFF;
        @(posedge clk);
        write_en = 1'b0;
        @(posedge clk);
        
        mmio_address = 32'h20000;
        @(posedge clk);
        #1;
        check("x0 protected from write", selected_register, 32'h00000000);

        // Final report
        $display("\n----------------------------------------");
        $display("TOTAL_CHECKS=%0d", checks);
        $display("ERRORS=%0d", errors);
        $display("WARNINGS=0");
        if (errors == 0) begin
            $display("ALL_TESTS_PASSED");
        end else begin
            $display("TESTS_FAILED");
        end
        $display("----------------------------------------");

        $finish;
    end

endmodule