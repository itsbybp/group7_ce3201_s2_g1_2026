module mode_b_constants
(
  input logic [2:0] control,
  output logic [7:0] alu_b_multiplexed_operand
);

  import alu_types_pkg::*;

  // Define ALU B multiplexed operand
  always_comb begin
  case (alu_op_t'(control))   // TODO: verify that the 3-bit operator values in the ENUM correspond to the especification.
    ADD: alu_b_multiplexed_operand = 8'hFF;
    SUB: alu_b_multiplexed_operand = 8'h01;
    AND: alu_b_multiplexed_operand = 8'hAA;
    OR:  alu_b_multiplexed_operand = 8'h55;
    XOR: alu_b_multiplexed_operand = 8'h0F;
    SLL: alu_b_multiplexed_operand = 8'h04;
    SRL: alu_b_multiplexed_operand = 8'h02;
    SRA: alu_b_multiplexed_operand = 8'h03;
    default: alu_b_multiplexed_operand = 8'h00; // Use a different value for the default to check if it ever appears.
  endcase
  end




endmodule
