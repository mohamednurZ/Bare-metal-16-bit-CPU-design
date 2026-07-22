// regfile.sv
// T16 Register File - 8 registers, 16 bits wide, 2 read ports + 1 write port
// R0 is hardwired to zero: reads of R0 always return 0, writes to R0 are discarded.

module regfile (
    input  logic        clk,
    input  logic        rst,         // synchronous, active-high - clears all registers to 0
    input  logic        we,          // write enable
    input  logic [2:0]  rd_addr,     // destination register (write address)
    input  logic [2:0]  rs1_addr,    // source register 1 (read address)
    input  logic [2:0]  rs2_addr,    // source register 2 (read address)
    input  logic [15:0] wr_data,     // data to write into rd_addr
    output logic [15:0] rs1_data,    // value read from rs1_addr
    output logic [15:0] rs2_data     // value read from rs2_addr
);

    logic [15:0] regs [1:7];  // R1..R7 - R0 is not stored, it's hardwired below

    // Synchronous write - writes to R0 (addr 0) are silently discarded.
    // Reset takes priority over a write in the same cycle.
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 1; i <= 7; i++) begin
                regs[i] <= 16'h0000;
            end
        end else if (we && rd_addr != 3'b000) begin
            regs[rd_addr] <= wr_data;
        end
    end

    // Combinational reads - R0 always reads as zero
    always_comb begin
        rs1_data = (rs1_addr == 3'b000) ? 16'h0000 : regs[rs1_addr];
        rs2_data = (rs2_addr == 3'b000) ? 16'h0000 : regs[rs2_addr];
    end

endmodule
