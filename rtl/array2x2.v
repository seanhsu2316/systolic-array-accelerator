// mac.v — Multiply-Accumulate (MAC) unit
// 這是 systolic array 裡每一格 (processing element, PE) 的核心。
//
// 規格：
//   - a, b 是 8-bit 有號數 (signed)
//   - 每個 clock 上升緣：
//       rst = 1          -> acc 清成 0
//       否則 en = 1      -> acc = acc + a * b
//       否則             -> acc 保持不變
//   - acc 是 32-bit 有號數
//
 
module mac #(
    parameter W   = 8,   // 輸入位元數
    parameter ACC = 32   // 累加器位元數
) (
    input  wire                  clk,
    input  wire                  rst,   // 同步 reset，高電位有效
    input  wire                  en,    // 1 = 這個 clock 要做乘加
    input  wire signed [W-1:0]   a,
    input  wire signed [W-1:0]   b,
    output reg  signed [ACC-1:0] acc
);
 
    always @(posedge clk) begin
        if (rst)
            acc <= 0;
        else if (en)
            acc <= acc + a * b;
    end
 
endmodule
 
// pe.v — Processing Element (PE)，systolic array 裡的一格
//
// PE = 第 1 天的 MAC + 兩個「傳給隔壁」的暫存器
//
//        b_in (從上面來)
//          |
//  a_in -> [ PE ] -> a_out (傳給右邊)
//          |
//        b_out (傳給下面)
//
// 規格：每個 clock 上升緣
//   rst = 1 -> a_out、b_out 清成 0（acc 由 MAC 自己清 0）
//   否則    -> a_out 存下 a_in，b_out 存下 b_in（晚一拍傳出去）
//              同時 MAC 做 acc = acc + a_in * b_in
//
 
module pe #(
    parameter W   = 8,
    parameter ACC = 32
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire signed [W-1:0]   a_in,
    input  wire signed [W-1:0]   b_in,
    output reg  signed [W-1:0]   a_out,
    output reg  signed [W-1:0]   b_out,
    output wire signed [ACC-1:0] acc
);
 
    // 直接重複使用第 1 天寫好的 MAC，en 固定接 1（每拍都算）
    mac #(.W(W), .ACC(ACC)) u_mac (
        .clk(clk), .rst(rst), .en(1'b1),
        .a(a_in), .b(b_in), .acc(acc)
    );
 
    always @(posedge clk) begin
        if (rst) begin
            a_out <= 0;
            b_out <= 0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
        end
    end
 
endmodule
 
// array2x2.v — 2×2 systolic array（4 個 PE 接成格子）
//
//            b0          b1
//            |           |
//   a0 -> [ PE00 ] -> [ PE01 ]
//            |           |
//   a1 -> [ PE10 ] -> [ PE11 ]
//
// - a 從左邊進來，往右傳
// - b 從上面進來，往下傳
// - 每個 PE 的 acc 就是答案 C 的一格：PE00 -> c00、PE01 -> c01 ...
//
// 格子之間的連線（中間的線）已經幫你宣告好了：
//   a_00_01：PE00 的 a_out 傳到 PE01 的 a_in
//   a_10_11：PE10 的 a_out 傳到 PE11 的 a_in
//   b_00_10：PE00 的 b_out 傳到 PE10 的 b_in
//   b_01_11：PE01 的 b_out 傳到 PE11 的 b_in
//
 
module array2x2 #(
    parameter W   = 8,
    parameter ACC = 32
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire signed [W-1:0]   a0, a1,   // 左邊進來的兩列
    input  wire signed [W-1:0]   b0, b1,   // 上面進來的兩行
    output wire signed [ACC-1:0] c00, c01, c10, c11
);
 
    // 格子之間的連線
    wire signed [W-1:0] a_00_01, a_10_11;
    wire signed [W-1:0] b_00_10, b_01_11;
 
    // PE00：左上角（範例）
    pe #(.W(W), .ACC(ACC)) pe00 (
        .clk(clk), .rst(rst),
        .a_in(a0),       .b_in(b0),
        .a_out(a_00_01), .b_out(b_00_10),
        .acc(c00)
    );
 
    // PE01：右上角（a 從 PE00 來，右邊沒人所以 a_out 留空）
    pe #(.W(W), .ACC(ACC)) pe01 (
        .clk(clk), .rst(rst),
        .a_in(a_00_01),  .b_in(b1),
        .a_out(),        .b_out(b_01_11),
        .acc(c01)
    );
 
    // PE10：左下角（b 從 PE00 來，下面沒人所以 b_out 留空）
    pe #(.W(W), .ACC(ACC)) pe10 (
        .clk(clk), .rst(rst),
        .a_in(a1),       .b_in(b_00_10),
        .a_out(a_10_11), .b_out(),
        .acc(c10)
    );
 
    // PE11：右下角（a 從 PE10 來、b 從 PE01 來，兩個輸出都留空）
    pe #(.W(W), .ACC(ACC)) pe11 (
        .clk(clk), .rst(rst),
        .a_in(a_10_11),  .b_in(b_01_11),
        .a_out(),        .b_out(),
        .acc(c11)
    );
 
endmodule
