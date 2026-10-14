

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
// TODO：只要完成最下面的 always block。
 
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
