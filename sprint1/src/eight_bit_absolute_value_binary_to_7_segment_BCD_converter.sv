// Combines the n-bit absolute value module, a BCD code, and the seven_segment_adapter module
// to convert an 8-bit signed input to three 7-bit outputs for 7-segment displays.
// Sign information is lost.
module eight_bit_absolute_value_binary_to_7_segment_BCD_converter
(
    input logic [7:0] in,
    output logic [6:0] ones_segments_abcdefg,
    output logic [6:0] tens_segments_abcdefg,
    output logic [6:0] hundreds_segments_abcdefg
);


// Use the absolute value of in
logic [7:0] absolute_value_of_in;
n_bit_absolute_value #(.N(8)) abs8 (
    .in(in),
    .out(absolute_value_of_in)
);

// BCD
logic [3:0] ones; // use 4 bits because a 7-segment display uses 4 bits and is the least amount of bit necessary to represent 10 different values.
logic [3:0] tens;
logic [3:0] hundreds;

logic [7:0] ones_value;
logic [7:0] tens_value;
logic [7:0] hundreds_value;

assign ones_value     = absolute_value_of_in % 8'd10;
assign tens_value     = (absolute_value_of_in / 8'd10) % 8'd10;
assign hundreds_value = absolute_value_of_in / 8'd100;

assign ones     = ones_value[3:0];
assign tens     = tens_value[3:0];
assign hundreds = hundreds_value[3:0];
// Nibble to 7-segment display.
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
