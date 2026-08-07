// instr_mem.sv
// T16 Instruction Memory — 4096 x 16-bit words, word-addressed, read-only
// from the CPU's perspective. Preloaded at synthesis/simulation time via
// $readmemh from a .mem file produced by the assembler.
//
// No write port exists here on purpose — this is program storage, not data
// storage (matches the ISA spec's Harvard architecture: separate instruction
// and data memories).

module instr_mem #(
    parameter string INIT_FILE = ""   // path to a .mem file, e.g. "fib.mem"
) (
    input  logic [15:0] pc,          // address, from pc.sv (word address, not byte address)
    output logic [15:0] instr        // the 16-bit instruction at that address
);

    logic [15:0] mem [0:4095];

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Combinational read — the instruction at the current PC must be visible
    // within the same cycle for a single-cycle design (no fetch delay).
    always_comb begin
        instr = mem[pc[11:0]];  // only the low 12 bits are a valid address (4096 words)
    end

endmodule
