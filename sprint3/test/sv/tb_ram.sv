`default_nettype none

module tb_ram;

    logic        clk;
    logic [14:0] addr_a;
    logic [31:0] data_in_a;
    logic        we_a;
    logic        re_a;
    logic [31:0] data_out_a;
    logic [14:0] addr_b;
    logic [31:0] data_in_b;
    logic        we_b;
    logic        re_b;
    logic [31:0] data_out_b;

    ram dut (
        .clk       (clk),
        .addr_a    (addr_a),
        .data_in_a (data_in_a),
        .we_a      (we_a),
        .re_a      (re_a),
        .data_out_a(data_out_a),
        .addr_b    (addr_b),
        .data_in_b (data_in_b),
        .we_b      (we_b),
        .re_b      (re_b),
        .data_out_b(data_out_b)
    );

    always #10 clk = ~clk;

    initial begin
        clk = 0;
        we_a = 0; re_a = 0;
        we_b = 0; re_b = 0;
        addr_a = 0; addr_b = 0;
        data_in_a = 0; data_in_b = 0;

        // Test 1: escritura y lectura puerto A
        @(posedge clk);
        we_a = 1; addr_a = 15'h0005; data_in_a = 32'hDEADBEEF;
        @(posedge clk);          // escribe
        we_a = 0; re_a = 1;
        @(posedge clk);          // captura en registro
        re_a = 0;
        @(posedge clk);          // data_out_a estable
        assert (data_out_a == 32'hDEADBEEF)
            else $error("Test 1 fallo: esperado 0xDEADBEEF, obtenido 0x%08X", data_out_a);

        // Test 2: escritura y lectura puerto B
        @(posedge clk);
        we_b = 1; addr_b = 15'h4000; data_in_b = 32'h000000FF;
        @(posedge clk);          // escribe
        we_b = 0; re_b = 1;
        @(posedge clk);          // captura en registro
        re_b = 0;
        @(posedge clk);          // data_out_b estable
        assert (data_out_b == 32'h000000FF)
            else $error("Test 2 fallo: esperado 0x000000FF, obtenido 0x%08X", data_out_b);

        // Test 3: puertos independientes simultaneos
        @(posedge clk);
        we_a = 1; addr_a = 15'h000A; data_in_a = 32'hCAFECAFE;
        @(posedge clk);          // precarga addr 10
        we_a = 1; addr_a = 15'h0014; data_in_a = 32'h12345678;
        re_b = 1; addr_b = 15'h000A;
        @(posedge clk);          // A escribe 20, B captura lectura de 10
        we_a = 0; re_b = 0;
        @(posedge clk);          // data_out_b estable
        assert (data_out_b == 32'hCAFECAFE)
            else $error("Test 3 fallo: esperado 0xCAFECAFE, obtenido 0x%08X", data_out_b);

        $display("Pruebas completadas exitosamente");
        $finish;
    end

endmodule