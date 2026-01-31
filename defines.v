// RISC-V RV32I opcode and funct3 definitions for the simple testbench
`ifndef DEFINES_V
`define DEFINES_V

// ========================================================================
// WHAT IS THIS FILE?
// ========================================================================
// This file contains definitions (macros) for RISC-V instruction opcodes
// and function codes (funct3).
//
// WHY WE USE DEFINES:
// - Instead of typing "7'b0000011" every time (hard to remember!)
// - We define once: `define OP_LOAD 7'b0000011
// - Then use everywhere: if(opcode == `OP_LOAD) ...
//
// BENEFIT: Code becomes READABLE and MAINTAINABLE
// - `OP_LOAD is clear - it's the LOAD opcode!
// - 7'b0000011 is confusing - what does this binary mean?
//
// ANALOGY: Like named constants in programming
//   Bad:  if (x == 42) ...  // What does 42 mean?
//   Good: if (x == MAX_AGE) ... // Clear what MAX_AGE represents
// ========================================================================

// ========================================================================
// OPCODES (7 bits) - First stage of instruction decoding
// ========================================================================
// WHAT IS AN OPCODE?
// - The rightmost 7 bits of a RISC-V instruction
// - Tells the CPU WHAT TYPE of instruction this is
// - Example: instruction = 32'b...0000011
//                                    ^^^^^^^^^ These 7 bits = opcode
//
// HOW IT'S USED:
// In rv32i.v, we decode: assign opcode = inst[6:0];
// Then check: if(opcode == `OP_LOAD) then it's a LOAD instruction
//
// THE 9 INSTRUCTION TYPES:
// ========================================================================
// CRUCIAL: Each instruction type has a UNIQUE 7-bit opcode!
//
// ANALOGY: Like zip codes
//   Zip 10001 = New York
//   Zip 90001 = Los Angeles
//   Zip 60601 = Chicago
// Each city has DIFFERENT zip code, not the same!
//
// SAME HERE:
//   Opcode 0000011 = LOAD (always)
//   Opcode 0100011 = STORE (always) ← DIFFERENT from LOAD!
//   Opcode 1100011 = BRANCH (always) ← DIFFERENT from both!
//   Opcode 0010011 = IMM (always) ← DIFFERENT from all!
//
// HOW DECODING WORKS:
// 1. CPU fetches 32-bit instruction
// 2. Extracts bits[6:0] (the opcode)
// 3. Compares: "Which 7-bit pattern is this?"
//    - Is it 0000011? → Use LOAD logic
//    - Is it 0100011? → Use STORE logic
//    - Is it 1100011? → Use BRANCH logic
//    - Is it 0010011? → Use IMM logic
//    - etc.
// 4. Then uses bits[14:12] (funct3) for sub-variants
//
// RESULT: Every instruction gets routed to the RIGHT logic!
// ========================================================================

`define OP_LOAD   7'b0000011  // LB, LH, LW, LBU, LHU - Load from memory
`define OP_STORE  7'b0100011  // SB, SH, SW - Store to memory
`define OP_BRANCH 7'b1100011  // BEQ, BNE, BLT, etc. - Jump if condition true
`define OP_IMM    7'b0010011  // ADDI, ANDI, ORI, etc. - Register-immediate ops
`define OP_OP     7'b0110011  // ADD, SUB, AND, OR, XOR, etc. - Register-register ops
`define OP_JAL    7'b1101111  // Jump and Link - unconditional jump, save return addr
`define OP_JALR   7'b1100111  // Jump and Link Register - jump to register+offset, save return addr
`define OP_LUI    7'b0110111  // Load Upper Immediate - load 20-bit immediate to upper bits
`define OP_AUIPC  7'b0010111  // Add Upper Immediate to PC - PC+immediate

// ========================================================================
// JUMP INSTRUCTIONS EXPLAINED - When to use which?
// ========================================================================
//
// THREE WAYS TO JUMP:
//
// 1. CONDITIONAL JUMP using OP_BRANCH (BEQ, BNE, BLT, etc.)
//    - Jump ONLY IF a condition is true
//    - Compare two registers, then jump
//    - Example: "If x == y, jump to address"
//    - Does NOT save return address (no way to return!)
//    - For: if-statements, loops
//
//    BEQ  (Branch if Equal)    - jump if rs1 == rs2
//    BNE  (Branch if Not Equal) - jump if rs1 != rs2
//    BLT  (Branch if Less Than) - jump if rs1 < rs2
//    BGE  (Branch if Greater/Equal) - jump if rs1 >= rs2
//    BLTU/BGEU - unsigned versions
//
//    Example Code:
//    if (a == b) {
//        jump_here
//    }
//
// 2. UNCONDITIONAL JUMP using OP_JAL (Jump And Link)
//    - ALWAYS jump (no condition check)
//    - Jump distance encoded in instruction (PC-relative)
//    - Saves return address in register (rd)
//    - For: function calls, procedures
//
//    Example Code:
//    call function()  // JAL x1, function_address
//                     // x1 = PC+4 (where to return)
//                     // Jump to function_address
//
// 3. REGISTER JUMP using OP_JALR (Jump And Link Register)
//    - ALWAYS jump to value in register + offset
//    - Saves return address in register (rd)
//    - For: returning from function, computed jumps
//
//    Example Code:
//    return()  // JALR x0, 0(x1)
//              // Jump to address in x1 (return address)
//              // x1 had PC+4 saved from earlier JAL
//
// DECISION TREE:
//
//   Need to jump?
//   └─ YES: Need to come back later?
//      ├─ NO (if-statement, loop): Use OP_BRANCH (BEQ, BNE, etc.)
//      └─ YES (function call): Use OP_JAL or OP_JALR
//         └─ Know address now?
//            ├─ YES: Use OP_JAL
//            └─ NO (in a register): Use OP_JALR
//
// ========================================================================

`define OP_JAL    7'b1101111  // Jump and Link - unconditional jump, save return addr
`define OP_JALR   7'b1100111  // Jump and Link Register - jump to register+offset, save return addr
`define OP_LUI    7'b0110111  // Load Upper Immediate - load 20-bit immediate to upper bits
`define OP_AUIPC  7'b0010111  // Add Upper Immediate to PC - PC+immediate

// ========================================================================
// FUNCT3 CODES (3 bits) - Second stage of instruction decoding
// ========================================================================
// WHAT IS FUNCT3?
// - When opcode alone is not enough, we look at funct3
// - These are bits [14:12] of the instruction
// - Some opcodes have multiple variants, funct3 distinguishes them
//
// EXAMPLE: LOAD (OP_LOAD = 7'b0000011)
// All these use same opcode, but different funct3:
//   LB  (Load Byte)        -> funct3 = 3'b000
//   LH  (Load Half)        -> funct3 = 3'b001
//   LW  (Load Word)        -> funct3 = 3'b010
//   LBU (Load Byte Unsigned) -> funct3 = 3'b100
//   LHU (Load Half Unsigned) -> funct3 = 3'b101
//
// The difference? How many bytes to load and whether to sign-extend
// ========================================================================

// funct3 codes (3 bits) - BRANCH instructions
`define OP_BEQ  3'b000  // Branch if Equal         - jump if rs1 == rs2
`define OP_BNE  3'b001  // Branch if Not Equal     - jump if rs1 != rs2
`define OP_BLT  3'b100  // Branch if Less Than     - jump if rs1 < rs2 (signed)
`define OP_BGE  3'b101  // Branch if Greater Equal - jump if rs1 >= rs2 (signed)
`define OP_BLTU 3'b110  // Branch if Less Than (U) - jump if rs1 < rs2 (unsigned)
`define OP_BGEU 3'b111  // Branch if Greater Equal (U) - jump if rs1 >= rs2 (unsigned)

// funct3 codes (3 bits) - LOAD instructions
`define OP_LB  3'b000  // Load Byte           - load 8 bits, sign-extend
`define OP_LH  3'b001  // Load Half-word      - load 16 bits, sign-extend
`define OP_LW  3'b010  // Load Word           - load 32 bits
`define OP_LBU 3'b100  // Load Byte Unsigned  - load 8 bits, zero-extend (no sign)
`define OP_LHU 3'b101  // Load Half Unsigned  - load 16 bits, zero-extend (no sign)

`endif
