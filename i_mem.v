module i_mem #(
    parameter   M_WIDTH     =   -1,
    parameter   M_STACK     =   -1,
    parameter   DATA_W      =   -1,
    parameter   PC_WIDTH    =   -1,
    parameter   ADDR_WIDTH  =   -1,
    parameter   MEM_INIT_FILE = "mem.bin"
)(
    input wire                  clk,
    input wire                  n_rst,
    input wire  [PC_WIDTH-1:0]  rd_addr,
    output wire [DATA_W-1:0]    d_out
);

    reg     [ADDR_WIDTH-1:0] ram [0:M_STACK-1];

    initial $readmemb(MEM_INIT_FILE,ram);

    // Little-endian: lowest address is least-significant byte
    assign d_out    = {ram[rd_addr+3],ram[rd_addr+2],ram[rd_addr+1],ram[rd_addr]};

endmodule