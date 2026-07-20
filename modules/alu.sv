// alu.sv
// T16 ALU — combinational, performs ADD/SUB/AND/OR/XOR/SHL/SHR
//
// alu_op encoding (3 bits — matches the low 3 bits of the R-type opcodes,
// since ADD=0001, SUB=0010, ... SHR=0111 conveniently increment by 1):
//   000 : unused (would collide with NOP's opcode range — not reachable via R-type dispatch)
//   001 : ADD
//   010 : SUB
//   011 : AND
//   100 : OR
//   101 : XOR
//   110 : SHL
//   111 : SHR

module alu (
    input  logic [15:0] a,
    input  logic [15:0] b,
    input  logic [2:0]  alu_op,
    output logic [15:0] result
);

    always_comb begin
        case (alu_op)
            3'b001: result = a + b;                 // ADD
            3'b010: result = a - b;                 // SUB
            3'b011: result = a & b;                 // AND
            3'b100: result = a | b;                 // OR
            3'b101: result = a ^ b;                 // XOR
            3'b110: result = a << b[3:0];            // SHL (low 4 bits of b = shift amount)
            3'b111: result = a >> b[3:0];            // SHR (logical)
            default: result = 16'h0000;
        endcase
    end

endmodule
