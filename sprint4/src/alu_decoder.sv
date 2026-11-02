module alu_decoder
(
    input logic op_6th_bit,
    input logic [2:0] funct_3,
    input logic funct_7_6th_bit, // This is valid to use even if the current instruction uses this bit for the immediate.
    // It doesn't interfere with the immediate because this bit is only used to distinguish between shifts
    // and this bit is the 10th bit of the immediate and a shift ignores that bit.


    input logic [1:0] alu_op,

    output alu_op_t alu_control // 3 bit signal.
);
    import alu_types_pkg::*;
    // ADD,
    // SUB,
    // AND,
    // OR,
    // XOR,
    // SLL,
    // SRL,
    // SRA

    always_comb begin
        if (alu_op == 2'b01) begin  // State is branch.
            alu_control = SUB;
        end else if (alu_op == 2'b10) begin // State is execute.
            case (funct_3)
                3'b000: begin
                    if (op_6th_bit & funct_7_6th_bit) begin // If not using immediate, decide between ADD and SUB
                        alu_control = SUB;                        
                    end else begin
                        alu_control = ADD;
                    end
                end
                3'b001: begin
                    alu_control = SLL;
                end
                3'b010: begin
                    alu_control = SUB;
                end
                3'b011: begin
                    alu_control = SUB;
                end
                3'b100: begin
                    alu_control = XOR;
                end
                3'b101: begin
                    if (funct_7_6th_bit) begin
                        alu_control = SRA;
                    end else begin
                        alu_control = SRL;
                    end
                end
                3'b110: begin
                    alu_control = OR;
                end
                3'b111: begin
                    alu_control = AND;
                end
                default: 
            endcase
        end else begin
            alu_control = ADD;  // Default. This is used for other states when adding addresses to obtain the PC.
        end
    end

endmodule