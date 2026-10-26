module counter
(
    input  logic clk,
    input  logic reset_n,

    input logic clear,
    input logic increase,
    input logic [31:0] timer_limit,
    output logic timeout
);
    logic [31:0] count;

    // Greater than or equal is used because timer_limit may be set below count through a JTAG write during the count.
    // count != is necessary for the counter not to output timeout on reset_n = 0.
    assign timeout = count >= timer_limit && count != '0;  

        always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count <= '0;
        end else if (clear) begin
            count <= '0;
        end else if (increase && !timeout) begin
            count <= count + 1'b1;
        end
    end

endmodule