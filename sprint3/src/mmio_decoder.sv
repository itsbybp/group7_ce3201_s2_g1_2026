`default_nettype none

module mmio_decoder (
    input  wire logic        clk,
    input  wire logic        rst_n,

    // Solo lo que el decoder necesita para decidir
    input  wire logic [31:0] addr,
    input  wire logic        valid,
    output logic             ready,
    output logic [31:0]      rdata,

    // Chip-selects
    // Chip selects are targeted valid signals. 
    output logic             cs_ram,
    output logic             cs_rb,
    output logic             cs_ledr,
    output logic             cs_hex,
    output logic             cs_cr, // CR refers to the control_registers module.

    // rdata de subordinates
    input  wire logic [31:0] ram_rdata,
    input  wire logic [31:0] rb_rdata,
    input  wire logic [31:0] cr_rdata
);

    typedef enum logic [2:0] {
        SEL_NONE = 3'd0,
        SEL_RAM  = 3'd1,
        SEL_RB   = 3'd2,
        SEL_IO   = 3'd3,
        SEL_CR   = 3'd4
    } sel_t;

    sel_t sel, sel_q;

    // --- Decodificacion de rango (combinacional) ---
    always_comb begin
        if (addr <= 32'h0001FFFF)                              sel = SEL_RAM;
        else if (addr >= 32'h00020000 && addr <= 32'h0002007C) sel = SEL_RB;
        else if (addr == 32'h00030000 || addr == 32'h00030004) sel = SEL_IO;
        else if (addr >= 32'h00040000 && addr <= 32'h0004000C) sel = SEL_CR;
        else                                                    sel = SEL_NONE;
    end

    // --- Chip-selects ---
    always_comb begin
        cs_ram  = (sel == SEL_RAM) && valid;
        cs_rb   = (sel == SEL_RB)  && valid;
        cs_ledr = (sel == SEL_IO) && valid && (addr == 32'h00030000);
        cs_hex  = (sel == SEL_IO) && valid && (addr == 32'h00030004);
        cs_cr   = (sel == SEL_CR)  && valid;
    end

    // --- ready: acepta en el mismo ciclo (SEL_NONE = 1, evita bloqueo AC7) ---
    assign ready = valid;

    // --- sel_q registrado para mux de lectura sincronica ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) sel_q <= SEL_NONE;
        else        sel_q <= sel;
    end

    // --- Mux de rdata (RAZ para IO write-only y NONE) ---
    always_comb begin
        case (sel_q)
            SEL_RAM: rdata = ram_rdata;
            SEL_RB:  rdata = rb_rdata;
            SEL_CR:  rdata = cr_rdata;
            default: rdata = 32'h0;
        endcase
    end

endmodule 