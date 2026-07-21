// tb_alu.sv
// Testbench for alu.sv — checks ADD, SUB, AND, OR, XOR, SHL, SHR
// Add this to Simulation Sources (not Design Sources) in Vivado.

`timescale 1ns / 1ps

module tb_alu;

    logic [15:0] a, b;
    logic [2:0]  alu_op;
    logic [15:0] result;
    int          errors = 0;

    // instantiate the ALU (device under test)
    alu dut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result)
    );

    // helper task: apply inputs, wait, check result, report
    task check(input [15:0] a_in, input [15:0] b_in, input [2:0] op,
               input [15:0] expected, input string name);
        begin
            a = a_in;
            b = b_in;
            alu_op = op;
            #10; // let combinational logic settle
            if (result !== expected) begin
                $display("FAIL: %s  a=%0d b=%0d  got=%0d (0x%0h)  expected=%0d (0x%0h)",
                          name, a_in, b_in, result, result, expected, expected);
                errors++;
            end else begin
                $display("PASS: %s  a=%0d b=%0d  result=%0d", name, a_in, b_in, result);
            end
        end
    endtask

    initial begin
        $display("---- ALU Testbench Start ----");

        check(16'd10, 16'd5,  3'b001, 16'd15,        "ADD 10+5");
        check(16'd10, 16'd5,  3'b010, 16'd5,         "SUB 10-5");
        check(16'd5,  16'd20, 3'b010, -16'd15,       "SUB 5-20 (negative)");
        check(16'hFF00, 16'h0FF0, 3'b011, 16'h0F00,  "AND");
        check(16'hFF00, 16'h00FF, 3'b100, 16'hFFFF,  "OR");
        check(16'hFFFF, 16'h00FF, 3'b101, 16'hFF00,  "XOR");
        check(16'd1,  16'd4,  3'b110, 16'd16,        "SHL 1<<4");
        check(16'd256,16'd4,  3'b111, 16'd16,        "SHR 256>>4");
        check(16'd0,  16'd0,  3'b001, 16'd0,         "ADD 0+0 (edge case)");

        $display("---- ALU Testbench Complete: %0d error(s) ----", errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
