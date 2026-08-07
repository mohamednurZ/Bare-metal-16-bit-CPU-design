// cpu_top.sv
// T16 CPU — Top-level integration. Wires together: pc, instr_mem,
// instr_decode, control_unit, regfile, alu, mem_decoder (+ data_mem),
// uart_tx. Single-cycle: fetch, decode, execute, memory access, and
// write-back all happen within one clock period.
//
// NOTE: every internal signal is declared at the TOP of the module,
// before any submodule instantiation uses it. This avoids Vivado's
// single-pass compiler silently creating an implicit (and potentially
// wrongly-sized) wire the first time a signal is referenced, ahead of
// its real declaration -- a real, worth-knowing SystemVerilog footgun.

module cpu_top #(
    parameter string INSTR_INIT_FILE = "",          // .mem file from assembler.py
    parameter int    CLK_FREQ_HZ     = 125_000_000, // MUST match your actual board clock
    parameter int    BAUD_RATE       = 9600
) (
    input  logic clk,
    input  logic rst,          // dedicated reset button, per your design decision

    output logic uart_tx_serial,  // to the board's UART TX pin
    output logic halted_led       // optional: wire to an LED so a demo can show "program finished"
);

    // ---------------------------------------------------------------
    // All internal signal declarations (grouped by which stage they
    // belong to, but declared up front regardless of use order below)
    // ---------------------------------------------------------------

    // PC <-> instruction memory
    logic [15:0] pc_out;
    logic [15:0] instr;

    // Instruction decode outputs
    logic [3:0]  opcode;
    logic [2:0]  rd, rs1, rs2, b_rs1, b_rs2;
    logic [15:0] imm6_sext, imm9_sext;
    logic [11:0] addr12;

    // Control unit outputs
    logic [2:0] alu_op;
    logic       alu_src_imm, use_branch_regs;
    logic       reg_write;
    logic [1:0] reg_write_src;
    logic       mem_read, mem_write;
    logic       branch_eq, branch_ne, jump, halt;

    // Register file
    logic [2:0]  regfile_rs1_addr, regfile_rs2_addr;
    logic [15:0] rs1_data, rs2_data;
    logic [15:0] regfile_wr_data;

    // ALU
    logic [15:0] alu_b, alu_result;

    // Memory
    logic [15:0] mem_rd_data;
    logic        uart_tx_start;
    logic [7:0]  uart_tx_data;

    // Branch resolution
    logic        branch_condition_met;
    logic        take_branch;
    logic [15:0] branch_target;

    // Write-back mux encoding
    localparam logic [1:0] WB_ALU = 2'b00;
    localparam logic [1:0] WB_MEM = 2'b01;
    localparam logic [1:0] WB_IMM = 2'b10;

    // ---------------------------------------------------------------
    // Program Counter <-> Instruction Memory
    // ---------------------------------------------------------------
    pc u_pc (
        .clk(clk),
        .rst(rst),
        .halt(halt),
        .take_branch(take_branch),
        .jump(jump),
        .branch_target(branch_target),
        .jump_target(addr12),
        .pc_out(pc_out)
    );

    instr_mem #(
        .INIT_FILE(INSTR_INIT_FILE)
    ) u_instr_mem (
        .pc(pc_out),
        .instr(instr)
    );

    // ---------------------------------------------------------------
    // Instruction Decode
    // ---------------------------------------------------------------
    instr_decode u_instr_decode (
        .instr(instr),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .b_rs1(b_rs1),
        .b_rs2(b_rs2),
        .imm6_sext(imm6_sext),
        .imm9_sext(imm9_sext),
        .addr12(addr12)
    );

    // ---------------------------------------------------------------
    // Control Unit
    // ---------------------------------------------------------------
    control_unit u_control_unit (
        .opcode(opcode),
        .alu_op(alu_op),
        .alu_src_imm(alu_src_imm),
        .use_branch_regs(use_branch_regs),
        .reg_write(reg_write),
        .reg_write_src(reg_write_src),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch_eq(branch_eq),
        .branch_ne(branch_ne),
        .jump(jump),
        .halt(halt)
    );

    // ---------------------------------------------------------------
    // Register File
    // ---------------------------------------------------------------
    // Read-address muxing — this is the one non-obvious wiring decision
    // in the whole design, worth understanding rather than just trusting:
    //
    //   rs1_addr: branches read b_rs1 (see instr_decode.sv's field-mapping
    //             note); everything else reads rs1 normally.
    //
    //   rs2_addr: branches read b_rs2. BUT for SW specifically, the ISA
    //             spec's "Rd" field is actually the *source* register
    //             holding the value to store (MEM[Rs1+imm6] = Rd) — not
    //             a write destination. Since regfile only has two read
    //             ports, we reuse the second one: when mem_write is
    //             asserted (SW), route 'rd' into this read port instead
    //             of 'rs2', so its VALUE comes out as rs2_data and can be
    //             forwarded to mem_decoder as the data to store. R-type
    //             instructions still get their real Rs2 here as normal.
    assign regfile_rs1_addr = use_branch_regs ? b_rs1 : rs1;
    assign regfile_rs2_addr = use_branch_regs ? b_rs2 : (mem_write ? rd : rs2);

    regfile u_regfile (
        .clk(clk),
        .rst(rst),
        .we(reg_write),
        .rd_addr(rd),
        .rs1_addr(regfile_rs1_addr),
        .rs2_addr(regfile_rs2_addr),
        .wr_data(regfile_wr_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // ---------------------------------------------------------------
    // ALU
    // ---------------------------------------------------------------
    // 'a' is always Rs1's value: for R-type it's an operand, for
    // ADDI/LW/SW it's the base address being offset.
    // 'b' is either Rs2's value (R-type) or the sign-extended imm6
    // (ADDI/LW/SW use the ALU purely as an address/offset adder).
    assign alu_b = alu_src_imm ? imm6_sext : rs2_data;

    alu u_alu (
        .a(rs1_data),
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_result)
    );

    // ---------------------------------------------------------------
    // Memory (data RAM + UART address decode)
    // ---------------------------------------------------------------
    mem_decoder u_mem_decoder (
        .clk(clk),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .addr(alu_result[11:0]),   // ALU computed Rs1 + imm6 as the address
        .wr_data(rs2_data),        // see the read-address mux note above — this is Rd's value for SW
        .rd_data(mem_rd_data),
        .uart_tx_start(uart_tx_start),
        .uart_tx_data(uart_tx_data)
    );

    // ---------------------------------------------------------------
    // UART Transmitter
    // ---------------------------------------------------------------
    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .rst(rst),
        .tx_start(uart_tx_start),
        .tx_data(uart_tx_data),
        .tx_serial(uart_tx_serial),
        .tx_busy()   // not currently checked by mem_decoder — documented limitation, see mem_decoder.sv
    );

    // ---------------------------------------------------------------
    // Write-back mux — picks what actually gets written to the register file
    // ---------------------------------------------------------------
    always_comb begin
        case (reg_write_src)
            WB_ALU:  regfile_wr_data = alu_result;
            WB_MEM:  regfile_wr_data = mem_rd_data;
            WB_IMM:  regfile_wr_data = imm9_sext;
            default: regfile_wr_data = 16'h0000;
        endcase
    end

    // ---------------------------------------------------------------
    // Branch resolution and PC control
    // ---------------------------------------------------------------
    // rs1_data/rs2_data already hold b_rs1/b_rs2's values for branch
    // instructions, thanks to the read-address mux above — so the
    // equality compare is just a straight comparison of what's already
    // sitting on the register file's read ports.
    assign branch_condition_met = (rs1_data == rs2_data);

    assign take_branch = (branch_eq && branch_condition_met) ||
                          (branch_ne && !branch_condition_met);

    // Branch target = PC + 1 + sext(offset6). imm6_sext already holds
    // the sign-extended offset — same field, reused for B-type per the
    // ISA spec's encoding.
    assign branch_target = pc_out + 16'd1 + imm6_sext;

    // ---------------------------------------------------------------
    // Debug / demo output
    // ---------------------------------------------------------------
    assign halted_led = halt;

endmodule
