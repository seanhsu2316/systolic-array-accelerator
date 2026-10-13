// Code your testbench here
// or browse Examples
// tb_array2x2.v — 2×2 陣列的 testbench（不用改）
// 算 C = A × B（都是 2×2 矩陣），把 A、B 用「斜著送」的方式餵進陣列，
// 跑完後檢查 c00、c01、c10、c11 是不是正確答案。
// 先跑一題手算得出來的，再跑 200 題亂數。
 
`timescale 1ns/1ps
module tb_array2x2;
    reg clk = 0, rst = 1;
    reg  signed [7:0]  a0 = 0, a1 = 0, b0 = 0, b1 = 0;
    wire signed [31:0] c00, c01, c10, c11;
    reg  signed [7:0]  A [0:1][0:1];
    reg  signed [7:0]  B [0:1][0:1];
    reg  signed [31:0] E [0:1][0:1];
    integer i, j, k, t, n, errors = 0, tests = 0;
 
    array2x2 dut (.clk(clk), .rst(rst), .a0(a0), .a1(a1), .b0(b0), .b1(b1),
                  .c00(c00), .c01(c01), .c10(c10), .c11(c11));
 
    always #5 clk = ~clk;
 
    task run_matmul;
        begin
            // 正確答案
            for (i = 0; i < 2; i = i + 1)
                for (j = 0; j < 2; j = j + 1) begin
                    E[i][j] = 0;
                    for (k = 0; k < 2; k = k + 1)
                        E[i][j] = E[i][j] + A[i][k] * B[k][j];
                end
 
            // reset
            rst = 1; a0 = 0; a1 = 0; b0 = 0; b1 = 0;
            @(posedge clk); #1;
            rst = 0;
 
            // 斜著送：第 1 列和第 1 行晚一拍
            for (t = 0; t < 4; t = t + 1) begin
                a0 = (t < 2)            ? A[0][t]   : 0;
                a1 = (t >= 1 && t < 3)  ? A[1][t-1] : 0;
                b0 = (t < 2)            ? B[t][0]   : 0;
                b1 = (t >= 1 && t < 3)  ? B[t-1][1] : 0;
                @(posedge clk); #1;
            end
            a0 = 0; a1 = 0; b0 = 0; b1 = 0;
 
            tests = tests + 1;
            if (c00 !== E[0][0] || c01 !== E[0][1] || c10 !== E[1][0] || c11 !== E[1][1]) begin
                errors = errors + 1;
                if (errors <= 5) begin
                    $display("FAIL test %0d: A=[%0d %0d; %0d %0d] B=[%0d %0d; %0d %0d]",
                             tests, A[0][0], A[0][1], A[1][0], A[1][1],
                             B[0][0], B[0][1], B[1][0], B[1][1]);
                    $display("    你的 C = [%0d %0d; %0d %0d]", c00, c01, c10, c11);
                    $display("    正確 C = [%0d %0d; %0d %0d]", E[0][0], E[0][1], E[1][0], E[1][1]);
                end
            end
        end
    endtask
 
    initial begin
        $dumpfile("array2x2.vcd");
        $dumpvars(0, tb_array2x2);
 
        // 手算題：A = [1 2; 3 4]，B = [5 6; 7 8]，答案 C = [19 22; 43 50]
        A[0][0] = 1; A[0][1] = 2; A[1][0] = 3; A[1][1] = 4;
        B[0][0] = 5; B[0][1] = 6; B[1][0] = 7; B[1][1] = 8;
        run_matmul;
 
        for (n = 0; n < 200; n = n + 1) begin
            for (i = 0; i < 2; i = i + 1)
                for (j = 0; j < 2; j = j + 1) begin
                    A[i][j] = $random;
                    B[i][j] = $random;
                end
            run_matmul;
        end
 
        if (errors == 0) $display("PASS: %0d matrix multiplications, all correct", tests);
        else             $display("FAILED: %0d of %0d matrix multiplications wrong", errors, tests);
        $finish;
    end
endmodule
