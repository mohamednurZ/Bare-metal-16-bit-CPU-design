// mem_decoder.sv
// T16 Memory Decode it sits between the CPU and data_mem.sv.
// Implements the memory-mapped UART decision from the ISA spec:
// a SW targeting address 0xFFF is intercepted and routed to the UART
// transmitter instead of being written into data RAM. Every other address
// behaves as ordinary RAM read/write.
// This is the one module that's allowed to know "0xFFF is special" maintains data_mem.sv itself generic and reusable.

module mem_decoder (
    input  logic        clk,
    input  logic        mem_write,   // from control_unit: this cycle is an SW
    input  logic        mem_read,    // from control_unit: this cycle is an LW (passthrough)
    input  logic [11:0] addr,        // computed address (Rs1 + sext(imm6)) from the ALU
    input  logic [15:0] wr_data,     // value being stored (Rd's contents, for SW)

    output logic [15:0] rd_data,     // read data, straight from data_mem

    output logic         uart_tx_start, // pulses high for 1 cycle when a UART send should begin
    output logic [7:0]   uart_tx_data   // low byte of wr_data, to send over UART
);

    localparam logic [11:0] UART_ADDR = 12'hFFF;

    logic is_uart_addr;
    assign is_uart_addr = (addr == UART_ADDR);

    // Only actually write to RAM if this ISN'T the UART address, stops a UART "write" from corrupting data memory.
    logic ram_we;
    assign ram_we = mem_write && !is_uart_addr;

    data_mem u_data_mem (
        .clk(clk),
        .we(ram_we),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(rd_data)
    );

    // Fires exactly one cycle whenever a real SW targets the UART address.
    assign uart_tx_start = mem_write && is_uart_addr;
    assign uart_tx_data  = wr_data[7:0];

    // there is no "UART busy" signal fed back to the CPU here. If a program
    // issues a second OUT/SW-to-0xFFF before the first byte has finished
    // transmitting (uart_tx.sv takes many clock cycles per byte at typical
    // baud rates), the second write's data may be dropped or corrupt the
    // transmission in progress. This is acceptable for a single-cycle CPU
    // with no stall/wait-state mechanism, as long as test programs pace
    // their UART writes with enough instructions in between. If this
    // becomes a real problem in testing, the fix is to add a uart_tx_busy
    // here to keep scope contained.

endmodule
