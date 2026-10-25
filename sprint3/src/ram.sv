`default_nettype none

module ram (
    input  wire logic        clk,
    // Puerto A -> buffer de entrada (0x00000-0x0FFFF, 64 KB)
    input  wire logic [13:0] addr_a,
    input  wire logic [31:0] data_in_a,
    input  wire logic        we_a,
    input  wire logic        re_a,
    output logic [31:0]      data_out_a,
    // Puerto B -> buffer de salida (0x10000-0x1FFFF, 64 KB)
    input  wire logic [13:0] addr_b,
    input  wire logic [31:0] data_in_b,
    input  wire logic        we_b,
    input  wire logic        re_b,
    output logic [31:0]      data_out_b
);
    logic [31:0] mem_in  [0:16383];
    logic [31:0] mem_out [0:16383];

    always_ff @(posedge clk) begin
        if (we_a) mem_in[addr_a] <= data_in_a;
        if (re_a) data_out_a     <= mem_in[addr_a];
    end

    always_ff @(posedge clk) begin
        if (we_b) mem_out[addr_b] <= data_in_b;
        if (re_b) data_out_b      <= mem_out[addr_b];
    end

endmodule