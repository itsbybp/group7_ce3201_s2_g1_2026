// The main purpose of this fsm is to ensure the alu_result is safely written to the destination register rd. 
module exec_fsm (
    input logic clk,
    input logic reset,

    input logic start_execute,  // Used to decide to exit the idle state.

    input logic step,   // This signals the FSM to advance a single step. A step is taken each cycle if this signal is on.
    input logic stepping_mode,

    output logic write_enable,  // This signal stays HIGH for a single cycle, even if stepping_mode is on.
    output logic [1:0] current_state

);

    logic [1:0] current_state_delayed;

    assign write_enable = current_state_delayed == 2'b10 && current_state == 2'b01;

    always_ff @(posedge clk or negedge reset)
    begin
        if (~reset) begin
            current_state <= 2'b11;
            current_state_delayed <= 2'b11;
        end
        else begin
            if (step|~stepping_mode)    // Only stop when stepping mode is on and step is off.
            begin
                unique case (current_state)
                2'b00: begin    // Wait a cycle with no changes to the settings.
                    current_state <= current_state - 2'b01; // Advance to next state.
                end
                2'b01: begin    // Set write_enable HIGH.
                    current_state <= current_state - 2'b01; // Advance to next state.
                end
                2'b10: begin    // Wait a cycle with no changes to the settings.
                    current_state <= current_state - 2'b01; // Advance to next state.
                end
                2'b11: begin    // Idle.
                    if (start_execute) begin
                        current_state <= current_state - 2'b01; // Advance to next state.
                    end
                    else begin
                        current_state <= current_state; // Loop Idle state.
                    end
                end
                default: begin

                end
            endcase
            end

            // current_state_delayed is used to enable write enable only once during the write state.
            // The write state may last more than one cycle if stepping mode is used. 
            current_state_delayed <= current_state;    

        end
    end



endmodule