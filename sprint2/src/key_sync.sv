module key_sync (
    input  logic clk,
    input  logic key_raw,
    input  logic key0_raw,
    output logic key_pulse,
    output logic reset_n
);

    logic sync_ff1, sync_ff2, sync_ff3;
    logic reset_ff1, reset_ff2;

    always_ff @(posedge clk) begin
        sync_ff1 <= key_raw;
        sync_ff2 <= sync_ff1;
        sync_ff3 <= sync_ff2;
    end

    assign key_pulse = sync_ff2 & ~sync_ff3;

    always_ff @(posedge clk or negedge key0_raw) begin
        if (!key0_raw) begin
            reset_ff1 <= 1'b0;
            reset_ff2 <= 1'b0;
        end else begin
            reset_ff1 <= 1'b1;
            reset_ff2 <= reset_ff1;
        end
    end

    assign reset_n = reset_ff2;

endmodule