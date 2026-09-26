module tb_key_sync;

    localparam int CLK_PERIOD = 20;

    logic clk;
    logic key_raw;
    logic key0_raw;
    logic key_pulse;
    logic reset_n;

    int errors;
    int checks;

    key_sync dut (
        .clk       (clk),
        .key_raw   (key_raw),
        .key0_raw  (key0_raw),
        .key_pulse (key_pulse),
        .reset_n   (reset_n)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic check(string name, logic actual, logic expected);
        checks++;
        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%0b actual=%0b", name, expected, actual);
        end else begin
            $display("PASS: %s", name);
        end
    endtask

    task automatic check_int(string name, int actual, int expected);
        checks++;
        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%0d actual=%0d", name, expected, actual);
        end else begin
            $display("PASS: %s", name);
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;

        key_raw  = 0;
        key0_raw = 0;
        #5;
        check("reset_asserted_while_key0_low", reset_n, 1'b0);

        key0_raw = 0;
        repeat (3) @(posedge clk);
        key0_raw = 1;
        repeat (3) @(posedge clk);
        check("reset_released_after_key0_high", reset_n, 1'b1);

        key_raw  = 0;
        key0_raw = 1;
        repeat (3) @(posedge clk);
        key_raw = 1;
        begin
            int pulses;
            pulses = 0;
            repeat (6) begin
                @(posedge clk);
                if (key_pulse === 1'b1) pulses++;
            end
            check_int("key_pulse_single_cycle", pulses, 1);
        end

        key_raw  = 0;
        key0_raw = 1;
        repeat (3) @(posedge clk);
        key_raw = 1;
        begin
            int pulses;
            pulses = 0;
            repeat (10) begin
                @(posedge clk);
                if (key_pulse === 1'b1) pulses++;
            end
            check_int("key_pulse_not_repeated_while_held", pulses, 1);
        end

        key_raw  = 0;
        key0_raw = 1;
        repeat (3) @(posedge clk);
        key_raw = 1;
        repeat (6) @(posedge clk);
        key_raw = 0;
        repeat (6) @(posedge clk);
        key_raw = 1;
        begin
            int pulses;
            pulses = 0;
            repeat (6) begin
                @(posedge clk);
                if (key_pulse === 1'b1) pulses++;
            end
            check_int("key_pulse_fires_again_on_second_press", pulses, 1);
        end

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