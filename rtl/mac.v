24 分鐘前
第 4 項，共 4 項
// tb_mac.v — MAC 單元的 testbench（不用改）
// 會先跑幾個手算得出來的固定測試，再跑 1000 次亂數測試，
// 每個 clock 都拿你的 acc 跟 testbench 自己算的正確答案比對。
 
`timescale 1ns/1ps
module tb_mac;
    reg clk = 0, rst = 1, en = 0;
    reg  signed [7:0]  a = 0, b = 0;
    wire signed [31:0] acc;
    reg  signed [31:0] expected;
    integer i, errors = 0, checks = 0;
 
    mac dut (.clk(clk), .rst(rst), .en(en), .a(a), .b(b), .acc(acc));
 
    always #5 clk = ~clk;
 
    // 每個 clock 更新正確答案（參考模型）
    always @(posedge clk) begin
        if (rst)      expected <= 0;
        else if (en)  expected <= expected + a * b;
    end
 
    task step(input r, input e, input signed [7:0] x, input signed [7:0] y);
        begin
            rst = r; en = e; a = x; b = y;
            @(posedge clk); #1;
            checks = checks + 1;
            if (acc !== expected) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL t=%0t rst=%0d en=%0d a=%0d b=%0d : acc=%0d, expected=%0d",
                             $time, r, e, x, y, acc, expected);
            end
        end
    endtask
 
    initial begin
        $dumpfile("mac.vcd");
        $dumpvars(0, tb_mac);
 
        step(1, 0, 0, 0);          // reset
        step(0, 1, 3, 4);          // 0 + 12 = 12
        step(0, 1, -2, 5);         // 12 - 10 = 2
        step(0, 0, 100, 100);      // en=0，保持 2
        step(0, 1, -128, -128);    // 2 + 16384 = 16386
        step(0, 1, 127, -128);     // 16386 - 16256 = 130
        step(1, 1, 9, 9);          // reset 優先，回到 0
 
        for (i = 0; i < 1000; i = i + 1)
            step(($random % 50) == 0, $random, $random, $random);
 
        if (errors == 0) $display("PASS: %0d checks, all correct", checks);
        else             $display("FAILED: %0d of %0d checks wrong", errors, checks);
        $finish;
    end
endmodule


