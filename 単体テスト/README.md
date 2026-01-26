RV32I Educational CPU - Minimal Simulation
=========================================

What this is
------------
This repository is a small educational RV32I (RISC‑V 32-bit) CPU example implemented in Verilog. It contains a compact single-file core (`rv32i.v`) plus simple memory models, a register file, an ALU, and a testbench that runs a tiny program (loads a 32-bit word into register x1).

Files of interest
-----------------
- `rv32i.v` - CPU core (fetch/decode/execute/memory/write-back pipeline implemented in one module).
- `reg.v` - register file (`rfile`) module used by the core.
- `alu.v` - simple ALU used by the core.
- `i_mem.v` - instruction memory (byte array assembled into 32-bit little-endian words).
- `d_mem.v` - data memory (byte array assembled little-endian, supports byte/half/word stores).
- `defines.v` - opcode/funct3 definitions used by the CPU.
- `tb_rv32i.v` - testbench that instantiates the CPU + memories, drives clock/reset, writes before/after memory dumps and runs a small test with an assertion.
- `mem.bin` - instruction memory initialization (for the small test program).
- `data_mem.dat` - data memory initialization (contains the word 0xDEADBEEF used by the example).

What the test does
------------------
The testbench runs a short simulation where the CPU fetches an `lw` instruction that loads the 32-bit word at memory address 0 into register x1. The test automatically checks that x1 equals 0xDEADBEEF and prints PASS or FAIL. The test also writes these files during simulation:

- `reg_before.mem`, `reg_after.mem` - register file before/after the test
- `data_before.mem`, `data_after.mem` - data memory before/after the test
- `sim.vcd` - waveform file for inspection in GTKWave

Prerequisites
-------------
- Icarus Verilog (iverilog, vvp) installed. On Windows MSYS2/MinGW64 you can install via pacman. GTKWave is recommended for waveform viewing.

Quick build & run (MSYS2 / MinGW64 preferred)
---------------------------------------------
Open an MSYS2 MinGW64 shell or any shell where `iverilog` and `vvp` are available and run:

```bash
cd /e/Sotsuken
iverilog -o sim.vvp tb_rv32i.v rv32i.v i_mem.v d_mem.v reg.v alu.v defines.v
vvp sim.vvp
```

Quick build & run (PowerShell)
------------------------------
If `iverilog` is in your PATH, from PowerShell:

```powershell
Set-Location E:\Sotsuken
iverilog -o sim.vvp tb_rv32i.v rv32i.v i_mem.v d_mem.v reg.v alu.v defines.v
vvp sim.vvp
```

View waveform
-------------
Open the generated `sim.vcd` with GTKWave:

```bash
gtkwave sim.vcd
```

Notes & caveats
---------------
- Endianness: `i_mem.v` and `d_mem.v` assemble words in little-endian order (lowest address = least-significant byte), which matches RISC‑V convention.
- Memory init warnings: the memories are parameterized with `M_STACK` (number of bytes). If you see warnings like `$readmemb(...) Not enough words`, either pad `mem.bin`/`data_mem.dat` with zeros or reduce `M_STACK` in the testbench instantiation (`tb_rv32i.v`). The testbench currently sets `.M_STACK(16)` for the small example.
- Internal access: the testbench reads/writes internal arrays via hierarchical names (e.g., `u_cpu.rfile.rf` and `u_dmem.ram`). Those are simulation conveniences; real hardware can't access them this way.