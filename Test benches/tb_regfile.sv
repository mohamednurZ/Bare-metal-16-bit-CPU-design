// tb_regfile.sv
// Testbench for regfile.sv — checks writes, reads, and R0-hardwired-to-zero behavior
// Add this to Simulation Sources (not Design Sources) in Vivado.

`timescale 1ns / 1ps

module tb_regfile;

    logic        clk = 0;
    logic        we;
    logic [2:0]  rd_addr, rs1_addr, rs2_addr;
    logic [15:0] wr_data;
    logic [15:0] rs1_data, rs2_data;
    int          errors = 0;

    regfile dut (
        .clk(clk),
        .we(we),
        .rd_addr(rd_addr),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .wr_data(wr_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // clock generator: 10ns period
    always #5 clk = ~clk;

    task check(input [15:0] actual, input [15:0] expected, input string name);
        begin
            if (actual !== expected) begin
                $display("FAIL: %s  got=0x%0h  expected=0x%0h", name, actual, expected);
                errors++;
            end else begin
                $display("PASS: %s  value=0x%0h", name, actual);
            end
        end
    endtask

    initial begin
        $display("---- Register File Testbench Start ----");

        we = 0; rd_addr = 0; wr_data = 0; rs1_addr = 0; rs2_addr = 0;
        @(negedge clk);

        // Write 0xABCD into R3
        we = 1; rd_addr = 3; wr_data = 16'hABCD;
        @(negedge clk);
        we = 0;
        rs1_addr = 3;
        #1;
        check(rs1_data, 16'hABCD, "Write/read R3");

        // Write 0x1234 into R7
        we = 1; rd_addr = 7; wr_data = 16'h1234;
        @(negedge clk);
        we = 0;
        rs2_addr = 7;
        #1;
        check(rs2_data, 16'h1234, "Write/read R7");

        // Attempt to write to R0 — should be discarded
        we = 1; rd_addr = 0; wr_data = 16'hFFFF;
        @(negedge clk);
        we = 0;
        rs1_addr = 0;
        #1;
        check(rs1_data, 16'h0000, "R0 write discarded, reads as zero");

        // Confirm R3 still holds its value after the R0 write attempt
        rs1_addr = 3;
        #1;
        check(rs1_data, 16'hABCD, "R3 unaffected by R0 write attempt");

        // Confirm both read ports work simultaneously (R3 and R7 at once)
        rs1_addr = 3; rs2_addr = 7;
        #1;
        check(rs1_data, 16'hABCD, "Dual-port read: rs1 = R3");
        check(rs2_data, 16'h1234, "Dual-port read: rs2 = R7");

        $display("---- Register File Testbench Complete: %0d error(s) ----", errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
