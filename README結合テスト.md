## New Testing Infrastructure

### Configurable Memory Modules
**Files**: `i_mem.v`, `d_mem.v`

Added parameters to support multiple test scenarios:
```verilog
parameter MEM_INIT_FILE = "mem.bin"       // Instruction memory
parameter DATA_INIT_FILE = "data_mem.dat" // Data memory
```

### Step A Integration Test
**Purpose**: Validate load/store round-trip and BEQ branch decision making

**Test Sequence** (`mem_cpu1_stepA.bin`):
```
0x00: lw   x1, 0(x0)        # Read constant 0x11223344 from mem[0]
0x04: sw   x1, 4(x0)        # Write to mem[4]
0x08: lw   x2, 4(x0)        # Read back from mem[4]
0x0C: beq  x1, x2, +16      # Compare: if equal → PASS path
0x10: addi x3, x0, 0        # FAIL: x3 = 0
0x14: sw   x3, 8(x0)        # Write 0 to mem[8]
0x18: jal  x0, +12          # Jump to END
0x1C: addi x3, x0, 1        # PASS: x3 = 1
0x20: sw   x3, 8(x0)        # Write 1 to mem[8]
0x24: jal  x0, 0            # END: infinite loop
```

**Pass Criterion**: `mem[8] == 32'h1` after 200 cycles

**Test Coverage**:
-  Load word (LW) with immediate offset(the number next to (x0) like 4)
-  Store word (SW) with immediate offset
-  ALU immediate operation (ADDI)
-  Conditional branch (BEQ) with register comparison
-  Unconditional jump (JAL) with offset
-  Register file read/write
-  Data memory read/write
-  Pipeline stage registers (_E/_M/_W) for basic stage separation

### Step B Integration Test
**Purpose**: Signature-based integration test (PASS flag + multiple signature words)

**Test Program** (`mem_cpu1_stepB.bin` + `data_cpu1_stepB.dat`):
- Loads constants from data memory (0x00, 0x04)
- Writes signature words to 0x80..0x90
- Writes PASS flag to 0x08
- Loops forever

**Signature Map**:
- 0x80 = 0xDEADBEEF
- 0x84 = 0xCAFEBABE
- 0x88 = 0x00000000
- 0x8C = 0x00000000
- 0x90 = 0x00000001

**Pass Criterion**: PASS flag observed (`mem[0x08] == 32'h1`) and all signatures match

**Note**: The CPU is pipelined without hazard detection/forwarding. The StepB program includes NOP spacing to avoid RAW hazards.

### Debug Testbench
**File**: `tb_cpu1_stepA_debug.v`

Provides cycle-by-cycle instruction trace showing:
- Program counter
- Decoded instruction (mnemonic)
- Register file state (non-zero values)
- Memory operations (read/write address and data)

**Usage**: Useful for tracing control flow and datapath activity (note: no hazard/forwarding logic implemented).

---

## Compilation and Execution

### Standard Test (Pass/Fail Only)
```bash
iverilog -g2012 -o sim_stepA.vvp \
  tb_cpu1_stepA.v rv32i.v i_mem.v d_mem.v alu.v

vvp sim_stepA.vvp
```

### Debug Test (Instruction Trace)
```bash
iverilog -g2012 -o sim_stepA_debug.vvp \
  tb_cpu1_stepA_debug.v rv32i.v i_mem.v d_mem.v alu.v

vvp sim_stepA_debug.vvp
```

### Step B Test (Signature Check)
```bash
iverilog -g2012 -o sim_stepB.vvp \
  tb_cpu1_stepB.v rv32i.v i_mem.v d_mem.v alu.v

vvp sim_stepB.vvp
```

### Waveform Analysis
```bash
gtkwave stepA.vcd
```
The VCD file contains all signal transitions for visual debugging in GTKWave.

---

## Architecture Overview

### 5-Stage Pipeline (Basic Stage Registers)

```
┌────────┐   ┌────────┐   ┌─────────┐   ┌────────┐   ┌───────────┐
│ Fetch  │──▶│ Decode │──▶│ Execute │──▶│ Memory │──▶│ Writeback │
└────────┘   └────────┘   └─────────┘   └────────┘   └───────────┘
    │            │              │             │              │
    pc         inst          alu_res       d_in/wr        wd/r_we
  _reg         rdata1/2       imm_E       _addr/data     rd_W
               opcode_E      funct3_E     opcode_M      opcode_W
```

**Stage Registers**:
- `_E` suffix: Execute stage latches (opcode_E, rdata_E1, imm_E, pc_E)
- `_M` suffix: Memory stage latches (opcode_M, alu_res_M, rd_M)
- `_W` suffix: Writeback stage latches (opcode_W, rd_data_W, rd_W)

**Limitations**:
- No hazard detection, stalls, or forwarding/bypass logic
- No pipeline flush logic
- Branch handling implemented only for BEQ
- JALR target does not clear bit0 (spec requires (rs1+imm) & ~1)
- PC is 8-bit (`PC_W=8`), so targets are truncated to 8 bits

### Control Hazard Handling (Current Implementation)

**Problem**: Control flow changes can cause wrong-path fetches in a pipelined design.

**Solution**: Early jump detection in Decode stage:
- JAL/JALR decoded using `opcode` (combinational)
- PC updated immediately: `pc_next = jal_target_D`
- Reduces jump penalty, but no explicit flush/stall logic is implemented

**Note**: There is no flush, stall, or delay-slot mechanism in the RTL; it simply selects `pc_next`.

---

## Results Documentation Plan

### For Professor Review

#### 1. Compilation Success Evidence
**What to include**:
```bash
# Show the before (error) and after (clean compile)
$ iverilog -g2012 -o sim_stepA.vvp tb_cpu1_stepA.v rv32i.v ...
[No errors]
$ ls -l sim_stepA.vvp
-rw-r--r-- 1 user group 45678 Dec 23 14:23 sim_stepA.vvp
```

#### 2. Test Execution Results
**What to include**:
```
$ vvp sim_stepA.vvp
WARNING: i_mem.v:17: $readmemb(mem_cpu1_stepA.bin): Not enough words...
WARNING: d_mem.v:26: $readmemb(data_cpu1_stepA.dat): Not enough words...
VCD info: dumpfile stepA.vcd opened for output.
TEST RESULT: PASS (mem[8]=1)
tb_cpu1_stepA.v:84: $finish called at 1995000 (1ps)
```
**Note**: Warnings are expected (256-byte memory, 40-byte program)

#### 3. Instruction Trace Excerpt
**What to include**: Key cycles from debug output showing:
```
Cycle 63: PC=0x00  Instruction=0x00002083
  → LW x1, 0(x0)
  Registers:
  MEM READ:  addr=0x00, data=0x11223344

Cycle 64: PC=0x04  Instruction=0x00102223
  → SW x1, 4(x0)
  Registers:
    x1  = 0x11223344

Cycle 66: PC=0x0c  Instruction=0x00208863
  → BEQ x1, x2, 16
  MEM WRITE: addr=0x04, data=0x11223344

Cycle 70: PC=0x1c  Instruction=0x00100193
  → ADDI x3, x0, 1
  Registers:
    x1  = 0x11223344
    x2  = 0x11223344

Cycle 71: PC=0x28  Instruction=0xxxxxxxxx
  MEM WRITE: addr=0x08, data=0x00000001
  ← This is the PASS indicator being written!

*** REACHED END (infinite loop at 0x24) ***
✓ TEST RESULT: PASS (mem[8]=1)
```

#### 4. Waveform
![alt text](image.png)
- `clk` signal
- `pc_reg` showing address progression: 0x00→0x04→0x08→0x0C→0x10→0x1C→0x24
- `instruction` bus decoding
- `dmem_we` pulse at cycle when store happens
- `u_dmem.ram[8]` changing from 0x00 to 0x01

**How to capture**:
1. Open `gtkwave stepA.vcd`
2. Add signals: `tb_cpu1_stepA.clk`, `tb_cpu1_stepA.u_cpu.pc_reg`, etc.
3. Zoom to cycles 60-75 (the actual program execution)
4. Screenshot → include in report/presentation

## Verification Metrics

### Functional Coverage
- [x] Load immediate offset addressing (I-type)
- [x] Store immediate offset addressing (S-type)
- [x] Branch comparison and offset (B-type)
- [x] Jump with offset (J-type)
- [x] ALU immediate operations
- [x] Register-to-register data flow
- [x] Memory-to-register data flow
- [x] Register-to-memory data flow

### Timing Analysis
- **Total simulation time**: 1995 ns (199.5 cycles @ 10ns period)
- **Active program cycles**: ~10 (cycles 63-72)
- **Infinite loop detection**: Cycle 131 (PC stuck at 0x24)
- **Pipeline depth**: 5 stages (no guarantee of 1 IPC; hazards are not handled)

### Bug Fixes Validated
1. Immediate decoding: LW offset=0 works, SW offset=4 works, BEQ offset=16 works
2. PC control: BEQ conditional jump executed, JAL unconditional jump executed
3. Register writeback: ADDI result stored in x3, LW result stored in x1/x2
4. Store operations: SW successfully writes to data memory (verified by readback)


## Appendix: Quick Command Reference

### Compile Everything
```bash
iverilog -g2012 -o sim_stepA.vvp \
    tb_cpu1_stepA.v rv32i.v i_mem.v d_mem.v reg.v alu.v defines.v
```

### Run Test
```bash
vvp sim_stepA.vvp
```

### Debug with Trace
```bash
iverilog -g2012 -o sim_stepA_debug.vvp \
    tb_cpu1_stepA_debug.v rv32i.v i_mem.v d_mem.v reg.v alu.v defines.v
vvp sim_stepA_debug.vvp | grep -E "Cycle (6[3-9]|7[0-5])|TEST RESULT"
```

### View Waveforms
```bash
gtkwave stepA.vcd &
```

### Check CPU State at Specific Cycle (for debugging)
```bash
vvp sim_stepA_debug.vvp | sed -n '/Cycle 66/,/Cycle 67/p'
```

---

**Document Version**: 1.1  
**Last Updated**: February 1, 2026    
**Status**: Step A and Step B integration tests passing