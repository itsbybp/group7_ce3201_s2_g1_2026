`default_nettype none

// Top de la placa DE10-Standard del Sprint 4.
//
// Controles de la placa:
//   KEY[0]  reset global (asincrono, liberacion sincrona)
//   KEY[1]  paso (pulso sincrono) cuando el modo paso a paso esta activo
//   SW[0]   0 = CPU a 50 MHz | 1 = paso a paso: cada pulso de KEY[1] avanza un estado de la FSM
//   SW[2:1] vista de los displays y LEDR:
//             00 registros MMIO (HEX = 0x40004, LEDR = 0x40000)
//             01 HEX = PC[23:0]
//             10 HEX = instruccion[23:0]
//             11 HEX = instruccion[31:8]
//           En 01, 10 y 11: LEDR[9] modo paso, [8] done, [7] busy, [6] illegal, [3:0] estado de la FSM
module top_level (
    input  wire logic        CLOCK_50,
    input  wire logic [2:0]  SW,
    input  wire logic [1:0]  KEY,
    output logic [9:0]       LEDR,
    output logic [6:0]       HEX0,
    output logic [6:0]       HEX1,
    output logic [6:0]       HEX2,
    output logic [6:0]       HEX3,
    output logic [6:0]       HEX4,
    output logic [6:0]       HEX5
);

    logic clk;
    logic rst_n;

    assign clk = CLOCK_50;

    // Reset: asserta asincrono y libera sincrono. El segundo key_sync entrega el pulso de KEY[1].
    // Los botones son activos en bajo, por eso se niega KEY[1] para detectar la pulsacion.
    logic step_pulse;

    key_sync u_key_sync_reset (
        .clk(clk),
        .key_raw(1'b0),
        .key0_raw(KEY[0]),
        .key_pulse(),
        .reset_n(rst_n)
    );

    key_sync u_key_sync_step (
        .clk(clk),
        .key_raw(~KEY[1]),
        .key0_raw(KEY[0]),
        .key_pulse(step_pulse),
        .reset_n()
    );

    // ---------------------------------------------------------------------------------
    // vJTAG (dominio tck). Igual que en el Sprint 3.
    // ---------------------------------------------------------------------------------
    logic       tck_w;
    logic       tdi_w;
    logic       tdo_w;
    logic [1:0] ir_in_w;
    logic       v_cdr_w;
    logic       v_sdr_w;
    logic       v_udr_w;

    vjtag vjtag_inst (
        .tdi(tdi_w),
        .tdo(tdo_w),
        .ir_in(ir_in_w),
        .ir_out(2'b00),
        .virtual_state_cdr(v_cdr_w),
        .virtual_state_sdr(v_sdr_w),
        .virtual_state_udr(v_udr_w),
        .virtual_state_e1dr(),
        .virtual_state_pdr(),
        .virtual_state_e2dr(),
        .virtual_state_cir(),
        .virtual_state_uir(),
        .tck(tck_w)
    );

    logic [31:0] jtag_addr_out;
    logic [31:0] jtag_data_out;
    logic [31:0] jtag_data_in;
    logic        jtag_write_toggle;
    logic        jtag_addr_toggle;

    vjtag_interface #(.AW(32), .DW(32)) u_vjtag_interface (
        .tck(tck_w),
        .tdi(tdi_w),
        .aclr(rst_n),
        .ir_in(ir_in_w),
        .v_cdr(v_cdr_w),
        .v_sdr(v_sdr_w),
        .udr(v_udr_w),
        .addr_out(jtag_addr_out),
        .data_out(jtag_data_out),
        .data_in(jtag_data_in),
        .tdo(tdo_w),
        .debug_dr2(),
        .debug_dr1(),
        .jtag_write_toggle(jtag_write_toggle),
        .jtag_addr_toggle(jtag_addr_toggle)
    );

    // Cruce tck -> clk (el toggle da margen para un solo registro de datos)
    logic [2:0]  addr_sync_q;
    logic [2:0]  write_sync_q;
    logic [31:0] jtag_addr_q;
    logic [31:0] jtag_wdata_q;
    logic        addr_pulse;
    logic        write_pulse;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_sync_q  <= '0;
            write_sync_q <= '0;
            jtag_addr_q  <= '0;
            jtag_wdata_q <= '0;
        end else begin
            addr_sync_q  <= {addr_sync_q[1:0], jtag_addr_toggle};
            write_sync_q <= {write_sync_q[1:0], jtag_write_toggle};
            jtag_addr_q  <= jtag_addr_out;
            jtag_wdata_q <= jtag_data_out;
        end
    end

    assign addr_pulse  = addr_sync_q[2] ^ addr_sync_q[1];
    assign write_pulse = write_sync_q[2] ^ write_sync_q[1];

    // Transacciones de bus del vJTAG (dominio clk). valid se mantiene hasta ready.
    typedef enum logic [1:0] {VJ_IDLE, VJ_WRITE_REQ, VJ_READ_REQ, VJ_READ_CAP} vj_state_t;

    vj_state_t   vj_state;
    vj_state_t   vj_next;
    logic        vjtag_valid;
    logic        vjtag_write_en;
    logic        vjtag_ready;
    logic [31:0] vjtag_rdata;
    logic [31:0] read_data_q;

    assign vjtag_valid    = (vj_state == VJ_WRITE_REQ) | (vj_state == VJ_READ_REQ);
    assign vjtag_write_en = (vj_state == VJ_WRITE_REQ);
    assign jtag_data_in   = read_data_q;

    always_comb begin
        vj_next = vj_state;
        case (vj_state)
            VJ_IDLE: begin
                if (write_pulse) begin
                    vj_next = VJ_WRITE_REQ;
                end else if (addr_pulse) begin
                    vj_next = VJ_READ_REQ;
                end
            end
            VJ_WRITE_REQ: begin
                if (vjtag_ready) begin
                    vj_next = VJ_IDLE;
                end
            end
            VJ_READ_REQ: begin
                if (vjtag_ready) begin
                    vj_next = VJ_READ_CAP;
                end
            end
            default: begin
                vj_next = VJ_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vj_state    <= VJ_IDLE;
            read_data_q <= '0;
        end else begin
            vj_state <= vj_next;
            if (vj_state == VJ_READ_CAP) begin
                read_data_q <= vjtag_rdata;
            end
        end
    end

    // ---------------------------------------------------------------------------------
    // Modo paso a paso (AC 4)
    // ---------------------------------------------------------------------------------
    // Un paso = la FSM del CPU avanza hasta cambiar de estado. No basta un solo ciclo de
    // reloj: FETCH y los accesos a datos necesitan varios ciclos de valid sostenido para
    // completar el handshake con la memoria (ready llega uno o dos ciclos despues).
    logic [1:0] step_mode_sync_q;
    logic       step_mode;
    logic       step_active_q;
    logic [3:0] step_ref_q;
    logic [3:0] cpu_state;
    logic       cpu_hold;
    logic       busy;
    logic       done;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_mode_sync_q <= '0;
        end else begin
            step_mode_sync_q <= {step_mode_sync_q[0], SW[0]};
        end
    end

    assign step_mode = step_mode_sync_q[1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_active_q <= 1'b0;
            step_ref_q    <= '0;
        end else if (!busy) begin
            step_active_q <= 1'b0;
        end else if (step_active_q) begin
            if (cpu_state != step_ref_q) begin
                step_active_q <= 1'b0;
            end
        end else if (step_pulse && step_mode) begin
            step_active_q <= 1'b1;
            step_ref_q    <= cpu_state;
        end
    end

    // En modo paso a paso el CPU solo corre mientras hay un paso activo y no ha cambiado de estado.
    assign cpu_hold = step_mode & ~(step_active_q & (cpu_state == step_ref_q));

    // ---------------------------------------------------------------------------------
    // Sistema RV32I
    // ---------------------------------------------------------------------------------
    logic [9:0]  ledr_reg;
    logic [23:0] hex_reg;
    logic [31:0] pc;
    logic [31:0] instruction;
    logic        handshake_instr;
    logic        illegal;

    // Senales para SignalTap (AC 12): se conservan con keep para poder encontrarlas en el Node Finder.
    (* keep *) logic        tap_imem_valid;
    (* keep *) logic        tap_imem_ready;
    (* keep *) logic        tap_cpu_valid;
    (* keep *) logic        tap_cpu_ready;

    rv32i_top u_rv32i_top (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_hold(cpu_hold),

        .vjtag_valid(vjtag_valid),
        .vjtag_addr(jtag_addr_q),
        .vjtag_data(jtag_wdata_q),
        .vjtag_write_en(vjtag_write_en),
        .vjtag_ready(vjtag_ready),
        .vjtag_rdata(vjtag_rdata),

        .ledr(ledr_reg),
        .hex(hex_reg),
        .busy(busy),
        .done(done),

        .pc(pc),
        .instruction(instruction),
        .handshake_instr(handshake_instr),
        .illegal(illegal),
        .cpu_state(cpu_state),
        .dbg_imem_valid(tap_imem_valid),
        .dbg_imem_ready(tap_imem_ready),
        .dbg_cpu_valid(tap_cpu_valid),
        .dbg_cpu_ready(tap_cpu_ready)
    );

    // ---------------------------------------------------------------------------------
    // Displays y LEDs
    // ---------------------------------------------------------------------------------
    logic [23:0] hex_view;
    logic        debug_view;
    logic [6:0]  seg0;
    logic [6:0]  seg1;
    logic [6:0]  seg2;
    logic [6:0]  seg3;
    logic [6:0]  seg4;
    logic [6:0]  seg5;

    assign debug_view = (SW[2:1] != 2'b00);

    always_comb begin
        case (SW[2:1])
            2'b01:   hex_view = pc[23:0];
            2'b10:   hex_view = instruction[23:0];
            2'b11:   hex_view = instruction[31:8];
            default: hex_view = hex_reg;
        endcase
    end

    seven_segment_adapter u_seg0 (.in(hex_view[3:0]),   .segments_abcdefg(seg0));
    seven_segment_adapter u_seg1 (.in(hex_view[7:4]),   .segments_abcdefg(seg1));
    seven_segment_adapter u_seg2 (.in(hex_view[11:8]),  .segments_abcdefg(seg2));
    seven_segment_adapter u_seg3 (.in(hex_view[15:12]), .segments_abcdefg(seg3));
    seven_segment_adapter u_seg4 (.in(hex_view[19:16]), .segments_abcdefg(seg4));
    seven_segment_adapter u_seg5 (.in(hex_view[23:20]), .segments_abcdefg(seg5));

    assign HEX0 = seg0;
    assign HEX1 = seg1;
    assign HEX2 = seg2;
    assign HEX3 = seg3;
    assign HEX4 = seg4;
    assign HEX5 = seg5;

    assign LEDR = debug_view ? {step_mode, done, busy, illegal, 2'b00, cpu_state} : ledr_reg;

    // handshake_instr no tiene salida fisica: queda disponible para SignalTap.
    (* keep *) logic tap_handshake_instr;
    assign tap_handshake_instr = handshake_instr;

endmodule

`default_nettype wire