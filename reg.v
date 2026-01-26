module rfile #(
    parameter REG_W = -1,
    parameter REG_S = -1,
    parameter DATA_W = -1
)(
    input wire  clk,
    input wire [REG_W-1:0] a1,a2,a3,
    output wire [DATA_W-1:0] rd1,rd2,
    input wire [DATA_W-1:0] wd,
    input wire              we
);
    reg [DATA_W-1:0] rf [0:REG_S-1];

    //debug processing just easier debugging 
    wire [DATA_W-1:0] x1;
    assign x1 = rf[1];
    //------

    // x0は常に０，それ以外はレジスタ値11‐17に更新RISC-V的に正しいらしい。
    assign rd1 = (a1 == 0) ? {DATA_W{1'b0}} : rf[a1];
    assign rd2 = (a2 == 0) ? {DATA_W{1'b0}} : rf[a2];

    always @(posedge clk) begin
        // x0 に書き込まん
        if (we && (a3 != 0)) begin
            rf[a3] <= wd;
        end
    end
endmodule