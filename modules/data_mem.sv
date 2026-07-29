// data_mem.sv
// T16 Data Memory — 4096 x 16-bit words, word-addressed.
// Synchronous write, combinational read (so a value written this cycle
// isn't visible until next cycle, but a value already stored can be read
// in the same cycle it's needed — matches regfile.sv's read behavior).
//
// NOTE: this module is generic RAM and knows nothing about the UART.
// mem_decoder.sv sits between the CPU and this module and intercepts
// writes to address 0xFFF before they ever reach here — see mem_decoder.sv.

module data_mem #(
    parameter string INIT_FILE = ""   // optional: path to a $readmemh file for simulation preload
) (
    input  logic        clk,
    input  logic        we,
    input  logic [11:0] addr,
    input  logic [15:0] wr_data,
    output logic [15:0] rd_data
);

    logic [15:0] mem [0:4095];

    // Optional preload — useful for testbenches that want to seed data memory
    // with known values before simulation starts.
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always_ff @(posedge clk) begin
        if (we) begin
            mem[addr] <= wr_data;
        end
    end

    always_comb begin
        rd_data = mem[addr];
    end

endmodule
