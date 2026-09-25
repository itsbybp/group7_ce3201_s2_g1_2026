// Absolute value should applied to bin outside of this module for signed values.
// In which case sign information is lost in this module.
module binary_to_bcd_converter (
    input  logic [15:0] bin,
    output logic [19:0] bcd
);

    integer i;

    always_comb begin
        bcd = 20'd0;

        for (i = 15;
        i >= 0;
        i = i - 1) begin

            // Add 3 to any BCD digit >= 5
            if (bcd[3:0]   >= 5)
                bcd[3:0]   = bcd[3:0]   + 3;

            if (bcd[7:4]   >= 5)
                bcd[7:4]   = bcd[7:4]   + 3;

            if (bcd[11:8]  >= 5)
                bcd[11:8]  = bcd[11:8]  + 3;

            if (bcd[15:12] >= 5)
                bcd[15:12] = bcd[15:12] + 3;

            if (bcd[19:16] >= 5)
                bcd[19:16] = bcd[19:16] + 3;

            // Shift left and insert next binary bit
            bcd = {bcd[18:0], bin[i]};
        end
    end

endmodule
