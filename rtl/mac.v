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
