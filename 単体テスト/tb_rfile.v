`timescale 1ns/1ps
// レジスタファイルのテストベンチ
module tb_rfile;
    // パラメータ（RV32I 想定）
    localparam REG_W  = 5;
    localparam REG_S  = 32;
    localparam DATA_W = 32;

    reg                   clk;
    reg  [REG_W-1:0]      a1, a2, a3;
    reg  [DATA_W-1:0]     wd;
    reg                   we;
    wire [DATA_W-1:0]     rd1, rd2;

    // DUT: レジスタファイル
    rfile #(
        .REG_W(REG_W),
        .REG_S(REG_S),
        .DATA_W(DATA_W)
    ) uut (
        .clk(clk),
        .a1(a1),
        .a2(a2),
        .a3(a3),
        .rd1(rd1),
        .rd2(rd2),
        .wd(wd),
        .we(we)
    );

    // クロック生成
    initial clk = 0;
    always #5 clk = ~clk;   // 10ns period

    // VCD 出力 (GTKWave 用)
    initial begin
        $dumpfile("rfile_tb.vcd");
        $dumpvars(0, tb_rfile);
    end

    initial begin
        // 初期化
        we = 0;
        a1 = 0;
        a2 = 0;
        a3 = 0;
        wd = 0;

        // 少し待つ
        #12;

        // ---- Test 1: x1 に 5 を書き込み → 読み出し確認 ----
        $display("=== Test 1: write 5 to x1, then read ===");
        we = 1;
        a3 = 5'd1;          // rd = x1
        wd = 32'd5;
        #10;                // 1クロック待ち（posedge 通過）

        we = 0;
        a1 = 5'd1;          // rs1 = x1
        #2;
        $display("time %0t : rd1 = %0d (Souteichi: 5)", $time, rd1);

        // ---- Test 2: x10 に 123 を書き込み → 読み出し確認 ----
        $display("=== Test 2: write 123 to x10, then read ===");
        we = 1;
        a3 = 5'd10;         // rd = x10
        wd = 32'd123;
        #10;

        we = 0;
        a1 = 5'd10;         // rs1 = x10
        #2;
        $display("time %0t : rd1 = %0d (Souteichi: 123)", $time, rd1);

        // ---- Test 3: x0 に書き込もうとしても 0 のままか ----
        $display("=== Test 3: try write 999 to x0, read should stay 0 ===");
        we = 1;
        a3 = 5'd0;          // rd = x0
        wd = 32'd999;
        #10;

        we = 0;
        a1 = 5'd0;          // rs1 = x0
        #2;
        $display("time %0t : rd1 = %0d (Souteichi: 0)", $time, rd1);

        // 終了
        #20;
        $display("=== rfile test done ===");
        $finish;
    end

endmodule