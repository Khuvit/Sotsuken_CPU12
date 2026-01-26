`timescale 1ns/1ps

module tb_cpu1_stepA;

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

  reg [31:0] result;

  // instruction memory (Step A image)
  i_mem #(
    .M_STACK(256), .DATA_W(32), .PC_WIDTH(8), .ADDR_WIDTH(8),
    .MEM_INIT_FILE("mem_cpu1_stepA.bin")
  ) u_imem (
    .clk(clk),
    .n_rst(rst_n),
    .rd_addr(pc),
    .d_out(instr)
  );

  // data memory (Step A image)
  d_mem #(
    .M_STACK(256), .DATA_W(32), .PC_WIDTH(8), .ADDR_WIDTH(8), .STORE_M(2),
    .DATA_INIT_FILE("data_cpu1_stepA.dat")
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

  // Debug monitor - print every instruction
  integer cycle;
  initial cycle = 0;
  
  always @(posedge clk) begin
    if (rst_n) begin
      cycle = cycle + 1;
      
      // Print PC and instruction
      $display("───────────────────────────────────────────────────────────");
      $display("Cycle %0d: PC=0x%h  Instruction=0x%h", cycle, pc, instr);
      
      // Decode instruction
      case(instr[6:0])
        7'b0000011: $display("  → LW x%0d, %0d(x%0d)", instr[11:7], $signed(instr[31:20]), instr[19:15]);
        7'b0100011: $display("  → SW x%0d, %0d(x%0d)", instr[24:20], $signed({instr[31:25],instr[11:7]}), instr[19:15]);
        7'b1100011: $display("  → BEQ x%0d, x%0d, %0d", instr[19:15], instr[24:20], $signed({instr[31],instr[7],instr[30:25],instr[11:8],1'b0}));
        7'b0010011: $display("  → ADDI x%0d, x%0d, %0d", instr[11:7], instr[19:15], $signed(instr[31:20]));
        7'b1101111: $display("  → JAL x%0d, %0d", instr[11:7], $signed({instr[31],instr[19:12],instr[20],instr[30:21],1'b0}));
        default:    $display("  → UNKNOWN");
      endcase
      
      // Print register file state (only non-zero)
      $display("  Registers:");
      if (u_cpu.rfile.rf[1] != 0) $display("    x1  = 0x%h", u_cpu.rfile.rf[1]);
      if (u_cpu.rfile.rf[2] != 0) $display("    x2  = 0x%h", u_cpu.rfile.rf[2]);
      if (u_cpu.rfile.rf[3] != 0) $display("    x3  = 0x%h", u_cpu.rfile.rf[3]);
      
      // Print memory operations
      if (dmem_we) 
        $display("  MEM WRITE: addr=0x%h, data=0x%h", dmem_waddr, dmem_wdata);
      if (u_cpu.opcode_M == 7'b0000011)
        $display("  MEM READ:  addr=0x%h, data=0x%h", dmem_raddr, dmem_rdata);
      
      // Stop after reaching infinite loop
      if (pc == 8'h24 && cycle > 20) begin
        $display("───────────────────────────────────────────────────────────");
        $display("\n*** REACHED END (infinite loop at 0x24) ***\n");
        
        result = {u_dmem.ram[11], u_dmem.ram[10], u_dmem.ram[9], u_dmem.ram[8]};
        if (result == 32'h1) begin
          $display("✓ TEST RESULT: PASS (mem[8]=1)");
        end else begin
          $display("✗ TEST RESULT: FAIL (mem[8]=%h)", result);
        end
        $finish;
      end
    end
  end

endmodule
