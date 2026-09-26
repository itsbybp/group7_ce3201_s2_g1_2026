module toggle (
    input logic clk,
    input logic reset,
    
    input logic enable, // enable must be a synchronous pulse.
    output logic out
);
    always_ff @(posedge clk or negedge reset)
    begin
        if (~reset) begin
            out <= 1'b0;
        end
        else if (enable) begin
            out <= ~out;
        end
    end
endmodule

// // async toggle
// module toggle (
//     input logic enable,
//     output logic out
// );
//     always_ff @(posedge enable)
//     begin
//         out <= ~out;
//     end
// endmodule
