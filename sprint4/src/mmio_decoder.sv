`default_nettype none

// Decodificador MMIO del Sprint 4 (Tabla 2 del enunciado).
//
// - Decodifica la direccion del bus de datos (ya arbitrado entre Host vJTAG y CPU).
// - Aplica los permisos por maestro: la escritura prohibida se descarta (Write-Ignored).
// - Direcciones no mapeadas: lectura devuelve 0 (Read-As-Zero) y la escritura se descarta.
// - Latencia de lectura fija de 1 ciclo (M10K sincronica): ready sube un ciclo
//   despues de valid en lecturas y en el mismo ciclo en escrituras.
// - Requiere que el maestro mantenga valid y la direccion estables hasta ready.
module mmio_decoder (
    input  wire logic        clk,
    input  wire logic        rst_n,

    // Bus de datos arbitrado
    input  wire logic [31:0] addr,
    input  wire logic        valid,
    input  wire logic        write_en,
    input  wire logic        is_cpu,       // 1 = CPU, 0 = Host vJTAG (lo entrega el arbiter)
    output logic             ready,
    output logic [31:0]      rdata,

    // Habilitacion de lectura de las RAM
    output logic             re_instr,
    output logic             re_in,
    output logic             re_out,
    output logic             re_hist,

    // Habilitacion de escritura, ya filtrada por permisos
    output logic             we_instr,
    output logic             we_in,
    output logic             we_out,
    output logic             we_hist,
    output logic             we_ledr,
    output logic             we_hex,
    output logic             we_ctrl,
    output logic             we_status,
    output logic             we_threshold,

    // rdata de los subordinados
    input  wire logic [31:0] instr_rdata,
    input  wire logic [31:0] in_rdata,
    input  wire logic [31:0] out_rdata,
    input  wire logic [31:0] hist_rdata,
    input  wire logic [31:0] reg_rdata     // LEDR, HEX, CTRL, STATUS y THRESHOLD
);

    // Mapa de memoria (Tabla 2). La RAM de instrucciones empieza en 0x0000_0000.
    localparam logic [31:0] INSTR_RAM_LAST = 32'h0000_1FFF;
    localparam logic [31:0] IN_RAM_BASE    = 32'h0001_0000;
    localparam logic [31:0] IN_RAM_LAST    = 32'h0001_FFFF;
    localparam logic [31:0] OUT_RAM_BASE   = 32'h0002_0000;
    localparam logic [31:0] OUT_RAM_LAST   = 32'h0002_FFFF;
    localparam logic [31:0] HIST_RAM_BASE  = 32'h0003_0000;
    localparam logic [31:0] HIST_RAM_LAST  = 32'h0003_03FC;
    localparam logic [31:0] ADDR_LEDR      = 32'h0004_0000;
    localparam logic [31:0] ADDR_HEX       = 32'h0004_0004;
    localparam logic [31:0] ADDR_CTRL      = 32'h0005_0000;
    localparam logic [31:0] ADDR_STATUS    = 32'h0005_0004;
    localparam logic [31:0] ADDR_THRESHOLD = 32'h0005_000C;

    typedef enum logic [2:0] {
        SEL_NONE  = 3'd0,
        SEL_INSTR = 3'd1,
        SEL_IN    = 3'd2,
        SEL_OUT   = 3'd3,
        SEL_HIST  = 3'd4,
        SEL_REG   = 3'd5
    } sel_t;

    sel_t sel;
    sel_t sel_q;

    logic is_host;
    logic wr;
    logic rd;

    assign is_host = ~is_cpu;
    assign wr      = valid && write_en;
    assign rd      = valid && !write_en;

    // Decodificacion de rango (combinacional)
    always_comb begin
        sel = SEL_NONE;
        if (addr <= INSTR_RAM_LAST) begin
            sel = SEL_INSTR;
        end else if (addr >= IN_RAM_BASE && addr <= IN_RAM_LAST) begin
            sel = SEL_IN;
        end else if (addr >= OUT_RAM_BASE && addr <= OUT_RAM_LAST) begin
            sel = SEL_OUT;
        end else if (addr >= HIST_RAM_BASE && addr <= HIST_RAM_LAST) begin
            sel = SEL_HIST;
        end else if (addr == ADDR_LEDR || addr == ADDR_HEX ||
                     addr == ADDR_CTRL || addr == ADDR_STATUS || addr == ADDR_THRESHOLD) begin
            sel = SEL_REG;
        end
    end

    // Lecturas: todas las regiones mapeadas son legibles por ambos maestros (RO o R/W)
    assign re_instr = rd && (sel == SEL_INSTR);
    assign re_in    = rd && (sel == SEL_IN);
    assign re_out   = rd && (sel == SEL_OUT);
    assign re_hist  = rd && (sel == SEL_HIST);

    // Escrituras con permisos de la Tabla 2 (el maestro sin permiso queda en Write-Ignored)
    assign we_instr     = wr && (sel == SEL_INSTR) && is_host;
    assign we_in        = wr && (sel == SEL_IN)    && is_host;
    assign we_out       = wr && (sel == SEL_OUT)   && is_cpu;
    assign we_hist      = wr && (sel == SEL_HIST)  && is_cpu;
    assign we_ledr      = wr && (addr == ADDR_LEDR);
    assign we_hex       = wr && (addr == ADDR_HEX);
    assign we_ctrl      = wr && (addr == ADDR_CTRL)      && is_host;
    assign we_status    = wr && (addr == ADDR_STATUS)    && is_cpu;
    assign we_threshold = wr && (addr == ADDR_THRESHOLD) && is_host;

    // ready: escritura en el mismo ciclo; lectura un ciclo despues (latencia de la M10K)
    logic pending_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_q <= 1'b0;
        end else begin
            pending_q <= rd && !pending_q;
        end
    end

    assign ready = valid && (write_en || pending_q);

    // sel registrado: alinea el mux de lectura con el dato sincronico de la RAM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sel_q <= SEL_NONE;
        end else begin
            sel_q <= sel;
        end
    end

    // Mux de rdata (RAZ para direcciones no mapeadas)
    always_comb begin
        case (sel_q)
            SEL_INSTR: rdata = instr_rdata;
            SEL_IN:    rdata = in_rdata;
            SEL_OUT:   rdata = out_rdata;
            SEL_HIST:  rdata = hist_rdata;
            SEL_REG:   rdata = reg_rdata;
            default:   rdata = 32'h0;
        endcase
    end

endmodule

`default_nettype wire
