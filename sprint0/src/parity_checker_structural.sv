module parity_checker_structural (
    input  logic [3:0] data,
    input  logic       p_even,
    input  logic       p_odd,
    output logic       error_even,
    output logic       error_odd,
    output logic       valid
);

    logic odd_check;
    logic any_error;

    xor (error_even, data[0], data[2], p_even);

    xor (odd_check, data[1], data[3], p_odd);
    not (error_odd, odd_check);

    or (any_error, error_even, error_odd);
    not (valid, any_error);

endmodule
