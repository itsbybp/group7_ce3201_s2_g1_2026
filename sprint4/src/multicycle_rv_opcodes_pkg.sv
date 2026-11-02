// This package categorizes instructions using their opcode according to the states the FSM can go to from DECODE 
package multicycle_rv_opcodes_pkg;

  typedef enum logic [6:0] {
    R_TYPE  = 7'b0110011,   // R
    I_TYPE  = 7'b0010011,   // I
    I_LOAD  = 7'b0000011,   // I
    S       = 7'b0100011,   // S
    B       = 7'b1100011,   // B
    J       = 7'b1101111,   // J
    // I_JUMP  = 7'b1100111,
    LUI     = 7'b0110111    // U
    //, AUIPC   = 7'b0010111
  } multicycle_rv_opcode;

endpackage