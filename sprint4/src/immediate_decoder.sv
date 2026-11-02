module immediate_decoder
(
    input logic [6:0] op,

    output multicycle_rv_instruction_format immediate_src, // [2:0]
);
    import multicycle_rv_opcodes_pkg::*;
        // R_TYPE  = 7'b0110011,
        // I_TYPE  = 7'b0010011,
        // I_LOAD  = 7'b0000011,
        // S       = 7'b0100011,
        // B       = 7'b1100011,
        // J       = 7'b1101111,
        // // I_JUM= 7'b1100111,
        // LUI     = 7'b0110111
        // //, AUIP= 7'b0010111

    import multicycle_rv_instruction_formats_pkg::*;
        // R,
        // I,
        // S,
        // B,
        // U,
        // J

    always_comb begin
        case (op)
            R_TYPE: immediate_src = R;
            I_TYPE: immediate_src = I;
            S: immediate_src = S;
            B: immediate_src = B;
            LUI: immediate_src = U;
            J: immediate_src = J;
            default: R 
        endcase
    end

endmodule