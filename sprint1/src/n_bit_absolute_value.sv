// Code by ChatGPT
module n_bit_absolute_value #(
  parameter int N = 8
)(
  input  logic [N-1:0] in,
  output logic [N-1:0] out
);
always_comb begin
  case (in[N-1])
    1'b0: out = in;
    1'b1: out = ~in + 1'b1;
    default: out = '0;
  endcase
end
endmodule