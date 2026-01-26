// RISC-V RV32I opcode and funct3 definitions for the simple testbench
`ifndef DEFINES_V
`define DEFINES_V

// Opcodes (7 bits)
`define OP_LOAD   7'b0000011
`define OP_STORE  7'b0100011
`define OP_BRANCH 7'b1100011
`define OP_IMM    7'b0010011
`define OP_OP     7'b0110011
`define OP_JAL    7'b1101111
`define OP_JALR   7'b1100111
`define OP_LUI    7'b0110111
`define OP_AUIPC  7'b0010111

// funct3 codes (3 bits)
// Branches
`define OP_BEQ  3'b000
`define OP_BNE  3'b001
`define OP_BLT  3'b100
`define OP_BGE  3'b101
`define OP_BLTU 3'b110
`define OP_BGEU 3'b111

// Loads
`define OP_LB  3'b000
`define OP_LH  3'b001
`define OP_LW  3'b010
`define OP_LBU 3'b100
`define OP_LHU 3'b101

`endif
