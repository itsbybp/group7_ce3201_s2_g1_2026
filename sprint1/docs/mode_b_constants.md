# mode_b_constants

## Purpose

Returns an 8-bit constant corresponding to an opcode as described in the design specs.

## Interface

| Signal                      | Direction | Width |
|-----------------------------|-----------|-------|
| `control`                   | Input     | 3 |
| `alu_b_multiplexed_operand` | Output    | 8 |

## Internal Architecture
```mermaid
graph TD
    OP[opcode]

    CASE["unique case"]

    ConstFF["8'hFF"]
    Const01["8'h01"]
    ConstAA["8'hAA"]
    Const55["8'h55"]
    Const0F["8'h0F"]
    Const04["8'h04"]
    Const02["8'h02"]
    Const03["8'h03"]

    OP --> CASE
    CASE --> ADD
    CASE --> SUB
    CASE --> AND
    CASE --> OR
    CASE --> XOR
    CASE --> SLL
    CASE --> SRL
    CASE --> SRA

    ADD --> ConstFF
    SUB --> Const01
    AND --> ConstAA
    OR --> Const55
    XOR --> Const0F
    SLL --> Const04
    SRL --> Const02
    SRA --> Const03

    
    ConstFF --> out
    Const01 --> out
    ConstAA --> out
    Const55 --> out
    Const0F --> out
    Const04 --> out
    Const02 --> out
    Const03 --> out
```

## Submodule Instantiation
### Constants Mux
```sv
  // Define ALU B multiplexed operand
  always_comb begin
  unique case (alu_op_t'(control))   
    ADD: alu_b_multiplexed_operand = 8'hFF;
    SUB: alu_b_multiplexed_operand = 8'h01;
    AND: alu_b_multiplexed_operand = 8'hAA;
    OR:  alu_b_multiplexed_operand = 8'h55;
    XOR: alu_b_multiplexed_operand = 8'h0F;
    SLL: alu_b_multiplexed_operand = 8'h04;
    SRL: alu_b_multiplexed_operand = 8'h02;
    SRA: alu_b_multiplexed_operand = 8'h03;
    default: alu_b_multiplexed_operand = 8'h00; 
  endcase
  end
```
