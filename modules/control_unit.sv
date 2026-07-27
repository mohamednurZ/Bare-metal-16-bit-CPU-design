// control_unit.sv
// T16 Control Unit — fully combinational. Decodes the 4-bit opcode into every
// control signal the rest of the datapath needs. Single-cycle design, so this
// is a straightforward case statement with no internal state.

module control_unit (
    input  logic [3:0] opcode,

    output logic [2:0] alu_op,       // passed straight to alu.sv
    output logic       alu_src_imm,  // 1 = ALU's B input is the immediate, 0 = it's rs2/b_rs2
    output logic       use_branch_regs, // 1 = datapath should read b_rs1/b_rs2 (branch), 0 = rd/rs1/rs2 (everything else)

    output logic       reg_write,    // 1 = write ALU/mem/imm result back into rd
    output logic [1:0] reg_write_src, // 00 = ALU result, 01 = memory read data, 10 = immediate (LI)

    output logic       mem_read,     // 1 = LW: read data_mem
    output logic       mem_write,    // 1 = SW: write data_mem (mem_decoder.sv handles UART redirect)

    output logic       branch_eq,    // 1 = BEQ: branch if rs1 == rs2
    output logic       branch_ne,    // 1 = BNE: branch if rs1 != rs2
    output logic       jump,         // 1 = JMP: unconditional PC <= address12

    output logic       halt          // 1 = HALT: stop execution
);

    // reg_write_src encoding
    localparam logic [1:0] WB_ALU  = 2'b00;
    localparam logic [1:0] WB_MEM  = 2'b01;
    localparam logic [1:0] WB_IMM  = 2'b10;

    always_comb begin
        // Safe defaults — every signal off unless a case below turns it on.
        // Prevents accidental latches and makes each case block only need
        // to set what's actually different for that instruction.
        alu_op          = 3'b000;
        alu_src_imm     = 1'b0;
        use_branch_regs = 1'b0;
        reg_write       = 1'b0;
        reg_write_src   = WB_ALU;
        mem_read        = 1'b0;
        mem_write       = 1'b0;
        branch_eq       = 1'b0;
        branch_ne       = 1'b0;
        jump            = 1'b0;
        halt            = 1'b0;

        case (opcode)
            4'b0000: begin // NOP — everything stays at default (no-op)
            end

            4'b0001: begin // ADD
                alu_op    = 3'b001;
                reg_write = 1'b1;
            end

            4'b0010: begin // SUB
                alu_op    = 3'b010;
                reg_write = 1'b1;
            end

            4'b0011: begin // AND
                alu_op    = 3'b011;
                reg_write = 1'b1;
            end

            4'b0100: begin // OR
                alu_op    = 3'b100;
                reg_write = 1'b1;
            end

            4'b0101: begin // XOR
                alu_op    = 3'b101;
                reg_write = 1'b1;
            end

            4'b0110: begin // SHL
                alu_op    = 3'b110;
                reg_write = 1'b1;
            end

            4'b0111: begin // SHR
                alu_op    = 3'b111;
                reg_write = 1'b1;
            end

            4'b1000: begin // ADDI — Rd = Rs1 + sext(imm6)
                alu_op      = 3'b001; // reuse ADD
                alu_src_imm = 1'b1;
                reg_write   = 1'b1;
            end

            4'b1001: begin // LW — Rd = MEM[Rs1 + sext(imm6)]
                alu_op        = 3'b001; // address = Rs1 + imm6, via ALU ADD
                alu_src_imm   = 1'b1;
                mem_read      = 1'b1;
                reg_write     = 1'b1;
                reg_write_src = WB_MEM;
            end

            4'b1010: begin // SW — MEM[Rs1 + sext(imm6)] = Rd
                alu_op      = 3'b001; // address = Rs1 + imm6, via ALU ADD
                alu_src_imm = 1'b1;
                mem_write   = 1'b1;
                // no reg_write — SW doesn't write back to the register file
            end

            4'b1011: begin // LI — Rd = sext(imm9)
                reg_write     = 1'b1;
                reg_write_src = WB_IMM;
            end

            4'b1100: begin // BEQ
                use_branch_regs = 1'b1;
                branch_eq       = 1'b1;
            end

            4'b1101: begin // BNE
                use_branch_regs = 1'b1;
                branch_ne       = 1'b1;
            end

            4'b1110: begin // JMP
                jump = 1'b1;
            end

            4'b1111: begin // HALT
                halt = 1'b1;
            end

            default: begin
                // Unrecognized opcode — should not occur if instr_mem only
                // ever holds assembler output, but default-safe (acts as NOP).
            end
        endcase
    end

endmodule
