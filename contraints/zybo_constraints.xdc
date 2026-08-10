## T16 CPU constraints for Zybo Z7-10 (cpu_top.sv)
## Pin data sourced from Digilent's official Zybo-Z7-Master.xdc

## Clock signal — 125 MHz external reference clock
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { clk }]; #Sch=sysclk
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

## Reset — dedicated push-button, btn[0]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { rst }]; #Sch=btn[0]

## Halt indicator LED — led[0]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { halted_led }]; #Sch=led[0]

## UART TX — routed to Pmod JE, pin 0 (V12).
## The Zybo Z7's onboard USB-UART bridge is wired through the Zynq PS's
## dedicated MIO pins, NOT exposed as a plain PL pin here — since uart_tx.sv
## is fabric (PL) logic, it can't be routed directly to that chip. Instead,
## connect an external USB-to-serial (FTDI) adapter to this Pmod pin to view
## UART output on a PC terminal.
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { uart_tx_serial }]; #Sch=je[1]
