package alu_types_pkg;

  typedef enum logic [2:0] {
    ADD,
    SUB,
    AND,
    OR,
    XOR,
    SLL,
    SRL,
    SRA
  } alu_op_t;

  typedef struct packed {
    logic zero;
    logic carry;
    logic negative;
    logic overflow;
  } alu_flags_t;

endpackage
