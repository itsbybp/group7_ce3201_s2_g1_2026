module immediate_decoder
(
    input logic [6:0] op,

    output multicycle_rv_instruction_format immediate_src // [2:0]
);
    import multicycle_rv_opcodes_pkg::*;
        // R_TYPE_OP  = 7'b0110011,
        // I_TYPE_OP  = 7'b0010011,
        // I_LOAD_OP  = 7'b0000011,
        // S_OP       = 7'b0100011,
        // B_OP       = 7'b1100011,
        // J_OP       = 7'b1101111,
        // // I_JUM_OP= 7'b1100111,
        // LUI_OP     = 7'b0110111
        // //, AUIP_OP= 7'b0010111

    import multicycle_rv_instruction_formats_pkg::*;
        // R,
        // I,
        // S,
        // B,
        // U,
        // J

    // R doesn't use the immediate. It is included because this signal outputs the instruction type
    always_comb begin
        case (op)
            R_TYPE_OP: immediate_src = R;
            I_TYPE_OP: immediate_src = I;
            S_OP: immediate_src = S;
            B_OP: immediate_src = B;
            LUI_OP: immediate_src = U;
            J_OP: immediate_src = J;
            default: immediate_src = R;
        endcase
    end

endmodule