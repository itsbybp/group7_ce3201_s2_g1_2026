// DO NOT ADD THIS FILE TO THE .qsf file.


module vjtag (
    output logic       tdi,
    input  logic       tdo,
    output logic [1:0] ir_in,
    input  logic [1:0] ir_out,
    output logic       virtual_state_cdr,
    output logic       virtual_state_sdr,
    output logic       virtual_state_e1dr,
    output logic       virtual_state_pdr,
    output logic       virtual_state_e2dr,
    output logic       virtual_state_udr,
    output logic       virtual_state_cir,
    output logic       virtual_state_uir,
    output logic       tck
);

    logic       sim_tck   /* verilator public */;
    logic       sim_tdi   /* verilator public */;
    logic [1:0] sim_ir_in /* verilator public */;
    logic       sim_v_cdr /* verilator public */;
    logic       sim_v_sdr /* verilator public */;
    logic       sim_v_udr /* verilator public */;

    assign tck               = sim_tck;
    assign tdi               = sim_tdi;
    assign ir_in             = sim_ir_in;
    assign virtual_state_cdr = sim_v_cdr;
    assign virtual_state_sdr = sim_v_sdr;
    assign virtual_state_udr = sim_v_udr;

    assign virtual_state_e1dr = 1'b0;
    assign virtual_state_pdr  = 1'b0;
    assign virtual_state_e2dr = 1'b0;
    assign virtual_state_cir  = 1'b0;
    assign virtual_state_uir  = 1'b0;

endmodule

