module tb_top_level;

    localparam int CLK_PERIOD = 20;


    logic        CLOCK_50;
    logic [9:0]  SW;
    logic [3:0]  KEY;

    logic [9:0]  LEDR;
    logic [6:0]  HEX0;
    logic [6:0]  HEX1;
    logic [6:0]  HEX2;
    logic [6:0]  HEX3;
    logic [6:0]  HEX4;
    logic [6:0]  HEX5;

    int errors;
    int checks;

    localparam logic [6:0] SEG [0:9] = '{
        7'b0000001, // 0
        7'b1001111, // 1
        7'b0010010, // 2
        7'b0000110, // 3
        7'b1001100, // 4
        7'b0100100, // 5
        7'b0100000, // 6
        7'b0001111, // 7
        7'b0000000, // 8
        7'b0001100  // 9
    };
    // localparam logic [6:0] SEG [0:9] = '{
    //     7'b1000000, // 0
    //     7'b1111001, // 1
    //     7'b0100100, // 2
    //     7'b0110000, // 3
    //     7'b0011001, // 4
    //     7'b0010010, // 5
    //     7'b0000010, // 6
    //     7'b1111000, // 7
    //     7'b0000000, // 8
    //     7'b0011000  // 9
    // };

    localparam logic [6:0] SEG_OFF   = 7'b1111111;
    localparam logic [6:0] SEG_MINUS = 7'b0111111;

    // import alu_types_pkg::*;

    // Assign helpers.
    task automatic set_SW_config_aux(input logic [1:0] value);
        begin
            SW[9:8] = value;
            wait_x_cycles(3);
        end
    endtask
    task automatic set_SW_local_menu(input logic [1:0] value);
        begin
            SW[7:6] = value;
            wait_x_cycles(3);
        end
    endtask
    task automatic set_SW_data(input logic [5:0] value);
        begin
            SW[5:0] = value;
            wait_x_cycles(3);
        end
    endtask
    task automatic set_SW_nibble(input logic [3:0] value);
        SW[3:0] = value;
        wait_x_cycles(3);
    endtask
    
    task automatic tap_KEY_reset();
        begin
            KEY[0] = 0;
            wait_x_cycles(3);
            KEY[0] = 1;
            wait_x_cycles(3);
            #1;
        end
    endtask
    task automatic tap_KEY_step();
        begin
            KEY[1] = 0;
            wait_x_cycles(3);
            KEY[1] = 1;
            wait_x_cycles(3);
            #1;
        end
    endtask
    task automatic tap_KEY_load();
        begin
            KEY[2] = 0;
            wait_x_cycles(3);
            KEY[2] = 1;
            wait_x_cycles(3);
            #1;
        end
    endtask
    task automatic tap_KEY_stepping_mode();
        begin
            KEY[3] = 0;
            wait_x_cycles(3);
            KEY[3] = 1;
            wait_x_cycles(3);
            #1;
        end
    endtask
    
    // Rename I/O
    // Inputs
    logic [1:0] config_aux;
    assign config_aux = SW[9:8];
    logic [1:0] local_menu;
    assign local_menu = SW[7:6];
    logic [5:0] data;
    assign data = SW[5:0];
    logic reset;
    assign reset = KEY[0];
    logic step;
    assign step = KEY[1];
    logic load;
    assign load = KEY[2];
    logic stepping_mode;
    assign stepping_mode = KEY[3];

    // Outputs
    logic stepping_mode_is_on;
    assign stepping_mode_is_on = LEDR[9];
    logic aux;   // "Puerto libre para depuración o indicadores auxiliares del sistema."
    assign aux = LEDR[8];
    logic negative;  // These should be displayed in this order: negative, zero, carry, overflow
    assign negative = LEDR[7];
    logic zero;
    assign zero = LEDR[6];
    logic carry;
    assign carry = LEDR[5];
    logic overflow;
    assign overflow = LEDR[4];
    logic [1:0] exec_FSM_show_state;
    assign exec_FSM_show_state = LEDR[3:2];
    logic [1:0] input_FSM_show_state;
    assign input_FSM_show_state = LEDR[1:0];

    top_level dut (
        .CLOCK_50 (CLOCK_50),
        .SW       (SW),
        .KEY      (KEY),
        .LEDR     (LEDR),
        .HEX0     (HEX0),
        .HEX1     (HEX1),
        .HEX2     (HEX2),
        .HEX3     (HEX3),
        .HEX4     (HEX4),
        .HEX5     (HEX5)
    );

    // Start clock
    initial CLOCK_50 = 1'b0;
    always #(CLK_PERIOD / 2) CLOCK_50 = ~CLOCK_50;

    task automatic check(string name, logic actual, logic expected);
        checks++;
        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%0b actual=%0b", name, expected, actual);
        end else begin
            $display("PASS: %s", name);
        end
    endtask
    task automatic check_LEDR(string name, logic [9:0] actual, logic [9:0] expected);
        checks++;
        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%0b actual=%0b", name, expected, actual);
        end else begin
            $display("PASS: %s", name);
        end
    endtask
    task automatic check_state(string name, logic [3:0] actual, logic [3:0] expected);
        checks++;
        if (actual !== expected) begin
            errors++;
            $display("FAIL: %s | expected=%0b actual=%0b", name, expected, actual);
        end else begin
            $display("PASS: %s", name);
        end
    endtask

    task automatic check_display(input string name, input logic [15:0] value);
        int unsigned abs_value;
        int unsigned units;
        int unsigned tens;
        int unsigned hundreds;
        int unsigned thousands;
        int unsigned ten_thousands;
        checks++;

        // Use 2's complement to get abs_value.
        if (value[15]) begin
            abs_value = 65536 - value;
            // $display("IF abs_value hex=%04h | abs_value dec=%0d| abs_value bin=%b", abs_value, abs_value, abs_value);
        end else begin
            abs_value = value;
            // $display("ELSE abs_value hex=%04h | abs_value dec=%0d| abs_value bin=%b", abs_value, abs_value, abs_value);
        end

        // $display("abs_value hex=%04h | abs_value dec=%0d| abs_value bin=%b", abs_value, abs_value, abs_value);
        units = abs_value % 10;
        abs_value = abs_value / 10;
        // $display("abs_value hex=%04h | abs_value dec=%0d| abs_value bin=%b", abs_value, abs_value, abs_value);
        tens = abs_value % 10;
        abs_value = abs_value / 10;
        // $display("abs_value hex=%04h | abs_value dec=%0d| abs_value bin=%b", abs_value, abs_value, abs_value);
        hundreds = abs_value % 10;
        abs_value = abs_value / 10;
        // $display("abs_value hex=%04h | abs_value dec=%0d| abs_value bin=%b", abs_value, abs_value, abs_value);
        thousands = abs_value % 10;
        abs_value = abs_value / 10;
        // $display("abs_value hex=%04h | abs_value dec=%0d| abs_value bin=%b", abs_value, abs_value, abs_value);
        ten_thousands = abs_value % 10;

        // $display("abs_value hex=%04h | abs_value dec=%0d| abs_value bin=%b", abs_value, abs_value, abs_value);

        if (
            (HEX0 !== SEG[units]) ||
            (HEX1 !== SEG[tens]) ||
            (HEX2 !== SEG[hundreds]) ||
            (HEX3 !== SEG[thousands]) ||
            (HEX4 !== SEG[ten_thousands]) ||
            (value[15] && (HEX5 !== SEG_MINUS)) || // value is negative and there's no '-'
            (!value[15] && (HEX5 !== SEG_OFF))     // value is positive and the last HEX is not off.
        ) begin
            errors++;

            $display(
                "FAIL: %s | value=%04h | expected digits=%0d%0d%0d%0d%0d | HEX=%b %b %b %b %b %b",
                name,
                value,
                ten_thousands,
                thousands,
                hundreds,
                tens,
                units,
                HEX5,
                HEX4,
                HEX3,
                HEX2,
                HEX1,
                HEX0
            );
        end
        else begin
            $display(
                "PASS: %s | displayed value=%04h",
                name,
                value
            );
        end

    endtask


    // Set defaults and wait helpers.
    task automatic apply_defaults();
        begin
            SW[7:0] = 8'b0; // Retains config_aux
            KEY = 4'b1111;
        end
    endtask

    task automatic wait_x_cycles(input int x);
        repeat (x)
            @(posedge CLOCK_50);
    endtask

    task automatic wait_past_rising_edge();
        begin
            @(posedge CLOCK_50);
            #1;
        end
    endtask

    // Set operation helpers
    task automatic menu01_set_regs(input logic [5:0] regs);
        wait_past_rising_edge();
        set_SW_data(regs);
        wait_past_rising_edge();
        set_SW_local_menu(2'b01);
        wait_past_rising_edge();
        tap_KEY_load();
    endtask

    task automatic menu10_set_opcode(input logic [3:0] opcode);
        wait_past_rising_edge();
        set_SW_nibble(opcode);
        wait_past_rising_edge();
        set_SW_local_menu(2'b10);
        wait_past_rising_edge();
        tap_KEY_load();
    endtask



    // ---test_use_case---
    initial begin

        errors = 0;
        checks = 0;

        // First Test
        // Enter a DCBA, try to enter a fifth nibble,
        // rd = 10; rs1 = 01; rs2 = 00,
        // opcode = 1
        // config_aux = 00 -> reg10 = reg01 - DCBA = 2346
        // Assert ALU flags == 0000
        // Launch execution to save the value
        $display("---First Test---");
        apply_defaults();
        tap_KEY_reset();

        // Check only zero flag remains after reset.
        check_LEDR("LEDR == 10'b0001000000", LEDR, 10'b0001000000);

        apply_defaults();

        // Enter A
        set_SW_nibble(4'hA);
        wait_past_rising_edge();
        tap_KEY_load();
        // Enter B
        set_SW_nibble(4'hB);
        tap_KEY_load();
        // Enter C
        set_SW_nibble(4'hC);
        tap_KEY_load();
        // Enter D
        set_SW_nibble(4'hD);
        tap_KEY_load();
        // Try to enter a fifth nibble.
        set_SW_nibble(4'hF);
        tap_KEY_load();
        check_display(
            "With local_menu==00, HEX == DCBA",
            16'hDCBA
        );

        // Menu 01 Enter destination and source registers
        wait_past_rising_edge();
        menu01_set_regs(6'b100100);

        // Assert that {rd, rs1, rs2} == 6'b10 01 00 in decimal on HEX.
        checks++;
        if (
            (HEX0 !== SEG[2]) ||    //rd
            (HEX1 !== SEG[1]) ||    //rs1
            (HEX2 !== SEG[0])       //rs2
        ) begin
            errors++;
            $display(
                "FAIL: Register configuration display"
            );
        end
        else begin
            $display(
                "PASS: Register configuration display"
            );
        end

        apply_defaults();
        wait_past_rising_edge();
        // Menu 10 Enter ALU opcode
        menu10_set_opcode(4'b0001);

        // Set operands
        set_SW_config_aux(2'b00);
        wait_past_rising_edge();

        // Check ALU flags.
        check("negative == 0", negative, 1'b0);
        check("zero == 0", zero, 1'b0);
        check("carry == 0", carry, 1'b0);
        check("overflow == 0", overflow, 1'b0);
        wait_past_rising_edge();



        // Menu 11 Start execution. Use automatic stepping.
        apply_defaults();
        #1;
        set_SW_local_menu(2'b11);
        #1;
        wait_past_rising_edge();
        check_display(
            "With local_menu==11, HEX == 16'h2346",
            16'h2346
        );
        #1;
        check("stepping_mode_is_on == 0", stepping_mode_is_on, 1'b0);
        #1;
        check_state("exec_FSM_show_state == 00", exec_FSM_show_state, 2'b00);

        // Launch execute_fsm.
        tap_KEY_load();
        wait_x_cycles(10);  // Make sure exec_fsm finishes











        // Menu 01 Enter destination and source registers
        // Menu 10 Enter ALU opcode
        // Menu 11 Start execution. Use automatic stepping.


        // Second Test
        // Use manual stepping mode.
        // Assert alu result using reg10 as an operand.
        // This test will also write to a source register. 
        // For this, execute reg10 = reg10 + reg10
        // == 0x2346 + 0x2346
        // == 0x468C
        // Skip menu 00 because no immediate will be used.

        $display("---Second Test---");
        apply_defaults();
        #1;

        // Menu 01 Enter destination and source registers
        menu01_set_regs(6'b101010);
        wait_past_rising_edge();

        // Menu 10 Enter ALU opcode
        menu10_set_opcode(4'b0000);
        #1
    
        set_SW_config_aux(2'b01);
        #1

        // Menu 11 Start execution. Use automatic stepping.
        wait_past_rising_edge();
        apply_defaults();
        #1;
        set_SW_local_menu(2'b11);
        wait_past_rising_edge();
        check_display(
            "With local_menu==11, HEX == 16'h468C",
            16'h468C
        );
        #1;
        tap_KEY_stepping_mode();
        check("stepping_mode_is_on == 1", stepping_mode_is_on, 1'b1);
        #1;
        check_state("exec_FSM_show_state == 00", exec_FSM_show_state, 2'b00);
        
        // Launch execute_fsm and slowly advance through the states.
        wait_past_rising_edge();
        tap_KEY_load();
        wait_past_rising_edge();
        check_state("exec_FSM_show_state == 00", exec_FSM_show_state, 2'b00);
        tap_KEY_step();
        check_state("exec_FSM_show_state == 01", exec_FSM_show_state, 2'b01);
        tap_KEY_step();
        check_state("exec_FSM_show_state == 10", exec_FSM_show_state, 2'b10);
        tap_KEY_step();
        check_state("exec_FSM_show_state == 11", exec_FSM_show_state, 2'b11);
        tap_KEY_step();
        check_state("exec_FSM_show_state == 00", exec_FSM_show_state, 2'b00);
        tap_KEY_step();
        check_state("exec_FSM_show_state == 00", exec_FSM_show_state, 2'b00);
        // Stays at 0 because the fsm needs to be launched with the load key again.









        // Third Test
        // Save an undefined 16'hXXXX value using the whole datapath (both fsms)
        // For this, execute reg11 = reg00 + immediate
        // immediate = 16'hXXXX
        $display("---Third Test---");
        apply_defaults();
        wait_past_rising_edge();

        // Enter X
        set_SW_nibble(4'bXXXX);
        tap_KEY_load();
        // Enter X
        set_SW_nibble(4'bXXXX);
        tap_KEY_load();
        // Enter X
        set_SW_nibble(4'bXXXX);
        tap_KEY_load();
        // Enter X
        set_SW_nibble(4'bXXXX);
        tap_KEY_load();
        
        check_display(
            "With local_menu==00, HEX == XXXX",
            16'hXXXX
        );

        // Menu 01 Enter destination and source registers
        wait_past_rising_edge();
        menu01_set_regs(110000);

        // Assert that {rd, rs1, rs2} == 6'b11 00 00 in decimal on HEX.
        checks++;
        if (
            (HEX0 !== SEG[3]) ||    //rd
            (HEX1 !== SEG[0]) ||    //rs1
            (HEX2 !== SEG[0])       //rs2
        ) begin
            errors++;
            $display(
                "FAIL: Register configuration display"
            );
        end
        else begin
            $display(
                "PASS: Register configuration display"
            );
        end

        wait_past_rising_edge();
        apply_defaults();
        wait_past_rising_edge();

        // Menu 10 Enter ALU opcode
        menu10_set_opcode(4'b0000);

        // Set operands
        set_SW_config_aux(2'b00);
        wait_past_rising_edge();

        // Menu 11 Start execution. Use automatic stepping.
        apply_defaults();
        #1;
        set_SW_local_menu(2'b11);
        wait_past_rising_edge();
        check_display(
            "With local_menu==11, HEX == 16'hXXXX",
            16'hXXXX
        );
        #1;
        tap_KEY_stepping_mode();
        check("stepping_mode_is_on == 0", stepping_mode_is_on, 1'b0);
        #1;
        check_state("exec_FSM_show_state == 00", exec_FSM_show_state, 2'b00);

        // Launch execute_fsm.
        tap_KEY_load();
        wait_x_cycles(10);  // Make sure exec_fsm finishes



        $display("----------------------------------------");
        $display("TOTAL_CHECKS=%0d", checks);
        $display("ERRORS=%0d", errors);
        $display("WARNINGS=0");
        if (errors == 0) begin
            $display("ALL_TESTS_PASSED");
        end else begin
            $display("TESTS_FAILED");
        end
        $display("----------------------------------------");

        $finish;

    end

endmodule
