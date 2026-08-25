module alu_param  #(parameter WIDTH = 8)
(
    input alu_types_pkg::alu_op_t code,
    input logic [WIDTH - 1:0] a,
    input logic [WIDTH - 1:0] b,
    output logic [WIDTH - 1:0] result
);

  import alu_types_pkg::*;

  always_comb begin

    logic [WIDTH - 1:0] b_mod;
    logic [WIDTH - 1:0] add_one;
    b_mod = '0;
    add_one = '0;

    case (code)

      ADD, SUB: begin
        b_mod = (code == ADD) ? b : ~b;
        add_one[0] = (code == SUB);
        result = a + b_mod + add_one;
      end

      AND:
        result = a&b;

      OR:
        result = a|b;

      XOR:
        result = a^b;

      SLL:
        result = a<<b;

      SRL:
        result = a>>b;

      SRA:
        result = $signed(a)>>>b;

      default:
        result = '0;

    endcase
  end


endmodule
