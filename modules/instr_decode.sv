// instr_decode.sv
// T16 Instruction Decoder — splits the raw 16-bit instruction into its
// constituent fields. Since different formats place fields at different
// bit positions, this module extracts ALL possible fields; control_unit.sv
// decides which ones are actually meaningful based on the opcode.

module instr_decode (
    input  logic [15:0] instr,

    output logic [3:0]  opcode,
    output logic [2:0]  rd,          // R-type / I-type / L-type destination
    output logic [2:0]  rs1,         // R-type / I-type source 1
    output logic [2:0]  rs2,         // R-type source 2
    output logic [2:0]  b_rs1,       // B-type source 1 (NOTE: same bit position as 'rd' above — different meaning!)
    output logic [2:0]  b_rs2,       // B-type source 2 (NOTE: same bit position as 'rs1' above — different meaning!)
    output logic [15:0] imm6_sext,   // sign-extended 6-bit immediate (I-type, B-type offset)
    output logic [15:0] imm9_sext,   // sign-extended 9-bit immediate (L-type)
    output logic [11:0] addr12       // unsigned 12-bit address (J-type)
);

    always_comb begin
        opcode = instr[15:12];
        rd     = instr[11:9];
        rs1    = instr[8:6];
        rs2    = instr[5:3];
        b_rs1  = instr[11:9];   // B-type: Rs1 sits where Rd sits for R/I-type
        b_rs2  = instr[8:6];    // B-type: Rs2 sits where Rs1 sits for R/I-type

        // I-type / B-type: imm6 lives in bits [5:0]
        imm6_sext = {{10{instr[5]}}, instr[5:0]};

        // L-type: imm9 lives in bits [8:0]
        imm9_sext = {{7{instr[8]}}, instr[8:0]};

        // J-type: address12 lives in bits [11:0]
        addr12 = instr[11:0];
    end

endmodule
