`timescale 1ns/1ps

module tb_multicycle_rv_control_fsm;

    import multicycle_rv_opcodes_pkg::*;
    import multicycle_rv_control_fsm_states_pkg::*;

    localparam int CLK_PERIOD = 20;
    localparam int FETCH_WAIT = 3;   // ciclos con ready_in_instr_memory = 0 antes del handshake
    localparam int MEM_WAIT   = 2;   // ciclos con ready_in_data_memory = 0 antes del handshake
    localparam multicycle_rv_opcode OP_IDLE = multicycle_rv_opcode'(7'b0000000);

    logic clk;
    logic rst_n;
    multicycle_rv_opcode op;
    logic soft_reset_n;
    logic enable;

    logic ready_in_instr_memory;
    logic ready_in_data_memory;
    logic valid_out_instr_memory;
    logic valid_out_data_memory;
    logic handshake_instr_memory;
    logic handshake_data_memory;

    logic        branch;
    logic        pc_update;
    logic        reg_write;
    logic        mem_write;
    logic        ir_write;
    logic [1:0]  result_src;
    logic [1:0]  alu_src_a;
    logic [1:0]  alu_src_b;
    logic        adr_src;
    logic [1:0]  alu_op;
    logic        forward_rs1;
    logic [3:0]  state_num;
    logic        illegal;

    int errors;
    int checks;

    multicycle_rv_control_fsm dut (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .op                       (op),
        .soft_reset_n             (soft_reset_n),
        .enable                   (enable),
        .ready_in_instr_memory    (ready_in_instr_memory),
        .ready_in_data_memory     (ready_in_data_memory),
        .valid_out_instr_memory   (valid_out_instr_memory),
        .valid_out_data_memory    (valid_out_data_memory),
        .handshake_instr_memory   (handshake_instr_memory),
        .handshake_data_memory    (handshake_data_memory),
        .branch                   (branch),
        .pc_update                (pc_update),
        .reg_write                (reg_write),
        .mem_write                (mem_write),
        .ir_write                 (ir_write),
        .result_src               (result_src),
        .alu_src_a                (alu_src_a),
        .alu_src_b                (alu_src_b),
        .adr_src                  (adr_src),
        .alu_op                   (alu_op),
        .forward_rs1              (forward_rs1),
        .state_num                (state_num),
        .illegal                  (illegal)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Compara current_state con el estado esperado
    task automatic check_state(input multicycle_rv_control_fsm_state expected);
        checks++;
        if (dut.current_state !== expected) begin
            errors++;
            $display("FAIL: t=%0t op=%h expected=%s actual=%s",
                     $time, op, expected.name(), dut.current_state.name());
        end
    endtask

    // Verifica el estado del ciclo actual y avanza al siguiente flanco de bajada
    task automatic cycle(input multicycle_rv_control_fsm_state expected);
        check_state(expected);
        @(negedge clk);
    endtask

    // Ejecuta una instrucción completa y verifica la secuencia de estados
    task automatic run_instruction(input multicycle_rv_opcode opc);
        // FETCH con backpressure: ready_in_instr_memory = 0 y opcode dummy
        op = OP_IDLE;
        ready_in_instr_memory = 1'b0;
        repeat (FETCH_WAIT) cycle(FETCH);

        // Handshake de instrucción junto con la aparición del nuevo opcode
        ready_in_instr_memory = 1'b1;
        op = opc;
        cycle(FETCH);
        ready_in_instr_memory = 1'b0;

        cycle(DECODE);

        case (opc)
            R_TYPE_OP: begin
                cycle(EXECUTE_R);
                cycle(ALU_WB);
            end
            I_TYPE_OP: begin
                cycle(EXECUTE_I);
                cycle(ALU_WB);
            end
            LUI_OP: begin
                cycle(EXECUTE_I);
                cycle(ALU_WB);
            end
            I_LOAD_OP: begin
                cycle(MEM_ADR);
                // MEM_READ con backpressure de memoria de datos
                repeat (MEM_WAIT) cycle(MEM_READ);
                ready_in_data_memory = 1'b1;
                cycle(MEM_READ);            // handshake_data_memory = 1
                ready_in_data_memory = 1'b0;
                cycle(MEM_WB);
            end
            S_OP: begin
                cycle(MEM_ADR);
                // MEM_WRITE con backpressure de memoria de datos
                repeat (MEM_WAIT) cycle(MEM_WRITE);
                ready_in_data_memory = 1'b1;
                cycle(MEM_WRITE);           // handshake_data_memory = 1
                ready_in_data_memory = 1'b0;
            end
            B_OP: begin
                cycle(BEQ);
            end
            J_OP, I_JUMP_OP: begin
                cycle(JAL);
                cycle(ALU_WB);
            end
            default: begin
                errors++;
                $display("FAIL: opcode sin secuencia definida: %h", opc);
            end
        endcase

        // Al terminar la instrucción la FSM vuelve a FETCH
        cycle(FETCH);
    endtask

    initial begin : main
        multicycle_rv_opcode ops [8];
        int fd;

        errors = 0;
        checks = 0;

        // Señales constantes durante toda la prueba
        soft_reset_n = 1'b1;
        enable       = 1'b1;

        // Reset inicial
        rst_n                 = 1'b0;
        op                    = OP_IDLE;
        ready_in_instr_memory = 1'b0;
        ready_in_data_memory  = 1'b0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        cycle(FETCH);

        ops = '{R_TYPE_OP, I_TYPE_OP, I_LOAD_OP, S_OP, B_OP, J_OP, I_JUMP_OP, LUI_OP};
        foreach (ops[i]) begin
            run_instruction(ops[i]);
        end

        $display("----------------------------------------");
        $display("TOTAL_CHECKS=%0d", checks);
        $display("ERRORS=%0d", errors);
        $display("WARNINGS=0");
        if (errors == 0) $display("ALL_TESTS_PASSED");
        else             $display("TESTS_FAILED");
        $display("----------------------------------------");

        fd = $fopen("questa_test_summary.log", "w");
        $fdisplay(fd, "TOTAL_CHECKS=%0d", checks);
        $fdisplay(fd, "ERRORS=%0d", errors);
        $fdisplay(fd, "WARNINGS=0");
        if (errors == 0) $fdisplay(fd, "ALL_TESTS_PASSED");
        else             $fdisplay(fd, "TESTS_FAILED");
        $fclose(fd);

        $finish;
    end

endmodule
