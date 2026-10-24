`default_nettype none

module top_level (
    input  logic        CLOCK_50,
    input  logic [1:0]  SW,
    input  logic [0:0]  KEY,
    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);
import alu_types_pkg::*;

    // Reloj, reset y nets compartidos del bus
    logic        clk, rst_n, soft_rst_q, core_rst_n;
    logic [31:0] mux_addr, mux_data, mmio_rdata, ram_rdata, rb_rdata, cr_rdata;
    logic        mux_write_en, mux_valid, mmio_ready, cs_ram, cs_rb, cs_ledr, cs_hex, cs_cr;
    logic        we_cr, we_ledr, we_hex;

    assign clk     = CLOCK_50;
    assign we_cr   = cs_cr   & mux_write_en;
    assign we_ledr = cs_ledr & mux_write_en;
    assign we_hex  = cs_hex  & mux_write_en;

    // Reset: asserta asincrono y libera sincrono (evita usar KEY[0] como reloj global)
    key_sync u_key_sync (.clk(clk), .key_raw(1'b0), .key0_raw(KEY[0]), .key_pulse(), .reset_n(rst_n));

    // soft_reset (CTRL[1]): pulso de 1 ciclo que reinicia FSM, timer y registros de control (no la RAM)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) soft_rst_q <= 1'b0;
        else        soft_rst_q <= we_cr && mux_addr[3:2] == 2'b00 && mux_data[1];
    end

    assign core_rst_n = rst_n & ~soft_rst_q;

    // vJTAG (dominio tck)
    logic       tck_w, tdi_w, tdo_w;
    logic [1:0] ir_in_w;
    logic       v_cdr_w, v_sdr_w, v_udr_w;

    vjtag vjtag_inst (
        .tdi(tdi_w), .tdo(tdo_w), .ir_in(ir_in_w), .ir_out(2'b00),
        .virtual_state_cdr(v_cdr_w), .virtual_state_sdr(v_sdr_w), .virtual_state_udr(v_udr_w),
        .virtual_state_e1dr(), .virtual_state_pdr(), .virtual_state_e2dr(),
        .virtual_state_cir(), .virtual_state_uir(), .tck(tck_w)
    );

    logic [31:0] jtag_addr_out, jtag_data_out, jtag_data_in;
    logic        jtag_write_toggle, jtag_addr_toggle;

    vjtag_interface #(.AW(32), .DW(32)) u_vjtag_interface (
        .tck(tck_w), .tdi(tdi_w), .aclr(rst_n), .ir_in(ir_in_w),
        .v_cdr(v_cdr_w), .v_sdr(v_sdr_w), .udr(v_udr_w),
        .addr_out(jtag_addr_out), .data_out(jtag_data_out), .data_in(jtag_data_in), .tdo(tdo_w),
        .debug_dr2(), .debug_dr1(),
        .jtag_write_toggle(jtag_write_toggle), .jtag_addr_toggle(jtag_addr_toggle)
    );

    // Cruce tck -> clk (el toggle da margen para un solo registro de datos)
    logic [2:0]  addr_sync_q, write_sync_q;
    logic [31:0] jtag_addr_q, jtag_wdata_q;
    logic        addr_pulse, write_pulse;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_sync_q <= '0; write_sync_q <= '0; jtag_addr_q <= '0; jtag_wdata_q <= '0;
        end else begin
            addr_sync_q  <= {addr_sync_q[1:0],  jtag_addr_toggle};
            write_sync_q <= {write_sync_q[1:0], jtag_write_toggle};
            jtag_addr_q  <= jtag_addr_out;
            jtag_wdata_q <= jtag_data_out;
        end
    end

    assign addr_pulse  = addr_sync_q[2]  ^ addr_sync_q[1];
    assign write_pulse = write_sync_q[2] ^ write_sync_q[1];

    // Transacciones de bus del vJTAG (dominio clk)
    typedef enum logic [1:0] {VJ_IDLE, VJ_WRITE_REQ, VJ_READ_REQ, VJ_READ_CAP} vj_state_t;
    vj_state_t   vj_state, vj_next;
    logic        vjtag_valid, vjtag_write_en, vjtag_ready;
    logic [31:0] read_data_q;

    assign vjtag_valid    = (vj_state == VJ_WRITE_REQ) | (vj_state == VJ_READ_REQ);
    assign vjtag_write_en = (vj_state == VJ_WRITE_REQ);
    assign jtag_data_in   = read_data_q;

    always_comb begin
        vj_next = vj_state;
        case (vj_state)
            VJ_IDLE:      if (write_pulse) vj_next = VJ_WRITE_REQ; else if (addr_pulse) vj_next = VJ_READ_REQ;
            VJ_WRITE_REQ: if (vjtag_ready) vj_next = VJ_IDLE;
            VJ_READ_REQ:  if (vjtag_ready) vj_next = VJ_READ_CAP;
            default:      vj_next = VJ_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vj_state <= VJ_IDLE; read_data_q <= '0;
        end else begin
            vj_state <= vj_next;
            if (vj_state == VJ_READ_CAP) read_data_q <= mmio_rdata;
        end
    end

    // FSM de pixeles
    logic        fsm_valid, fsm_ready, fsm_write_en, alu_start, alu_done, alu_n;
    logic        timer_start, timer_clear, timer_timeout, fsm_busy_w, clear_on_start_w;
    logic [31:0] fsm_addr, fsm_data, alu_a, alu_b;
    logic [13:0] pixel_count_w;
    logic [7:0]  last_pixel_w, last_result_w;
    logic [3:0]  fsm_state_w;

    // Grant registrado: fsm_rdata solo es valido el ciclo en que el arbiter
    // realmente le dio el bus a la FSM el ciclo anterior (evita que la FSM
    // lea datos de una transaccion de vJTAG que llego al mismo tiempo).
    logic        fsm_gnt_q;
    logic [31:0] fsm_rdata_g;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) fsm_gnt_q <= 1'b0;
        else        fsm_gnt_q <= fsm_valid & fsm_ready;
    end

    assign fsm_rdata_g = fsm_gnt_q ? mmio_rdata : 32'h0;

    fsm u_fsm (
        .clk(clk), .rst_n(core_rst_n),
        .fsm_valid(fsm_valid), .fsm_ready(fsm_ready), .fsm_addr(fsm_addr), .fsm_data(fsm_data),
        .fsm_write_en(fsm_write_en), .fsm_rdata(fsm_rdata_g),
        .alu_a(alu_a), .alu_b(alu_b), .alu_start(alu_start), .alu_done(alu_done), .alu_n(alu_n),
        .timer_start(timer_start), .timer_clear(timer_clear), .timer_timeout(timer_timeout),
        .fsm_busy(fsm_busy_w), .clear_on_start(clear_on_start_w),
        .pixel_count(pixel_count_w), .last_pixel(last_pixel_w), .last_result(last_result_w),
        .fsm_state_num(fsm_state_w)
    );

    // ALU: pixel - threshold, solo se usa el flag negativo
    alu_flags_t alu_flags;
    alu_param #(.WIDTH(32)) u_alu (.code(SUB), .a(alu_a), .b(alu_b), .result(), .flags(alu_flags));
    assign alu_n = alu_flags.negative;

    // Registros de apoyo: ALU done, timer, perifericos LEDR/HEX y sombras (control_registers no expone sus valores)
    logic        timer_running_q;
    logic [31:0] timer_limit_q;
    logic [7:0]  threshold_q;
    logic [2:1]  status_q;   // [1]=done, [2]=timeout
    logic [9:0]  ledr_q;     // 0x30000
    logic [23:0] hex_q;      // 0x30004: un nibble por display

    always_ff @(posedge clk or negedge core_rst_n) begin
        if (!core_rst_n) begin
            alu_done <= 1'b0; timer_running_q <= 1'b0;
            timer_limit_q <= '0; threshold_q <= '0; status_q <= '0;
            ledr_q <= '0; hex_q <= '0;
        end else begin
            alu_done <= alu_start;
            // timer_start tiene prioridad sobre timer_clear: S_TH_CAP activa
            // ambos el mismo ciclo y el timer debe quedar corriendo, no en 0.
            if (timer_start)       timer_running_q <= 1'b1;
            else if (timer_clear)  timer_running_q <= 1'b0;
            if (we_cr && mux_addr[3:2] == 2'b10) timer_limit_q <= mux_data;
            if (we_cr && mux_addr[3:2] == 2'b11) threshold_q   <= mux_data[7:0];
            if (clear_on_start_w)                     status_q <= '0;
            else if (we_cr && mux_addr[3:2] == 2'b01) status_q <= mux_data[2:1];
            if (we_ledr) ledr_q <= mux_data[9:0];
            if (we_hex)  hex_q  <= mux_data[23:0];
        end
    end

    counter u_counter (
        .clk(clk), .reset_n(core_rst_n), .clear(timer_clear), .increase(timer_running_q),
        .timer_limit(timer_limit_q), .timeout(timer_timeout)
    );

    // Arbiter y decodificador MMIO
    arbiter u_arbiter (
        .clk(clk), .rst_n(rst_n),
        .vjtag_valid(vjtag_valid), .vjtag_addr(jtag_addr_q), .vjtag_data(jtag_wdata_q),
        .vjtag_write_en(vjtag_write_en), .vjtag_ready(vjtag_ready),
        .fsm_valid(fsm_valid), .fsm_addr(fsm_addr), .fsm_data(fsm_data),
        .fsm_write_en(fsm_write_en), .fsm_ready(fsm_ready),
        .subordinate_ready(mmio_ready),
        .mux_addr(mux_addr), .mux_data(mux_data), .mux_write_en(mux_write_en), .mux_valid(mux_valid)
    );

    mmio_decoder u_mmio_decoder (
        .clk(clk), .rst_n(rst_n), .addr(mux_addr), .valid(mux_valid), .ready(mmio_ready), .rdata(mmio_rdata),
        .cs_ram(cs_ram), .cs_rb(cs_rb), .cs_ledr(cs_ledr), .cs_hex(cs_hex), .cs_cr(cs_cr),
        .ram_rdata(ram_rdata), .rb_rdata(rb_rdata), .cr_rdata(cr_rdata)
    );

    // RAM: puerto A = buffer de entrada, puerto B = buffer de salida (mux_addr[16])
    logic        buf_sel, we_ram, re_ram;
    logic [31:0] ram_rdata_a, ram_rdata_b;

    assign buf_sel   = mux_addr[16];
    assign we_ram    = cs_ram & mux_write_en;
    assign re_ram    = cs_ram & ~mux_write_en;
    assign ram_rdata = buf_sel ? ram_rdata_b : ram_rdata_a;

    ram u_ram (
        .clk(clk),
        .addr_a(mux_addr[15:2]), .data_in_a(mux_data), .we_a(we_ram & ~buf_sel), .re_a(re_ram & ~buf_sel), .data_out_a(ram_rdata_a),
        .addr_b(mux_addr[15:2]), .data_in_b(mux_data), .we_b(we_ram &  buf_sel), .re_b(re_ram &  buf_sel), .data_out_b(ram_rdata_b)
    );

    // Banco de registros RISC-V y registros CTRL/STATUS/TIMER_LIMIT/THRESHOLD
    memory_mapped_register_file u_mmrf (
        .clk(clk), .reset_n(rst_n), .mmio_address(mux_addr),
        .write_en(cs_rb & mux_write_en), .write_data(mux_data), .selected_register(rb_rdata)
    );

    control_registers u_control_registers (
        .clk(clk), .reset_n(core_rst_n), .write_data(mux_data), .mmio_address(mux_addr),
        .write_en(we_cr), .busy_in(fsm_busy_w), .clear_on_start(clear_on_start_w), .selected_register(cr_rdata)
    );

    // Display: SW[1:0] = 00 contador+estado | 01 threshold | 10 pixel+resultado | 11 valores escritos por MMIO
    logic [19:0] count_bcd, threshold_bcd, pixel_bcd, result_bcd;
    logic [23:0] nib;   // nibbles de HEX5..HEX0
    logic [5:0]  off;   // 1 = apagar ese display
    logic [6:0]  seg0, seg1, seg2, seg3, seg4, seg5;

    binary_to_bcd_converter u_bcd_count     (.bin({2'b00, pixel_count_w}), .bcd(count_bcd));
    binary_to_bcd_converter u_bcd_threshold (.bin({8'b0, threshold_q}),    .bcd(threshold_bcd));
    binary_to_bcd_converter u_bcd_pixel     (.bin({8'b0, last_pixel_w}),   .bcd(pixel_bcd));
    binary_to_bcd_converter u_bcd_result    (.bin({8'b0, last_result_w}),  .bcd(result_bcd));

    seven_segment_adapter u_seg0 (.in(nib[3:0]),   .segments_abcdefg(seg0));
    seven_segment_adapter u_seg1 (.in(nib[7:4]),   .segments_abcdefg(seg1));
    seven_segment_adapter u_seg2 (.in(nib[11:8]),  .segments_abcdefg(seg2));
    seven_segment_adapter u_seg3 (.in(nib[15:12]), .segments_abcdefg(seg3));
    seven_segment_adapter u_seg4 (.in(nib[19:16]), .segments_abcdefg(seg4));
    seven_segment_adapter u_seg5 (.in(nib[23:20]), .segments_abcdefg(seg5));

    always_comb begin
        nib = {fsm_state_w, count_bcd};
        off = 6'b000000;
        case (SW[1:0])
            2'b01:   begin nib[11:0] = threshold_bcd[11:0]; off = 6'b111000; end
            2'b10:   nib = {pixel_bcd[11:0], result_bcd[11:0]};
            2'b11:   nib = hex_q;
            default: ;
        endcase
    end

    assign HEX0 = off[0] ? 7'b1111111 : seg0;
    assign HEX1 = off[1] ? 7'b1111111 : seg1;
    assign HEX2 = off[2] ? 7'b1111111 : seg2;
    assign HEX3 = off[3] ? 7'b1111111 : seg3;
    assign HEX4 = off[4] ? 7'b1111111 : seg4;
    assign HEX5 = off[5] ? 7'b1111111 : seg5;

    // LEDR: SW=11 -> valor MMIO; si no, [0]=busy, [1]=done, [2]=timeout
    assign LEDR = (SW == 2'b11) ? ledr_q : {7'b0, status_q, fsm_busy_w};

endmodule