module tb_counter;

    localparam int CLK_PERIOD = 20;

    logic        clk;
    logic        reset_n;
    logic        clear;
    logic        increase;
    logic [31:0] timer_limit;
    logic        timeout;

    int errors;
    int checks;

    counter dut (
        .clk        (clk),
        .reset_n    (reset_n),
        .clear      (clear),
        .increase   (increase),
        .timer_limit(timer_limit),
        .timeout    (timeout)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper tasks
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

    task automatic apply_reset();
        begin
            reset_n = 1'b0;
            wait_x_cycles(2);
            reset_n = 1'b1;
            wait_past_rising_edge();
        end
    endtask

    task automatic apply_defaults();
        begin
            clear      = 1'b0;
            increase   = 1'b0;
            timer_limit = 32'h0;
        end
    endtask

    // Uses the timout logic without needing it as a parameter.
    task automatic expect_timeout(input logic expected, input string msg);
        checks++;
        if (timeout !== expected) begin
            errors++;
            $display("FAIL: %s | expected timeout=%0b actual=%0b", msg, expected, timeout);
        end
    endtask

    // test_use_case_and_clear
    initial begin
        errors = 0;
        checks = 0;

        $display("---Test Use Case and Clear---");
        begin : test_use_case_and_clear
            int errs_before;
            errs_before = errors;

            apply_defaults();
            apply_reset();

            // Count up to timer_limit = 123
            timer_limit = 32'd123;
            wait_past_rising_edge();
            increase = 1'b1;

            for (int i = 0; i < 123; i++) begin
                expect_timeout(1'b0, $sformatf("count=%0d, timeout must be 0", i));
                wait_past_rising_edge();
            end
            expect_timeout(1'b1, "count=123, timeout must be 1");

            // Timeout must stay up while increase is still active
            for (int i = 0; i < 123; i++) begin
                wait_past_rising_edge();
                expect_timeout(1'b1, "timeout must stay up");
            end

            // Restart with clear (soft reset)
            increase = 1'b0;
            clear    = 1'b1;
            wait_past_rising_edge();
            clear    = 1'b0;
            expect_timeout(1'b0, "after clear, timeout must be 0");

            // Count up to timer_limit = 321
            timer_limit = 32'd321;
            wait_past_rising_edge();
            increase = 1'b1;

            for (int i = 0; i < 321; i++) begin
                expect_timeout(1'b0, $sformatf("second run count=%0d, timeout must be 0", i));
                wait_past_rising_edge();
            end
            expect_timeout(1'b1, "second run count=321, timeout must be 1");

            // Timeout must stay up
            for (int i = 0; i < 321; i++) begin
                wait_past_rising_edge();
                expect_timeout(1'b1, "second run timeout must stay up");
            end

            if (errors == errs_before)
                $display("PASS: test_use_case_and_clear");
            else
                $display("FAIL: test_use_case_and_clear");
        end

        $display("---Test Lower Timer Limit Mid Count---");
        begin : test_lower_timer_limit_mid_count
            int errs_before;
            errs_before = errors;

            apply_defaults();
            apply_reset();

            timer_limit = 32'd333;
            wait_past_rising_edge();
            increase = 1'b1;
            // Count up to half of timer_limit (166)
            for (int i = 0; i < 166; i++) begin
                expect_timeout(1'b0, $sformatf("count=%0d, timeout must be 0", i));
                wait_past_rising_edge();
            end
            expect_timeout(1'b0, "count=166, timeout must still be 0");

            // Lower timer_limit below count: timeout must assert immediately
            timer_limit = 32'd10;
            #1;
            expect_timeout(1'b1, "timer_limit lowered below count, timeout must be 1");

            if (errors == errs_before)
                $display("PASS: test_lower_timer_limit_mid_count");
            else
                $display("FAIL: test_lower_timer_limit_mid_count");
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