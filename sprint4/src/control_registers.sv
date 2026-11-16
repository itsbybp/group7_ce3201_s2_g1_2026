// Registros MMIO del Sprint 4: perifericos LEDR/HEX y registros de control.
//
//   0x40000 LEDR       R/W Host y CPU   (10 bits)
//   0x40004 HEX        R/W Host y CPU   (24 bits, un nibble por display)
//   0x50000 CTRL       R/W Host, RO CPU (bit 0 = start)
//   0x50004 STATUS     RO Host, R/W CPU (bit 0 = busy, calculado; bit 1 = done)
//   0x5000C THRESHOLD  R/W Host, RO CPU (0 a 255)
//
// Los permisos por maestro los aplica el mmio_decoder (we_* ya filtrados).
// La lectura esta registrada: dato valido un ciclo despues de mmio_address,
// igual que las RAM.
module control_registers
(
    input  logic        clk,
    input  logic        reset_n,

    // verilator lint_off UNUSEDSIGNAL
    input  logic [31:0] write_data,    // solo se usan los bits bajos
    input  logic [31:0] mmio_address,  // solo se usan los bits 16, 3 y 2
    // verilator lint_on UNUSEDSIGNAL

    input  logic        we_ledr,
    input  logic        we_hex,
    input  logic        we_ctrl,
    input  logic        we_status,
    input  logic        we_threshold,

    output logic [31:0] selected_register,

    // Hacia el procesador
    output logic        start,        // CTRL[0]: soft_reset_n del procesador
    output logic        cpu_enable,   // start && !done: apaga los valid al terminar
    output logic        busy,
    output logic        done,

    // Hacia perifericos y firmware
    output logic [7:0]  threshold,
    output logic [9:0]  ledr,
    output logic [23:0] hex
);

    // Seleccion: bit 16 distingue 0x4xxxx de 0x5xxxx; bits [3:2] el registro
    logic [2:0] select;
    assign select = {mmio_address[16], mmio_address[3:2]};

    localparam logic [2:0] SEL_LEDR      = 3'b000;
    localparam logic [2:0] SEL_HEX       = 3'b001;
    localparam logic [2:0] SEL_CTRL      = 3'b100;
    localparam logic [2:0] SEL_STATUS    = 3'b101;
    localparam logic [2:0] SEL_THRESHOLD = 3'b111;

    assign busy       = start && !done;
    assign cpu_enable = start && !done;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            start     <= 1'b0;
            done      <= 1'b0;
            threshold <= '0;
            ledr      <= '0;
            hex       <= '0;
        end else begin
            if (we_ctrl) begin
                start <= write_data[0];
            end

            // done se limpia mientras start = 0: el Host re-arma bajando y subiendo CTRL[0]
            if (!start) begin
                done <= 1'b0;
            end else if (we_status) begin
                done <= write_data[1];
            end

            if (we_threshold) begin
                threshold <= write_data[7:0];
            end
            if (we_ledr) begin
                ledr <= write_data[9:0];
            end
            if (we_hex) begin
                hex <= write_data[23:0];
            end
        end
    end

    // Lectura registrada; direcciones no mapeadas (p. ej. 0x50008) devuelven 0
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            selected_register <= '0;
        end else begin
            case (select)
                SEL_LEDR:      selected_register <= {22'b0, ledr};
                SEL_HEX:       selected_register <= {8'b0, hex};
                SEL_CTRL:      selected_register <= {31'b0, start};
                SEL_STATUS:    selected_register <= {30'b0, done, busy};
                SEL_THRESHOLD: selected_register <= {24'b0, threshold};
                default:       selected_register <= '0;
            endcase
        end
    end

endmodule
