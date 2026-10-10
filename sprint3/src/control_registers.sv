module control_registers
(
    input  logic clk,
    input  logic reset_n,

    input logic [31:0] write_data,
    input logic [31:0] mmio_address,

    input logic write_en,   // This uses the chip select.
    
    output logic [31:0] selected_register
);

    logic [1:0] select;
    assign select = mmio_address[3:2];  // MMIO address ranges from 40000 to 4000C

    logic [31:0] ctrl;
    logic [31:0] status;
    logic [31:0] timer_limit;
    logic [31:0] threshold;

    always_comb begin
        case (select)
            2'b00: selected_register = ctrl;
            2'b01: selected_register = status;
            2'b10: selected_register = timer_limit;
            2'b11: selected_register = threshold;
            default: selected_register = '0;
        endcase
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            ctrl <= '0;
            status <= '0;
            timer_limit <= '0;
            threshold <= '0;
        end else if (write_en) begin
            case (select)
                2'b00: ctrl <= write_data;
                2'b01: status <= write_data;
                2'b10: timer_limit <= write_data;
                2'b11: threshold <= write_data;
                default: ;
            endcase
        end
    end

endmodule