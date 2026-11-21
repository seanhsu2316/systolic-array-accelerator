`timescale 1ns/1ps
module tb_mac;
    logic clk = 0, rst = 1, en = 0;
    logic signed [7:0]  a = 0, b = 0;
    logic signed [31:0] acc;
    logic signed [31:0] expected;
    int errors = 0, checks = 0;

    int ctrl_hits [4];         
    int a_hits    [5];         
    int b_hits    [5];
    int ab_hits   [5][5];      

    mac dut (.*);
    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        if (rst)     expected <= 0;
        else if (en) expected <= expected + a * b;
    end

    // 把一個數字分到 5 個桶子之一：0=min 1=neg 2=zero 3=pos 4=max
    function automatic string name_of(int k);
        case (k) 0: return "min"; 1: return "neg"; 2: return "zero"; 3: return "pos"; default: return "max"; endcase
    endfunction

    function automatic int bin_of(logic signed [7:0] v);
        if (v == -128)    return 0;
        else if (v == 127) return 4;
        else if (v == 0)   return 2;
        else if (v < 0)    return 1;
        else               return 3;
    endfunction

function automatic logic signed [7:0] rand_val();
    case ($urandom_range(0, 9))
        0:       return -128;
        1:       return 0;
        2:       return 127;
        default: return $urandom;   
    endcase
endfunction

 
    task automatic sample();
        ctrl_hits[{rst, en}]++;
        a_hits[bin_of(a)]++;
        b_hits[bin_of(b)]++;
        ab_hits[bin_of(a)][bin_of(b)]++;
    endtask

    task automatic step(input logic r, e, input logic signed [7:0] x, y);
        rst = r; en = e; a = x; b = y;
        sample();
        @(posedge clk); #1;
        checks++;
        assert (acc === expected)
            else begin
                errors++;
                $error("a=%0d b=%0d : acc=%0d, expected=%0d", x, y, acc, expected);
            end
    endtask

   
    task automatic report();
        int filled;
        $display("---------- coverage ----------");
        filled = 0;
        foreach (ctrl_hits[k]) if (ctrl_hits[k] > 0) filled++;
        $display("rst/en : %0d / 4 bins   (00=%0d 01=%0d 10=%0d 11=%0d)",
                 filled, ctrl_hits[0], ctrl_hits[1], ctrl_hits[2], ctrl_hits[3]);
        filled = 0;
        foreach (a_hits[k]) if (a_hits[k] > 0) filled++;
        $display("a      : %0d / 5 bins   (min=%0d max=%0d zero=%0d)", filled, a_hits[0], a_hits[4], a_hits[2]);
        filled = 0;
        foreach (b_hits[k]) if (b_hits[k] > 0) filled++;
        $display("b      : %0d / 5 bins   (min=%0d max=%0d zero=%0d)", filled, b_hits[0], b_hits[4], b_hits[2]);
        filled = 0;
        foreach (ab_hits[i, j]) begin
            if (ab_hits[i][j] > 0) filled++;
            else $display("  hole: a=%s, b=%s never tested", name_of(i), name_of(j));
        end
        $display("a x b  : %0d / 25 bins", filled);
    endtask

    initial begin
        step(1, 0, 0, 0);
        repeat (1000) begin
            step($urandom_range(0, 49) == 0,
                 $urandom_range(0, 9) != 0,
                 rand_val(), rand_val());;
        end
        if (errors == 0) $display("PASS: %0d checks, all correct", checks);
        else             $display("FAILED: %0d of %0d checks wrong", errors, checks);
        report();
        $finish;
    end
endmodule
