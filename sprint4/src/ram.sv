`default_nettype none

// Memorias del Sprint 4 (Tabla 2). Lectura sincronica de 1 ciclo (M10K).
//
//   instr: 2048 palabras (8 KB).  Puerto de datos (Host R/W) + puerto de instrucciones
//          de la CPU (solo lectura, directo, sin pasar por el arbiter).
//   in:    16384 palabras, imagen de entrada.
//   out:   16384 palabras, imagen binarizada.
//   hist:  256 palabras, histograma.
//
// Los permisos por maestro ya vienen aplicados en we_* (los filtra el mmio_decoder).
module ram (
    input  wire logic        clk,
    input  wire logic        rst_n,

    // Bus de datos (arbitrado y decodificado)
    // verilator lint_off UNUSEDSIGNAL
    input  wire logic [31:0] addr,     // solo se usan los bits [15:2]
    // verilator lint_on UNUSEDSIGNAL
    input  wire logic [31:0] data_in,

    input  wire logic        we_instr,
    input  wire logic        re_instr,
    output logic [31:0]      instr_rdata,

    input  wire logic        we_in,
    input  wire logic        re_in,
    output logic [31:0]      in_rdata,

    input  wire logic        we_out,
    input  wire logic        re_out,
    output logic [31:0]      out_rdata,

    input  wire logic        we_hist,
    input  wire logic        re_hist,
    output logic [31:0]      hist_rdata,

    // Bus de instrucciones de la CPU (solo lectura)
    input  wire logic        imem_valid,
    // verilator lint_off UNUSEDSIGNAL
    input  wire logic [31:0] imem_addr, // solo se usan los bits [12:2]
    // verilator lint_on UNUSEDSIGNAL
    output logic             imem_ready,
    output logic [31:0]      imem_rdata
);

    localparam int INSTR_WORDS = 2048;
    localparam int IMG_WORDS   = 16384;
    localparam int HIST_WORDS  = 256;

    logic [31:0] mem_instr [0:INSTR_WORDS-1];
    logic [31:0] mem_in    [0:IMG_WORDS-1];
    logic [31:0] mem_out   [0:IMG_WORDS-1];
    logic [31:0] mem_hist  [0:HIST_WORDS-1];

    logic [10:0] instr_addr;
    logic [13:0] img_addr;
    logic [7:0]  hist_addr;
    logic [10:0] imem_word_addr;

    assign instr_addr     = addr[12:2];
    assign img_addr       = addr[15:2];
    assign hist_addr      = addr[9:2];
    assign imem_word_addr = imem_addr[12:2];

    // Puerto de datos de la RAM de instrucciones (Host)
    always_ff @(posedge clk) begin
        if (we_instr) begin
            mem_instr[instr_addr] <= data_in;
        end
        if (re_instr) begin
            instr_rdata <= mem_instr[instr_addr];
        end
    end

    // Puerto de instrucciones (CPU, solo lectura)
    always_ff @(posedge clk) begin
        if (imem_valid) begin
            imem_rdata <= mem_instr[imem_word_addr];
        end
    end

    // ready del bus de instrucciones: un ciclo despues de valid (latencia de la M10K)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_ready <= 1'b0;
        end else begin
            imem_ready <= imem_valid && !imem_ready;
        end
    end

    // Imagen de entrada
    always_ff @(posedge clk) begin
        if (we_in) begin
            mem_in[img_addr] <= data_in;
        end
        if (re_in) begin
            in_rdata <= mem_in[img_addr];
        end
    end

    // Imagen de salida
    always_ff @(posedge clk) begin
        if (we_out) begin
            mem_out[img_addr] <= data_in;
        end
        if (re_out) begin
            out_rdata <= mem_out[img_addr];
        end
    end

    // Histograma
    always_ff @(posedge clk) begin
        if (we_hist) begin
            mem_hist[hist_addr] <= data_in;
        end
        if (re_hist) begin
            hist_rdata <= mem_hist[hist_addr];
        end
    end

endmodule

`default_nettype wire
