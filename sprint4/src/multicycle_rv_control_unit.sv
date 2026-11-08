module multicycle_rv_control_unit
(
    input logic clk,
    input logic rst_n,
    input logic [6:0] op,
    input logic [2:0] funct_3,
    input logic [6:0] funct_7,

    input logic enable, 
    input logic soft_reset_n, 

    input alu_types_pkg::alu_flags_t alu_flags, // [1:0]
    // OV is unused. Zero and Negative are used for branches. Carry is used for sltu (set less than unsigned). 


    // Ready valid inputs
    input logic ready_in_instr_memory,
    input logic ready_in_data_memory,

    // Ready valid outputs
    output logic valid_out_instr_memory,
    output logic valid_out_data_memory,

    // Handshakes 
    output logic handshake_instr_memory,
    output logic handshake_data_memory,


    output logic pc_write,
    output alu_types_pkg::alu_op_t alu_control,
    output multicycle_rv_instruction_formats_pkg::multicycle_rv_instruction_format immediate_src, // [2:0]


    output logic reg_write,
    output logic mem_write,
    output logic ir_write,
    output logic [1:0] result_src,
    output logic [1:0] alu_src_a,
    output logic [1:0] alu_src_b,
    output logic adr_src,
    output [1:0] slt_sltu_source,


    // Tests
    output logic illegal
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

    import multicycle_rv_instruction_formats_pkg::*;

    logic branch;
    logic pc_update;
    logic [1:0] alu_op;

    multicycle_rv_control_fsm control_fsm
    (
        .clk(clk),
        .rst_n(rst_n),
        .op(op),
        .soft_reset_n(soft_reset_n), 
        .enable(enable), 
        
        // Ready valid inputs
        .ready_in_instr_memory(ready_in_instr_memory),
        .ready_in_data_memory(ready_in_data_memory),
        // Ready valid outputs
        .valid_out_instr_memory(valid_out_instr_memory),
        .valid_out_data_memory(valid_out_data_memory),
        // Handshakes 
        .handshake_instr_memory(handshake_instr_memory),
        .handshake_data_memory(handshake_data_memory),

        .branch(branch),
        .pc_update(pc_update),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .ir_write(ir_write),
        .result_src(result_src),
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),
        .adr_src(adr_src),
        .alu_op(alu_op),

        // Test
        .illegal(illegal)
    );



    // Define branch condition
    // It depends on the current branch type and the values of zero, negative, and carry (for unsigned) from the ALU.
    logic branch_condition;
    always_comb begin
        case (funct_3)
            3'b000: begin // beq
                branch_condition = alu_flags.zero;
            end 
            3'b001: begin // bne
                branch_condition = ~alu_flags.zero;
            end 
            3'b100: begin // blt
                branch_condition = alu_flags.negative;
            end 
            3'b101: begin // bge
                branch_condition = ~alu_flags.negative;
            end
            3'b110: begin // bltu   // Implementing other branch types because the carry flag is already inside the control unit.
                branch_condition = ~alu_flags.carry;
            end 
            3'b111: begin // bgeu
                branch_condition = alu_flags.carry;
            end
            default: branch_condition = alu_flags.zero; // Invalid branch funct_3.
        endcase
    end
    // flags.zero
    // flags.negative
    // flags.carry
    // flags.overflow
    assign pc_write = pc_update || branch && branch_condition;



    // Define alu_control
    alu_decoder alu_decoder_instance
    (
        .op_6th_bit(op[5]),
        .funct_3(funct_3),
        .funct_7_6th_bit(funct_7[5]),
        .alu_op(alu_op),
        .alu_control(alu_control),
        .slt_sltu_source(slt_sltu_source)
    );



    // Define immediate_src
    immediate_decoder immediate_decoder_instance
    (
        .op(op),
        .immediate_src(immediate_src)
    );




endmodule