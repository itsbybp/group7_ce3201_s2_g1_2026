module top_level (
    input  logic        CLOCK_50,
    input  logic [9:0]  SW,
    input  logic [3:0]  KEY,

    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1,
    output logic [6:0]  HEX2,
    output logic [6:0]  HEX3,
    output logic [6:0]  HEX4,
    output logic [6:0]  HEX5
);

    logic reset_n;
    logic key1_pulse;
    logic key2_pulse;
    logic reset_n_unused_1;

    key_sync u_key_sync_1 (
        .clk       (CLOCK_50),
        .key_raw   (KEY[1]),
        .key0_raw  (KEY[0]),
        .key_pulse (key1_pulse),
        .reset_n   (reset_n)
    );

    key_sync u_key_sync_2 (
        .clk       (CLOCK_50),
        .key_raw   (KEY[2]),
        .key0_raw  (KEY[0]),
        .key_pulse (key2_pulse),
        .reset_n   (reset_n_unused_1)
    );

    logic write_en_tmp;
    assign write_en_tmp = key2_pulse;

    logic [1:0] rd_tmp;
    logic [1:0] rs1_tmp;
    logic [1:0] rs2_tmp;
    assign rd_tmp  = SW[5:4];
    assign rs1_tmp = SW[3:2];
    assign rs2_tmp = SW[1:0];

    logic [15:0] write_data_tmp;
    assign write_data_tmp = {6'b0, SW};

    logic [15:0] rs1_data;
    logic [15:0] rs2_data;

    register_bank #(
        .WIDTH(16)
    ) u_register_bank (
        .clk        (CLOCK_50),
        .reset_n    (reset_n),
        .rd         (rd_tmp),
        .rs1        (rs1_tmp),
        .rs2        (rs2_tmp),
        .write_en   (write_en_tmp),
        .write_data (write_data_tmp),
        .rs1_data   (rs1_data),
        .rs2_data   (rs2_data)
    );

    assign LEDR = {8'b0, rs1_data[1:0]};
    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;

endmodule