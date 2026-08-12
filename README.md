# T16 — A 16-bit CPU Built From Scratch

T16 is a small, single-cycle, 16-bit CPU implemented in SystemVerilog, targeting the
Digilent Zybo Z7-10 (Xilinx Zynq-7000). It's a from-scratch learning project: a
complete, custom instruction set architecture; every datapath module hand-written and
individually testbenched; and a real FPGA target with UART output for a live demo.

## Status

`cpu_top.sv` integrates every module into a complete single-cycle CPU, with pin
constraints for the Zybo Z7-10. Simulate it with the included Fibonacci demo, or
synthesize it and run it on real hardware.

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
contraints/                 Vivado constraints (.xdc) for the Zybo Z7-10
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

## Building for hardware

1. Add every file under `modules/` as a design source, with `cpu_top` set as the top module.
2. Add `contraints/zybo_constraints.xdc` as a constraints source.
3. Set `INSTR_INIT_FILE` to your program's `.mem` file (e.g. `fib.mem`), and confirm
   `CLK_FREQ_HZ` matches the board's actual clock before relying on the UART's baud rate.
4. Connect an external USB-to-serial (FTDI) adapter to Pmod JE pin 0 to view UART
   output on a PC terminal — the Zybo Z7's onboard USB-UART bridge isn't reachable
   from fabric (PL) logic, so `uart_tx_serial` is routed to a Pmod pin instead.

## Known limitations

- Single-cycle only — no pipelining, no interrupts/exceptions, no flags register.
- `mem_decoder.sv` doesn't feed a UART-busy signal back to the CPU, so a program that
  issues a second UART write before the first byte finishes transmitting may drop
  data. Fine as long as test programs space out UART writes.
- No assembler is included in this repository; `.mem` files are currently hand-assembled.

## Development workflow

Features are built module-by-module on short-lived branches, roughly in dependency
order (ALU and register file first, top-level integration last), and merged into
`main` once each module is implemented and testbenched.
