module register_bank #(
    parameter int WIDTH = 16
) (
    input  logic             clk,
    input  logic             reset_n,

    input  logic [1:0]       rd,
    input  logic [1:0]       rs1,
    input  logic [1:0]       rs2,

    input  logic             write_en,
    input  logic [WIDTH-1:0] write_data,

    output logic [WIDTH-1:0] rs1_data,
    output logic [WIDTH-1:0] rs2_data
);

    localparam logic [WIDTH-1:0] X0_CONST = '0;

    logic [WIDTH-1:0] x1_q;
    logic [WIDTH-1:0] x2_q;
    logic [WIDTH-1:0] x3_q;

    logic we_x1;
    logic we_x2;
    logic we_x3;

    assign we_x1 = write_en & (rd == 2'b01);
    assign we_x2 = write_en & (rd == 2'b10);
    assign we_x3 = write_en & (rd == 2'b11);

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            x1_q <= '0;
        end else if (we_x1) begin
            x1_q <= write_data;
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            x2_q <= '0;
        end else if (we_x2) begin
            x2_q <= write_data;
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            x3_q <= '0;
        end else if (we_x3) begin
            x3_q <= write_data;
        end
    end

    always_comb begin
        case (rs1)
            2'b00:   rs1_data = X0_CONST;
            2'b01:   rs1_data = x1_q;
            2'b10:   rs1_data = x2_q;
            2'b11:   rs1_data = x3_q;
            default: rs1_data = X0_CONST;
        endcase
    end

    always_comb begin
        case (rs2)
            2'b00:   rs2_data = X0_CONST;
            2'b01:   rs2_data = x1_q;
            2'b10:   rs2_data = x2_q;
            2'b11:   rs2_data = x3_q;
            default: rs2_data = X0_CONST;
        endcase
    end

endmodule