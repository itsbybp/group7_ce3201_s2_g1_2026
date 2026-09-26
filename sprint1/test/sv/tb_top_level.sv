module tb_top_level;

    import alu_types_pkg::*;

    logic [2:0] src0, src1;
    logic [3:0] control;
    logic       display_toggle_button;

    logic [6:0] seg1, seg2, seg3, seg4, seg5, seg6;
    logic zero, carry, negative, overflow;
    logic operand_a_is_negative, operand_b_is_negative, result_is_negative;

    int errors;
    int checks;

    top_level dut (
        .src0                   (src0),
        .src1                   (src1),
        .control                (control),
        .display_toggle_button  (display_toggle_button),

        .seven_segment_display_one   (seg1),
        .seven_segment_display_two   (seg2),
        .seven_segment_display_three (seg3),
        .seven_segment_display_four  (seg4),
        .seven_segment_display_five  (seg5),
        .seven_segment_display_six   (seg6),

        .zero     (zero),
        .carry    (carry),
        .negative (negative),
        .overflow (overflow),

        .operand_a_is_negative (operand_a_is_negative),
        .operand_b_is_negative (operand_b_is_negative),
        .result_is_negative    (result_is_negative)
    );

    function automatic logic [7:0] mode_b_constant(logic [2:0] code);
        case (alu_op_t'(code))
            ADD: mode_b_constant = 8'hFF;
            SUB: mode_b_constant = 8'h01;
            AND: mode_b_constant = 8'hAA;
            OR:  mode_b_constant = 8'h55;
            XOR: mode_b_constant = 8'h0F;
            SLL: mode_b_constant = 8'h04;
            SRL: mode_b_constant = 8'h02;
            SRA: mode_b_constant = 8'h03;
            default: mode_b_constant = 8'h00;
        endcase
    endfunction

    task automatic alu_result_flags(
        input  int          w,
        input  alu_op_t     op,
        input  logic [7:0]  a,
        input  logic [7:0]  b,
        output logic [7:0]  result,
        output logic        exp_zero,
        output logic        exp_carry,
        output logic        exp_negative,
        output logic        exp_overflow
    );
        logic [7:0] mask;
        logic [7:0] b_mod;
        logic       add_one;
        logic [8:0] full_res;
        logic       msb;
        logic signed [7:0] a_signed;
        logic signed [7:0] shifted;

        msb     = 1'b0;
        mask    = (w == 3) ? 8'h07 : 8'hFF;
        b_mod   = (op == ADD) ? b : ((~b) & mask);
        add_one = (op == SUB);
        full_res = {1'b0, a} + {1'b0, b_mod} + {8'b0, add_one};

        case (op)
            ADD, SUB: result = full_res[7:0];
            AND:      result = a & b;
            OR:       result = a | b;
            XOR:      result = a ^ b;
            SLL:      result = a << b;
            SRL:      result = a >> b;
            SRA: begin
                if (w == 3) begin
                    a_signed = {{5{a[2]}}, a[2:0]};
                    shifted  = a_signed >>> b;
                    result   = {5'b0, shifted[2:0]};
                end else begin
                    result = $signed(a) >>> b;
                end
            end
            default:  result = '0;
        endcase

        case (w)
            3: msb = result[2];
            8: msb = result[7];
        endcase

        exp_zero     = (w == 3) ? (result[2:0] == '0) : (result == '0);
        exp_negative = msb;
        exp_carry    = (op == ADD || op == SUB) ? ((w == 3) ? full_res[3] : full_res[8]) : 1'b0;
        exp_overflow = ((op == ADD) && (a[w-1] == b[w-1]) && (msb != a[w-1]))
                     || ((op == SUB) && (a[w-1] != b[w-1]) && (msb != a[w-1]));
    endtask

    task automatic check(string name, logic actual, logic expected);
        checks++;
        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%0b actual=%0b (control=%0h src0=%0d src1=%0d)",
                      name, expected, actual, control, src0, src1);
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;
        display_toggle_button = 1'b0;

        for (int c = 0; c < 16; c++) begin
            for (int s0 = 0; s0 < 8; s0++) begin
                for (int s1 = 0; s1 < 8; s1++) begin
                    logic [7:0]  result;
                    logic        exp_zero, exp_carry, exp_negative, exp_overflow;
                    logic [7:0]  a_op, b_op;
                    int          width;

                    control = c[3:0];
                    src0    = s0[2:0];
                    src1    = s1[2:0];
                    #1;

                    if (control[3] == 1'b0) begin
                        width = 3;
                        a_op  = {5'b0, src0};
                        b_op  = {5'b0, src1};
                    end else begin
                        width = 8;
                        a_op  = {src1, 2'b0, src0};
                        b_op  = mode_b_constant(control[2:0]);
                    end

                    alu_result_flags(width, alu_op_t'(control[2:0]), a_op, b_op,
                                      result, exp_zero, exp_carry, exp_negative, exp_overflow);

                    check("zero",     zero,     exp_zero);
                    check("carry",    carry,    exp_carry);
                    check("negative", negative, exp_negative);
                    check("overflow", overflow, exp_overflow);

                    if (control[3] == 1'b0) begin
                        check("operand_a_is_negative", operand_a_is_negative, src0[2]);
                        check("operand_b_is_negative", operand_b_is_negative, src1[2]);
                        check("result_is_negative",    result_is_negative,    result[2]);
                    end else begin
                        check("operand_a_is_negative", operand_a_is_negative, src1[2]);
                        check("operand_b_is_negative", operand_b_is_negative, b_op[7]);
                        check("result_is_negative",    result_is_negative,    result[7]);
                    end
                end
            end
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