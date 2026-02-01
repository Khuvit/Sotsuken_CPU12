`timescale 1ns/1ps
// tb_cpu1_stepB.v
// CPU12 integration-style testbench (Signature method + timeout + per-check reporting)
// NOTE: Replace MEM/DATA init filenames + expected signature values to match your StepB program.

module tb_cpu1_stepB;

  // clock/reset
  reg clk = 0;
  reg rst_n = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
  end

  // wires to DUT
  wire [31:0] instr;
  wire [7:0]  pc;
  wire [31:0] dmem_rdata;
  wire [31:0] dmem_wdata;
  wire        dmem_we;
  wire [1:0]  dmem_mode;
  wire [7:0]  dmem_waddr;
  wire [7:0]  dmem_raddr;

  // Instruction memory (StepB image)
  i_mem #(
    .M_STACK(256), .DATA_W(32), .PC_WIDTH(8), .ADDR_WIDTH(8),
    .MEM_INIT_FILE("mem_cpu1_stepB.bin")   // <-- TODO: your StepB program
  ) u_imem (
    .clk(clk),
    .n_rst(rst_n),
    .rd_addr(pc),
    .d_out(instr)
  );

  // Data memory (StepB image)
  d_mem #(
    .M_STACK(256), .DATA_W(32), .PC_WIDTH(8), .ADDR_WIDTH(8), .STORE_M(2),
    .DATA_INIT_FILE("data_cpu1_stepB.dat") // <-- TODO: your StepB data image (or blank)
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

  // DUT
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

  // Helper: read little-endian 32-bit word from byte-addressed RAM
  function automatic [31:0] read_word(input integer base);
    begin
      read_word = {u_dmem.ram[base+3], u_dmem.ram[base+2], u_dmem.ram[base+1], u_dmem.ram[base+0]};
    end
  endfunction

  integer fail = 0;

  task automatic check_sig(input [7:0] base, input [31:0] exp);
    reg [31:0] got;
    begin
      got = read_word(base);
      if (got !== exp) begin
        fail = 1;
        $display("SIG FAIL @0x%02h: got=0x%08h exp=0x%08h", base, got, exp);
      end else begin
        $display("SIG  OK  @0x%02h: 0x%08h", base, got);
      end
    end
  endtask

  // PASS flag location (same convention as StepA)
  localparam [7:0] PASS_ADDR = 8'h08;

  // Signature addresses (example: 0x80..)
  // TODO: set these expected values to match your StepB program.
  localparam [7:0] SIG0 = 8'h80;
  localparam [7:0] SIG1 = 8'h84;
  localparam [7:0] SIG2 = 8'h88;
  localparam [7:0] SIG3 = 8'h8C;
  localparam [7:0] SIG4 = 8'h90;

  localparam [31:0] EXP0 = 32'hDEADBEEF; // TODO
  localparam [31:0] EXP1 = 32'hCAFEBABE; // TODO
  localparam [31:0] EXP2 = 32'h00000000; // TODO
  localparam [31:0] EXP3 = 32'h00000000; // TODO
  localparam [31:0] EXP4 = 32'h00000001; // TODO

  // Timeout (cycles)
  localparam integer TIMEOUT_CYCLES = 2000;

  integer cyc;
  reg saw_pass;

  initial begin
    $dumpfile("stepB.vcd");
    $dumpvars(0, tb_cpu1_stepB);

    saw_pass = 0;

    // Run until PASS flag observed or timeout
    for (cyc = 0; cyc < TIMEOUT_CYCLES && !saw_pass; cyc = cyc + 1) begin
      @(posedge clk);
      if (read_word(PASS_ADDR) == 32'h1) begin
        saw_pass = 1;
        $display("PASS flag observed at cycle %0d (mem[0x%02h]=1).", cyc, PASS_ADDR);
      end
    end

    if (!saw_pass) begin
      $display("TIMEOUT after %0d cycles. PASS flag not observed.", TIMEOUT_CYCLES);
    end

    // Signature checks (adjust list as needed)
    $display("---- Signature checks ----");
    check_sig(SIG0, EXP0);
    check_sig(SIG1, EXP1);
    check_sig(SIG2, EXP2);
    check_sig(SIG3, EXP3);
    check_sig(SIG4, EXP4);

    if (!fail && saw_pass) begin
      $display("TEST RESULT: PASS (PASS flag + all signature words matched)");
    end else if (!fail && !saw_pass) begin
      $display("TEST RESULT: FAIL (signature matched but PASS flag missing)");
    end else begin
      $display("TEST RESULT: FAIL (signature mismatch detected)");
    end

    $finish;
  end

endmodule
