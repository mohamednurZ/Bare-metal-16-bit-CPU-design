#!/usr/bin/env python3
"""
T16 Assembler
Converts T16 assembly source into 16-bit machine code.

Usage:
    python assembler.py program.asm -o program.mem
    python assembler.py program.asm -o program.hex --format hex
"""

import argparse
import re
import sys


REGISTERS = {f"R{i}": i for i in range(8)}

OPCODES = {
    "NOP":  ("0000", "N"),
    "ADD":  ("0001", "R"),
    "SUB":  ("0010", "R"),
    "AND":  ("0011", "R"),
    "OR":   ("0100", "R"),
    "XOR":  ("0101", "R"),
    "SHL":  ("0110", "R"),
    "SHR":  ("0111", "R"),
    "ADDI": ("1000", "I"),
    "LW":   ("1001", "I"),
    "SW":   ("1010", "I"),
    "LI":   ("1011", "L"),
    "BEQ":  ("1100", "B"),
    "BNE":  ("1101", "B"),
    "JMP":  ("1110", "J"),
    "HALT": ("1111", "N"),
}


def expand_pseudo(mnemonic, args):
    if mnemonic == "MOV":
        rd, rs = args
        return "ADD", [rd, rs, "R0"]
    if mnemonic == "CLR":
        rd, = args
        return "ADD", [rd, "R0", "R0"]
    if mnemonic == "INC":
        rd, = args
        return "ADDI", [rd, rd, "1"]
    if mnemonic == "DEC":
        rd, = args
        return "ADDI", [rd, rd, "-1"]
    if mnemonic == "B":
        target, = args
        return "BEQ", ["R0", "R0", target]
    return mnemonic, args


PSEUDO_OPS = {"MOV", "CLR", "INC", "DEC", "B"}


class AssemblerError(Exception):
    def __init__(self, line_num, message):
        super().__init__(f"Line {line_num}: {message}")
        self.line_num = line_num
        self.message = message


def strip_comment(line):
    for marker in (";", "//"):
        idx = line.find(marker)
        if idx != -1:
            line = line[:idx]
    return line.strip()


def parse_register(tok, line_num):
    tok = tok.strip().upper()
    if tok not in REGISTERS:
        raise AssemblerError(line_num, f"Invalid register '{tok}'")
    return REGISTERS[tok]


def parse_immediate(tok, line_num, labels=None, current_addr=None, is_branch=False):
    tok = tok.strip()
    if labels is not None and tok in labels:
        target = labels[tok]
        if is_branch:
            return target - (current_addr + 1)
        return target
    try:
        if tok.lower().startswith("0x"):
            return int(tok, 16)
        return int(tok, 10)
    except ValueError:
        raise AssemblerError(line_num, f"Invalid immediate or undefined label '{tok}'")


def to_signed_field(value, bits, line_num):
    lo = -(1 << (bits - 1))
    hi = (1 << (bits - 1)) - 1
    if not (lo <= value <= hi):
        raise AssemblerError(line_num, f"Value {value} out of range for {bits}-bit signed field ({lo}..{hi})")
    return value & ((1 << bits) - 1)


def to_unsigned_field(value, bits, line_num):
    hi = (1 << bits) - 1
    if not (0 <= value <= hi):
        raise AssemblerError(line_num, f"Value {value} out of range for {bits}-bit unsigned field (0..{hi})")
    return value & hi


def bits(value, width):
    return format(value, f"0{width}b")


def split_instruction(line, line_num):
    parts = line.split(None, 1)
    mnemonic = parts[0].upper()
    args = []
    if len(parts) > 1:
        args = [a.strip() for a in parts[1].split(",") if a.strip() != ""]
    return mnemonic, args


def assemble(source_lines):
    cleaned = []
    labels = {}
    addr = 0

    for line_num, raw in enumerate(source_lines, start=1):
        line = strip_comment(raw)
        if not line:
            continue

        label_match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", line)
        if label_match:
            label_name, rest = label_match.groups()
            if label_name in labels:
                raise AssemblerError(line_num, f"Duplicate label '{label_name}'")
            labels[label_name] = addr
            line = rest.strip()
            if not line:
                continue

        mnemonic, args = split_instruction(line, line_num)

        if mnemonic in PSEUDO_OPS:
            mnemonic, args = expand_pseudo(mnemonic, args)
        elif mnemonic not in OPCODES:
            raise AssemblerError(line_num, f"Unknown mnemonic '{mnemonic}'")

        cleaned.append((line_num, mnemonic, args))
        addr += 1

    machine_code = []
    for addr, (line_num, mnemonic, args) in enumerate(cleaned):
        opcode_bin, fmt = OPCODES[mnemonic]

        if fmt == "N":
            word = opcode_bin + "0" * 12

        elif fmt == "R":
            if len(args) != 3:
                raise AssemblerError(line_num, f"{mnemonic} expects 3 register args (Rd, Rs1, Rs2)")
            rd = parse_register(args[0], line_num)
            rs1 = parse_register(args[1], line_num)
            rs2 = parse_register(args[2], line_num)
            word = opcode_bin + bits(rd, 3) + bits(rs1, 3) + bits(rs2, 3) + "000"

        elif fmt == "I":
            if len(args) != 3:
                raise AssemblerError(line_num, f"{mnemonic} expects 3 args (Rd, Rs1, imm6)")
            rd = parse_register(args[0], line_num)
            rs1 = parse_register(args[1], line_num)
            imm = parse_immediate(args[2], line_num, labels, addr)
            imm_field = to_signed_field(imm, 6, line_num)
            word = opcode_bin + bits(rd, 3) + bits(rs1, 3) + bits(imm_field, 6)

        elif fmt == "L":
            if len(args) != 2:
                raise AssemblerError(line_num, f"{mnemonic} expects 2 args (Rd, imm9)")
            rd = parse_register(args[0], line_num)
            imm = parse_immediate(args[1], line_num, labels, addr)
            imm_field = to_signed_field(imm, 9, line_num)
            word = opcode_bin + bits(rd, 3) + bits(imm_field, 9)

        elif fmt == "B":
            if len(args) != 3:
                raise AssemblerError(line_num, f"{mnemonic} expects 3 args (Rs1, Rs2, target)")
            rs1 = parse_register(args[0], line_num)
            rs2 = parse_register(args[1], line_num)
            imm = parse_immediate(args[2], line_num, labels, addr, is_branch=True)
            imm_field = to_signed_field(imm, 6, line_num)
            word = opcode_bin + bits(rs1, 3) + bits(rs2, 3) + bits(imm_field, 6)

        elif fmt == "J":
            if len(args) != 1:
                raise AssemblerError(line_num, f"{mnemonic} expects 1 arg (address12)")
            imm = parse_immediate(args[0], line_num, labels, addr)
            imm_field = to_unsigned_field(imm, 12, line_num)
            word = opcode_bin + bits(imm_field, 12)

        else:
            raise AssemblerError(line_num, f"Internal error, unknown format '{fmt}'")

        assert len(word) == 16, f"Internal error, word length {len(word)} != 16 on line {line_num}"
        machine_code.append((addr, word, mnemonic, args, line_num))

    return machine_code, labels


def format_output(machine_code, fmt):
    lines = []
    for addr, word, mnemonic, args, line_num in machine_code:
        val = int(word, 2)
        if fmt == "mem":
            lines.append(f"{val:04x}")
        elif fmt == "hex":
            lines.append(f"0x{val:04x}")
        elif fmt == "bin":
            lines.append(word)
        else:
            raise ValueError(f"Unknown output format '{fmt}'")
    return "\n".join(lines) + "\n"


def print_listing(machine_code):
    print(f"{'ADDR':>5}  {'WORD':>6}  {'HEX':>6}  INSTRUCTION")
    print("-" * 50)
    for addr, word, mnemonic, args, line_num in machine_code:
        val = int(word, 2)
        instr_text = f"{mnemonic} " + ", ".join(args)
        print(f"{addr:5d}  {word:>6}  0x{val:04x}  {instr_text}")


def main():
    parser = argparse.ArgumentParser(description="T16 Assembler")
    parser.add_argument("source", help="Path to .asm source file")
    parser.add_argument("-o", "--output", help="Output file path")
    parser.add_argument("--format", choices=["mem", "hex", "bin"], default="mem",
                         help="Output format (default: mem)")
    parser.add_argument("--listing", action="store_true",
                         help="Print a human readable listing to stdout")
    args = parser.parse_args()

    with open(args.source, "r") as f:
        source_lines = f.readlines()

    try:
        machine_code, labels = assemble(source_lines)
    except AssemblerError as e:
        print(f"Assembly error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.listing or not args.output:
        print_listing(machine_code)
        if labels:
            print("\nLabels:")
            for name, addr in labels.items():
                print(f"  {name}: {addr}")

    if args.output:
        output_text = format_output(machine_code, args.format)
        with open(args.output, "w") as f:
            f.write(output_text)
        print(f"\nWrote {len(machine_code)} words to {args.output}")


if __name__ == "__main__":
    main()
