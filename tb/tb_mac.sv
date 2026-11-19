`timescale 1ns/1ps
module tb_mac;
    logic clk = 0, rst = 1, en = 0;
    logic signed [7:0]  a = 0, b = 0;
    logic signed [31:0] acc;
    logic signed [31:0] expected;
    int errors = 0, checks = 0;

    mac dut (.*);        
    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        if (rst)     expected <= 0;
        else if (en) expected <= expected + a * b;
    end

    task automatic step(input logic r, e, input logic signed [7:0] x, y);
        rst = r; en = e; a = x; b = y;
        @(posedge clk); #1;
        checks++;
        assert (acc === expected)
            else begin
                errors++;
                $error("a=%0d b=%0d : acc=%0d, expected=%0d", x, y, acc, expected);
            end
    endtask

    initial begin
        step(1, 0, 0, 0);
        repeat (1000) begin
            step($urandom_range(0, 49) == 0, 
                 $urandom_range(0, 9) != 0,     
                 $urandom, $urandom);
        end
        if (errors == 0) $display("PASS: %0d checks, all correct", checks);
        else             $display("FAILED: %0d of %0d checks wrong", errors, checks);
        $finish;
    end
endmodule
