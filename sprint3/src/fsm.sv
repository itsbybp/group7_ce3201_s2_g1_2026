module fsm (
    input  logic        clk,
    input  logic         rst_n,

    // Bus hacia el arbiter
    output logic         fsm_valid,
    input  logic         fsm_ready,
    output logic [31:0]  fsm_addr,
    output logic [31:0]  fsm_data,
    output logic         fsm_write_en,
    input  logic [31:0]  fsm_rdata,

    // ALU
    output logic [31:0]  alu_a,
    output logic [31:0]  alu_b,
    output logic         alu_start,
    input  logic         alu_done,
    input  logic         alu_n,

    // Timer
    output logic         timer_start,
    output logic         timer_clear,
    input  logic         timer_timeout,

    // Status en vivo
    output logic         fsm_busy,

    // Pulso fuera del bus: limpia CTRL y STATUS
    output logic         clear_on_start,

    // Snapshot para HEX/LEDR (demo)
    output logic [13:0]  pixel_count,
    output logic [7:0]   last_pixel,
    output logic [7:0]   last_result,
    output logic [3:0]   fsm_state_num
);

    localparam logic [31:0] ADDR_CTRL      = 32'h00040000; // select=00
    localparam logic [31:0] ADDR_STATUS    = 32'h00040004; // select=01
    localparam logic [31:0] ADDR_TIMER_LIM = 32'h00040008; // select=10
    localparam logic [31:0] ADDR_THRESHOLD = 32'h0004000C; // select=11
    localparam logic [31:0] ADDR_MMRF_X1   = 32'h00020004; // addr[6:2]=00001

    localparam logic [31:0] BASE_IN  = 32'h00000000;
    localparam logic [31:0] BASE_OUT = 32'h00010000;

    // bits de STATUS: 0=busy, 1=done, 2=timeout
    localparam logic [31:0] STATUS_DONE    = 32'h2;
    localparam logic [31:0] STATUS_TIMEOUT = 32'h4;

    parameter int unsigned NUM_PIXELS = 16384;

    typedef enum logic [3:0] {
        S_IDLE,
        S_TH_REQ,
        S_TH_CAP,
        S_FETCH_REQ,
        S_FETCH_CAP,
        S_STORE_REQ,
        S_COMPUTE,
        S_WRITE_REQ,
        S_NEXT,
        S_DONE_REQ
    } state_t;

    state_t state, next_state;

    logic [13:0] counter_q, counter_d;
    logic [31:0] threshold_q, threshold_d;
    logic [31:0] pixel_q, pixel_d;
    logic [31:0] result_q, result_d;
    logic alu_busy_q;
    logic timed_out_q, timed_out_d; // recuerda si el S_DONE_REQ actual vino de un timeout

    assign fsm_busy      = (state != S_IDLE);
    assign pixel_count   = counter_q;
    assign last_pixel    = pixel_q[7:0];
    assign last_result   = result_q[7:0];
    assign fsm_state_num = state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            counter_q   <= '0;
            threshold_q <= '0;
            pixel_q     <= '0;
            result_q    <= '0;
            alu_busy_q  <= 1'b0;
            timed_out_q <= 1'b0;
        end else begin
            state       <= next_state;
            counter_q   <= counter_d;
            threshold_q <= threshold_d;
            pixel_q     <= pixel_d;
            result_q    <= result_d;
            timed_out_q <= timed_out_d;

            if (alu_start)      alu_busy_q <= 1'b1;
            else if (alu_done)  alu_busy_q <= 1'b0;
        end
    end

    always_comb begin
        next_state     = state;
        counter_d      = counter_q;
        threshold_d    = threshold_q;
        pixel_d        = pixel_q;
        result_d       = result_q;
        timed_out_d    = timed_out_q;

        fsm_valid      = 1'b0;
        fsm_addr       = 32'h0;
        fsm_data       = 32'h0;
        fsm_write_en   = 1'b0;

        alu_a          = pixel_q;
        alu_b          = threshold_q;
        alu_start      = 1'b0;

        timer_start    = 1'b0;
        timer_clear    = 1'b0;

        clear_on_start = 1'b0;

        // Si hay timeout y el estado no tiene una transaccion de bus en curso,
        // va directo a S_DONE_REQ. Si la tiene (los *_REQ/*_CAP), se espera a
        // ganar el bus (ver bloque final) para no romper AC1 a medio camino.
        if (timer_timeout && state != S_IDLE && state != S_DONE_REQ &&
            state != S_TH_REQ && state != S_TH_CAP && state != S_FETCH_REQ &&
            state != S_FETCH_CAP && state != S_STORE_REQ && state != S_WRITE_REQ) begin
            timed_out_d = 1'b1;
            next_state  = S_DONE_REQ;
        end else begin
            case (state)

                S_IDLE: begin
                    fsm_valid = 1'b1;
                    fsm_addr  = ADDR_CTRL;
                    if (fsm_ready && fsm_rdata[0]) begin
                        clear_on_start = 1'b1;  // limpia CTRL y STATUS
                        timed_out_d    = 1'b0;  // limpia el timeout de una corrida anterior
                        next_state     = S_TH_REQ;
                    end
                end

                S_TH_REQ: begin
                    fsm_valid = 1'b1;
                    fsm_addr  = ADDR_THRESHOLD;
                    if (fsm_ready) next_state = S_TH_CAP;
                end

                S_TH_CAP: begin
                    fsm_valid = 1'b1;
                    fsm_addr  = ADDR_THRESHOLD;
                    if (fsm_ready) begin
                        threshold_d = fsm_rdata;
                        counter_d   = '0;
                        timer_start = 1'b1;
                        next_state  = S_FETCH_REQ;
                    end else begin
                        next_state  = S_TH_REQ; // perdio el bus: reintenta el request
                    end
                end

                S_FETCH_REQ: begin
                    fsm_valid = 1'b1;
                    fsm_addr  = BASE_IN + 32'({counter_q, 2'b00});
                    if (fsm_ready) next_state = S_FETCH_CAP;
                end

                S_FETCH_CAP: begin
                    fsm_valid  = 1'b1;
                    fsm_addr   = BASE_IN + 32'({counter_q, 2'b00});
                    if (fsm_ready) begin
                        pixel_d    = fsm_rdata;
                        next_state = S_STORE_REQ;
                    end else begin
                        next_state = S_FETCH_REQ; // perdio el bus: reintenta el request
                    end
                end

                S_STORE_REQ: begin
                    fsm_valid    = 1'b1;
                    fsm_addr     = ADDR_MMRF_X1;
                    fsm_data     = pixel_q;
                    fsm_write_en = 1'b1;
                    if (fsm_ready) next_state = S_COMPUTE;
                end

                S_COMPUTE: begin
                    alu_start = !alu_busy_q && !alu_done;
                    if (alu_done) begin
                        result_d   = alu_n ? 32'd0 : 32'd255;
                        next_state = S_WRITE_REQ;
                    end
                end

                S_WRITE_REQ: begin
                    fsm_valid    = 1'b1;
                    fsm_addr     = BASE_OUT + 32'({counter_q, 2'b00});
                    fsm_data     = result_q;
                    fsm_write_en = 1'b1;
                    if (fsm_ready) next_state = S_NEXT;
                end

                S_NEXT: begin
                    if (counter_q == 14'(NUM_PIXELS - 1)) begin
                        next_state = S_DONE_REQ;
                    end else begin
                        counter_d  = counter_q + 14'd1;
                        next_state = S_FETCH_REQ;
                    end
                end

                S_DONE_REQ: begin
                    fsm_valid    = 1'b1;
                    fsm_addr     = ADDR_STATUS;
                    fsm_data     = timed_out_q ? STATUS_TIMEOUT : STATUS_DONE;
                    fsm_write_en = 1'b1;
                    timer_clear  = 1'b1;
                    if (fsm_ready) next_state = S_IDLE;
                end

                default: next_state = S_IDLE;
            endcase

            // Timeout mientras hay una transaccion de bus pendiente: se honra
            // apenas se gana el bus ese mismo ciclo (no deja el addr/data a medias).
            if (timer_timeout && fsm_ready &&
                (state == S_TH_REQ || state == S_TH_CAP || state == S_FETCH_REQ ||
                 state == S_FETCH_CAP || state == S_STORE_REQ || state == S_WRITE_REQ)) begin
                timed_out_d = 1'b1;
                next_state  = S_DONE_REQ;
            end
        end
    end

endmodule