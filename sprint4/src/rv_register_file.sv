module rv_register_file #(
    parameter int WIDTH = 32
) (
    input  logic             clk,
    input  logic             rst_n,

    input  logic [4:0]       rs1,
    input  logic [4:0]       rs2,
    input  logic [4:0]       rd,

    input  logic             write_en,
    input  logic [WIDTH-1:0] write_data,

    output logic [WIDTH-1:0] rs1_data,
    output logic [WIDTH-1:0] rs2_data
);

    logic [WIDTH-1:0] registers [31:1]; // An x0 register is not instantiated.

    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (
                i = 1; 
                i < 32; 
                i = i + 1
            ) begin
                registers[i] <= '0;
            end
        end else if (write_en && (rd != '0)) begin
            registers[rd] <= write_data;
        end
    end

    always_comb begin
        if (rs1 == '0) begin
            rs1_data = '0;
        end else begin
            rs1_data = registers[rs1];
        end

        if (rs2 == '0) begin
            rs2_data = '0;
        end else begin
            rs2_data = registers[rs2];
        end
    end

endmodule