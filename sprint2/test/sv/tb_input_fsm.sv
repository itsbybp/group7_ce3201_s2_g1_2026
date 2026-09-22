`timescale 1ns/1ps

module tb_input_fsm;

    // ============================================================
    // Signals
    // ============================================================

    logic clk;
    logic reset;

    logic [7:0] nibble_input;
    logic step;

    logic [15:0] out;
    logic [1:0] current_state;

    int errors;
    int checks;


    // ============================================================
    // DUT
    // ============================================================

    input_fsm dut (
        .clk           (clk),
        .reset         (reset),
        .nibble_input  (nibble_input),
        .step          (step),
        .out           (out),
        .current_state(current_state)
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


    task automatic check_out(
        string name,
        logic [15:0] actual,
        logic [15:0] expected
    );
        checks++;

        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%h actual=%h",
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
        $display("        INPUT_FSM TEST START");
        $display("========================================");


        // --------------------------------------------------------
        // Initial values
        // --------------------------------------------------------

        reset        = 1'b0;
        nibble_input = 8'h00;
        step         = 1'b0;


        // --------------------------------------------------------
        // Test 1: Reset
        // --------------------------------------------------------

        #2;

        check_state(
            "reset_current_state",
            current_state,
            2'b11
        );

        check_out(
            "reset_out",
            out,
            16'h0000
        );


        // Release reset
        reset = 1'b1;


        // --------------------------------------------------------
        // Test 2: step = 0
        //
        // The FSM should not advance or modify out.
        // --------------------------------------------------------

        nibble_input = 8'h12;
        step         = 1'b0;

        @(posedge clk);
        #1;

        check_state(
            "step_zero_state",
            current_state,
            2'b11
        );

        check_out(
            "step_zero_out",
            out,
            16'h0000
        );


        // --------------------------------------------------------
        // Test 3: First nibble
        //
        // State 11 stores the nibble in out[3:0].
        // --------------------------------------------------------

        nibble_input = 8'h01;
        step         = 1'b1;

        @(posedge clk);
        #1;

        check_out(
            "first_nibble",
            out[3:0],
            4'h1
        );

        check_state(
            "first_nibble_state",
            current_state,
            2'b10
        );


        // --------------------------------------------------------
        // Test 4: Second nibble
        //
        // State 10 stores the nibble in out[7:4].
        // --------------------------------------------------------

        nibble_input = 8'h02;

        @(posedge clk);
        #1;

        check_out(
            "second_nibble",
            out[7:4],
            4'h2
        );

        check_state(
            "second_nibble_state",
            current_state,
            2'b01
        );


        // --------------------------------------------------------
        // Test 5: Third nibble
        //
        // State 01 stores the nibble in out[11:8].
        // --------------------------------------------------------

        nibble_input = 8'h03;

        @(posedge clk);
        #1;

        check_out(
            "third_nibble",
            out[11:8],
            4'h3
        );

        check_state(
            "third_nibble_state",
            current_state,
            2'b00
        );


        // --------------------------------------------------------
        // Test 6: Fourth nibble
        //
        // State 00 stores the nibble in out[15:12].
        // This is the final nibble.
        // --------------------------------------------------------

        nibble_input = 8'h04;

        @(posedge clk);
        #1;

        check_out(
            "fourth_nibble",
            out[15:12],
            4'h4
        );


        // --------------------------------------------------------
        // Test 7: Final state
        //
        // After the fourth nibble:
        // current_state remains 00
        // serial_assembly_FSM_finished becomes 1
        // --------------------------------------------------------

        check_state(
            "final_state",
            current_state,
            2'b00
        );

        check_out(
            "final_output",
            out,
            16'h4321
        );


        // --------------------------------------------------------
        // Test 8: Additional input must be ignored
        //
        // serial_assembly_FSM_finished = 1, so even though
        // step = 1, the FSM must not accept another nibble.
        // --------------------------------------------------------

        nibble_input = 8'h0F;
        step         = 1'b1;

        @(posedge clk);
        #1;

        check_out(
            "additional_nibble_ignored",
            out,
            16'h4321
        );

        check_state(
            "additional_nibble_state",
            current_state,
            2'b00
        );


        // --------------------------------------------------------
        // Test 9: step can be held HIGH
        //
        // The FSM should process one nibble per clock cycle.
        // This test mainly confirms that the fourth-nibble
        // sequence behaves as expected when step stays HIGH.
        //
        // Reset first to start another sequence.
        // --------------------------------------------------------

        reset = 1'b0;

        #2;

        if (current_state !== 2'b11 || out !== 16'h0000) begin
            errors++;
            $display(
                "FAIL: reset_before_continuous_stepping | expected state=11 out=0000 actual state=%b out=%h",
                current_state,
                out
            );
        end
        else begin
            $display("PASS: reset_before_continuous_stepping");
        end
        checks++;

        reset = 1'b1;

        nibble_input = 8'h0A;
        step = 1'b1;

        @(posedge clk);
        #1;

        nibble_input = 8'h0B;

        @(posedge clk);
        #1;

        nibble_input = 8'h0C;

        @(posedge clk);
        #1;

        nibble_input = 8'h0D;

        @(posedge clk);
        #1;

        check_out(
            "continuous_stepping",
            out,
            16'hDCBA
        );


        // --------------------------------------------------------
        // Summary
        // --------------------------------------------------------

        $display("========================================");
        $display("         INPUT_FSM TEST END");
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