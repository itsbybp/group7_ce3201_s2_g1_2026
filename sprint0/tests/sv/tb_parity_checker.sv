module tb_parity_checker();
    
    logic [3:0] data;
    logic p_even;
    logic p_odd;
    logic error_even_behavioral;
    logic error_odd_behavioral;
    logic valid_behavioral;
    logic error_even_structural;
    logic error_odd_structural;
    logic valid_structural;

    parity_checker_behavioral u_parity_checker_behavioral (
        .data(data),
        .p_even(p_even),
        .p_odd(p_odd),
        .error_even(error_even_behavioral),
        .error_odd(error_odd_behavioral),
        .valid(valid_behavioral)
    );

    parity_checker_structural u_parity_checker_structural (
        .data(data),
        .p_even(p_even),
        .p_odd(p_odd),
        .error_even(error_even_structural),
        .error_odd(error_odd_structural),
        .valid(valid_structural)
    );

    initial begin
        $display("Starting testbench for parity_checker...");
        //TODO: Agregue casos de prueba para verificar el funcionamiento de ambos módulos
        #10us;
        $display("Testbench completed.");
        $finish;
    end

endmodule