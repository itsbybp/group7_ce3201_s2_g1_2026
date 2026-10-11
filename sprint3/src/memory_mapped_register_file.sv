module memory_mapped_register_file
(
    input  logic        clk,
    input  logic        reset_n,

    input  logic [31:0] mmio_address,

    input  logic        write_en,
    input  logic [31:0] write_data,
    
    output logic [31:0] selected_register  // 32-bit words

);
    logic [4:0] address; 
    assign address = mmio_address[6:2];  // MMIO address ranges from 20000 to 2007C
    // The last two hex digits of the two numbers are: 0000 0000 and 0111 1100.

    logic [31:0] registers [31:1];  // 31 physical registers of 32 bits each. x0 does not have a physical memory component.

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            registers <= '{default: '0};  // Correct way to zero out an unpacked array. i. e. all the values inside the array become '0.
        end else if (write_en && address != 5'b0) begin
            registers[address] <= write_data;
        end
    end

    always_comb begin
        if (address != 5'b0) begin
            selected_register = registers[address];
        end else begin
            selected_register = '0;
        end
        
    end

endmodule