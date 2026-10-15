// tb_golden.v — 讀 Python 產生的 .hex 檔來測 4×4 陣列（不用改）
// a.hex、b.hex：每題 16 個 8-bit 數字（一列一列排）
// c_expected.hex：每題 16 個 32-bit 正確答案（NumPy 算的）
 
`timescale 1ns/1ps
module tb_golden;
    localparam N = 4;
    localparam NUM_TESTS = 100;
 
    reg clk = 0, rst = 1;
    reg  [N*8-1:0]    a_left = 0, b_top = 0;
    wire [N*N*32-1:0] c;
 
    // 從檔案讀進來的資料
    reg [7:0]  a_mem [0:NUM_TESTS*N*N-1];
    reg [7:0]  b_mem [0:NUM_TESTS*N*N-1];
    reg [31:0] c_mem [0:NUM_TESTS*N*N-1];
 
    integer i, j, t, n, base, bad, errors = 0;
    reg [31:0] got, exp;
 
    systolic_array #(.N(N)) dut (.clk(clk), .rst(rst), .a_left(a_left), .b_top(b_top), .c(c));
 
    always #5 clk = ~clk;
 
    initial begin
        $readmemh("a.hex", a_mem);
        $readmemh("b.hex", b_mem);
        $readmemh("c_expected.hex", c_mem);
 
        for (n = 0; n < NUM_TESTS; n = n + 1) begin
            base = n * N * N;   // 第 n 題在檔案裡從第幾個數字開始
 
            rst = 1; a_left = 0; b_top = 0;
            @(posedge clk); #1;
            rst = 0;
 
            // 斜著送：A[i][k] 在 a_mem[base + i*N + k]，B[k][j] 在 b_mem[base + k*N + j]
            for (t = 0; t < 3*N; t = t + 1) begin
                for (i = 0; i < N; i = i + 1) begin
                    a_left[i*8 +: 8] = (t-i >= 0 && t-i < N) ? a_mem[base + i*N + (t-i)] : 8'd0;
                    b_top [i*8 +: 8] = (t-i >= 0 && t-i < N) ? b_mem[base + (t-i)*N + i] : 8'd0;
                end
                @(posedge clk); #1;
            end
            a_left = 0; b_top = 0;
 
            bad = 0;
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    got = c[(i*N + j)*32 +: 32];
                    exp = c_mem[base + i*N + j];
                    if (got !== exp) begin
                        bad = 1;
                        if (errors < 5)
                            $display("FAIL test %0d: C[%0d][%0d] = %0d, NumPy says %0d",
                                     n, i, j, $signed(got), $signed(exp));
                    end
                end
            if (bad) errors = errors + 1;
        end
 
        if (errors == 0) $display("PASS: %0d tests match NumPy golden model", NUM_TESTS);
        else             $display("FAILED: %0d of %0d tests differ from NumPy", errors, NUM_TESTS);
        $finish;
    end
endmodule
