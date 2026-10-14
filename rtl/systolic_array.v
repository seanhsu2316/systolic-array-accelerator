// systolic_array.v — N×N systolic array（預設 4×4 = 16 個 PE）
//
// 跟第 3 天的 2×2 一樣，只是不再一格一格手寫，
// 而是用 generate for 迴圈自動產生 N×N 個 PE。
//
// 連線的想法：把格子之間的線排成「表格」
//   a_wire[i][j]：第 i 列、第 j 格「左邊」的 a 線
//                 a_wire[i][0] 是外面送進來的，a_wire[i][N] 是最右邊多出來的
//   b_wire[i][j]：第 i 列、第 j 格「上面」的 b 線
//                 b_wire[0][j] 是外面送進來的，b_wire[N][j] 是最下面多出來的
//
//   所以 PE(i,j)：a 從 a_wire[i][j] 進來，從 a_wire[i][j+1] 出去（往右）
//                 b 從 b_wire[i][j] 進來，從 b_wire[i+1][j] 出去（往下）
//
// 輸入輸出是「攤平」的長線：
//   a_left 有 N 段，每段 W bit：第 i 段給第 i 列
//   b_top  有 N 段，每段 W bit：第 j 段給第 j 行
//   c      有 N×N 段，每段 ACC bit：第 (i*N + j) 段是 C[i][j]
//
 
module systolic_array #(
    parameter N   = 4,
    parameter W   = 8,
    parameter ACC = 32
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire [N*W-1:0]          a_left,
    input  wire [N*W-1:0]          b_top,
    output wire [N*N*ACC-1:0]      c
);
 
    wire signed [W-1:0] a_wire [0:N-1][0:N];
    wire signed [W-1:0] b_wire [0:N][0:N-1];
 
    genvar i, j;
 
    // 把外面送進來的線接到表格的邊上
    generate
        for (i = 0; i < N; i = i + 1) begin : edge_in
            assign a_wire[i][0] = a_left[i*W +: W];
            assign b_wire[0][i] = b_top [i*W +: W];
        end
    endgenerate
 
    // 產生 N×N 個 PE
    generate
        for (i = 0; i < N; i = i + 1) begin : row
            for (j = 0; j < N; j = j + 1) begin : col
                pe #(.W(W), .ACC(ACC)) u_pe (
                    .clk  (clk),
                    .rst  (rst),
                    .a_in (a_wire[i][j]),
                    .b_in (b_wire[i][j]),
                    .a_out(a_wire[i][j+1]),
                    .b_out(b_wire[i+1][j]),
                    .acc  (c[(i*N + j)*ACC +: ACC])
                );
            end
        end
    endgenerate
 
endmodule
