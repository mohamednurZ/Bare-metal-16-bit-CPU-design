// uart_tx.sv
// T16 UART Transmitter — sends one byte at a time, serially, at a
// configurable baud rate. Standard framing: 1 start bit (low), 8 data bits
// (LSB first), 1 stop bit (high). Idle line is held high.
//
// Usage: pulse tx_start high for one clock cycle with tx_data valid;
// the module latches tx_data and transmits it over several thousand clock
// cycles (however long one bit period takes at the chosen baud rate).
// tx_busy stays high for the whole transmission — mem_decoder.sv does not
// currently check this (see the documented limitation in mem_decoder.sv),
// but it's exposed here in case you want to add that check later.

module uart_tx #(
    parameter int CLK_FREQ_HZ = 125_000_000,  // match this to your board's actual system clock
    parameter int BAUD_RATE   = 9600          // standard, safe default for a terminal program
) (
    input  logic       clk,
    input  logic        rst,        // synchronous, active-high — forces IDLE, line high, not busy
    input  logic        tx_start,
    input  logic [7:0]  tx_data,
    output logic        tx_serial,
    output logic        tx_busy
);

    // How many clock cycles make up one bit period at this baud rate.
    // e.g. 125,000,000 / 9600 ≈ 13,021 clocks per bit.
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    typedef enum logic [1:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    } state_t;

    state_t         state      = IDLE;
    logic [15:0]    clk_count  = 16'd0;
    logic [2:0]     bit_index  = 3'd0;
    logic [7:0]     data_reg   = 8'd0;

    initial begin
        tx_serial = 1'b1;  // line idles high
        tx_busy   = 1'b0;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx_serial <= 1'b1;
            tx_busy   <= 1'b0;
            clk_count <= 16'd0;
            bit_index <= 3'd0;
        end else begin
        case (state)

            IDLE: begin
                tx_serial <= 1'b1;
                clk_count <= 16'd0;
                bit_index <= 3'd0;
                if (tx_start) begin
                    data_reg <= tx_data;   // latch the byte to send
                    tx_busy  <= 1'b1;
                    state    <= START_BIT;
                end else begin
                    tx_busy <= 1'b0;
                end
            end

            START_BIT: begin
                tx_serial <= 1'b0;  // start bit is always low
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 16'd1;
                end else begin
                    clk_count <= 16'd0;
                    state     <= DATA_BITS;
                end
            end

            DATA_BITS: begin
                tx_serial <= data_reg[bit_index];  // LSB first
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 16'd1;
                end else begin
                    clk_count <= 16'd0;
                    if (bit_index < 3'd7) begin
                        bit_index <= bit_index + 3'd1;
                    end else begin
                        bit_index <= 3'd0;
                        state     <= STOP_BIT;
                    end
                end
            end

            STOP_BIT: begin
                tx_serial <= 1'b1;  // stop bit is always high
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 16'd1;
                end else begin
                    clk_count <= 16'd0;
                    tx_busy   <= 1'b0;
                    state     <= IDLE;
                end
            end

            default: state <= IDLE;

        endcase
        end
    end

endmodule
