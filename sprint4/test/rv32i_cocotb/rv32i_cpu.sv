module rv32i_cpu
(
    input logic clk,
    input logic reset,
    output logic imem_valid,
    input logic imem_ready,
    output logic [31:0] imem_addr,
    input logic [31:0] imem_rdata,
    output logic dmem_valid,
    input logic dmem_ready,
    output logic [31:0] dmem_addr,
    output logic dmem_we,
    output logic [31:0] dmem_wdata,
    input logic [31:0] dmem_rdata,
    output logic illegal_instruction
);

    import alu_types_pkg::*;
    import multicycle_rv_opcodes_pkg::*;
    import multicycle_rv_instruction_formats_pkg::*;

    // Instantiate the actual multicycle rv32i.
    logic enable;
    assign enable = 1'b1;
    logic soft_reset_n;
    assign soft_reset_n = 1'b1;
    multicycle_rv32i dutcito
    (
        .clk(clk),
        .rst_n(~reset), // Invert reset because the testbench expects an active high reset.

        .enable(enable), 
        .soft_reset_n(soft_reset_n), 

        // Ready valid inputs
        .ready_in_instr_memory(imem_ready),
        .ready_in_data_memory(dmem_ready),

        // Ready valid outputs
        .valid_out_instr_memory(imem_valid),
        .valid_out_data_memory(dmem_valid),

        // Handshakes. Display these.
        .handshake_instr_memory(),
        .handshake_data_memory(),

        // Instruction memory
        .address_instr_memory(imem_addr),
        .read_data_instr_memory(imem_rdata),

        // Data memory
        .write_enable_data_memory(dmem_we),
        .address_data_memory(dmem_addr),
        .write_data_data_memory(dmem_wdata),
        .read_data_data_memory(dmem_rdata),

        // Display
        .instruction(),

        // Tests
        .illegal(illegal_instruction)
    );

endmodule