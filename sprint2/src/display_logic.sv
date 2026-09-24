module display_logic (
    input logic [1:0] local_menu,
    input logic [15:0] immediate,
    
    // input logic [5:0] data,
    input logic [1:0] rd,   // Even though these registers and the opcode can be inferred from data in this implementation,
    input logic [1:0] rs1,  //they are left as inputs to make this module more suitable for the next sprint.
    input logic [1:0] rs2,
    input logic [3:0] opcode,
    
    input logic [15:0] alu_result_freeze,

    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1,
    output logic [6:0]  HEX2,
    output logic [6:0]  HEX3,
    output logic [6:0]  HEX4,
    output logic [6:0]  HEX5
);

    // // Extract menu depending values from data
    // logic [1:0] rd;
    // assign rd = data[5:4];
    // logic [1:0] rs1;
    // assign rs1 = data[3:2];
    // logic [1:0] rs2;
    // assign rs2 = data[1:0];
    // logic [3:0] opcode;
    // assign opcode = data[3:0];

    // Instantiate the binary to bcd converter.
    // The input will be mutiplexed to use the same module for the immediate and the ALU result. 
    logic [15:0] binary_to_bcd_in;  // mutiplexed input.
    logic [19:0] concat_display_bits;   // The output is the concatenation of the five 4-bit digits.
    logic [3:0] display_bits_units;
    logic [3:0] display_bits_tens;
    logic [3:0] display_bits_hundreds;
    logic [3:0] display_bits_thousands;
    logic [3:0] display_bits_ten_thousands;
    assign display_bits_units =         concat_display_bits[3:0];
    assign display_bits_tens =          concat_display_bits[7:4];
    assign display_bits_hundreds =      concat_display_bits[11:8];
    assign display_bits_thousands =     concat_display_bits[15:12];
    assign display_bits_ten_thousands = concat_display_bits[19:16];
    
    // Calculate the absolute value of bin before bcd conversion
    logic [15:0] bin_abs;
    n_bit_absolute_value #(.N(16)) abs (
        .in(binary_to_bcd_in),
        .out(bin_abs)
    );
    binary_to_bcd_converter binary_to_bcd (
        .bin   (bin_abs),
        .bcd  (concat_display_bits)
    );

    // 7-segment displays off constant.
    logic [6:0] display_off;
    assign display_off = 7'b1111111; // The 7-segment displays' LEDs are active low.

    // 7-segment display minus sign "-".
    logic [6:0] display_minus_sign;
    assign display_minus_sign = 7'b0111111;


    // Define output to display based on local_menu.
    // Menu 00
    //     Show the immediate in decimal format with sign.
    // Menu 01
    //     Show rd, rs1, and rs2.
    // Menu 10
    //     Show the opcode as a decimal value.
    // Menu 11
    //     Show ALU result in decimal format with sign.

    // Seven segment adapters instantiation.
    logic [3:0] hex_0_nibble;
    logic [3:0] hex_1_nibble;
    logic [3:0] hex_2_nibble;
    logic [3:0] hex_3_nibble;
    logic [3:0] hex_4_nibble;
    // HEX5 can only show the minus sign or be empty, so there's no nibble to display adapter for it.
    logic [6:0] hex_0_segments;
    logic [6:0] hex_1_segments;
    logic [6:0] hex_2_segments;
    logic [6:0] hex_3_segments;
    logic [6:0] hex_4_segments;
    
    // Instantiate a nibble to 7-segment adapter for each display except HEX5 (five of the six displays).
    seven_segment_adapter hex_0_nibble_adapter (
        .in   (hex_0_nibble),
        .segments_abcdefg  (hex_0_segments)
    );
    seven_segment_adapter hex_1_nibble_adapter (
        .in   (hex_1_nibble),
        .segments_abcdefg  (hex_1_segments)
    );
    seven_segment_adapter hex_2_nibble_adapter (
        .in   (hex_2_nibble),
        .segments_abcdefg  (hex_2_segments)
    );
    seven_segment_adapter hex_3_nibble_adapter (
        .in   (hex_3_nibble),
        .segments_abcdefg  (hex_3_segments)
    );
    seven_segment_adapter hex_4_nibble_adapter (
        .in   (hex_4_nibble),
        .segments_abcdefg  (hex_4_segments)
    );

    always_comb begin
        // The adapters' default behaviour is to be driven by the bcd converter.
        hex_0_nibble = display_bits_units;
        hex_1_nibble = display_bits_tens;
        hex_2_nibble = display_bits_hundreds;
        hex_3_nibble = display_bits_thousands;
        hex_4_nibble = display_bits_ten_thousands;
        // The displays' default behaviour is to be driven by the adapters.
        HEX0 = hex_0_segments;
        HEX1 = hex_1_segments;
        HEX2 = hex_2_segments;
        HEX3 = hex_3_segments;
        HEX4 = hex_4_segments;

        binary_to_bcd_in = alu_result_freeze;   // The bcd converters takes the alu result by default.

        unique case (local_menu)
            2'b00: begin    // Immediate
                // Drive the immediate into the bcd converter
                binary_to_bcd_in = immediate;
                // Directly show minus sign or turn off HEX5.
                if (immediate[15]) begin // If the number to display is negative.
                    HEX5 = display_minus_sign;
                end
                else begin
                    HEX5 = display_off;
                end
            end             // Registers
            2'b01: begin
                hex_0_nibble = {2'b00, rd};
                hex_1_nibble = {2'b00, rs1};
                hex_2_nibble = {2'b00, rs2};
                HEX3 = display_off;
                HEX4 = display_off;
                HEX5 = display_off;
            end             // Opcode
            2'b10: begin
                binary_to_bcd_in = {12'b0, opcode};
                HEX2 = display_off;
                HEX3 = display_off;
                HEX4 = display_off;
                HEX5 = display_off;
            end
            2'b11: begin        // Alu result
                // ALU result is received by the BCD converter by default.
                if (alu_result_freeze[15]) begin // If the number to display is negative.
                    HEX5 = display_minus_sign;
                end
                else begin
                    HEX5 = display_off;
                end
            end
            default: begin
                HEX0 = display_off;
                HEX1 = display_off;
                HEX2 = display_off;
                HEX3 = display_off;
                HEX4 = display_off;
                HEX5 = display_off;
            end
        endcase
end

endmodule

