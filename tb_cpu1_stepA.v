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

	// test sequence
	initial begin
		$dumpfile("stepA.vcd");
		$dumpvars(0, tb_cpu1_stepA);

		// run for a bounded number of cycles
		repeat (200) @(posedge clk);

		// observe mem[8] as 32-bit little endian
		result = {u_dmem.ram[11], u_dmem.ram[10], u_dmem.ram[9], u_dmem.ram[8]};

		if (result == 32'h1) begin
			$display("TEST RESULT: PASS (mem[8]=1)");
		end else begin
			$display("TEST RESULT: FAIL (mem[8]=%h)", result);
		end

		$finish;
	end

endmodule
