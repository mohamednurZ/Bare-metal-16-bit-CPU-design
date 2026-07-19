# T16 Instruction Set Architecture

**Author:** Mo
**Target Platform:** Digilent Zybo Z7-10 (Xilinx Zynq-7000, xc7z010clg400-1)
**Implementation Language:** SystemVerilog
**Toolchain:** Xilinx Vivado

---

## 1. Overview

T16 is a 16-bit, register-based, load/store instruction set architecture designed for a single-cycle hardware implementation. The architecture prioritizes a small, complete, and fully verifiable instruction set over feature breadth — every instruction earns its place, and the design deliberately avoids complexity (pipelining, interrupts, flags) that would not be fully realized within the project's scope.

**Core architectural decisions:**

- **8 general-purpose registers**, with R0 hardwired to zero — a standard RISC convention that simplifies several common operations (register clears, moves, and unconditional branches all reduce to existing instructions with no dedicated opcode).
- **No architectural flags register.** Conditional branches compare two registers directly, removing an entire class of control-path complexity and hazard cases that a status register would introduce.
- **Harvard memory architecture** — separate instruction and data memories, avoiding the port-contention issues a unified memory would introduce in a single-cycle design.
- **Memory-mapped I/O for UART output.** A single reserved address in the data memory space is intercepted and routed to a UART transmitter, giving the processor a real, observable output channel without adding a dedicated I/O opcode.

---

## 2. Register Set

| Register | Encoding | Description |
|---|---|---|
| R0 | `000` | Hardwired to zero. Writes are discarded. |
| R1 – R6 | `001` – `110` | General purpose |
| R7 | `111` | General purpose |
| PC | — | 16-bit program counter (not software-addressable) |

All registers are 16 bits wide.

---

## 3. Memory Architecture

| | |
|---|---|
| Instruction memory | 4096 x 16-bit words, word-addressed |
| Data memory | 4096 x 16-bit words, word-addressed |
| I/O | Address `0xFFF` is reserved as the UART transmit register |

Memory is word-addressed rather than byte-addressed, eliminating alignment logic entirely — a deliberate simplification with no meaningful cost given the instruction and data widths involved.

**UART output:** a store instruction (`SW`) targeting address `0xFFF` is intercepted before reaching data memory and routed to a UART transmitter, which sends the low 8 bits of the source register serially off-chip. Every other address behaves as ordinary read/write memory.

---

## 4. Instruction Encoding

All instructions are a fixed 16 bits. Four formats:

```
R-type   [ opcode 4 ][ Rd 3 ][ Rs1 3 ][ Rs2 3 ][ unused 3 ]
          15      12  11   9  8     6  5     3  2       0

I-type   [ opcode 4 ][ Rd 3 ][ Rs1 3 ][ imm6 (signed) ]
          15      12  11   9  8     6  5             0

L-type   [ opcode 4 ][ Rd 3 ][ imm9 (signed) ]
          15      12  11   9  8                     0

B-type   [ opcode 4 ][ Rs1 3 ][ Rs2 3 ][ offset6 (signed) ]
          15      12  11    9  8     6  5                0

J-type   [ opcode 4 ][ address12 ]
          15      12  11                                 0
```

| Field | Width | Range |
|---|---|---|
| imm6 / offset6 | 6 bits, signed | −32 to +31 |
| imm9 | 9 bits, signed | −256 to +255 |
| address12 | 12 bits, unsigned | 0 to 4095 |

---

## 5. Instruction Set

| Opcode | Mnemonic | Format | Operation |
|---|---|---|---|
| `0000` | NOP | — | No operation |
| `0001` | ADD | R | Rd ← Rs1 + Rs2 |
| `0010` | SUB | R | Rd ← Rs1 − Rs2 |
| `0011` | AND | R | Rd ← Rs1 & Rs2 |
| `0100` | OR | R | Rd ← Rs1 \| Rs2 |
| `0101` | XOR | R | Rd ← Rs1 ^ Rs2 |
| `0110` | SHL | R | Rd ← Rs1 << Rs2 |
| `0111` | SHR | R | Rd ← Rs1 >> Rs2 |
| `1000` | ADDI | I | Rd ← Rs1 + sext(imm6) |
| `1001` | LW | I | Rd ← MEM[Rs1 + sext(imm6)] |
| `1010` | SW | I | MEM[Rs1 + sext(imm6)] ← Rd |
| `1011` | LI | L | Rd ← sext(imm9) |
| `1100` | BEQ | B | if (Rs1 == Rs2): PC ← PC + 1 + sext(offset6) |
| `1101` | BNE | B | if (Rs1 != Rs2): PC ← PC + 1 + sext(offset6) |
| `1110` | JMP | J | PC ← address12 |
| `1111` | HALT | — | Halts execution |

Shift amount for `SHL`/`SHR` is taken from the low 4 bits of `Rs2`. Branch offsets are relative to the address following the branch instruction. Writes to R0 are always discarded.

---

## 6. Pseudo-Instructions

Expanded by the assembler into real instructions — no additional opcodes required.

| Pseudo-instruction | Expansion | Operation |
|---|---|---|
| `MOV Rd, Rs` | `ADD Rd, Rs, R0` | Rd ← Rs |
| `CLR Rd` | `ADD Rd, R0, R0` | Rd ← 0 |
| `INC Rd` | `ADDI Rd, Rd, 1` | Rd ← Rd + 1 |
| `DEC Rd` | `ADDI Rd, Rd, -1` | Rd ← Rd − 1 |
| `B target` | `BEQ R0, R0, target` | Unconditional branch |
| `OUT Rd` | `SW Rd, Rx, 0` (Rx preloaded with `0xFFF`) | Transmit Rd's low byte over UART |

---

## 7. Assembly Syntax

Operands are written in the same order they appear in the instruction encoding:

| Format | Syntax |
|---|---|
| R-type | `ADD Rd, Rs1, Rs2` |
| I-type | `ADDI Rd, Rs1, imm6` / `LW Rd, Rs1, imm6` / `SW Rd, Rs1, imm6` |
| L-type | `LI Rd, imm9` |
| B-type | `BEQ Rs1, Rs2, target` |
| J-type | `JMP target` |

Labels are supported for branch and jump targets and are resolved at assembly time.

---

## 8. Example Program

Computes the first eight Fibonacci numbers, storing each into memory, and halts.

```asm
        LI   R1, 0        ; fib(n-1)
        LI   R2, 1        ; fib(n)
        LI   R3, 8        ; loop counter
        LI   R4, 0        ; memory pointer

LOOP:   SW   R1, R4, 0    ; store current fib value
        ADD  R5, R1, R2   ; R5 = next fib
        MOV  R1, R2
        MOV  R2, R5
        INC  R4
        DEC  R3
        BNE  R3, R0, LOOP
        HALT
```

---

## 9. Scope

The following are intentionally excluded from this architecture:

- Pipelining
- Interrupts and exceptions
- Status/flags register
- Byte-addressable memory
- Multiply/divide

This scope reflects a deliberate tradeoff in favor of a complete, fully verified, and demonstrable system over a broader but less certain feature set.
