`timescale 1ns/1ps

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

    logic expected_even;
    logic expected_odd;
    logic expected_valid;

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

        for (int i = 0; i < 16; i++) begin

            data = i[3:0];
    
            for (int j = 0; j < 4; j++) begin
    
                p_even = j[0];
                p_odd = j[1];
    
                expected_even = data[0] ^ data[2] ^ p_even;
                expected_odd = ~(data[1] ^ data[3] ^ p_odd);
                expected_valid = ~expected_even & ~expected_odd;
    
                #10;
    
                if (error_even_behavioral !== expected_even)
                    $error("Behavioral error_even FAIL");
    
                if (error_odd_behavioral !== expected_odd)
                    $error("Behavioral error_odd FAIL");
    
                if (valid_behavioral !== expected_valid)
                    $error("Behavioral valid FAIL");
    
                if (error_even_structural !== expected_even)
                    $error("Structural error_even FAIL");
    
                if (error_odd_structural !== expected_odd)
                    $error("Structural error_odd FAIL");
    
                if (valid_structural !== expected_valid)
                    $error("Structural valid FAIL");
    
            end
        end

        // Prueba de propagacion de X
        data = 4'b0x00;
        p_even = 1'b0;
        p_odd = 1'b1;

        #10;

        if (error_even_behavioral !== 1'bx)
            $error("Behavioral X propagation FAIL");

        if (error_even_structural !== 1'bx)
            $error("Structural X propagation FAIL");

        if (valid_behavioral !== 1'bx)
            $error("Behavioral valid X propagation FAIL");

        if (valid_structural !== 1'bx)
            $error("Structural valid X propagation FAIL");


        // Prueba de propagacion de Z
        data = 4'b00z0;
        p_even = 1'b0;
        p_odd = 1'b0;

        #10;

        if (error_odd_behavioral !== 1'bx)
            $error("Behavioral Z propagation FAIL");

        if (error_odd_structural !== 1'bx)
            $error("Structural Z propagation FAIL");

        if (valid_behavioral !== 1'bx)
            $error("Behavioral valid Z propagation FAIL");

        if (valid_structural !== 1'bx)
            $error("Structural valid Z propagation FAIL");

        $finish;
    end

endmodule
