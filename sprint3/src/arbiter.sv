module arbiter (
    input  logic        clk,
    input  logic        rst_n,

    // vJTAG (manager)
    input  logic        vjtag_valid,
    input  logic [31:0] vjtag_addr,
    input  logic [31:0] vjtag_data,
    output logic        vjtag_ready,

    // FSM (manager)
    input  logic        fsm_valid,
    input  logic [31:0] fsm_addr,
    input  logic [31:0] fsm_data,
    output logic        fsm_ready,

    // Subordinate
    input  logic        subordinate_ready,
    output logic [31:0] mux_addr,
    output logic [31:0] mux_data,
    output logic        mux_valid
);

    typedef enum logic [1:0] {
        IDLE         = 2'b00,
        VJTAG_ACCESS = 2'b01,
        FSM_ACCESS   = 2'b10
    } state_t;

    state_t state, next_state;

    // Estado
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // Siguiente estado
    always_comb begin
        case (state)
            IDLE: begin
                if (vjtag_valid)        next_state = VJTAG_ACCESS;
                else if (fsm_valid)     next_state = FSM_ACCESS;
                else                    next_state = IDLE;
            end
            VJTAG_ACCESS: begin
                if (vjtag_valid)        next_state = VJTAG_ACCESS;
                else if (fsm_valid)     next_state = FSM_ACCESS;
                else                    next_state = IDLE;
            end
            FSM_ACCESS: begin
                if (vjtag_valid)        next_state = VJTAG_ACCESS;
                else if (fsm_valid)     next_state = FSM_ACCESS;
                else                    next_state = IDLE;
            end
            default:                    next_state = IDLE;
        endcase
    end

    // Salidas
    always_comb begin
        mux_addr    = '0;
        mux_data    = '0;
        mux_valid   = 1'b0;
        vjtag_ready = 1'b0;
        fsm_ready   = 1'b0;

        case (state)
            VJTAG_ACCESS: begin
                mux_addr    = vjtag_addr;
                mux_data    = vjtag_data;
                mux_valid   = vjtag_valid;
                vjtag_ready = subordinate_ready;
            end
            FSM_ACCESS: begin
                mux_addr  = fsm_addr;
                mux_data  = fsm_data;
                mux_valid = fsm_valid;
                fsm_ready = subordinate_ready;
            end
            default: ;
        endcase
    end

endmodule