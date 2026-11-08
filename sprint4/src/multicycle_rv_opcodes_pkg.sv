// This package categorizes instructions using their opcode according to the states the FSM can go to from DECODE 
package multicycle_rv_opcodes_pkg;

  typedef enum logic [6:0] {
    R_TYPE_OP  = 7'b0110011,   // R
    I_TYPE_OP  = 7'b0010011,   // I
    I_LOAD_OP  = 7'b0000011,   // I
    S_OP       = 7'b0100011,   // S
    B_OP       = 7'b1100011,   // B
    J_OP       = 7'b1101111,   // J
    I_JUMP_OP  = 7'b1100111,   // Not a state. Corresponds to jalr which has a unique opcode.
    LUI_OP     = 7'b0110111    // U
    //, AUIPC_OP   = 7'b0010111
  } multicycle_rv_opcode;

endpackage