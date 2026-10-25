module tb_top_level;

    localparam int HALF  = 40;      // medio periodo de tck (ns)
    localparam int N_PIX = 16384;

    localparam logic [31:0] RAM_IN = 32'h00000, RAM_OUT = 32'h10000, RB = 32'h20000;
    localparam logic [31:0] LEDR_A = 32'h30000, HEX_A = 32'h30004;
    localparam logic [31:0] CTRL = 32'h40000, STATUS = 32'h40004, TLIM = 32'h40008, THR = 32'h4000C;

    logic       CLOCK_50 = 1'b0;
    logic [1:0] SW = 2'b00;
    logic [0:0] KEY = 1'b0;
    logic [9:0] LEDR;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

    int errors = 0;
    int collisions = 0;
    logic [31:0] rd, rd2;
    logic [6:0]  segtab [0:15];

    top_level dut (.CLOCK_50(CLOCK_50), .SW(SW), .KEY(KEY), .LEDR(LEDR),
                   .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5));

    always #10 CLOCK_50 = ~CLOCK_50;

    // ---------------- Utilidades ----------------
    task chk(input string m, input logic [31:0] g, input logic [31:0] e);
        if (g !== e) begin
            errors++;
            $error("%s: obtenido %h esperado %h", m, g, e);
        end
    endtask

    task clk(input int n);
        repeat (n) @(posedge CLOCK_50);
    endtask

    task tck_pulse;
        #(HALF);
        dut.vjtag_inst.sim_tck = 1'b1;
        #(HALF);
        dut.vjtag_inst.sim_tck = 1'b0;
    endtask

    task jtag_dr(input logic [1:0] ir, input logic [31:0] val, output logic [31:0] o);
        integer i;
        begin
            dut.vjtag_inst.sim_ir_in = ir;
            dut.vjtag_inst.sim_v_cdr = 1'b1;
            tck_pulse;
            dut.vjtag_inst.sim_v_cdr = 1'b0;
            dut.vjtag_inst.sim_v_sdr = 1'b1;
            for (i = 0; i < 32; i = i + 1) begin
                dut.vjtag_inst.sim_tdi = val[i];
                #(HALF);
                o[i] = dut.tdo_w;
                dut.vjtag_inst.sim_tck = 1'b1;
                #(HALF);
                dut.vjtag_inst.sim_tck = 1'b0;
            end
            dut.vjtag_inst.sim_v_sdr = 1'b0;
            dut.vjtag_inst.sim_v_udr = 1'b1;
            tck_pulse;
            dut.vjtag_inst.sim_v_udr = 1'b0;
        end
    endtask

    task jwrite(input logic [31:0] a, input logic [31:0] d);
        logic [31:0] dummy;
        begin
            jtag_dr(2'd3, a, dummy);
            jtag_dr(2'd1, d, dummy);
            clk(8);
        end
    endtask

    task jread(input logic [31:0] a, output logic [31:0] d);
        logic [31:0] dummy;
        begin
            jtag_dr(2'd3, a, dummy);
            clk(12);
            jtag_dr(2'd2, 32'h0, d);
        end
    endtask

    task jcheck(input string m, input logic [31:0] a, input logic [31:0] e);
        begin
            jread(a, rd);
            chk(m, rd, e);
        end
    endtask

    task do_reset;
        begin
            KEY = 1'b0;
            dut.vjtag_inst.sim_tck = 1'b0;
            dut.vjtag_inst.sim_tdi = 1'b0;
            dut.vjtag_inst.sim_v_cdr = 1'b0;
            dut.vjtag_inst.sim_v_sdr = 1'b0;
            dut.vjtag_inst.sim_v_udr = 1'b0;
            dut.vjtag_inst.sim_ir_in = 2'b00;
            clk(6);
            KEY = 1'b1;
            clk(6);
        end
    endtask

    task soft_reset;
        begin
            jwrite(CTRL, 32'h2);
            clk(4);
        end
    endtask

    task start_proc(input logic [31:0] th, input logic [31:0] tlim);
        int n;
        begin
            jwrite(THR, th);
            jwrite(TLIM, tlim);
            jwrite(CTRL, 32'h1);
            n = 0;
            while (!dut.fsm_busy_w && n < 100) begin
                clk(1);
                n++;
            end
            chk("FSM arranca tras CTRL.start", dut.fsm_busy_w, 1'b1);
        end
    endtask

    task wait_done;
        int n;
        begin
            n = 0;
            while (dut.status_q == 2'b00 && n < 400000) begin
                clk(200);
                n += 200;
            end
            chk("espera done/timeout (TB)", n < 400000, 1'b1);
            clk(10);
        end
    endtask

    task learn_segs;
        logic [23:0] base;
        logic [41:0] hall;
        int k, j;
        begin
            SW = 2'b11;
            for (j = 0; j < 3; j++) begin
                base = (j == 0) ? 24'h543210 : (j == 1) ? 24'hBA9876 : 24'h00FEDC;
                jwrite(HEX_A, {8'h00, base});
                clk(2);
                hall = {HEX5, HEX4, HEX3, HEX2, HEX1, HEX0};
                for (k = 0; k < 6; k++) segtab[base[4*k +: 4]] = hall[7*k +: 7];
            end
            for (j = 0; j < 16; j++) chk("segtab != apagado", segtab[j] != 7'h7F, 1'b1);
        end
    endtask

    // dig = {d5..d0}; off[k]=1 espera display apagado
    task chk_hex(input string m, input logic [23:0] dig, input logic [5:0] off);
        logic [41:0] hall;
        logic [41:0] expv;
        int k;
        begin
            hall = {HEX5, HEX4, HEX3, HEX2, HEX1, HEX0};
            for (k = 0; k < 6; k++) expv[7*k +: 7] = off[k] ? 7'h7F : segtab[dig[4*k +: 4]];
            if (hall !== expv) begin
                errors++;
                $error("%s: HEX obtenido %h esperado %h", m, hall, expv);
            end
        end
    endtask

    // ---------------- Monitor de bus (AC1, AC2) ----------------
    logic        mon_en = 1'b0;
    logic        p_fv, p_fr, p_vv, p_vr, p_corex;
    logic [64:0] p_f, p_v;
    int          held = 0;

    always @(negedge CLOCK_50) begin
        if (mon_en) begin
            // el soft_reset borra la FSM a mitad de transaccion: no es violacion de AC1.
            // se exime si el reset del core estuvo bajo en cualquiera de las dos muestras,
            // porque el async reset de la FSM no cae justo en un flanco de este monitor.
            if (p_fv && !p_fr && p_f !== {dut.fsm_addr, dut.fsm_data, dut.fsm_write_en} &&
                !(p_corex || !dut.core_rst_n)) begin
                errors++; $error("AC1: FSM cambio bus con ready=0");
            end
            if (p_vv && !p_vr && p_v !== {dut.jtag_addr_q, dut.jtag_wdata_q, dut.vjtag_write_en}) begin
                errors++; $error("AC1: vJTAG cambio bus con ready=0");
            end
            if (dut.fsm_ready && dut.vjtag_ready) begin
                errors++; $error("AC2: ambos ready en el mismo ciclo");
            end
            if (dut.fsm_valid && dut.vjtag_valid) collisions++;
            held = (dut.vjtag_valid && !dut.vjtag_ready) ? held + 1 : 0;
            if (held > 2) begin
                errors++; $error("vJTAG inanicion: valid sin ready > 2 ciclos");
            end
        end
        p_fv = dut.fsm_valid;  p_fr = dut.fsm_ready;
        p_vv = dut.vjtag_valid; p_vr = dut.vjtag_ready;
        p_f  = {dut.fsm_addr, dut.fsm_data, dut.fsm_write_en};
        p_v  = {dut.jtag_addr_q, dut.jtag_wdata_q, dut.vjtag_write_en};
        p_corex = !dut.core_rst_n;
    end

    // ---------------- Tests ----------------
    task t_reset_and_spurious;
        begin
            $display("[TB] reset y arranque no espurio");
            chk("LEDR=0", LEDR, 10'h0);
            chk("busy=0", dut.fsm_busy_w, 1'b0);
            jcheck("CTRL", CTRL, 0);     jcheck("STATUS", STATUS, 0);
            jcheck("TLIM", TLIM, 0);     jcheck("THR", THR, 0);
            jcheck("LEDR_A", LEDR_A, 0); jcheck("HEX_A", HEX_A, 0);
            jcheck("x1", RB + 4, 0);
            jwrite(RAM_IN, 32'hFF);
            jwrite(RB + 8, 32'h1);
            // lee de vuelta lo que se acaba de escribir: si la FSM capturara basura
            // de estas transacciones (BUG de arranque espurio) esto lo detecta
            jcheck("RAM[0] tras escritura", RAM_IN, 32'hFF);
            jcheck("x2 tras escritura", RB + 8, 32'h1);
            clk(100);
            chk("sin arranque espurio", dut.fsm_busy_w, 1'b0);
            jcheck("RAM[0] no se corrompio", RAM_IN, 32'hFF);
        end
    endtask

    task t_iface;
        logic [31:0] o;
        logic        w0, a0;
        int          n;
        begin
            $display("[TB] interfaz vJTAG");
            w0 = dut.jtag_write_toggle; a0 = dut.jtag_addr_toggle;
            jtag_dr(2'd3, 32'h00000ABC, o);
            chk("SET_ADDR toggle addr", {31'b0, dut.jtag_addr_toggle}, {31'b0, ~a0});
            chk("SET_ADDR no toggle wr", dut.jtag_write_toggle, w0);
            chk("addr_out", dut.jtag_addr_out, 32'hABC);
            clk(12);
            w0 = dut.jtag_write_toggle; a0 = dut.jtag_addr_toggle;
            jtag_dr(2'd1, 32'hCAFEF00D, o);
            chk("WRITE toggle wr", {31'b0, dut.jtag_write_toggle}, {31'b0, ~w0});
            chk("data_out", dut.jtag_data_out, 32'hCAFEF00D);
            clk(8);
            w0 = dut.jtag_write_toggle; a0 = dut.jtag_addr_toggle;
            jtag_dr(2'd2, 32'h0, o);
            jtag_dr(2'd0, 32'hA5C3F00F, o);
            chk("BYPASS 1 bit de retardo", o, 32'hA5C3F00F << 1);
            chk("READ/BYPASS sin toggle", dut.jtag_write_toggle == w0 && dut.jtag_addr_toggle == a0, 1'b1);
            jtag_dr(2'd3, 32'h00000010, o);
            chk("SET_ADDR reemplaza", dut.jtag_addr_out, 32'h10);
            clk(12);
            n = 0;
            fork
                jtag_dr(2'd1, 32'h1, o);
                begin
                    while (!dut.vjtag_valid && n < 200) begin clk(1); n++; end
                end
            join
            chk("CDC: vjtag_valid subio", n < 200, 1'b1);
            clk(10);
            jwrite(RAM_IN + 32'h20, 32'h12345678);
            jcheck("lectura vJTAG", RAM_IN + 32'h20, 32'h12345678);
        end
    endtask

    task t_mmio;
        begin
            $display("[TB] mapa MMIO (RAM, regfile, CTRL/STATUS/TLIM/THR, RAZ/WI)");
            jwrite(RAM_IN, 32'h11);     jwrite(RAM_IN + 4, 32'h22);
            jwrite(RAM_OUT, 32'h33);   jwrite(RAM_OUT + 4, 32'h44);
            jcheck("in[0]", RAM_IN, 32'h11);   jcheck("in[1]", RAM_IN + 4, 32'h22);
            jcheck("out[0]", RAM_OUT, 32'h33); jcheck("out[1]", RAM_OUT + 4, 32'h44);
            jwrite(RB, 32'hFFFFFFFF);
            jcheck("x0 = 0", RB, 0);
            jwrite(RB + 4, 32'hDEADBEEF);
            jcheck("x1", RB + 4, 32'hDEADBEEF);
            jwrite(TLIM, 32'h1234);
            jwrite(THR, 32'h80);
            jwrite(STATUS, 32'h6);
            jcheck("TIMER_LIMIT", TLIM, 32'h1234);
            jcheck("THRESHOLD", THR, 32'h80);
            jcheck("STATUS", STATUS, 32'h6);
            chk("timer_limit_q", dut.timer_limit_q, 32'h1234);
            chk("threshold_q", dut.threshold_q, 8'h80);
            chk("status_q", dut.status_q, 2'b11);
            jwrite(STATUS, 32'h0);           // limpia STATUS: no debe quedar para las pruebas siguientes
            jcheck("STATUS limpio", STATUS, 0);
            jwrite(32'h20080, 32'hFFFFFFFF);
            jcheck("RAZ regfile", 32'h20080, 0);
            jwrite(32'h30008, 32'hFFFFFFFF);
            jcheck("RAZ IO", 32'h30008, 0);
            jwrite(32'h40010, 32'hFFFFFFFF);
            jcheck("RAZ CR", 32'h40010, 0);
            jwrite(32'hFFFFFFFC, 32'hFFFFFFFF);
            jcheck("RAZ fuera de rango", 32'hFFFFFFFC, 0);
            // Nota: no se revisa mux_valid=0 aqui: la FSM en S_IDLE pide el bus
            // (fsm_valid=1) todo el tiempo leyendo CTRL, asi que mux_valid=1 es normal.
            jcheck("WI no toco RAM", RAM_IN, 32'h11);
        end
    endtask

    task t_display;
        begin
            $display("[TB] LEDR/HEX y modos de display");
            learn_segs;
            jwrite(LEDR_A, 32'h3FF);
            jwrite(HEX_A, 32'h123456);
            clk(2);
            chk("LEDR SW=11", LEDR, 10'h3FF);
            chk_hex("HEX SW=11", 24'h123456, 6'b000000);
            SW = 2'b00; clk(2);
            chk("LEDR SW=00 reposo", LEDR, 10'h0);
            chk_hex("HEX SW=00 reposo", 24'h000000, 6'b000000);
            jwrite(THR, 32'd7);
            SW = 2'b01; clk(2);
            chk_hex("HEX SW=01 TH=7", 24'h000007, 6'b111000);
            SW = 2'b10; clk(2);
            chk_hex("HEX SW=10 reposo", 24'h000000, 6'b000000);
        end
    endtask

    task t_pixel_flow;
        int k, i, e;
        logic [31:0] px_v [0:4];
        int          px_i [0:4];
        begin
            $display("[TB] flujo de pixeles + arbitraje bajo carga");
            collisions = 0;
            px_i[0] = 0; px_v[0] = 0;
            px_i[1] = 1; px_v[1] = 127;
            px_i[2] = 2; px_v[2] = 128;
            px_i[3] = 3; px_v[3] = 255;
            px_i[4] = N_PIX - 1; px_v[4] = 200;
            for (k = 0; k < 5; k++) jwrite(RAM_IN + 4 * px_i[k], px_v[k]);
            start_proc(32'd128, 32'h0FFFFFFF);
            chk("busy en LEDR[0]", LEDR[0], 1'b1);
            clk(50);
            for (k = 0; k < 20; k++) begin  // trafico vJTAG concurrente: AC1/AC2
                jwrite(RAM_IN + 32'h2000 + 4 * k, k);
                jcheck("lectura bajo carga", RAM_IN + 32'h2000 + 4 * k, k);
                jread(STATUS, rd2);
                chk("busy visible en STATUS[0]", rd2[0], 1'b1);
            end
            chk("hubo colisiones vJTAG/FSM", collisions > 0, 1'b1);
            wait_done;
            chk("busy=0", dut.fsm_busy_w, 1'b0);
            chk("contador final", dut.pixel_count_w, N_PIX - 1);
            chk("LEDR=done", LEDR, 10'b0000000010);
            jcheck("STATUS=done", STATUS, 32'h2);
            jcheck("CTRL limpio", CTRL, 0);
            for (k = 0; k < 5; k++) begin
                e = (px_v[k] >= 128) ? 255 : 0;
                jread(RAM_OUT + 4 * px_i[k], rd);
                if (rd !== e) begin
                    errors++;
                    $error("pixel %0d: v=%0d esperado %0d obtenido %0d", px_i[k], px_v[k], e, rd);
                end
            end
            jcheck("x1 = ultimo pixel", RB + 4, 200);
        end
    endtask

    task t_timeout;
        begin
            $display("[TB] timeout");
            start_proc(32'd128, 32'd50);
            wait_done;
            chk("busy=0 tras timeout", dut.fsm_busy_w, 1'b0);
            chk("no llego al final", dut.pixel_count_w < N_PIX - 1, 1'b1);
            jcheck("STATUS=timeout", STATUS, 32'h4);
            chk("LEDR[2]=timeout", LEDR, 10'b0000000100);
        end
    endtask

    task t_soft;
        begin
            $display("[TB] soft_reset");
            jwrite(RAM_IN + 32'h40, 32'h55);
            jwrite(RAM_OUT + 32'h3000, 32'h66);  // offset lejos de lo que procesan los tests previos
            jwrite(LEDR_A, 32'h15);
            start_proc(32'd77, 32'd999999);
            clk(200);
            soft_reset;
            chk("FSM idle", dut.fsm_state_w, 4'd0);
            chk("busy=0", dut.fsm_busy_w, 1'b0);
            chk("ledr_q limpio", LEDR, 10'h0);
            jcheck("CTRL=0", CTRL, 0);   jcheck("STATUS=0", STATUS, 0);
            jcheck("TLIM=0", TLIM, 0);   jcheck("THR=0", THR, 0);
            jcheck("RAM in conservada", RAM_IN + 32'h40, 32'h55);
            jcheck("RAM out conservada", RAM_OUT + 32'h3000, 32'h66);
            start_proc(32'd5, 32'd999999);  // puede re-arrancar tras el soft_reset
            chk("re-arranca", dut.fsm_busy_w, 1'b1);
        end
    endtask

    task t_key;
        begin
            $display("[TB] reset por KEY[0]");
            jwrite(RAM_IN + 32'h80, 32'h99);
            jwrite(RB + 4, 32'h1234);
            start_proc(32'd50, 32'd500000);
            clk(200);
            KEY = 1'b0; clk(6);
            chk("KEY no reinicio la FSM", dut.fsm_busy_w, 1'b0);
            chk("contador 0", dut.pixel_count_w, 14'd0);
            KEY = 1'b1; clk(6);
            jcheck("CTRL", CTRL, 0);   jcheck("STATUS", STATUS, 0);
            jcheck("TLIM", TLIM, 0);   jcheck("THR", THR, 0);
            jcheck("x1", RB + 4, 0);
            jcheck("RAM sin reset", RAM_IN + 32'h80, 32'h99);
        end
    endtask

    // ---------------- Principal ----------------
    initial begin
        do_reset;
        mon_en = 1'b1;
        t_reset_and_spurious;
        t_iface;
        t_mmio;
        t_display;
        t_pixel_flow;
        t_timeout;
        t_soft;
        t_key;
        if (errors == 0) $display("Pruebas completadas exitosamente");
        else             $display("PRUEBAS FALLIDAS: %0d errores", errors);
        $finish;
    end

    initial begin
        #2000000000;
        $error("watchdog: la simulacion excedio el tiempo maximo");
        $finish;
    end

endmodule