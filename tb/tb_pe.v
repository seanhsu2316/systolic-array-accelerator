// tb_pe.v — PE 的 testbench（不用改）
// 每個 clock 檢查三件事：
//   1. a_out 是不是「上一拍的 a_in」
//   2. b_out 是不是「上一拍的 b_in」
//   3. acc 是不是一路累加 a_in * b_in
 
`timescale 1ns/1ps
module tb_pe;
    reg clk = 0, rst = 1;
    reg  signed [7:0]  a_in = 0, b_in = 0;
    wire signed [7:0]  a_out, b_out;
    wire signed [31:0] acc;
    reg  signed [7:0]  exp_a, exp_b;
    reg  signed [31:0] exp_acc;
    integer i, errors = 0, checks = 0;
 
    pe dut (.clk(clk), .rst(rst), .a_in(a_in), .b_in(b_in),
            .a_out(a_out), .b_out(b_out), .acc(acc));
 
    always #5 clk = ~clk;
 
    // 參考模型
    always @(posedge clk) begin
        if (rst) begin
            exp_a <= 0; exp_b <= 0; exp_acc <= 0;
        end else begin
            exp_a <= a_in; exp_b <= b_in; exp_acc <= exp_acc + a_in * b_in;
        end
    end
 
    task step(input r, input signed [7:0] x, input signed [7:0] y);
        begin
            rst = r; a_in = x; b_in = y;
            @(posedge clk); #1;
            checks = checks + 1;
            if (a_out !== exp_a || b_out !== exp_b || acc !== exp_acc) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL t=%0t rst=%0d a_in=%0d b_in=%0d : a_out=%0d(exp %0d) b_out=%0d(exp %0d) acc=%0d(exp %0d)",
                             $time, r, x, y, a_out, exp_a, b_out, exp_b, acc, exp_acc);
            end
        end
    endtask
 
    initial begin
        $dumpfile("pe.vcd");
        $dumpvars(0, tb_pe);
 
        step(1, 0, 0);       // reset：全部 0
        step(0, 3, 4);       // a_out=3, b_out=4, acc=12
        step(0, -2, 5);      // a_out=-2, b_out=5, acc=2
        step(0, 0, 0);       // 送 0 進去：a_out=0, b_out=0, acc 保持 2
        step(0, -128, 127);  // acc = 2 - 16256 = -16254
        step(1, 9, 9);       // reset 優先：全部回到 0
 
        for (i = 0; i < 1000; i = i + 1)
            step(($random % 50) == 0, $random, $random);
 
        if (errors == 0) $display("PASS: %0d checks, all correct", checks);
        else             $display("FAILED: %0d of %0d checks wrong", errors, checks);
        $finish;
    end
endmodule
