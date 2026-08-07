// pc.sv
// T16 Program Counter — 16-bit register holding the current instruction
// address (as a word address into instr_mem, so it counts 0, 1, 2, ... not
// byte offsets). On reset, execution always starts at address 0 — this is
// why reset matters most for this module: without it, where the CPU starts
// executing would be undefined.

module pc (
    input  logic        clk,
    input  logic         rst,        // synchronous, active-high — forces PC to 0

    input  logic         halt,       // from control_unit — freezes PC when HALT executes
    input  logic         take_branch, // from datapath: (branch_eq && equal) || (branch_ne && !equal)
    input  logic         jump,       // from control_unit — JMP
    input  logic [15:0]  branch_target, // PC + 1 + sext(offset6), computed in cpu_top
    input  logic [11:0]  jump_target,   // address12 from the instruction, zero-extended by caller

    output logic [15:0]  pc_out       // current PC value, fed to instr_mem's address input
);

    logic [15:0] pc_reg = 16'h0000;

    always_ff @(posedge clk) begin
        if (rst) begin
            pc_reg <= 16'h0000;
        end else if (halt) begin
            pc_reg <= pc_reg;  // frozen — HALT stops execution in place
        end else if (jump) begin
            pc_reg <= {4'b0000, jump_target};  // zero-extend 12-bit address to 16 bits
        end else if (take_branch) begin
            pc_reg <= branch_target;
        end else begin
            pc_reg <= pc_reg + 16'd1;  // normal sequential execution
        end
    end

    assign pc_out = pc_reg;

endmodule
