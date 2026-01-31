module d_mem #(
    parameter   M_WIDTH     =   -1,
    parameter   M_STACK     =   -1,
    parameter   DATA_W      =   -1,
    parameter   PC_WIDTH    =   -1,
    parameter   STORE_M     =   -1,
    parameter   ADDR_WIDTH  =   -1,
    // ====================================================================
    // WHY WE USE A PARAMETER INSTEAD OF HARDCODING THE FILENAME (Line 8)
    // ====================================================================
    // OLD WAY (inflexible - hardcoded):  
    //   initial $readmemb("data_mem.dat", ram);
    //
    // NEW WAY (flexible - parameterized):
    //   parameter DATA_INIT_FILE = "data_mem.dat"
    //   initial $readmemb(DATA_INIT_FILE, ram);
    //
    // BENEFITS OF USING A PARAMETER:
    //
    // 1. REUSABILITY - Use SAME module with DIFFERENT files!
    //    Example: 
    //    d_mem #(.DATA_INIT_FILE("test1.dat")) mem1(...);  // Load test1.dat
    //    d_mem #(.DATA_INIT_FILE("test2.dat")) mem2(...);  // Load test2.dat
    //    Without parameter, you'd have to copy the entire module code!
    //
    // 2. TESTING - Run different tests with different memory contents
    //    - Unit test: use "test_mem.dat"
    //    - Integration test: use "data_mem.dat"
    //    - Simulation: use "sim_mem.dat"
    //    All without changing the module code!
    //
    // 3. MAINTAINABILITY - Change default file in ONE place
    //    If all your code uses this parameter, updating the filename
    //    only requires changing it here, not in every instantiation.
    //
    // 4. CONFIGURABILITY - Override when needed
    //    Default is "data_mem.dat", but each instantiation can override it
    //    Makes the module more like a reusable component.
    //
    // ANALOGY: Like a function parameter
    //   Hardcoded:  print("Hello");        <- Always prints "Hello"
    //   Parameter:  print(message);        <- Can print different text
    //                print("Hello");       <- Default: "Hello"
    //                print("Goodbye");     <- Can override: "Goodbye"
    // ====================================================================
    parameter   DATA_INIT_FILE = "data_mem.dat"
)(
    input wire                  clk,
    input wire                  n_rst,
    input wire                  wr_en,
    input wire  [PC_WIDTH-1:0]  rd_addr,
    input wire  [PC_WIDTH-1:0]  wr_addr,
    input wire  [STORE_M-1:0]   mode,
    input wire  [DATA_W-1:0]    d_in,
    output wire [DATA_W-1:0]    d_out
);
    localparam ST_B = 2'b00;
    localparam ST_H = 2'b01;
    localparam ST_W = 2'b10;

    reg [ADDR_WIDTH-1:0] ram [0:M_STACK-1];
    initial $readmemb(DATA_INIT_FILE,ram);

    // Little-endian: lowest address is least-significant byte(Hamgiin tom dugaartai addressaasaa oruulj ehelne gesen ug)
    assign d_out    = {ram[rd_addr+3],ram[rd_addr+2],ram[rd_addr+1],ram[rd_addr]};

    always @(posedge clk) begin
        if (wr_en) begin
            if (mode == ST_B) begin
                ram[wr_addr] <= d_in[ADDR_WIDTH-1:0];
            end else if (mode == ST_H) begin
                {ram[wr_addr+1],ram[wr_addr]} <= {d_in[(ADDR_WIDTH*2)-1:ADDR_WIDTH],d_in[ADDR_WIDTH-1:0]};
            end else if (mode == ST_W) begin
                {ram[wr_addr+3],ram[wr_addr+2],ram[wr_addr+1],ram[wr_addr]} <= d_in;
            end else begin
                {ram[wr_addr],ram[wr_addr+1],ram[wr_addr+2],ram[wr_addr+3]} <= 32'hzzzzzzzz;
            end
        end
    end

endmodule