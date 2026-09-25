module top_level
(
    input  logic        CLOCK_50,
    input  logic [9:0]  SW,
    input  logic [3:0]  KEY,

    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1,
    output logic [6:0]  HEX2,
    output logic [6:0]  HEX3,
    output logic [6:0]  HEX4,
    output logic [6:0]  HEX5
);
    import alu_types_pkg::*;

    // Assign user input to system input.

    logic [1:0] config_aux;     // Used to choose the operands of the ALU.
    assign config_aux = SW[9:8];
    logic [1:0] local_menu;
    assign local_menu = SW[7:6];

    logic [5:0] data;    // These swithces are used for serial data (nibble) entry, register addresses and the opcode.
    assign data = SW[5:0];

    logic reset;  // Async reset. The button of the current FPGA is low when pressed.
                        // This reset goes through the reset bridge before being used.
    assign reset = KEY[0];

    logic step;   // used by the execute_fsm.
    assign step = KEY[1];
    
    logic load;   // used to captue configurations and nibbles for the input_fsm.
    assign load = KEY[2];
    
    logic stepping_mode;  // This should be a toggle, I guess?, Doesn't seem like it in Tabla 1, but it'd be convenient.
    assign stepping_mode = KEY[3];

    logic stepping_mode_is_on;
    assign LEDR[9] = stepping_mode_is_on;

    // logic aux;   // ??? "Puerto libre para depuración o indicadores auxiliares del sistema."
    // assign LEDR[8] = aux;
    assign LEDR[8] = 0;

    
    logic negative;  // These should be displayed in this order: negative, zero, carry, overflow
    assign LEDR[7] = negative;
    logic zero;
    assign LEDR[6] = zero;
    logic carry;
    assign LEDR[5] = carry;
    logic overflow;
    assign LEDR[4] = overflow;

    // exec_FSM_show_state is the complement of the current state.
    logic [1:0] exec_FSM_show_state;
    assign LEDR[3:2] = exec_FSM_show_state; 

    // input_FSM_show_state is the complement of the current state.
    logic [1:0] input_FSM_show_state;
    assign LEDR[1:0] = input_FSM_show_state;

    // Reset bridge

    // logic bridged_reset;    // Is this the correct name for an active low reset with reset bridge?
    // reset_bridge reset_bridge_module (
    //     .clk   (CLOCK_50),
    //     .async_reset (reset),
    //     .reset_with_synchronous_positive_edge (bridged_reset)
    // );
    logic reset_n;


    logic step_pulse;
    key_sync step_key_sync (
        .clk       (CLOCK_50),
        .key_raw   (~step),
        .key0_raw   (KEY[0]),
        .key_pulse   (step_pulse),
        .reset_n (reset_n)
    );
    logic load_pulse;
    key_sync load_key_sync (
        .clk       (CLOCK_50),
        .key_raw   (~load),
        .key0_raw   (KEY[0]),
        .key_pulse   (load_pulse),
        .reset_n ()
    );
    logic stepping_mode_pulse;
    key_sync stepping_mode_key_sync (
        .clk       (CLOCK_50),
        .key_raw   (~stepping_mode),
        .key0_raw   (KEY[0]),
        .key_pulse   (stepping_mode_pulse),
        .reset_n ()
    );
    // Assign stepping_mode_is_on as a toggle driven by stepping_mode_pulse.
        toggle stepping_mode_toggle (
        .clk    (CLOCK_50),
        .reset  (reset_n),
        .enable     (stepping_mode_pulse),
        .out    (stepping_mode_is_on)
    );

    logic execute_FSM_write_enable;

    // Local menu behaviour.
    // Menu 00 Enter immediate
    logic [1:0] serial_assembly_FSM_current_state;
    assign input_FSM_show_state = ~serial_assembly_FSM_current_state;

    logic [15:0] immediate;

    logic step_input_fsm;
    assign step_input_fsm = load_pulse && local_menu == 2'b00;

    // instantiate the serial_assembly_FSM and connect it or something.
    input_fsm serial_assembly_FSM (
        .clk   (CLOCK_50),
        .reset (reset_n & ~execute_FSM_write_enable),  // input_fsm accepts a new input when the last one was sent.
        .nibble_input (data[3:0]),
        .step (step_input_fsm),
        .out (immediate),
        .current_state (serial_assembly_FSM_current_state)
    );

    // Menu 01 Enter destination and source registers
    logic [1:0] rd;
    logic [1:0] rs1;
    logic [1:0] rs2;

    // Modular version of this menu is only 1 line shorter.
    // menu_memory_registers menu_memory_01 (
    //     .clk   (CLOCK_50),
    //     .reset      (src0), 
    //     .data      (src1),
    //     .local_menu (local_menu),
    //     .load_pulse (load_pulse),
    //     .rd (rd),
    //     .rs1 (rs1),
    //     .rs2  (rs2)
    // );

    always_ff @(posedge CLOCK_50 or negedge reset_n) begin
        if (~reset_n) begin
            rd <= 2'b00;
            rs1 <= 2'b00;
            rs2 <= 2'b00;
        end
        else if (load_pulse && local_menu == 2'b01) begin
            rd <= data[5:4];
            rs1 <= data[3:2];
            rs2 <= data[1:0];
        end
        else begin
            // No logic in an else block defaults to the default behaviour which is to mantain the current value of the flip flops.
        end
    end

    // Menu 10 Enter ALU opcdoe
    logic [3:0] alu_control;
    always_ff @(posedge CLOCK_50 or negedge reset_n) begin
        if (~reset_n) begin
            alu_control <= 4'b0000;
        end
        else if (load_pulse && local_menu == 2'b10) begin
            alu_control <= data[3:0];
        end
    end

    // Menu 11 Start execution
    // Execute FSM signals:
    logic [1:0] execute_FSM_current_state;
    assign exec_FSM_show_state = ~execute_FSM_current_state;
    

    // start_execute_fsm may need to stay on for several cycles to wait for the user to hit step.
    // start_execute_fsm is reset by execute_FSM_write_enable because at the moment that signal appears,
    //there's no longer risk at raising this signal again.
    logic start_execute_fsm;
    always_ff @(posedge CLOCK_50 or negedge reset_n) begin
        if (~reset_n) begin   // async reset.
            start_execute_fsm <= 1'b0;
        end
        else if (load_pulse && local_menu == 2'b11) begin
            start_execute_fsm <= 1'b1;
        end
        else if (execute_FSM_write_enable) begin    // sync reset when the fsm raises write enable.
            start_execute_fsm <= 1'b0;
        end   
    end
    
    exec_fsm execute_fsm (
        .clk   (CLOCK_50),
        .reset      (reset_n),
        .start_execute      (start_execute_fsm),
        .step (step_pulse),
        .stepping_mode  (stepping_mode_is_on),
        .write_enable  (execute_FSM_write_enable),
        .current_state  (execute_FSM_current_state)
    );

    // Signals extracted from the state of the FSM:
    logic execute_fsm_is_idle;
    assign execute_fsm_is_idle = execute_FSM_current_state == 2'b11;



    // Instantiate a 16-bit ALU
    alu_flags_t alu_flags;
    logic [15:0] alu_result;
    
    // Preserve the ALU result during execution for the displays and writing.
    // alu_result_freeze can't be changed if the execute fsm is running, 
    //otherwise it's overwritten alu_result every cycle.
    // This mimics alu result going through a pipeline, so that write enable is synchronous to the ALU result.
    logic [15:0] alu_result_freeze;
    always_ff @(posedge CLOCK_50 or negedge reset_n) begin
        if (~reset_n) begin
            alu_result_freeze <= 16'b0000000000000000;
        end
        else if (execute_fsm_is_idle) begin
            alu_result_freeze <= alu_result;
        end
    end
    
    // Assign alu_flags to the outputs of the top module.
    assign negative = alu_flags.negative;
    assign zero = alu_flags.zero;
    assign carry = alu_flags.carry;
    assign overflow = alu_flags.overflow;

    // Choose ALU operands based on config_aux
    logic [15:0] operand_a;
    logic [15:0] operand_b;
    logic [15:0] rs1_data;
    logic [15:0] rs2_data;
    
    always_comb begin
        case (config_aux)
            2'b00: begin 
                operand_a = rs1_data;
                operand_b = immediate;
            end
            2'b01: begin 
                operand_a = rs1_data;
                operand_b = rs2_data;
            end
            2'b10: begin 
                operand_a = immediate;
                operand_b = rs1_data;
            end
            2'b11: begin 
                operand_a = rs2_data;
                operand_b = rs1_data;
            end
            default: begin 
                operand_a = rs1_data;
                operand_b = immediate;
            end
        endcase
    end

    alu_param #(
        .WIDTH(16)
    ) alu_a (
        .code   (alu_op_t'(alu_control)),
        .a      (operand_a),
        .b      (operand_b),
        .result (alu_result),
        .flags  (alu_flags)
    );



    // Instantiate the reg file
    register_bank #(
        .WIDTH(16)
    ) u_register_bank (
        .clk        (CLOCK_50),
        .reset_n    (reset_n),
        .rd         (rd),
        .rs1        (rs1),
        .rs2        (rs2),
        .write_en   (execute_FSM_write_enable),
        .write_data (alu_result_freeze),
        .rs1_data   (rs1_data),
        .rs2_data   (rs2_data)
    );
    
    

    // Isntantiate display logic to drive the 7-segment displays.
    display_logic display_logic_using_local_menu (
        .local_menu        (local_menu),
        .immediate    (immediate),
        .rd        (rd),
        .rs1        (rs1),
        .rs2   (rs2),
        .opcode (alu_control),  // Show the alu_control to see the saved opcode or data[3:0] to see the current state of the switches.
        .alu_result_freeze   (alu_result_freeze),
        .HEX0   (HEX0),
        .HEX1   (HEX1),
        .HEX2   (HEX2),
        .HEX3   (HEX3),
        .HEX4   (HEX4),
        .HEX5   (HEX5)
    );

endmodule

