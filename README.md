# T16 — A 16-bit CPU Built From Scratch

T16 is a small, single-cycle, 16-bit CPU implemented in SystemVerilog, targeting the
Digilent Zybo Z7-10 (Xilinx Zynq-7000). It's a from-scratch learning project: a
complete, custom instruction set architecture; every datapath module hand-written and
individually testbenched; and a real FPGA target with UART output for a live demo.

## Status

Work in progress. See the commit history for what's implemented so far.

## Documentation

- [`T16_ISA_Specification.md`](T16_ISA_Specification.md) — the instruction set architecture

## Design at a glance

- 16-bit fixed-width instructions, load/store RISC-style
- 8 general-purpose registers (R0 hardwired to zero)
- No flags register — branches compare registers directly
- Harvard memory model (separate instruction/data memory)
- Memory-mapped UART output for real hardware demos

## Requirements

- [Xilinx Vivado](https://www.xilinx.com/support/download.html) (WebPACK edition is sufficient) for synthesis and simulation
- A Zybo Z7-10 board if you want to run it on real hardware (optional — everything can be simulated without one)

## Repository layout

```
T16_ISA_Specification.md   ISA specification
```

## Development workflow

Features are built module-by-module on short-lived branches, roughly in dependency
order (ALU and register file first, top-level integration last), and merged into
`main` once each module is implemented and testbenched.
