package multicycle_rv_control_fsm_states_pkg;

  typedef enum logic [3:0] {
    FETCH,
    DECODE,
    MEM_ADR,
    MEM_READ,
    MEM_WB,
    MEM_WRITE,
    EXECUTE_R,
    ALU_WB,
    EXECUTE_I,
    JAL,
    BEQ
  } multicycle_rv_control_fsm_state;

endpackage





module multicycle_rv_control_fsm 
(
    input logic clk,
    input logic rst_n,
    input logic [6:0] op,

    // enable should be connected to CTRL[0], i.e. start.
    // If LOW, the FSM state resets to FETCH and raising ready valid outputs is prevented.
    input logic enable, 

    // Ready is not needed because the RAM doesn't have an input buffer, data reads are fast,
    // and the RV32I FSM can't advance without receiving the data required in FETCH/MEM_READ/MEM_WRITE.
    // So that mantaining valid_out until the valid_in from the RAM rises is enough.
    // NO READY THEN????????????

    // Ready valid inputs
    // input logic ready_in_instr_memory,
    input logic valid_in_instr_memory,
    // input logic ready_in_data_memory,
    input logic valid_in_data_memory,

    // Ready valid outputs
    // output logic ready_out_instr_memory,
    output logic valid_out_instr_memory,
    // output logic ready_out_data_memory,
    output logic valid_out_data_memory,




    output logic branch,
    output logic pc_update,
    output logic reg_write,
    output logic mem_write,
    output logic ir_write,
    output logic [1:0] result_src,
    output logic [1:0] alu_src_a,
    output logic [1:0] alu_src_b,
    output logic adr_src,
    output logic [1:0] alu_op
);

    import multicycle_rv_opcodes_pkg::*;
        // R_TYPE  = 7'b0110011,
        // I_TYPE  = 7'b0010011,
        // I_LOAD  = 7'b0000011,
        // S       = 7'b0100011,
        // B       = 7'b1100011,
        // J       = 7'b1101111,
        // // I_JUMP  = 7'b1100111,
        // LUI     = 7'b0110111
        // //, AUIPC   = 7'b0010111

    assign branch = current_state == BEQ;   // Posiblity of branching. Branching is finally determined in the control unit.
    assign pc_update = current_state == FETCH || current_state == JAL; // Write enable of pc register.
    assign reg_write = current_state == MEM_WB || current_state == ALU_WB; // Write enable reg file.
    assign mem_write = current_state == MEM_WRITE; // write enable of data bus.
    assign ir_write = current_state == FETCH; // write enable of instruction register.
    
    // 2'b11 is not a possible value because FETCH and MEM_WB are mutually exclusive since they are states.
    assign result_src = {current_state == FETCH, current_state == MEM_WB}; // Selection input of write back mux.
    
    assign alu_src_a = {current_state == MEM_ADR || current_state == EXECUTE_R || current_state == EXECUTE_I || current_state == BEQ,
        current_state == DECODE || current_state == JAL}; // Selection input of alu operand a mux. 2'b11 is not possible.

    // Selection input of alu operand b mux. 2'b11 is not possible.
    assign alu_src_b = {current_state == FETCH || JAL, current_state == DECODE || current_state == MEM_ADR || EXECUTE_I};
    
    assign adr_src = current_state == MEM_READ || current_state == MEM_WRITE; // The data bus is active when HIGH.
    assign alu_op = {current_state == EXECUTE_R || EXECUTE_I, current_state == BEQ}; // TODO Check this. This a partial result before alu_ctrl

    multicycle_rv_control_fsm_state current_state; 
    multicycle_rv_control_fsm_state next_state; 

    always_comb begin
        next_state = FETCH;
        case (current_state)
            FETCH: begin
                if (conditions) begin
                    
                end 
                next_state = DECODE;
            end
            DECODE: begin 
                case (op)
                    R_TYPE: begin
                        next_state = EXECUTE_R;
                    end 
                    I_TYPE: begin
                        next_state = EXECUTE_I;
                    end 
                    I_LOAD: begin
                        next_state = MEM_ADR;
                    end 
                    S: begin
                        next_state = MEM_ADR;
                    end 
                    B: begin
                        next_state = BEQ;
                    end 
                    J: begin
                        next_state = JAL;
                    end 
                    // I_JUMP: begin
                    //     next_state = JAL;
                    // end 
                    LUI: begin
                        next_state = JAL;
                    end 
                    // AUIPC: begin
                    //     next_state = JAL;
                    // end 
                    default: ;
                endcase
            end
            MEM_ADR: begin 
                case (op) 
                    I_LOAD: begin
                        next_state = MEM_READ;
                    end 
                    S: begin
                        next_state = MEM_WRITE;
                    end 
                    default: ;
                endcase
            end
            MEM_READ: begin 
                next_state = MEM_WB;
            end
            
            MEM_WB: begin 
                next_state = FETCH;
            end
            
            MEM_WRITE: begin 
                next_state = FETCH;
            end
            
            EXECUTE_R: begin 
                next_state = ALU_WB;
            end
            
            ALU_WB: begin 
                next_state = FETCH;
            end
            
            EXECUTE_I: begin 
                next_state = ALU_WB;
            end
            
            JAL: begin 
                next_state = ALU_WB;
            end
            
            BEQ: begin 
                next_state = FETCH;
            end
            
            default: begin 
                next_state = FETCH; // Hoping it was a bubble. 
            end
        endcase
    end



    always_ff @(posedge clk or negedge rst_n)
    begin
        if (~rst_n) begin
            current_state <= FETCH;
        end
        else if (enable) begin
            current_state <= FETCH;
        end
        else begin
            current_state <= next_state;
        end
    end
    

endmodule