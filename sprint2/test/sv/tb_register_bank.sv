module tb_register_bank;

    localparam int WIDTH = 16;
    localparam int CLK_PERIOD = 20;

    logic             clk;
    logic             reset_n;
    logic [1:0]       rd;
    logic [1:0]       rs1;
    logic [1:0]       rs2;
    logic             write_en;
    logic [WIDTH-1:0] write_data;
    logic [WIDTH-1:0] rs1_data;
    logic [WIDTH-1:0] rs2_data;

    int errors;
    int checks;

    register_bank #(
        .WIDTH(WIDTH)
    ) dut (
        .clk        (clk),
        .reset_n    (reset_n),
        .rd         (rd),
        .rs1        (rs1),
        .rs2        (rs2),
        .write_en   (write_en),
        .write_data (write_data),
        .rs1_data   (rs1_data),
        .rs2_data   (rs2_data)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic check(string name, logic [WIDTH-1:0] actual, logic [WIDTH-1:0] expected);
        checks++;
        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%0h actual=%0h", name, expected, actual);
        end else begin
            $display("PASS: %s", name);
        end
    endtask

    task automatic do_reset();
        reset_n    = 0;
        rd         = 0;
        rs1        = 0;
        rs2        = 0;
        write_en   = 0;
        write_data = 0;
        repeat (3) @(posedge clk);
        reset_n = 1;
        @(posedge clk);
    endtask

    task automatic write_reg(logic [1:0] target, logic [WIDTH-1:0] value);
        rd         = target;
        write_data = value;
        write_en   = 1;
        @(posedge clk);
        write_en   = 0;
    endtask

    initial begin
        errors = 0;
        checks = 0;

        do_reset();
        rs1 = 1;
        rs2 = 2;
        @(posedge clk);
        check("reset_values_rs1", rs1_data, '0);
        check("reset_values_rs2", rs2_data, '0);

        do_reset();
        write_reg(2'd0, 16'hBEEF);
        rs1 = 0;
        @(posedge clk);
        check("x0_always_zero", rs1_data, '0);

        do_reset();
        write_reg(2'd1, 16'h1234);
        rs1 = 1;
        @(posedge clk);
        check("write_x1_read_rs1", rs1_data, 16'h1234);

        do_reset();
        rd         = 2;
        write_data = 16'h5555;
        write_en   = 0;
        @(posedge clk);
        rs1 = 2;
        @(posedge clk);
        check("write_disabled_no_write", rs1_data, '0);

        do_reset();
        write_reg(2'd2, 16'hAAAA);
        write_reg(2'd3, 16'hBBBB);
        rs1 = 2;
        rs2 = 3;
        @(posedge clk);
        check("individual_we_x2", rs1_data, 16'hAAAA);
        check("individual_we_x3", rs2_data, 16'hBBBB);

        do_reset();
        write_reg(2'd1, 16'h4242);
        reset_n = 0;
        @(posedge clk);
        reset_n = 1;
        @(posedge clk);
        rs1 = 1;
        @(posedge clk);
        check("reset_clears_registers", rs1_data, '0);

        $display("----------------------------------------");
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