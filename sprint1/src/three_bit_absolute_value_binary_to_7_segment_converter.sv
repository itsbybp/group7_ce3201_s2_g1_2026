// Combines the n-bit absolute value module and the seven_segment_adapter module
// to convert a 3-bit signed input to a 7-bit output for a 7-segment.
// Sign information is lost.
module three_bit_absolute_value_binary_to_7_segment_converter
(
    input logic [2:0] in,
    output logic [6:0] segments_abcdefg
);


// Use the absolute value of in
logic [2:0] absolute_value_of_in;
n_bit_absolute_value #(.N(3)) abs3 (
    .in(in),
    .out(absolute_value_of_in)
);

// Nibble to 7-segment display.
seven_segment_adapter adapter (
  .in   ({1'b0, absolute_value_of_in}),
  .segments_abcdefg  (segments_abcdefg)
);

endmodule
