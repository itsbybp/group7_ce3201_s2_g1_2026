module vjtag_interface #(
    parameter int AW = 32,
    parameter int DW = 32
) (
    input  wire             tck,
    input  wire             tdi,
    input  wire             aclr,
    input  wire [1:0]       ir_in,
    input  wire             v_cdr,
    input  wire             v_sdr,
    input  wire             udr,
    output logic [(AW-1):0] addr_out,
    output logic [(DW-1):0] data_out,
    input  wire  [(DW-1):0] data_in,
    output logic            tdo,
    output logic [(DW-1):0] debug_dr2,
    output logic [(DW-1):0] debug_dr1,
    output logic            jtag_write_toggle,
    output logic            jtag_addr_toggle     // <-- NUEVO
);

typedef enum logic [1:0] {
    BYPASS   = 2'b00,
    WRITE    = 2'b01,
    READ     = 2'b10,
    SET_ADDR = 2'b11
} jtag_ir_state_t;

jtag_ir_state_t ir_state;

logic                 DR0_bypass_reg;
logic [(DW-1):0]      DR1;
logic [(DW-1):0]      DR2;
logic [(AW-1):0]      DR_ADDR;

always_ff @(posedge tck or negedge aclr) begin
    if (~aclr) begin
        DR0_bypass_reg <= 1'b0;
    end
    else begin
        if (v_cdr && (ir_state == BYPASS)) begin
            DR0_bypass_reg <= 1'b0;
        end
        else begin
            if (v_sdr && (ir_state == BYPASS)) begin
                DR0_bypass_reg <= tdi;
            end
        end
    end
end

always_ff @(posedge tck or negedge aclr) begin
    if (~aclr) begin
        DR_ADDR <= '0;
    end
    else begin
        if (v_sdr && (ir_state == SET_ADDR)) begin
            DR_ADDR <= {tdi, DR_ADDR[(AW-1):1]};
        end
    end
end

always_ff @(posedge tck or negedge aclr) begin
    if (~aclr) begin
        DR1 <= '0;
    end
    else begin
        if (v_sdr && (ir_state == WRITE)) begin
            DR1 <= {tdi, DR1[(DW-1):1]};
        end
    end
end

//TODO: Fix the ugly arrow antipattern
always_ff @(posedge tck or negedge aclr) begin
    if (~aclr) begin
        DR2 <= '0;
    end
    else begin
        if (ir_state == READ) begin
            if (v_cdr) begin
                DR2 <= data_in;
            end
            else begin
                if (v_sdr) begin
                    DR2 <= {tdi, DR2[(DW-1):1]};
                end
            end
        end
    end
end

always_ff @(posedge tck) begin
    if (udr) begin
        if (ir_state == WRITE) begin
            data_out <= DR1;
        end
        if (ir_state == SET_ADDR) begin
            addr_out <= DR_ADDR;
        end
    end
end

always_ff @(posedge tck or negedge aclr) begin
    if (~aclr) begin
        jtag_write_toggle <= 1'b0;
    end
    else if (udr && (ir_state == WRITE)) begin
        jtag_write_toggle <= ~jtag_write_toggle;
    end
end

// NUEVO: mismo patron que jtag_write_toggle, pero para SET_ADDR
always_ff @(posedge tck or negedge aclr) begin
    if (~aclr) begin
        jtag_addr_toggle <= 1'b0;
    end
    else if (udr && (ir_state == SET_ADDR)) begin
        jtag_addr_toggle <= ~jtag_addr_toggle;
    end
end

always_comb begin
    case (ir_state)
        WRITE: begin
            tdo = DR1[0];
        end
        READ: begin
            tdo = DR2[0];
        end
        SET_ADDR: begin
            tdo = DR_ADDR[0];
        end
        BYPASS: begin
            tdo = DR0_bypass_reg;
        end
        default: begin
            tdo = DR0_bypass_reg;
        end
    endcase
end

assign debug_dr2 = DR2;
assign debug_dr1 = DR1;
assign ir_state = jtag_ir_state_t'(ir_in);
endmodule