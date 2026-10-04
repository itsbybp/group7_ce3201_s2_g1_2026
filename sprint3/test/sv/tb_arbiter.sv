module tb_arbiter;

    logic        clk, rst_n;
    logic        vjtag_valid, fsm_valid;
    logic [31:0] vjtag_addr, vjtag_data;
    logic [31:0] fsm_addr, fsm_data;
    logic        subordinate_ready;
    logic        vjtag_ready, fsm_ready;
    logic [31:0] mux_addr, mux_data;
    logic        mux_valid;

    arbiter dut (.*);

    always #10 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0;
        vjtag_valid = 0; fsm_valid = 0;
        subordinate_ready = 0;
        vjtag_addr = 0; vjtag_data = 0;
        fsm_addr = 0; fsm_data = 0;
        @(posedge clk); rst_n = 1;

        // vJTAG gana cuando ambos solicitan al mismo tiempo
        vjtag_valid = 1; fsm_valid = 1;
        vjtag_addr = 32'h100; vjtag_data = 32'hFF;
        fsm_addr = 32'h200; fsm_data = 32'hAA;
        subordinate_ready = 1;
        @(posedge clk);
        @(posedge clk);
        assert (mux_addr == 32'h100) else $error("vJTAG debe ganar arbitraje");
        assert (vjtag_ready == 1)    else $error("vjtag_ready debe ser 1");
        assert (fsm_ready == 0)      else $error("fsm_ready debe ser 0");

        // Bus se congela cuando subordinado no está listo
        vjtag_valid = 1; fsm_valid = 0;
        subordinate_ready = 0;
        @(posedge clk);
        @(posedge clk);
        assert (vjtag_ready == 0)    else $error("vjtag_ready debe ser 0 con backpressure");
        assert (mux_addr == 32'h100) else $error("addr debe mantenerse estable");

        $display("Pruebas completadas exitosamente");
        $finish;
    end

endmodule