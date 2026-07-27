// tb_instr_decode.sv
// Testbench for instr_decode.sv — builds one instruction per format
// (R, I, L, B, J) and verifies every extracted field, including sign extension.
// Add this to Simulation Sources (not Design Sources) in Vivado.

`timescale 1ns / 1ps

module tb_instr_decode;

    logic [15:0] instr;
    logic [3:0]  opcode;
    logic [2:0]  rd, rs1, rs2, b_rs1, b_rs2;
    logic [15:0] imm6_sext, imm9_sext;
    logic [11:0] addr12;
    int          errors = 0;

    instr_decode dut (
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

    task check(input [15:0] actual, input [15:0] expected, input string name);
        begin
            if (actual !== expected) begin
                $display("FAIL: %s  got=0x%0h  expected=0x%0h", name, actual, expected);
                errors++;
            end else begin
                $display("PASS: %s  value=0x%0h", name, actual);
            end
        end
    endtask

    initial begin
        $display("---- Instruction Decoder Testbench Start ----");

        // --- R-type: ADD Rd=3, Rs1=2, Rs2=5 ---
        instr = {4'b0001, 3'd3, 3'd2, 3'd5, 3'b000};
        #1;
        check(opcode, 4'b0001, "R-type opcode");
        check(rd,  3'd3, "R-type rd");
        check(rs1, 3'd2, "R-type rs1");
        check(rs2, 3'd5, "R-type rs2");

        // --- I-type: ADDI Rd=1, Rs1=2, imm6=-3 ---
        instr = {4'b1000, 3'd1, 3'd2, 6'(-3)};
        #1;
        check(opcode, 4'b1000, "I-type opcode");
        check(rd,  3'd1, "I-type rd");
        check(rs1, 3'd2, "I-type rs1");
        check(imm6_sext, 16'(-3), "I-type imm6 sign-extended");

        // --- L-type: LI Rd=4, imm9=-100 ---
        instr = {4'b1011, 3'd4, 9'(-100)};
        #1;
        check(opcode, 4'b1011, "L-type opcode");
        check(rd, 3'd4, "L-type rd");
        check(imm9_sext, 16'(-100), "L-type imm9 sign-extended");

        // --- B-type: BEQ Rs1=5, Rs2=6, offset6=10 ---
        instr = {4'b1100, 3'd5, 3'd6, 6'd10};
        #1;
        check(opcode, 4'b1100, "B-type opcode");
        check(b_rs1, 3'd5, "B-type b_rs1 (NOT rd)");
        check(b_rs2, 3'd6, "B-type b_rs2 (NOT rs1)");
        check(imm6_sext, 16'd10, "B-type offset6");

        // --- J-type: JMP addr12=3000 ---
        instr = {4'b1110, 12'd3000};
        #1;
        check(opcode, 4'b1110, "J-type opcode");
        check(addr12, 12'd3000, "J-type addr12");

        $display("---- Instruction Decoder Testbench Complete: %0d error(s) ----", errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
