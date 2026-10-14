// tb_systolic_array.v — 4×4 陣列的 testbench（不用改）
// 算 C = A × B（4×4 矩陣），斜著送進陣列，跑完後檢查 16 格答案。
// 先跑一題看得出答案的（A 乘上單位矩陣，答案應該等於 A），再跑 200 題亂數。
 
`timescale 1ns/1ps
module tb_systolic_array;
    localparam N = 4;
    reg clk = 0, rst = 1;
    reg  [N*8-1:0]    a_left = 0, b_top = 0;
    wire [N*N*32-1:0] c;
    reg  signed [7:0]  A [0:N-1][0:N-1];
    reg  signed [7:0]  B [0:N-1][0:N-1];
    reg  signed [31:0] E [0:N-1][0:N-1];
    reg  signed [31:0] got;
    integer i, j, k, t, n, bad, errors = 0, tests = 0;
 
    systolic_array #(.N(N)) dut (.clk(clk), .rst(rst), .a_left(a_left), .b_top(b_top), .c(c));
 
    always #5 clk = ~clk;
 
    task run_matmul;
        begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    E[i][j] = 0;
                    for (k = 0; k < N; k = k + 1)
                        E[i][j] = E[i][j] + A[i][k] * B[k][j];
                end
 
            rst = 1; a_left = 0; b_top = 0;
            @(posedge clk); #1;
            rst = 0;
 
            // 斜著送：第 i 列晚 i 拍，第 j 行晚 j 拍
            for (t = 0; t < 3*N; t = t + 1) begin
                for (i = 0; i < N; i = i + 1) begin
                    a_left[i*8 +: 8] = (t-i >= 0 && t-i < N) ? A[i][t-i] : 0;
                    b_top [i*8 +: 8] = (t-i >= 0 && t-i < N) ? B[t-i][i] : 0;
                end
                @(posedge clk); #1;
            end
            a_left = 0; b_top = 0;
 
            tests = tests + 1;
            bad = 0;
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    got = c[(i*N + j)*32 +: 32];
                    if (got !== E[i][j]) begin
                        bad = 1;
                        if (errors < 5)
                            $display("FAIL test %0d: C[%0d][%0d] = %0d, expected %0d", tests, i, j, got, E[i][j]);
                    end
                end
            if (bad) errors = errors + 1;
        end
    endtask
 
    initial begin
        $dumpfile("systolic_array.vcd");
        $dumpvars(0, tb_systolic_array);
 
        // 第 1 題：A = 1~16，B = 單位矩陣，答案 C 應該等於 A
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                A[i][j] = i*N + j + 1;
                B[i][j] = (i == j) ? 1 : 0;
            end
        run_matmul;
 
        for (n = 0; n < 200; n = n + 1) begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    A[i][j] = $random;
                    B[i][j] = $random;
                end
            run_matmul;
        end
 
        if (errors == 0) $display("PASS: %0d 4x4 matrix multiplications, all correct", tests);
        else             $display("FAILED: %0d of %0d matrix multiplications wrong", errors, tests);
        $finish;
    end
endmodule
