module control_logic (
  input logic mode_select, 
  input logic display_toggle_button,

  input logic [2:0] src0,
  input logic [2:0] src1,
  input logic [2:0] alu_a_result,
  
  input logic [7:0] alu_b_concatenated_operand,
  input logic [7:0] alu_b_multiplexed_operand,
  input logic [7:0] alu_b_result,

  output logic [6:0] seven_segment_display_one,
  output logic [6:0] seven_segment_display_two,
  output logic [6:0] seven_segment_display_three,
  output logic [6:0] seven_segment_display_four,
  output logic [6:0] seven_segment_display_five,
  output logic [6:0] seven_segment_display_six

);


    // 7-segment displays BCD and adapters for 3-bit numbers.
    logic [6:0] mode_a_src0_segments_abcdefg;
    logic [6:0] mode_a_src1_segments_abcdefg;
    logic [6:0] mode_a_result_segments_abcdefg;
    // src 0
    three_bit_absolute_value_binary_to_7_segment_converter mode_a_src0_adapter (
        .in   (src0),
        .segments_abcdefg  (mode_a_src0_segments_abcdefg)
    );
    // src 1
    three_bit_absolute_value_binary_to_7_segment_converter mode_a_src1_adapter (
        .in   (src1),
        .segments_abcdefg  (mode_a_src1_segments_abcdefg)
    );
    // ALU A result
    three_bit_absolute_value_binary_to_7_segment_converter mode_a_result_adapter (
        .in   (alu_a_result),
        .segments_abcdefg  (mode_a_result_segments_abcdefg)
    );
    // 7-segment displays BCD and adapters for 8-bit numbers.
    logic [6:0] mode_b_concatenated_operand_ones_segments_abcdefg;
    logic [6:0] mode_b_concatenated_operand_tens_segments_abcdefg;
    logic [6:0] mode_b_concatenated_operand_hundreds_segments_abcdefg;
    logic [6:0] mode_b_multiplexed_operand_ones_segments_abcdefg;
    logic [6:0] mode_b_multiplexed_operand_tens_segments_abcdefg;
    logic [6:0] mode_b_multiplexed_operand_hundreds_segments_abcdefg;
    logic [6:0] mode_b_result_ones_segments_abcdefg;
    logic [6:0] mode_b_result_tens_segments_abcdefg;
    logic [6:0] mode_b_result_hundreds_segments_abcdefg;
    eight_bit_absolute_value_binary_to_7_segment_BCD_converter mode_b_concatenated_operand_adapter (
        .in   (alu_b_concatenated_operand),
        .ones_segments_abcdefg  (mode_b_concatenated_operand_ones_segments_abcdefg),
        .tens_segments_abcdefg  (mode_b_concatenated_operand_tens_segments_abcdefg),
        .hundreds_segments_abcdefg  (mode_b_concatenated_operand_hundreds_segments_abcdefg)
    );
    eight_bit_absolute_value_binary_to_7_segment_BCD_converter mode_b_multiplexed_operand_adapter (
        .in   (alu_b_multiplexed_operand),
        .ones_segments_abcdefg  (mode_b_multiplexed_operand_ones_segments_abcdefg),
        .tens_segments_abcdefg  (mode_b_multiplexed_operand_tens_segments_abcdefg),
        .hundreds_segments_abcdefg  (mode_b_multiplexed_operand_hundreds_segments_abcdefg)
    );
    eight_bit_absolute_value_binary_to_7_segment_BCD_converter mode_b_result_adapter (
        .in   (alu_b_result),
        .ones_segments_abcdefg  (mode_b_result_ones_segments_abcdefg),
        .tens_segments_abcdefg  (mode_b_result_tens_segments_abcdefg),
        .hundreds_segments_abcdefg  (mode_b_result_hundreds_segments_abcdefg)
    );

    // 7-segment displays off.
    logic [6:0] display_off;
    assign display_off = 7'b1111111; // The 7-segment displays' LEDs are active low.

    // 7-segment displays one to and six multiplexing.
    logic [1:0] displays_selection;
    assign displays_selection = {mode_select, display_toggle_button};
    always_comb begin
    case (displays_selection)
        2'b00: begin
            seven_segment_display_one = mode_a_src0_segments_abcdefg;
            seven_segment_display_two = mode_a_src1_segments_abcdefg;
            seven_segment_display_three = mode_a_result_segments_abcdefg;

            seven_segment_display_four = display_off;
            seven_segment_display_five = display_off;
            seven_segment_display_six = display_off;
        end
        2'b01: begin // Same as 2'b00 because toggle has no effect during mode A.
            seven_segment_display_one = mode_a_src0_segments_abcdefg;
            seven_segment_display_two = mode_a_src1_segments_abcdefg;
            seven_segment_display_three = mode_a_result_segments_abcdefg;

            seven_segment_display_four = display_off;
            seven_segment_display_five = display_off;
            seven_segment_display_six = display_off;
        end
        2'b10: begin
            seven_segment_display_one = mode_b_concatenated_operand_ones_segments_abcdefg;
            seven_segment_display_two = mode_b_concatenated_operand_tens_segments_abcdefg;
            seven_segment_display_three = mode_b_concatenated_operand_hundreds_segments_abcdefg;
            
            seven_segment_display_four = mode_b_multiplexed_operand_ones_segments_abcdefg;
            seven_segment_display_five = mode_b_multiplexed_operand_tens_segments_abcdefg;
            seven_segment_display_six = mode_b_multiplexed_operand_hundreds_segments_abcdefg;
        end
        2'b11: begin
            seven_segment_display_one = mode_b_result_ones_segments_abcdefg;
            seven_segment_display_two = mode_b_result_tens_segments_abcdefg;
            seven_segment_display_three = mode_b_result_hundreds_segments_abcdefg;
            
            seven_segment_display_four = display_off;
            seven_segment_display_five = display_off;
            seven_segment_display_six = display_off;
        end
        default: begin
            seven_segment_display_one = display_off;
            seven_segment_display_two = display_off;
            seven_segment_display_three = display_off;
            
            seven_segment_display_four = display_off;
            seven_segment_display_five = display_off;
            seven_segment_display_six = display_off;
        end
    endcase
end


























endmodule