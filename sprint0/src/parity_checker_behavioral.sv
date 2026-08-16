module parity_checker_behavioral (
    input  logic [3:0] data,
    input  logic       p_even,
    input  logic       p_odd,
    output logic       error_even,
    output logic       error_odd,
    output logic       valid
);
    assign error_even = ^{data[0], data[2], p_even};
    assign error_odd = ~^{data[1], data[3], p_odd};
    assign valid = ~error_even & ~error_odd;
endmodule
