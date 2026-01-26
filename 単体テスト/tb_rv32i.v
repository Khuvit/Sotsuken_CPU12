`timescale 1ns/1ps
`include "defines.v"

module tb;
    // Clock and reset
    reg clk = 0;
    reg n_rst = 0;

    // Wires between modules
    wire [31:0] instruction;
    wire [7:0]  pc; // PC width used by rv32i default is 8

    wire [31:0] d_out_mem; // data memory -> cpu
    wire [31:0] d_out_cpu; // cpu -> data memory (write data)
    wire        wr_en;
    wire [1:0]  mode;
    wire [7:0]  wr_addr;
    wire [7:0]  rd_addr;

    // clocks
    initial begin
        forever #5 clk = ~clk; // 10ns period
    end

    // reset
    initial begin
        n_rst = 0;
        #20;
        n_rst = 1;
    end

    // Instantiate instruction memory (i_mem)
    i_mem #(
        .M_STACK(16),
        .DATA_W(32),
        .PC_WIDTH(8),
        .ADDR_WIDTH(8)
    ) u_imem (
        .clk(clk),
        .n_rst(n_rst),
        .rd_addr(pc),
        .d_out(instruction)
    );

    // Instantiate data memory (d_mem)
    d_mem #(
        .M_STACK(16),
        .DATA_W(32),
        .PC_WIDTH(8),
        .ADDR_WIDTH(8),
        .STORE_M(2)
    ) u_dmem (
        .clk(clk),
        .n_rst(n_rst),
        .wr_en(wr_en),
        .rd_addr(rd_addr),
        .wr_addr(wr_addr),
        .mode(mode),
        .d_in(d_out_cpu),
        .d_out(d_out_mem)
    );

    // Instantiate CPU (rv32i)
    rv32i #(
        .MEMORY_S(2**8),
        .PC_W(8),
        .DATA_W(32),
        .REG_W(5),
        .REG_S(32)
    ) u_cpu (
        .clk(clk),
        .n_rst(n_rst),
        .instruction(instruction),
        .pc(pc),
        .d_in(d_out_mem),
        .wr_en(wr_en),
        .mode(mode),
        .wr_addr(wr_addr),
        .rd_addr(rd_addr),
        .d_out(d_out_cpu)
    );

    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0,tb);
        //----------------------------------------------------------------------
        // Dump register file and data memory BEFORE running the main cycles
        //----------------------------------------------------------------------
        // give a few cycles for reset to propagate
        #30;
        $display("--- DUMP BEFORE ---");
        $display("PC(before) = %0h", pc);
        // write register file memory to a file (simulation-only hierarchical access)
        $writememb("reg_before.mem", u_cpu.rfile.rf);
        // write data memory to a file
        $writememb("data_before.mem", u_dmem.ram);

        // let simulation run enough cycles for fetch->decode->exec->mem->wb
        #440; // total ~500ns runtime as before

        //----------------------------------------------------------------------
        // Dump registers and memory AFTER the run so we can compare
        //----------------------------------------------------------------------
        $display("--- DUMP AFTER ---");
        $display("PC(after) = %0h", pc);
        $display("x1 (rf[1]) = %h", u_cpu.rfile.rf[1]);
        $writememb("reg_after.mem", u_cpu.rfile.rf);
        $writememb("data_after.mem", u_dmem.ram);

        // Simple assertion: expect x1 == 32'hDEADBEEF
        if (u_cpu.rfile.rf[1] === 32'hDEADBEEF) begin
            $display("TEST RESULT: PASS - x1 == DEADBEEF");
        end else begin
            $display("TEST RESULT: FAIL - x1 == %h (expected DEADBEEF)", u_cpu.rfile.rf[1]);
        end

        #10 $finish;
    end

endmodule
