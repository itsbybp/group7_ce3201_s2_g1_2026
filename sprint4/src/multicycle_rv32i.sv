module multicycle_rv32i
(
    input logic clk,
    input logic rst_n,

    input logic enable, 
    input logic soft_reset_n, 

    // Ready valid inputs
    input logic ready_in_instr_memory,
    input logic ready_in_data_memory,

    // Ready valid outputs
    output logic valid_out_instr_memory,
    output logic valid_out_data_memory,

    // Handshakes. Display these.
    output logic handshake_instr_memory,
    output logic handshake_data_memory,

    // Instruction memory
    output logic [31:0] address_instr_memory, // The pc, but renamed.
    input logic [31:0] read_data_instr_memory,

    // Data memory
    output logic write_enable_data_memory,
    output logic [31:0] address_data_memory,
    output logic [31:0] write_data_data_memory,
    input logic [31:0] read_data_data_memory,
    
    // Display
    output logic [31:0] instruction,

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

    // Decoded instruction 
    logic [6:0] op;
    logic [2:0] funct_3;
    logic [6:0] funct_7;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;

    logic [31:0] immediate;

    alu_types_pkg::alu_flags_t alu_flags; // [1:0]

    logic pc_write;

    alu_types_pkg::alu_op_t alu_control;

    multicycle_rv_instruction_format immediate_src; // [2:0]

    logic reg_write;

    // logic mem_write; // This is the same as write_enable_data_memory and that's its only role.

    logic ir_write;

    logic [1:0] result_src;

    logic [1:0] alu_src_a;
    logic [1:0] alu_src_b;
    
    logic adr_src;  // TODO Is this necessary???
    logic [1:0] slt_sltu_source;
    logic forward_rs1; // Decides whether to use the register conncected to the output of the register file or the output of the register_file_directly.

    // Control unit
    multicycle_rv_control_unit control_unit
    (
        .clk(clk),
        .rst_n(rst_n),
        .op(op),
        .funct_3(funct_3),
        .funct_7(funct_7),

        .enable(enable), 
        .soft_reset_n(soft_reset_n), 

        .alu_flags(alu_flags), // [1:0]

        // Ready valid inputs
        .ready_in_instr_memory(ready_in_instr_memory),
        .ready_in_data_memory(ready_in_data_memory),
        // Ready valid outputs
        .valid_out_instr_memory(valid_out_instr_memory),
        .valid_out_data_memory(valid_out_data_memory),
        // Handshakes 
        .handshake_instr_memory(handshake_instr_memory),
        .handshake_data_memory(handshake_data_memory),

        .pc_write(pc_write),
        .alu_control(alu_control),
        .immediate_src(immediate_src), // [2:0]

        .reg_write(reg_write),
        .mem_write(write_enable_data_memory),
        .ir_write(ir_write),
        .result_src(result_src),
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),
        .adr_src(adr_src),
        .slt_sltu_source(slt_sltu_source),
        .forward_rs1(forward_rs1),

        // Test
        .illegal(illegal)
    );



    // PC
    logic [31:0] pc;
    logic [31:0] wb_mux;    // write back multiplexer.
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pc <= '0;
        end else if (~soft_reset_n) begin
            pc <= '0;
        end else if (enable && pc_write) begin
            pc <= wb_mux;
        end
    end    
    assign address_instr_memory = pc; // This is simply the pc.
    // Renaming the signal is justified because pc is used for old_pc
    //and it's a more recognizable signal name in the processor.

    // FETCH to DECODE
    logic [31:0] old_pc;    
    // Instruction of the current cycle.
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            old_pc <= '0;
            instruction <= '0;
        // end else if (~soft_reset_n) begin    // No need to reset nonarchitectural registers with soft reset
        //     pc <= '0;
        end else if (enable && ir_write) begin
            old_pc <= pc;
            instruction <= read_data_instr_memory;
        end
    end    

    // Instrucction split. Assign op, funct_3, and funct_7 from instruction
    assign op = instruction[6:0];
    assign funct_3 = instruction[14:12];
    assign funct_7 = instruction[31:25];
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign rd = instruction[11:7];

    // read data from data memory register.
    logic [31:0] read_data_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            read_data_reg <= '0;
        end else begin
            read_data_reg <= read_data_data_memory; // This is always enabled. TODO find out if enable is not required.
        end
    end    

    // Register file
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    rv_register_file #(.WIDTH(32)) rv32i_reg_file
    (
        .clk(clk),
        .rst_n(rst_n),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .write_en(reg_write),
        .write_data(wb_mux),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );
    // DECODE to EXECUTE
    logic [31:0] rs1_data_reg;
    logic [31:0] rs2_data_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rs1_data_reg <= '0;
            rs2_data_reg <= '0;
        end else if (enable) begin
            rs1_data_reg <= rs1_data;
            rs2_data_reg <= rs2_data;
        end
    end

    // Immediate builder
    // R,
    // I,
    // S,
    // B,
    // U,
    // J
    always_comb begin
        case (immediate_src)
            I: begin
                immediate = {{20{instruction[31]}}, instruction[31:20]};
            end
            S: begin
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end
            B: begin
                immediate = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            end
            U: begin
                immediate = {instruction[31:12], 12'b0}; // This shifts 12 bits to the left when doing lui.
            end
            J: begin
                immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end 
            default: begin
                immediate = {{20{instruction[31]}}, instruction[31:20]};
            end
        endcase
    end


    // ALU Source
    logic [31:0] alu_operand_a;
    logic [31:0] alu_operand_b;
    always_comb begin
        case (alu_src_a)
            2'b00: begin
                alu_operand_a = pc;
            end
            2'b01: begin
                alu_operand_a = old_pc;
            end
            2'b10: begin
                if (forward_rs1) begin  // This is true when op == I_JUMP_OP && fsm.current_state == DECODE
                    alu_operand_a = rs1_data;
                end else begin
                    alu_operand_a = rs1_data_reg;
                end
            end
            2'b11: begin
                alu_operand_a = '0;
            end
            default: alu_operand_a = pc;
        endcase
    end
    always_comb begin
        case (alu_src_b)
            2'b00: begin
                alu_operand_b = rs2_data_reg;
            end
            2'b01: begin
                alu_operand_b = immediate;
            end
            2'b10: begin
                alu_operand_b = 32'b100; // This is the 4 to add to PC.
            end
            2'b11: begin
                alu_operand_b = '0;
            end
            default: alu_operand_b = 32'b100;
        endcase
    end

    // ALU
    logic [31:0] alu_result_wo_slt; // This is the output of the ALU without slt and sltu.
                                    // It must be multiplexed to include results for slt and sltu.
    logic [31:0] alu_operand_b_shifts; // Ignores bits outside of [4:0] when shifting.
    always_comb begin
        if ((alu_control==SLL) || (alu_control==SRL) || (alu_control==SRA)) begin
            alu_operand_b_shifts = {27'b0, alu_operand_b[4:0]};
        end else begin
            alu_operand_b_shifts = alu_operand_b;
        end
    end
    alu_param #(.WIDTH(32)) rv32i_alu
    (
        .code   (alu_control),
        .a      (alu_operand_a),
        .b      (alu_operand_b_shifts),
        .result (alu_result_wo_slt),
        .flags  (alu_flags)
    );
    logic [31:0] alu_result_slt;
    assign alu_result_slt = {31'b0, alu_flags.negative ^ alu_flags.overflow}; // if overflow==1, negative is wrong.
    logic [31:0] alu_result_sltu;
    assign alu_result_sltu = {31'b0, !alu_flags.carry};
    logic [31:0] alu_result;
    always_comb begin
        alu_result = alu_result_wo_slt;
        if (slt_sltu_source == 2'b01) begin
            alu_result = alu_result_slt;
        end else if (slt_sltu_source == 2'b10) begin
            alu_result = alu_result_sltu;
        end
    end


    // EXECUTE to WRITEBACK
    logic [31:0] alu_result_reg;
    // Register to delay ALU result. This is used when a state needs a value calculated in the ALU in the previous state.
    // This is true for all states that set result_src to 2'b00.
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            alu_result_reg <= '0;
        end else if (enable && (handshake_data_memory || !valid_out_data_memory)) begin
            // This condition is equivalent to 
            // enable && ((ready_in_data_memory && valid_out_data_memory) || !valid_out_data_memory)
            // also valid_out_data_memory = fsm.current_state == MEM_WRITE or MEM_READ
            // So that this condition is enable && (~(want to access memory and memory is not valid yet))
            alu_result_reg <= alu_result;
        end
    end    

    // WRITEBACK
    assign address_data_memory = wb_mux; // It's just an assignment.
    // But the names are too different and the mux is also connected to other things
    // so changing the name of this output is justified.
    assign write_data_data_memory = rs2_data_reg; // Same thing with this signal.

    always_comb begin
        case (result_src)
            2'b00: begin
                wb_mux = alu_result_reg; // This is an address for memory or the PC or a value from an R/I type instruction.
            end
            2'b01: begin
                wb_mux = read_data_reg; // To read from the data memory in a load instruction.
            end
            2'b10: begin
                wb_mux = alu_result; // This is used to select PC+4 for the PC register at the beginning.
                // (which is possibly the PC for the next instruction).
            end 
            default: begin
                wb_mux = '0;
            end
        endcase
    end 




endmodule