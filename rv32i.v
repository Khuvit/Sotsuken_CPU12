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

    // ------------------------------------------------------------------
    // Register declarations for pipeline state
    // ------------------------------------------------------------------
    reg [PC_W - 1:0]        pc_reg;    // Current program counter value (address of current instruction)
    reg [DATA_W - 1:0]      inst;      // Current instruction being executed
    wire                    r_we;      // Register write enable signal (1 = write to register file)
    wire [PC_W-1:0]         pc_next;   // Next PC value to be loaded on next clock cycle
                                       // WHY: We need pc_next to handle different control flows:
                                       //      - Normal: PC+4 (next sequential instruction)
                                       //      - Branch: PC+offset (when branch condition is true)
                                       //      - Jump: target address (JAL/JALR instructions)

    assign pc    = pc_reg;

    //  --------------------------------------------------------------------
    //  Fetch STAGE
    //  --------------------------------------------------------------------
    // WHY THIS CHANGED: Previously was "pc_reg <= pc_reg + 8'd4" (always +4)
    // PROBLEM: We couldn't handle branches or jumps properly!
    // NEW APPROACH: Use pc_next which is calculated later based on:
    //   - If JAL/JALR detected in Decode: jump immediately
    //   - If branch taken in Execute: branch to target
    //   - Otherwise: PC+4 (normal sequential execution)
    // This allows proper control flow for all instruction types

    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            pc_reg <= 0;
        end else begin
            pc_reg <= pc_next;  // Load the calculated next PC value
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

    // 115-167 are updated files diff from cpu10
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
    
    // ======================================================================
    // EARLY PC CONTROL - Detect jumps in Decode stage (lines 101-128)
    // ======================================================================
    // WHY WE ADDED THIS:
    // Problem: Originally we calculated jumps in Execute stage, wasting 1 cycle
    // Solution: Detect JAL/JALR here in Decode and calculate target immediately
    // 
    // BENEFIT: Reduces jump penalty from 2 cycles to 1 cycle
    //          JAL and JALR can now execute faster!
    //
    // HOW IT WORKS:
    // 1. Check if current instruction is JAL or JALR (is_jal_D, is_jalr_D)
    // 2. Calculate jump target address right away:
    //    - JAL:  PC + immediate offset
    //    - JALR: register value + immediate offset
    // 3. These targets feed into pc_next logic (in Execute stage)
    // ======================================================================
    
    wire                    is_jal_D;       // 1 if current instruction is JAL
    wire                    is_jalr_D;      // 1 if current instruction is JALR
    wire    [PC_W-1:0]      jal_target_D;   // Jump target for JAL (8-bit address)
    wire    [PC_W-1:0]      jalr_target_D;  // Jump target for JALR (8-bit address)
    wire    [DATA_W-1:0]    jal_sum_D;      // Full 32-bit calculation: PC + imm
    wire    [DATA_W-1:0]    jalr_sum_D;     // Full 32-bit calculation: rs1 + imm
    
    // Detect if this is a jump instruction
    assign is_jal_D       = (opcode == `OP_JAL);
    assign is_jalr_D      = (opcode == `OP_JALR);
    
    // Calculate jump target addresses
    // JAL:  jump to PC + offset (PC-relative jump)
    // JALR: jump to register + offset (absolute jump to computed address)
    assign jal_sum_D      = pc_reg + imm_sel;
    assign jalr_sum_D     = rdata1 + imm_sel;
    
    // Extract lower 8 bits for our 8-bit PC (256-byte instruction memory)
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

    // ======================================================================
    // BRANCH & PC CONTROL LOGIC (lines 169-178)
    // ======================================================================
    // WHY WE ADDED THIS:
    // Need to decide what instruction to execute next based on current instruction
    //
    // 3 POSSIBILITIES:
    // 1. Normal: Go to next instruction (PC+4)
    // 2. Branch: If condition is true, jump to branch target
    // 3. Jump: JAL/JALR always jump to target address
    // ======================================================================
    
    // Check if branch should be taken (currently only BEQ - Branch if Equal)
    // branch_taken_E = 1 when: it's a BRANCH instruction AND BEQ AND rs1==rs2
    assign branch_taken_E = (opcode_E == `OP_BRANCH) && (funct3_E == `OP_BEQ) && (rdata_E1 == rdata_E2);
    
    // Calculate potential PC values
    assign pc_plus4       = pc_reg + 8'd4;      // Next sequential instruction
    assign branch_sum     = pc_E + imm_E;       // Branch target (PC + offset)
    assign branch_target  = branch_sum[7:0];    // Extract 8-bit address

    // ======================================================================
    // PC PRIORITY LOGIC - Decide next PC value
    // ======================================================================
    // PRIORITY ORDER (highest to lowest):
    // 1. JALR (highest) - unconditional jump to register+immediate
    // 2. JAL           - unconditional jump to PC+immediate  
    // 3. Branch        - conditional jump if condition true
    // 4. PC+4 (lowest) - default: next sequential instruction
    //
    // WHY THIS ORDER: 
    // - Jumps (JAL/JALR) detected in Decode stage have highest priority
    //   because they're unconditional and need to execute immediately
    // - Branches checked in Execute stage (need to compare register values)
    // - If none apply, just increment PC by 4
    // ======================================================================
    always @(*) begin
        pc_next_r = pc_plus4;                   // Default: go to next instruction
        if (branch_taken_E)  pc_next_r = branch_target;  // Override if branch taken
        if (is_jal_D)        pc_next_r = jal_target_D;   // Override if JAL detected
        if (is_jalr_D)       pc_next_r = jalr_target_D;  // Override if JALR detected (highest priority)
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

    // ======================================================================
    // JAL/JALR LINK ADDRESS (Return Address) - line 235
    // ======================================================================
    // WHY WE NEED THIS:
    // JAL and JALR instructions need to save a "return address" so the 
    // program can come back after the jump (like function calls)
    //
    // EXPLANATION:
    // - When JAL/JALR executes, CPU jumps to a new address
    // - Before jumping, we must save "where to return" in a register (rd)
    // - Return address = PC + 4 (the instruction right after JAL/JALR)
    // - This is stored in the destination register so we can return later
    //
    // EXAMPLE: 
    //   Address 0x10: JAL x1, function  -> x1 = 0x14, jump to function
    //   Address 0x14: next instruction  -> when function returns, come here
    // ======================================================================
    assign jal_link  = pc_W + 32'd4;  // Calculate return address (PC of JAL instruction + 4)
    
    // ======================================================================
    // WRITE DATA SELECTION (wd) - lines 267-272
    // ======================================================================
    // WHY WE NEED THIS:
    // Different instructions write different types of data to registers
    // This multiplexer selects what data to write based on instruction type
    //
    // EXPLANATION OF EACH CASE:
    // - LOAD:         Write data from memory (rd_data_W)
    // - OP/IMM:       Write ALU calculation result (alu_res_W)
    //                 Examples: ADD, SUB, AND, OR, XOR, shifts, etc.
    // - LUI/AUIPC:    Write ALU result (immediate value or PC+immediate)
    // - JAL/JALR:     Write return address (jal_link = PC+4)
    //                 So the program knows where to return after jump
    // - Default:      rd_data_W (shouldn't happen, but safe default)
    // ======================================================================
    assign wd        = (opcode_W == `OP_LOAD)                         ? rd_data_W :
                       (opcode_W == `OP_OP   || opcode_W == `OP_IMM ||
                        opcode_W == `OP_AUIPC || opcode_W == `OP_LUI) ? alu_res_W :
                       (opcode_W == `OP_JAL  || opcode_W == `OP_JALR) ? jal_link :
                       rd_data_W;

    // ======================================================================
    // REGISTER WRITE ENABLE (r_we) - lines 274-277
    // ======================================================================
    // WHY WE NEED THIS:
    // Not all instructions write to registers! This signal controls when
    // the register file should actually save data
    //
    // INSTRUCTIONS THAT WRITE TO REGISTERS (r_we = 1):
    // - LOAD:   Load data from memory into register
    // - OP:     Register-register operations (ADD, SUB, etc.)
    // - IMM:    Register-immediate operations (ADDI, ANDI, etc.)
    // - JAL:    Save return address in register
    // - JALR:   Save return address in register
    // - LUI:    Load upper immediate into register
    // - AUIPC:  Add upper immediate to PC, store in register
    //
    // INSTRUCTIONS THAT DON'T WRITE (r_we = 0):
    // - STORE:  Only writes to memory, not registers
    // - BRANCH: Only changes PC, doesn't write registers
    // ======================================================================
    assign r_we     = (opcode_W == `OP_LOAD)  || (opcode_W == `OP_OP)   ||
                      (opcode_W == `OP_IMM)   || (opcode_W == `OP_JAL)  ||
                      (opcode_W == `OP_JALR)  || (opcode_W == `OP_LUI)  ||
                      (opcode_W == `OP_AUIPC);
    
    // ======================================================================
    // DATA MEMORY OUTPUT SIGNALS - lines 279-282
    // ======================================================================
    // WHY WE NEED THESE:
    // These signals control the data memory module for STORE instructions
    //
    // SIGNAL EXPLANATIONS:
    // - wr_en:   Write Enable = 1 only for STORE instructions
    //            Tells memory "yes, write this data to memory now"
    //
    // - mode:    Store Mode (from funct3) tells memory HOW MUCH to write:
    //            00 = byte  (8 bits)  - SB instruction
    //            01 = half  (16 bits) - SH instruction  
    //            10 = word  (32 bits) - SW instruction
    //
    // - wr_addr: Write Address - WHERE in memory to write
    //            Calculated by ALU (base address + offset)
    //
    // - d_out:   Data Out - WHAT data to write to memory
    //            Comes from rs2 register (second source register)
    // ======================================================================
    // Output assignments
    assign wr_en    = (opcode_M == `OP_STORE);
    assign mode     = funct3_M[1:0];
    assign wr_addr  = alu_res_M;
    assign d_out    = rdata_M2;
endmodule