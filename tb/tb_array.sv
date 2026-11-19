`timescale 1ns/1ps
module tb_array;
    localparam int N = 4;

    logic clk = 0, rst = 1;
    logic [N*8-1:0]    a_left = 0, b_top = 0;
    logic [N*N*32-1:0] c;

    logic signed [7:0]  A [N][N];       
    logic signed [7:0]  B [N][N];       
    logic signed [31:0] C_ref [N][N];   
    int errors = 0, tests = 0;

    systolic_array #(.N(N)) dut (.*);

    always #5 clk = ~clk;

    task automatic make_problem();
        foreach (A[i, j]) A[i][j] = $urandom;
        foreach (B[i, j]) B[i][j] = $urandom;
    endtask

    task automatic compute_ref();
        foreach (C_ref[i, j]) begin
            C_ref[i][j] = 0;
            for (int k = 0; k < N; k++)
                C_ref[i][j] = C_ref[i][j] + A[i][k] * B[k][j];
        end
    endtask

    task automatic run_array();
        rst = 1; a_left = 0; b_top = 0;
        @(posedge clk); #1;
        rst = 0;
        for (int t = 0; t < 3*N; t++) begin
            for (int i = 0; i < N; i++) begin
                a_left[i*8 +: 8] = (t-i >= 0 && t-i < N) ? A[i][t-i] : 8'd0;
                b_top [i*8 +: 8] = (t-i >= 0 && t-i < N) ? B[t-i][i] : 8'd0;
            end
            @(posedge clk); #1;
        end
    endtask

    task automatic check();
        tests++;
        foreach (C_ref[i, j])
            assert ($signed(c[(i*N + j)*32 +: 32]) === C_ref[i][j])
                else begin
                    errors++;
                    $error("test %0d C[%0d][%0d]: hw=%0d ref=%0d",
                           tests, i, j, $signed(c[(i*N + j)*32 +: 32]), C_ref[i][j]);
                end
    endtask

    initial begin
        repeat (500) begin
            make_problem();
            compute_ref();
            run_array();
            check();
        end
        if (errors == 0) $display("PASS: %0d random matrix multiplications", tests);
        else             $display("FAILED: %0d wrong elements", errors);
        $finish;
    end
endmodule
