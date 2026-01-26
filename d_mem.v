module d_mem #(
    parameter   M_WIDTH     =   -1,
    parameter   M_STACK     =   -1,
    parameter   DATA_W      =   -1,
    parameter   PC_WIDTH    =   -1,
    parameter   STORE_M     =   -1,
    parameter   ADDR_WIDTH  =   -1,
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