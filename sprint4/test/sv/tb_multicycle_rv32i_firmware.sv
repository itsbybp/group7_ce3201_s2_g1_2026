`timescale 1ns/1ps

// Testbench de sistema: ejecuta firmware.hex en multicycle_rv32i.
//
// Modelo de memoria (latencia de un ciclo):
//   - Instrucciones: ready_in_instr_memory sube un ciclo despues de que
//     valid_out_instr_memory se enciende.
//   - Datos: ready_in_data_memory sube un ciclo despues de que
//     valid_out_data_memory se enciende.
//   - Ambos ready se bajan en el ciclo siguiente al handshake.
//
// enable = 1 y soft_reset_n = 1 durante toda la simulacion.
// Este testbench se utiliza exclusivamente para generar waveforms.

module tb_multicycle_rv32i_firmware;

    // Ruta al programa. Se sobreescribe desde el .do con -GFIRMWARE_HEX=<ruta>
    parameter string FIRMWARE_HEX = "firmware.hex";

    localparam int CLK_PERIOD   = 10;
    localparam int RUN_CYCLES   = 4000;
    localparam int IMEM_WORDS   = 256;
    localparam int DMEM_WORDS   = 262144;   // indexado por addr[19:2]

    // ---------------- Señales ----------------
    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        enable = 1'b1;
    logic        soft_reset_n = 1'b1;

    logic        ready_in_instr_memory = 1'b0;
    logic        ready_in_data_memory  = 1'b0;

    logic        valid_out_instr_memory;
    logic        valid_out_data_memory;
    logic        handshake_instr_memory;
    logic        handshake_data_memory;

    logic [31:0] address_instr_memory;
    logic [31:0] read_data_instr_memory;

    logic        write_enable_data_memory;
    logic [31:0] address_data_memory;
    logic [31:0] write_data_data_memory;
    logic [31:0] read_data_data_memory;

    logic [31:0] instruction;
    logic [3:0]  state_num;
    logic        illegal;

    // Memorias del modelo
    logic [31:0] imem [0:IMEM_WORDS-1];
    logic [31:0] dmem [0:DMEM_WORDS-1];

    always #(CLK_PERIOD/2) clk = ~clk;

    multicycle_rv32i dut (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .enable                   (enable),
        .soft_reset_n             (soft_reset_n),
        .ready_in_instr_memory    (ready_in_instr_memory),
        .ready_in_data_memory     (ready_in_data_memory),
        .valid_out_instr_memory   (valid_out_instr_memory),
        .valid_out_data_memory    (valid_out_data_memory),
        .handshake_instr_memory   (handshake_instr_memory),
        .handshake_data_memory    (handshake_data_memory),
        .address_instr_memory     (address_instr_memory),
        .read_data_instr_memory   (read_data_instr_memory),
        .write_enable_data_memory (write_enable_data_memory),
        .address_data_memory      (address_data_memory),
        .write_data_data_memory   (write_data_data_memory),
        .read_data_data_memory    (read_data_data_memory),
        .instruction              (instruction),
        .state_num                (state_num),
        .illegal                  (illegal)
    );

    // ---------------- Carga del programa ----------------
    initial begin
        for (int i = 0; i < DMEM_WORDS; i++) dmem[i] = 32'h0;
        for (int i = 0; i < IMEM_WORDS; i++) imem[i] = 32'h0;
        $readmemh(FIRMWARE_HEX, imem);
    end

    // ---------------- Memoria de instrucciones ----------------
    assign read_data_instr_memory = imem[address_instr_memory[9:2]];

    always_ff @(posedge clk) begin
        if (!rst_n) ready_in_instr_memory <= 1'b0;
        else        ready_in_instr_memory <= valid_out_instr_memory && !ready_in_instr_memory;
    end

    // ---------------- Memoria de datos ----------------
    assign read_data_data_memory = dmem[address_data_memory[19:2]];

    always_ff @(posedge clk) begin
        if (!rst_n) ready_in_data_memory <= 1'b0;
        else        ready_in_data_memory <= valid_out_data_memory && !ready_in_data_memory;
    end

    always @(posedge clk) begin
        if (handshake_data_memory && write_enable_data_memory)
            dmem[address_data_memory[19:2]] <= write_data_data_memory;
    end

    // ---------------- Secuencia principal ----------------
    initial begin
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        repeat (RUN_CYCLES) @(posedge clk);

        $finish;
    end

endmodule






