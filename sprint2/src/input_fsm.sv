module input_fsm (
    input logic clk,
    input logic reset,

    input logic [7:0] nibble_input,
    input logic step,   // This signals the FSM to advance a single step. A step is taken each cycle if this signal is on.

    output logic [15:0] out,
    output logic [1:0] current_state

    // output logic [6:0] seven_segment_display_six
);

    logic serial_assembly_FSM_finished; // the FSM can only receive nibble inputs if this value is 0.

    always_ff @(posedge clk or negedge reset)
    begin
        if (~reset) begin
            current_state <= 2'b11;
            out <= 16'b0000000000000000;
            serial_assembly_FSM_finished <= 1'b0;
        end
        else begin
            if (step && !serial_assembly_FSM_finished) begin // LSBs are entered first.
                unique case (current_state)
                2'b00: begin
                    out[15:12] <= nibble_input; 
                end
                2'b01: begin
                    out[11:8] <= nibble_input; 
                end
                2'b10: begin
                    out[7:4] <= nibble_input; 
                end
                2'b11: begin
                    out[3:0] <= nibble_input; 
                end
                default: begin
                    out <= out; // This is redundant and the default case for an unassigned value in an ff block. Left out for clarity.
                    // fyi we are no pros and this helps me remember what happens in this scenario.
                    // And just to be safe I wouldn't be leaving these kind of comments if it wasn't just my image at risk.
                    // i.e. I wouldn't keep yapping like this with actual, professional code at a work setting.
                end
            endcase
                if (current_state != 2'b00) begin
                    current_state <= current_state - 2'b01;
                end
                else begin
                    serial_assembly_FSM_finished <= 1'b1;
                end
            end
        end
    end



endmodule