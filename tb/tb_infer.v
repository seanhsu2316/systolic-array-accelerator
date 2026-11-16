`timescale 1ns/1ps
module tb_infer;
    localparam N = 4;
    localparam K = 12;          // 每段有 12 個特徵
    localparam GROUPS = 16;     // 64 段 ÷ 4

    reg clk = 0, rst = 1;
    reg  [N*8-1:0]    a_left = 0, b_top = 0;
    wire [N*N*32-1:0] c;

    reg [7:0]  fq_mem  [0:64*K-1];
    reg [7:0]  wq_mem  [0:K*N-1];
    reg [31:0] bq_mem  [0:N-1];
    reg [7:0]  lab_mem [0:63];
    reg [31:0] exp_mem [0:64*N-1];

    integer g, i, j, t, r, best, correct = 0, mismatch = 0;
    reg signed [31:0] score, best_score;

    systolic_array #(.N(N)) dut (.clk(clk), .rst(rst), .a_left(a_left), .b_top(b_top), .c(c));

    always #5 clk = ~clk;

    initial begin
        $readmemh("fq.hex", fq_mem);
        $readmemh("wq.hex", wq_mem);
        $readmemh("bq.hex", bq_mem);
        $readmemh("labels.hex", lab_mem);
        $readmemh("expected.hex", exp_mem);

        for (g = 0; g < GROUPS; g = g + 1) begin
            rst = 1; a_left = 0; b_top = 0;
            @(posedge clk); #1;
            rst = 0;
            for (t = 0; t < K + 2*N; t = t + 1) begin
                for (i = 0; i < N; i = i + 1) begin
                    a_left[i*8 +: 8] = (t-i >= 0 && t-i < K) ? fq_mem[(g*N + i)*K + (t-i)] : 8'd0;
                    b_top[i*8 +: 8]  = (t-i >= 0 && t-i < K) ? wq_mem[(t-i)*N + i] : 8'd0;
                end
                @(posedge clk); #1;
            end
            a_left = 0; b_top = 0;

            for (i = 0; i < N; i = i + 1) begin
                r = g*N + i;
                best = 0; best_score = 0;
                for (j = 0; j < 3; j = j + 1) begin
                    if (c[(i*N + j)*32 +: 32] !== exp_mem[r*N + j]) mismatch = mismatch + 1;
                    score = $signed(c[(i*N + j)*32 +: 32]) + $signed(bq_mem[j]);
                    if (j == 0 || score > best_score) begin best = j; best_score = score; end
                end
                if (r < 63 && best == lab_mem[r]) correct = correct + 1;
                if (r % 8 == 0) $display("window %0d: hardware says %0d, answer %0d", r, best, lab_mem[r]);
            end
        end

        $display("----------------------------------------");
        if (mismatch == 0) $display("PASS: all hardware scores match NumPy");
        else               $display("FAIL: %0d scores differ from NumPy", mismatch);
        $display("hardware accuracy: %0d / 63", correct);
        $finish;
    end
endmodule
