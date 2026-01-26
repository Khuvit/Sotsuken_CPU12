    //  --------------------------------------------------------------------
    //  このファイルは今後の結合テストのベースとしておいています。今回のテストには関係ないです。
    //  --------------------------------------------------------------------
`timescale 1ns/1ps

module tb_integration;

  // ---- clock/reset ----
  reg clk = 0;
  reg rst_n = 0;   // TODO: CPU①に合わせて極性/名前修正

  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
  end

  // ---- wires ----
  wire [31:0] instr;
  wire [7:0]  pc;       // TODO: PC幅はCPU①に合わせる

  // dmem interface (TODO: CPU①の実I/Fで確定)
  wire [31:0] dmem_rdata;
  wire [31:0] dmem_wdata;
  wire        dmem_we;
  wire [1:0]  dmem_mode;
  wire [7:0]  dmem_waddr;
  wire [7:0]  dmem_raddr;

  // ---- memories ----
  i_mem #(
    .M_STACK(256), .DATA_W(32), .PC_WIDTH(8), .ADDR_WIDTH(8)
  ) u_imem (
    .clk(clk),
    .n_rst(rst_n),
    .rd_addr(pc),
    .d_out(instr)
  );

  d_mem #(
    .M_STACK(256), .DATA_W(32), .PC_WIDTH(8), .ADDR_WIDTH(8), .STORE_M(2)
  ) u_dmem (
    .clk(clk),
    .n_rst(rst_n),
    .wr_en(dmem_we),
    .rd_addr(dmem_raddr),
    .wr_addr(dmem_waddr),
    .mode(dmem_mode),
    .d_in(dmem_wdata),
    .d_out(dmem_rdata)
  );

  // ---- DUT ----
  // TODO: CPU①のトップI/F
  rv32i u_cpu (
    .clk(clk),
    .n_rst(rst_n),
    .instruction(instr),
    .pc(pc),
    .d_in(dmem_rdata),
    .wr_en(dmem_we),
    .mode(dmem_mode),
    .wr_addr(dmem_waddr),
    .rd_addr(dmem_raddr),
    .d_out(dmem_wdata)
  );

  // ---- counters ----
  integer total_cycles = 0;
  // retired_instructions は「コミット信号」が無い限り推測しない
  integer retired = 0;

  always @(posedge clk) begin
    if (!rst_n) total_cycles <= 0;
    else        total_cycles <= total_cycles + 1;
  end

  // ---- test control ----
  localparam [7:0] END_PC = 8'h80; // TODO: プログラム配置が決まったら確定

  task automatic dump_state(string tag);
    begin
      $display("---- %s ----", tag);
      $display("PC=%0h cycles=%0d", pc, total_cycles);
      $writememb({tag,"_reg.mem"},  u_cpu.rfile.rf); // TODO: 階層名もCPU①に合わせる
      $writememb({tag,"_data.mem"}, u_dmem.ram);
    end
  endtask

  // ---- PASS/FAIL (placeholder) ----
  // 期待値は「テストプログラム確定後」にここへ置く
  task automatic check_expected;
    begin
      // 例: checksumを格納したメモリ先頭ワードが期待値と一致するか
      // TODO: アドレス/期待値確定後に実装
      // if (observed == expected) PASS else FAIL
    end
  endtask

  initial begin
    $dumpfile("integration.vcd");
    $dumpvars(0, tb_integration);

    // reset後少し待つ
    repeat(10) @(posedge clk);
    dump_state("before");

    // 終了条件: PCがEND_PCに到達 or タイムアウト
    fork
      begin : timeout
        repeat(5000) @(posedge clk);
        $display("TEST RESULT: FAIL (timeout)");
        $finish;
      end

      begin : run_to_end
        wait (pc == END_PC);
        dump_state("after");
        check_expected();
        $display("total_cycles=%0d retired=%0d", total_cycles, retired);
        $finish;
      end
    join
  end

endmodule
