module eight_bit_absolute_value_binary_to_7_segment_BCD_converter
(
    input logic [7:0] in,
    output logic [6:0] ones_segments_abcdefg,
    output logic [6:0] tens_segments_abcdefg,
    output logic [6:0] hundreds_segments_abcdefg
);

logic [7:0] absolute_value_of_in;
n_bit_absolute_value #(.N(8)) abs8 (
    .in(in),
    .out(absolute_value_of_in)
);

logic [3:0] ones;
logic [3:0] tens;
logic [3:0] hundreds;

logic [19:0] shift_reg;
integer i;

always_comb begin
    shift_reg = {12'b0, absolute_value_of_in};
    i = 0;
    while (i < 8) begin
        if (shift_reg[19:16] >= 5)
            shift_reg[19:16] = shift_reg[19:16] + 3'd3;
        if (shift_reg[15:12] >= 5)
            shift_reg[15:12] = shift_reg[15:12] + 3'd3;
        if (shift_reg[11:8] >= 5)
            shift_reg[11:8] = shift_reg[11:8] + 3'd3;
        shift_reg = shift_reg << 1;
        i = i + 1;
    end
end

assign hundreds = shift_reg[19:16];
assign tens     = shift_reg[15:12];
assign ones     = shift_reg[11:8];

seven_segment_adapter ones_adapter (
  .in   (ones),
  .segments_abcdefg  (ones_segments_abcdefg)
);
seven_segment_adapter tens_adapter (
  .in   (tens),
  .segments_abcdefg  (tens_segments_abcdefg)
);
seven_segment_adapter hundreds_adapter (
  .in   (hundreds),
  .segments_abcdefg  (hundreds_segments_abcdefg)
);

endmodule