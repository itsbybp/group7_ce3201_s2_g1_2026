module top_level
(
    // input logic [N-1:0] a,
    // input logic [N-1:0] b,
    // output logic [N-1:0] c
    input logic [2:0] src0,
    input logic [2:0] src1,
    input logic [3:0] control,
    input logic display_toggle_button,

    output logic [6:0] seven_segment_display_one,
    output logic [6:0] seven_segment_display_two,
    output logic [6:0] seven_segment_display_three,
    output logic [6:0] seven_segment_display_four,
    output logic [6:0] seven_segment_display_five,
    output logic [6:0] seven_segment_display_six,

    output logic zero,
    output logic carry,
    output logic negative,
    output logic overflow,

    output logic operand_a_is_negative,
    output logic operand_b_is_negative,
    output logic result_is_negative
    

);

    import alu_types_pkg::*;

    // ALU A output
    logic [2:0] alu_a_result;
    // ALU A flags.
    alu_flags_t alu_a_flags;
    
    // ALU B input
    logic [7:0] alu_b_concatenated_operand;
    assign alu_b_concatenated_operand = {src1, 2'b0, src0}; // Concatenate both operands with src1 as MSBs and src0 as LSBs.
    logic [7:0] alu_b_multiplexed_operand;
    // ALU B output
    logic [7:0] alu_b_result;
    // ALU B flags.
    alu_flags_t alu_b_flags;
    // ALU A and B multiplexed flags. The selection input is control[3] which selects between ALU A and B.
    alu_flags_t selected_alu_flags;
    always_comb begin
    unique case (control[3])
        1'b0: selected_alu_flags = alu_a_flags;
        1'b1: selected_alu_flags = alu_b_flags;
        default: begin
            selected_alu_flags.zero     = 1'b0;
            selected_alu_flags.carry    = 1'b0;
            selected_alu_flags.negative = 1'b0;
            selected_alu_flags.overflow = 1'b0;
            // This block could simply be "default: selected_alu_flags = '0;" which works on packed structs for some reason fyi.
        end
    endcase
end
    // Assign selected_alu_flags to the outputs of the top module.
    assign zero = selected_alu_flags.zero;
    assign carry = selected_alu_flags.carry;
    assign negative = selected_alu_flags.negative;
    assign overflow = selected_alu_flags.overflow;
    
    // operand_a_is_negative multiplexed flag.
    always_comb begin
    case (control[3])
        1'b0: operand_a_is_negative = src0[2];
        1'b1: operand_a_is_negative = alu_b_concatenated_operand[7]; // alu_b_concatenated_operand[7] == src1[2]
        default: operand_a_is_negative = 1'b0;
    endcase
end
    // operand_b_is_negative multiplexed flag.
    always_comb begin
    case (control[3])
        1'b0: operand_b_is_negative = src1[2];
        1'b1: operand_b_is_negative = alu_b_multiplexed_operand[7];
        default: operand_b_is_negative = 1'b0;
    endcase
end
    // result_is_negative multiplexed flag.
    always_comb begin
    case (control[3])
        1'b0: result_is_negative = alu_a_result[2];
        1'b1: result_is_negative = alu_b_result[7];
        default: result_is_negative = 1'b0;
    endcase
end

    // Receives the operating mode and display toggle inputs, and the operands and results of the ALUs and outputs the values to display on the six 7-segment displays. 
    control_logic ctrl_logic (
        .mode_select (control[3]),
        .display_toggle_button (display_toggle_button),

        .src0 (src0),
        .src1 (src1),
        .alu_a_result (alu_a_result),

        .alu_b_concatenated_operand (alu_b_concatenated_operand),
        .alu_b_multiplexed_operand (alu_b_multiplexed_operand),
        .alu_b_result (alu_b_result),

        .seven_segment_display_one (seven_segment_display_one),
        .seven_segment_display_two (seven_segment_display_two),
        .seven_segment_display_three (seven_segment_display_three),
        .seven_segment_display_four (seven_segment_display_four),
        .seven_segment_display_five (seven_segment_display_five),
        .seven_segment_display_six (seven_segment_display_six)
    );


    // Instantiate the 3-bit ALU (ALU A)
    alu_param #(
        .WIDTH(3)
    ) alu_a (
        .code   (alu_op_t'(control)), // Cast 4-bit input to enum
        .a      (src0),
        .b      (src1),
        .result (alu_a_result),
        .flags  (alu_a_flags)
    );

    // Instantiate the 8-bit ALU (ALU B)
    alu_param #(
        .WIDTH(8)
    ) alu_b (
        .code   (alu_op_t'(control)), // Cast 4-bit input to enum
        .a      (alu_b_concatenated_operand),
        .b      (alu_b_multiplexed_operand),
        .result (alu_b_result),
        .flags  (alu_b_flags)
    );


    // Receives the ALU select (control[2:0]) and outputs alu_b_multiplexed_operand according to the specified constants bank. 
    // TODO: verify that the 3-bit operator values in the ENUM correspond to the especification.
    mode_b_constants constants_bank (
        .control (control[2:0]),
        .alu_b_multiplexed_operand (alu_b_multiplexed_operand)
    );



endmodule

