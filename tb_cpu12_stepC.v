`timescale 1ns/1ps
// tb_perf_compare_stepC.v
// Performance-compare testbench for CPU12 vs CPU14 (cycle-based).
//
// How to use (example with iverilog):
//  CPU12:
//    iverilog -g2012 -o simC12.vvp tb_perf_compare_stepC.v rv32i.v i_mem.v d_mem.v reg.v alu.v defines.v
//    vvp simC12.vvp
//
//  CPU14 (compile CPU14 sources + define CPU14):
//    iverilog -g2012 -DCPU14 -o simC14.vvp tb_perf_compare_stepC.v rv32i.v i_mem.v d_mem.v reg.v alu.v defines.v
//    vvp simC14.vvp
//
// Notes:
// - This TB measures "cycles until PASS flag" (mem[0x08] == 1).
// - For CPU14, if the core exposes valid_W internally, we count retired instructions.
// - Replace MEM/DATA init filenames + expected signatures to match your StepC program.

module tb_perf_compare_stepC;

  // clock/reset
  reg clk = 0;
  reg rst_n = 0;
  always #5 clk = ~clk;  // fixed period for fair comparison

  initial begin
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
  end

  // wires
  wire [31:0] instr;
  wire [7:0]  pc;
  wire [31:0] dmem_rdata;
  wire [31:0] dmem_wdata;
  wire        dmem_we;
  wire [1:0]  dmem_mode;
  wire [7:0]  dmem_waddr;
  wire [7:0]  dmem_raddr;

  // Instruction memory (StepC image)
  i_mem #(
    .M_STACK(256), .DATA_W(32), .PC_WIDTH(8), .ADDR_WIDTH(8),
    .MEM_INIT_FILE("mem_cpu12_stepC.bin")
  ) u_imem (
    .clk(clk),
    .n_rst(rst_n),
    .rd_addr(pc),
    .d_out(instr)
  );

  // Data memory (StepC image)
  d_mem #(
    .M_STACK(256), .DATA_W(32), .PC_WIDTH(8), .ADDR_WIDTH(8), .STORE_M(2),
    .DATA_INIT_FILE("data_cpu12_stepC.dat")
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

  // Conventions
  localparam [7:0] PASS_ADDR = 8'h08;      // PASS flag word address (byte base)
  localparam integer TIMEOUT_CYCLES = 50000;

  // Signature addresses (example region)
  // TODO: set these to whatever your StepC program writes.
  localparam [7:0] SIG0 = 8'h80;
  localparam [7:0] SIG1 = 8'h84;
  localparam [7:0] SIG2 = 8'h88;
  localparam [7:0] SIG3 = 8'h8C;

  // Expected signature values from data:
  // data[0x00] = 0x44332211, data[0x04] = 0x88776655, data[0x08] = 0x12345678
  localparam [31:0] EXP0 = 32'h44332211;  // sig[0x80] = data[0x00]
  localparam [31:0] EXP1 = 32'h88776655;  // sig[0x84] = data[0x04]
  localparam [31:0] EXP2 = 32'hCCAA8866;  // sig[0x88] = data[0x00] + data[0x04]
  localparam [31:0] EXP3 = 32'h00000001;  // sig[0x8C] = PASS flag

  // Performance counters
  integer cyc;
  integer retired;
  reg saw_pass;

  // Optional: CPU14 retirement counting (valid_W)
`ifdef CPU14
  always @(posedge clk) begin
    if (!rst_n) begin
      retired <= 0;
    end else begin
      if (u_cpu.valid_W) retired <= retired + 1;
    end
  end
`else
  initial retired = -1; // N/A
`endif

  initial begin
`ifdef CPU14
    $display("=== PERF TB: CPU14 mode (with retirement count if valid_W exists) ===");
`else
    $display("=== PERF TB: CPU12 mode (cycle-based) ===");
`endif

    $dumpfile("stepC_perf.vcd");
    $dumpvars(0, tb_perf_compare_stepC);

    saw_pass = 0;

    // Run until PASS flag observed or timeout
    for (cyc = 0; cyc < TIMEOUT_CYCLES && !saw_pass; cyc = cyc + 1) begin
      @(posedge clk);
      if (rst_n && (read_word(PASS_ADDR) == 32'h1)) begin
        saw_pass = 1;
        $display("PASS flag observed at cycle %0d (mem[0x%02h]=1).", cyc, PASS_ADDR);
      end
    end

    if (!saw_pass) begin
      $display("TIMEOUT after %0d cycles. PASS flag not observed.", TIMEOUT_CYCLES);
    end

    // Signature checks
    $display("---- Signature checks ----");
    check_sig(SIG0, EXP0);
    check_sig(SIG1, EXP1);
    check_sig(SIG2, EXP2);
    check_sig(SIG3, EXP3);

    // Performance report
    $display("---- Performance report ----");
    $display("Cycles_to_PASS = %0d", cyc);
`ifdef CPU14
    $display("Retired_instructions = %0d", retired);
    if (retired > 0) begin
      $display("CPI = %f", cyc * 1.0 / retired);
      $display("IPC = %f", retired * 1.0 / cyc);
    end else begin
      $display("CPI/IPC not computed (retired <= 0).");
    end
`else
    $display("Retired_instructions = N/A (CPU12 mode)");
`endif

    // Final verdict
    if (saw_pass && !fail) begin
      $display("TEST RESULT: PASS");
    end else if (!saw_pass && !fail) begin
      $display("TEST RESULT: FAIL (PASS flag missing)");
    end else begin
      $display("TEST RESULT: FAIL (signature mismatch)");
    end

    $finish;
  end

endmodule
