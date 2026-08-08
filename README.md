# T16 — A 16-bit CPU Built From Scratch

T16 is a small, single-cycle, 16-bit CPU implemented in SystemVerilog, targeting the
Digilent Zybo Z7-10 (Xilinx Zynq-7000). It's a from-scratch learning project: a
complete, custom instruction set architecture; every datapath module hand-written and
individually testbenched; and a real FPGA target with UART output for a live demo.

## Status

`cpu_top.sv` integrates every module into a complete single-cycle CPU. Simulate it
with the included Fibonacci demo, or synthesize it for the Zybo Z7-10.

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
modules/                   SystemVerilog design sources (+ fib.mem demo program)
Test benches/               Per-module testbenches (simulation sources)
```

## Running the testbenches

Each module under `modules/` that has a corresponding file in `Test benches/` can be
simulated on its own — no need to build the full CPU first. In Vivado, add the module
under test as a design source and its testbench as a simulation source, then run
behavioral simulation. Each testbench prints `PASS`/`FAIL` per check and a final
summary line.

Implemented so far: `alu.sv`, `regfile.sv`, `instr_decode.sv`.

## Simulating the full CPU

`modules/fib.mem` is a hand-assembled program (the Fibonacci example from
`T16_ISA_Specification.md` §8) ready to load via `cpu_top`'s `INSTR_INIT_FILE`
parameter:

```systemverilog
cpu_top #(.INSTR_INIT_FILE("fib.mem")) dut (...);
```

Run it in behavioral simulation and watch `rd_data`/register values change each
cycle, or watch `uart_tx_serial` if your test program writes to the UART address.

## Memory-mapped UART

A `SW` targeting address `0xFFF` doesn't reach data memory — `mem_decoder.sv`
intercepts it and routes the low byte of the stored register out over UART instead.
Every other address behaves as ordinary RAM. See `T16_ISA_Specification.md` §3 for
the full memory map.

## Development workflow

Features are built module-by-module on short-lived branches, roughly in dependency
order (ALU and register file first, top-level integration last), and merged into
`main` once each module is implemented and testbenched.
