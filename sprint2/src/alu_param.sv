module alu_param  #(parameter WIDTH = 8)
(
    input alu_types_pkg::alu_op_t code,
    input logic [WIDTH - 1:0] a,
    input logic [WIDTH - 1:0] b,
    output logic [WIDTH - 1:0] result,
    output alu_types_pkg::alu_flags_t flags
);

  import alu_types_pkg::*;

  always_comb begin

    logic [WIDTH - 1:0] b_mod;
    logic [WIDTH - 1:0] add_one;
    logic [WIDTH:0] full_res;
    b_mod = '0;
    add_one = '0;
    full_res = '0;
    flags = '0;

    unique case (code)

      ADD, SUB: begin
        b_mod = (code == ADD) ? b : ~b;
        add_one[0] = (code == SUB);
        full_res = {1'b0, a} + {1'b0, b_mod} + {1'b0, add_one};
        result = full_res[WIDTH - 1:0];
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

    flags.zero = (result == '0);
    flags.negative = result[WIDTH - 1];
    flags.carry = full_res[WIDTH];
    flags.overflow = ((code == ADD) && (a[WIDTH-1] == b[WIDTH-1]) && (result[WIDTH-1] != a[WIDTH-1]))
    || ((code == SUB) && (a[WIDTH-1] != b[WIDTH-1]) && (result[WIDTH-1] != a[WIDTH-1]));

  end


endmodule
