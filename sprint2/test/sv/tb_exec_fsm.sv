`timescale 1ns/1ps

module tb_exec_fsm;

    // ============================================================
    // Signals
    // ============================================================

    logic clk;
    logic reset;

    logic start_execute;
    logic step;
    logic stepping_mode;

    logic write_enable;
    logic [1:0] current_state;

    int errors;
    int checks;


    // ============================================================
    // DUT
    // ============================================================

    exec_fsm dut (
        .clk           (clk),
        .reset         (reset),
        .start_execute (start_execute),
        .step          (step),
        .stepping_mode (stepping_mode),
        .write_enable  (write_enable),
        .current_state (current_state)
    );


    // ============================================================
    // Check tasks
    // ============================================================

    task automatic check_state(
        string name,
        logic [1:0] actual,
        logic [1:0] expected
    );
        checks++;

        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%b actual=%b",
                     name, expected, actual);
        end
        else begin
            $display("PASS: %s", name);
        end
    endtask


    task automatic check_write_enable(
        string name,
        logic actual,
        logic expected
    );
        checks++;

        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%b actual=%b",
                     name, expected, actual);
        end
        else begin
            $display("PASS: %s", name);
        end
    endtask


    // ============================================================
    // Clock generation
    // 10 ns period
    // ============================================================

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end


    // ============================================================
    // Test
    // ============================================================

    initial begin

        errors = 0;
        checks = 0;

        $display("========================================");
        $display("        EXEC_FSM TEST START");
        $display("========================================");


        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------

        reset          = 1'b0;
        start_execute  = 1'b0;
        step           = 1'b0;
        stepping_mode  = 1'b0;


        // --------------------------------------------------------
        // Test 1: Reset
        // --------------------------------------------------------

        #2;

        check_state(
            "reset_current_state",
            current_state,
            2'b11
        );

        check_write_enable(
            "reset_write_enable",
            write_enable,
            1'b0
        );


        // Release reset
        reset = 1'b1;


        // --------------------------------------------------------
        // Test 2: Remain in IDLE when start_execute = 0
        // --------------------------------------------------------

        @(posedge clk);
        #1;

        check_state(
            "idle_without_start",
            current_state,
            2'b11
        );


        // --------------------------------------------------------
        // Test 3: Start execution
        // --------------------------------------------------------

        start_execute = 1'b1;

        @(posedge clk);
        #1;

        check_state(
            "start_execution",
            current_state,
            2'b10
        );

        start_execute = 1'b0;


        // --------------------------------------------------------
        // Test 4: Transition 10 -> 01
        // --------------------------------------------------------

        @(posedge clk);
        #1;

        check_state(
            "transition_10_to_01",
            current_state,
            2'b01
        );


        // --------------------------------------------------------
        // Test 5: write_enable should pulse
        //
        // current_state_delayed = 10
        // current_state         = 01
        //
        // Therefore:
        // write_enable = 1
        // --------------------------------------------------------

        check_write_enable(
            "write_enable_high",
            write_enable,
            1'b1
        );


        // --------------------------------------------------------
        // Test 6: Transition 01 -> 00
        // --------------------------------------------------------

        @(posedge clk);
        #1;

        check_state(
            "transition_01_to_00",
            current_state,
            2'b00
        );

        check_write_enable(
            "write_enable_low",
            write_enable,
            1'b0
        );


        // --------------------------------------------------------
        // Test 7: Transition 00 -> 11
        // --------------------------------------------------------

        @(posedge clk);
        #1;

        check_state(
            "transition_00_to_11",
            current_state,
            2'b11
        );


        // --------------------------------------------------------
        // Test 8: Stepping mode
        //
        // With stepping_mode = 1 and step = 0,
        // the FSM must NOT advance.
        // --------------------------------------------------------

        stepping_mode = 1'b1;
        step          = 1'b0;
        start_execute = 1'b1;

        @(posedge clk);
        #1;

        check_state(
            "stepping_mode_without_step",
            current_state,
            2'b11
        );


        // --------------------------------------------------------
        // Test 9: Step allows FSM to advance
        // --------------------------------------------------------

        step = 1'b1;

        @(posedge clk);
        #1;

        check_state(
            "step_advances_fsm",
            current_state,
            2'b10
        );


        // --------------------------------------------------------
        // Test 10: Stop stepping
        //
        // step = 0 means the FSM should hold its current state.
        // --------------------------------------------------------

        step = 1'b0;

        @(posedge clk);
        #1;

        check_state(
            "step_zero_holds_state",
            current_state,
            2'b10
        );


        // --------------------------------------------------------
        // Test 11: Step again
        // --------------------------------------------------------

        step = 1'b1;

        @(posedge clk);
        #1;

        check_state(
            "second_step_transition",
            current_state,
            2'b01
        );

        check_write_enable(
            "second_step_write_enable",
            write_enable,
            1'b1
        );


        // --------------------------------------------------------
        // Summary
        // --------------------------------------------------------

        $display("========================================");
        $display("         EXEC_FSM TEST END");
        $display("========================================");

        $display("----------------------------------------");
        $display("TOTAL_CHECKS=%0d", checks);
        $display("ERRORS=%0d", errors);
        $display("WARNINGS=0");

        if (errors == 0) begin
            $display("ALL_TESTS_PASSED");
        end
        else begin
            $display("TESTS_FAILED");
        end

        $display("----------------------------------------");

        $finish;

    end

endmodule