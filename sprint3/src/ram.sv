`default_nettype none

module ram (
    input  wire logic        clk,
    // Puerto A (vJTAG y FSM)
    input  wire logic [14:0] addr_a,
    input  wire logic [31:0] data_in_a,
    input  wire logic        we_a,
    input  wire logic        re_a,
    output logic [31:0] data_out_a,
    // Puerto B para diseno incremental
    input  wire logic [14:0] addr_b,
    input  wire logic [31:0] data_in_b,
    input  wire logic        we_b,
    input  wire logic        re_b,
    output logic [31:0] data_out_b
);
    // Hay 128 * 128 pixeles en una imagen. Se almacena un pixel por palabra.
    // Las palabras son de 32 bits
    // Hay dos imagenes ->
    // 32768 palabras x 32 bits = 128KB
    logic [31:0] mem [0:32767];

    always_ff @(posedge clk) begin
        // Puerto A
        if (we_a) begin
            mem[addr_a] <= data_in_a;
        end
        if (re_a) begin
            data_out_a <= mem[addr_a];
        end else begin
            data_out_a <= 32'h0;
        end

        // Puerto B
        if (we_b) begin
            mem[addr_b] <= data_in_b;   // El puerto B tiene prioridad de escritura
        end
        if (re_b) begin
            data_out_b <= mem[addr_b];
        end else begin
            data_out_b <= 32'h0;
        end
    end


endmodule