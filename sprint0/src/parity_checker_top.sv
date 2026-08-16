module parity_checker_top (
    input logic [3:0] data,
    input logic p_even,
    input logic p_odd,
    output logic error_even,
    output logic error_odd,
    output logic valid
);

`ifdef STRUCTURAL
    parity_checker_structural u_parity_checker (
        .data(data),
        .p_even(p_even),
        .p_odd(p_odd),
        .error_even(error_even),
        .error_odd(error_odd),
        .valid(valid)
    );
`else
    parity_checker_behavioral u_parity_checker (
        .data(data),
        .p_even(p_even),
        .p_odd(p_odd),
        .error_even(error_even),
        .error_odd(error_odd),
        .valid(valid)
    );
`endif

endmodule