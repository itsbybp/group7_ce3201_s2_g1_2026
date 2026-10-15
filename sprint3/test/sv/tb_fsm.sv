module tb_fsm;

    logic        clk, rst_n;
    logic        fsm_valid, fsm_ready;
    logic [31:0] fsm_addr, fsm_data;
    logic        fsm_write_en;
    logic [31:0] fsm_rdata;
    logic [31:0] alu_a, alu_b;
    logic        alu_start, alu_done, alu_n;
    logic        timer_start, timer_clear, timer_timeout;

    fsm #(.NUM_PIXELS(8)) dut (.*);

    always #10 clk = ~clk;

    localparam logic [31:0] ADDR_CTRL      = 32'h00040000;
    localparam logic [31:0] ADDR_STATUS    = 32'h00040004;
    localparam logic [31:0] ADDR_THRESHOLD = 32'h0004000C;
    localparam logic [31:0] ADDR_MMRF_X1   = 32'h00020004;
    localparam logic [31:0] BASE_IN        = 32'h00000000;
    localparam logic [31:0] BASE_OUT       = 32'h00010000;
    localparam int          NUM_PIXELS_TB  = 8;
    localparam int unsigned THRESHOLD_VAL  = 32'd100;

    logic [31:0] mem_in  [0:NUM_PIXELS_TB-1];
    logic [31:0] mem_out [0:NUM_PIXELS_TB-1];
    logic [31:0] status_q;
    logic        start_flag;

    function automatic logic [31:0] read_mux(logic [31:0] addr);
        logic [31:0] data;
        data = 32'h0;
        if (addr == ADDR_CTRL) data = {31'b0, start_flag};
        else if (addr == ADDR_THRESHOLD) data = THRESHOLD_VAL;
        else if (addr >= BASE_IN && addr < BASE_IN + (NUM_PIXELS_TB*4))
            data = mem_in[(addr - BASE_IN) >> 2];
        return data;
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) fsm_rdata <= '0;
        else        fsm_rdata <= read_mux(fsm_addr);
    end

    assign fsm_ready = fsm_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_q <= '0;
            for (int i = 0; i < NUM_PIXELS_TB; i++) mem_out[i] <= '0;
        end else if (fsm_valid && fsm_ready && fsm_write_en) begin
            if (fsm_addr == ADDR_STATUS) status_q <= fsm_data;
            else if (fsm_addr >= BASE_OUT && fsm_addr < BASE_OUT + (NUM_PIXELS_TB*4))
                mem_out[(fsm_addr - BASE_OUT) >> 2] <= fsm_data;
        end
    end

    logic [1:0]  alu_cnt;
    logic [31:0] alu_a_latched, alu_b_latched;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_cnt <= '0; alu_done <= 1'b0; alu_n <= 1'b0;
        end else begin
            alu_done <= 1'b0;
            if (alu_start) begin
                alu_a_latched <= alu_a;
                alu_b_latched <= alu_b;
                alu_cnt       <= 2'd2;
            end else if (alu_cnt != 0) begin
                alu_cnt <= alu_cnt - 1'b1;
                if (alu_cnt == 2'd1) begin
                    alu_done <= 1'b1;
                    alu_n    <= ($signed(alu_a_latched) - $signed(alu_b_latched)) < 0;
                end
            end
        end
    end

    assign timer_timeout = 1'b0;

    initial begin
        mem_in[0] = 32'd50;  mem_in[1] = 32'd150; mem_in[2] = 32'd99;  mem_in[3] = 32'd100;
        mem_in[4] = 32'd255; mem_in[5] = 32'd0;   mem_in[6] = 32'd200; mem_in[7] = 32'd1;

        clk = 0; rst_n = 0; start_flag = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        start_flag = 1;
        repeat (2) @(posedge clk);
        start_flag = 0;

        wait (status_q == 32'h1);
        @(posedge clk);

        for (int i = 0; i < NUM_PIXELS_TB; i++) begin
            automatic logic [31:0] expected;
            expected = (mem_in[i] < THRESHOLD_VAL) ? 32'd0 : 32'd255;
            assert (mem_out[i] == expected)
                else $error("Pixel %0d: esperado=%0d obtenido=%0d", i, expected, mem_out[i]);
        end

        $display("Pruebas completadas exitosamente");
        $finish;
    end

endmodule