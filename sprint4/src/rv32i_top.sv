// Top de integracion del Sprint 4 (Avance 2).
//
//   Host vJTAG ----\
//                   arbiter --> mmio_decoder --> ram (instr, in, out, hist)
//   CPU (datos) ---/                         \-> control_registers (LEDR, HEX, CTRL, STATUS, THRESHOLD)
//
//   CPU (instrucciones) ------------------------> ram (puerto de instrucciones, directo)
//
// CTRL[0] (start) es el soft_reset_n del CPU y cpu_enable = start && !done congela
// el CPU cuando el firmware escribe STATUS.done = 1.
module rv32i_top
(
    input  logic        clk,
    input  logic        rst_n,

    // Host vJTAG (manager)
    input  logic        vjtag_valid,
    input  logic [31:0] vjtag_addr,
    input  logic [31:0] vjtag_data,
    input  logic        vjtag_write_en,
    output logic        vjtag_ready,
    output logic [31:0] vjtag_rdata,

    // Perifericos y estado
    output logic [9:0]  ledr,
    output logic [23:0] hex,
    output logic        busy,
    output logic        done,

    // Depuracion (para pruebas y SignalTap)
    output logic [31:0] pc,
    output logic [31:0] instruction,
    output logic        handshake_instr,
    output logic        illegal
);

    // CPU: bus de instrucciones (directo a la RAM)
    logic        imem_valid;
    logic        imem_ready;
    logic [31:0] imem_rdata;

    // CPU: bus de datos (hacia el arbiter)
    logic        cpu_valid;
    logic        cpu_ready;
    logic        cpu_write_en;
    logic [31:0] cpu_addr;
    logic [31:0] cpu_wdata;

    // Bus de datos arbitrado
    logic        bus_valid;
    logic        bus_ready;
    logic        bus_write_en;
    logic        bus_is_cpu;
    logic [31:0] bus_addr;
    logic [31:0] bus_wdata;
    logic [31:0] bus_rdata;

    // Control del CPU (desde control_registers)
    logic        start;
    logic        cpu_enable;

    // Habilitaciones del mmio_decoder
    logic        re_instr, re_in, re_out, re_hist;
    logic        we_instr, we_in, we_out, we_hist;
    logic        we_ledr, we_hex, we_ctrl, we_status, we_threshold;

    // rdata de los subordinados
    logic [31:0] instr_rdata, in_rdata, out_rdata, hist_rdata, reg_rdata;

    multicycle_rv32i cpu
    (
        .clk(clk),
        .rst_n(rst_n),

        .enable(cpu_enable),
        .soft_reset_n(start),

        .ready_in_instr_memory(imem_ready),
        .ready_in_data_memory(cpu_ready),

        .valid_out_instr_memory(imem_valid),
        .valid_out_data_memory(cpu_valid),

        .handshake_instr_memory(handshake_instr),
        .handshake_data_memory(),

        .address_instr_memory(pc),
        .read_data_instr_memory(imem_rdata),

        .write_enable_data_memory(cpu_write_en),
        .address_data_memory(cpu_addr),
        .write_data_data_memory(cpu_wdata),
        .read_data_data_memory(bus_rdata),

        .instruction(instruction),
        .illegal(illegal)
    );

    // Los puertos fsm_* del arbiter son los del CPU (nombre heredado del Sprint 3).
    arbiter arbiter_inst
    (
        .clk(clk),
        .rst_n(rst_n),

        .vjtag_valid(vjtag_valid),
        .vjtag_addr(vjtag_addr),
        .vjtag_data(vjtag_data),
        .vjtag_write_en(vjtag_write_en),
        .vjtag_ready(vjtag_ready),

        .fsm_valid(cpu_valid),
        .fsm_addr(cpu_addr),
        .fsm_data(cpu_wdata),
        .fsm_write_en(cpu_write_en),
        .fsm_ready(cpu_ready),

        .subordinate_ready(bus_ready),
        .mux_addr(bus_addr),
        .mux_data(bus_wdata),
        .mux_write_en(bus_write_en),
        .mux_valid(bus_valid),
        .mux_is_cpu(bus_is_cpu)
    );

    mmio_decoder mmio_decoder_inst
    (
        .clk(clk),
        .rst_n(rst_n),

        .addr(bus_addr),
        .valid(bus_valid),
        .write_en(bus_write_en),
        .is_cpu(bus_is_cpu),
        .ready(bus_ready),
        .rdata(bus_rdata),

        .re_instr(re_instr),
        .re_in(re_in),
        .re_out(re_out),
        .re_hist(re_hist),

        .we_instr(we_instr),
        .we_in(we_in),
        .we_out(we_out),
        .we_hist(we_hist),
        .we_ledr(we_ledr),
        .we_hex(we_hex),
        .we_ctrl(we_ctrl),
        .we_status(we_status),
        .we_threshold(we_threshold),

        .instr_rdata(instr_rdata),
        .in_rdata(in_rdata),
        .out_rdata(out_rdata),
        .hist_rdata(hist_rdata),
        .reg_rdata(reg_rdata)
    );

    ram ram_inst
    (
        .clk(clk),
        .rst_n(rst_n),

        .addr(bus_addr),
        .data_in(bus_wdata),

        .we_instr(we_instr),
        .re_instr(re_instr),
        .instr_rdata(instr_rdata),

        .we_in(we_in),
        .re_in(re_in),
        .in_rdata(in_rdata),

        .we_out(we_out),
        .re_out(re_out),
        .out_rdata(out_rdata),

        .we_hist(we_hist),
        .re_hist(re_hist),
        .hist_rdata(hist_rdata),

        .imem_valid(imem_valid),
        .imem_addr(pc),
        .imem_ready(imem_ready),
        .imem_rdata(imem_rdata)
    );

    control_registers control_registers_inst
    (
        .clk(clk),
        .reset_n(rst_n),

        .write_data(bus_wdata),
        .mmio_address(bus_addr),

        .we_ledr(we_ledr),
        .we_hex(we_hex),
        .we_ctrl(we_ctrl),
        .we_status(we_status),
        .we_threshold(we_threshold),

        .selected_register(reg_rdata),

        .start(start),
        .cpu_enable(cpu_enable),
        .busy(busy),
        .done(done),

        .threshold(),
        .ledr(ledr),
        .hex(hex)
    );

    // El Host lee por el mismo rdata que el CPU
    assign vjtag_rdata = bus_rdata;

endmodule