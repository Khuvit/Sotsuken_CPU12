`include "defines.v"
`include "reg.v" // reg.v zuer oruulahaa marttsan baidag bnshd

module rv32i #(
    //  --------------------------------------------------------------------
    //  parameter declare
    //  --------------------------------------------------------------------
    parameter   MEMORY_S    =   2**8,
    parameter   OPCODE_W    =   7,
    parameter   SHAMT_W     =   5,
    parameter   OP          =   3,
    parameter   PC_W        =   8,
    parameter   REG_W       =   5,
    parameter   DATA_W      =   32,
    parameter   REG_S       =   32,
    parameter   FUNCT3      =   3,
    parameter   FUNCT7      =   7,
    parameter   IMM         =   32,
    parameter   BYTE        =   8,
    parameter   HALF        =   2*BYTE,
    parameter   WORD        =   4*BYTE,
    parameter   STORE_M     =   2
)(
    // input wire
    input wire                  clk,
    input wire                  n_rst,

    // input from instruction mem
    input wire  [DATA_W-1:0]    instruction,
    // output to instruction mem
    output wire [PC_W-1:0]      pc,

    // input from data mem
    input wire  [DATA_W-1:0]    d_in,

    // output to data mem
    output wire                 wr_en,
    output wire [STORE_M-1:0]   mode,
    output wire [PC_W-1:0]      wr_addr,
    output wire [PC_W-1:0]      rd_addr,
    output wire [DATA_W-1:0]    d_out
);

    reg [PC_W - 1:0]        pc_reg;
    reg [DATA_W - 1:0]      inst;
    wire                    r_we;
    wire [PC_W-1:0]         pc_next;

    assign pc    = pc_reg;

    //  --------------------------------------------------------------------
    //  Fetch STAGE
    //  --------------------------------------------------------------------

    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            pc_reg <= 0;
        end else begin
            pc_reg <= pc_next;
        end
    end

    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            inst <= 0;
        end else begin
            inst <= instruction;
        end
    end


    //  --------------------------------------------------------------------
    //  Decode STAGE
    //  --------------------------------------------------------------------

    wire    [REG_W-1:0]     rs1,rs2,rd;
    wire    [DATA_W-1:0]    rdata1,rdata2;
    wire                    aluop;
    wire    [OPCODE_W-1:0]  opcode;
    wire    [FUNCT3-1:0]    funct3;
    wire    [FUNCT7-1:0]    funct7;
    wire    [DATA_W-1:0]    imm_i, imm_s, imm_b, imm_j, imm_u;
    wire    [DATA_W-1:0]    imm_sel;

    reg     [REG_W-1:0]     rd_E;
    reg     [DATA_W-1:0]    rdata_E1,rdata_E2;
    reg                     aluop_E;
    reg     [OP-1:0]        funct3_E;
    reg     [IMM-1:0]       imm_E;
    reg     [OPCODE_W-1:0]  opcode_E;
    reg     [PC_W-1:0]      pc_E;

    assign funct7   = inst[31:25];
    assign rs2      = inst[24:20];
    assign rs1      = inst[19:15];
    assign funct3   = inst[14:12];
    assign rd       = inst[11:7];
    assign opcode   = inst[6:0];
    assign aluop    = inst[30];

    // Immediate decode (sign-extended to DATA_W)
    assign imm_i = {{20{inst[31]}}, inst[31:20]};
    assign imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    assign imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    assign imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
    assign imm_u = {inst[31:12], 12'b0};

    assign imm_sel = (opcode == `OP_LOAD   || opcode == `OP_IMM   || opcode == `OP_JALR) ? imm_i :
                     (opcode == `OP_STORE)   ? imm_s :
                     (opcode == `OP_BRANCH)  ? imm_b :
                     (opcode == `OP_JAL)     ? imm_j :
                     (opcode == `OP_LUI || opcode == `OP_AUIPC) ? imm_u :
                     imm_i;
    
    // Early PC control (Decode stage) - detect jumps immediately
    wire                    is_jal_D;
    wire                    is_jalr_D;
    wire    [PC_W-1:0]      jal_target_D;
    wire    [PC_W-1:0]      jalr_target_D;
    wire    [DATA_W-1:0]    jal_sum_D;
    wire    [DATA_W-1:0]    jalr_sum_D;
    
    assign is_jal_D       = (opcode == `OP_JAL);
    assign is_jalr_D      = (opcode == `OP_JALR);
    assign jal_sum_D      = pc_reg + imm_sel;
    assign jalr_sum_D     = rdata1 + imm_sel;
    assign jal_target_D   = jal_sum_D[PC_W-1:0];
    assign jalr_target_D  = jalr_sum_D[PC_W-1:0];
       
    rfile #(
        .REG_W(REG_W),
        .DATA_W(DATA_W),
        .REG_S(REG_S)
    )rfile(
        .clk(clk),
        .a1(rs1),       // read address 1
        .a2(rs2),       // read address 2
        .a3(rd_W),      // write address
        .rd1(rdata1),   // read data 1
        .rd2(rdata2),   // read data 2
        .wd(wd),        // write data
        .we(r_we)       // write enable
    );

    always @(posedge clk) begin
        rdata_E1    <= rdata1;
        rdata_E2    <= rdata2;
        rd_E        <= rd;
        funct3_E    <= funct3;
        aluop_E     <= aluop;
        opcode_E    <= opcode;
        imm_E       <= imm_sel;
        pc_E        <= pc_reg;
    end

    //  --------------------------------------------------------------------
    //  Execute STAGE
    //  --------------------------------------------------------------------

    reg     [DATA_W-1:0]    alu_res_M;
    reg     [REG_W-1:0]     rd_M;
    reg     [FUNCT3-1:0]    funct3_M;
    reg     [DATA_W-1:0]    rdata_M1,rdata_M2;
    reg     [OPCODE_W-1:0]  opcode_M;
    reg     [PC_W-1:0]      pc_M;
    wire    [DATA_W-1:0]    alu_res;
    wire    [DATA_W-1:0]    in_a, in_b;
    wire    [FUNCT3-1:0]    s;
    wire                    branch_taken_E;
    wire    [PC_W-1:0]      pc_plus4;
    wire    [PC_W-1:0]      branch_target;
    wire    [PC_W-1:0]      jal_target;
    wire    [PC_W-1:0]      jalr_target;
    wire                    use_imm_E;
    reg     [PC_W-1:0]      pc_next_r;
    wire    [DATA_W-1:0]    branch_sum;
    wire    [DATA_W-1:0]    jal_sum;
    wire    [DATA_W-1:0]    jalr_sum;

    assign s        = (opcode_E == `OP_OP || opcode_E == `OP_IMM) ? funct3_E : 0;
    assign use_imm_E= (opcode_E == `OP_LOAD)  || (opcode_E == `OP_STORE) ||
                      (opcode_E == `OP_IMM)   || (opcode_E == `OP_JAL)   ||
                      (opcode_E == `OP_JALR)  || (opcode_E == `OP_LUI)   ||
                      (opcode_E == `OP_AUIPC);
    assign in_a     = (opcode_E == `OP_AUIPC) ? pc_E : (opcode_E == `OP_LUI ? {DATA_W{1'b0}} : rdata_E1);
    assign in_b     = use_imm_E ? imm_E : rdata_E2;

    assign branch_taken_E = (opcode_E == `OP_BRANCH) && (funct3_E == `OP_BEQ) && (rdata_E1 == rdata_E2);
    assign pc_plus4       = pc_reg + 8'd4;
    assign branch_sum     = pc_E + imm_E;
    assign branch_target  = branch_sum[7:0];

    // PC update: prioritize Decode-stage jumps (JAL/JALR) over Execute-stage branches
    always @(*) begin
        pc_next_r = pc_plus4;
        if (branch_taken_E)  pc_next_r = branch_target;
        if (is_jal_D)        pc_next_r = jal_target_D;
        if (is_jalr_D)       pc_next_r = jalr_target_D;
    end

    assign pc_next = pc_next_r;

    alu #(
        .DATA_W(DATA_W),
        .SHAMT_W(SHAMT_W),
        .OP(OP)
    )alu(
        .a(in_a),
        .b(in_b),
        .s(s), // need 0
        .ext(aluop_E),
        .y(alu_res)
    );

    always @(posedge clk)begin
        alu_res_M   <= alu_res;
        rd_M        <= rd_E;
        funct3_M    <= funct3_E;
        opcode_M    <= opcode_E;
        rdata_M1    <= rdata_E1;
        rdata_M2    <= rdata_E2;
        pc_M        <= pc_E;
    end

    //  --------------------------------------------------------------------
    //  Memory STAGE
    //  --------------------------------------------------------------------

    wire    [DATA_W-1:0]    rd_data;

    reg     [OPCODE_W-1:0]  opcode_W;
    reg     [DATA_W-1:0]    rd_data_W;
    reg     [DATA_W-1:0]    alu_res_W;
    reg     [REG_W-1:0]     rd_W;
    reg     [PC_W-1:0]      pc_W;

    assign rd_addr  = alu_res_M;
    assign rd_data  = rd_data_sel(funct3_M,d_in);

    function [DATA_W-1:0] rd_data_sel(
        input [FUNCT3-1:0] funct,
        input [DATA_W-1:0] data
    );
        case(funct)
            3'b000 : rd_data_sel = (data[7]) ? {24'hFFFFFF,data[7:0]}:{24'h0,data[7:0]};
            3'b001 : rd_data_sel = (data[15]) ? {16'hFFFF,data[15:0]}:{16'h0,data[15:0]};
            3'b010 : rd_data_sel = data;
            3'b100 : rd_data_sel = {24'h0,data[7:0]};
            3'b101 : rd_data_sel = {16'h0,data[15:0]};
            default: rd_data_sel = 32'h0;
        endcase
    endfunction


    always @(posedge clk) begin
        opcode_W    <= opcode_M;
        rd_data_W   <= rd_data;
        rd_W        <= rd_M;
        alu_res_W   <= alu_res_M;
        pc_W        <= pc_M;
    end

    //  --------------------------------------------------------------------
    //  Write Back STAGE
    //  --------------------------------------------------------------------

    wire [DATA_W-1:0]   wd;
    wire [DATA_W-1:0]   jal_link;

    assign jal_link  = pc_W + 32'd4;
    assign wd        = (opcode_W == `OP_LOAD)                         ? rd_data_W :
                       (opcode_W == `OP_OP   || opcode_W == `OP_IMM ||
                        opcode_W == `OP_AUIPC || opcode_W == `OP_LUI) ? alu_res_W :
                       (opcode_W == `OP_JAL  || opcode_W == `OP_JALR) ? jal_link :
                       rd_data_W;

    assign r_we     = (opcode_W == `OP_LOAD)  || (opcode_W == `OP_OP)   ||
                      (opcode_W == `OP_IMM)   || (opcode_W == `OP_JAL)  ||
                      (opcode_W == `OP_JALR)  || (opcode_W == `OP_LUI)  ||
                      (opcode_W == `OP_AUIPC);
    
    // Output assignments
    assign wr_en    = (opcode_M == `OP_STORE);
    assign mode     = funct3_M[1:0];
    assign wr_addr  = alu_res_M;
    assign d_out    = rdata_M2;
endmodule