## 新しいテスト基盤

### メモリモジュールの設定可能化
**対象ファイル**: i_mem.v, d_mem.v

複数のテストシナリオをサポートするために、以下のパラメータを追加。

### Step A 結合テスト
**目的**: Load/Store の往復と BEQ 分岐判定の検証

**テストシーケンス** (mem_cpu1_stepA.bin):
- 0x00: lw x1, 0(x0)        # mem[0] から 0x11223344 を読み込み
- 0x04: sw x1, 4(x0)        # mem[4] に書き込み
- 0x08: lw x2, 4(x0)        # mem[4] を読み戻し
- 0x0C: beq x1, x2, +16     # 一致なら PASS パスへ
- 0x10: addi x3, x0, 0      # FAIL: x3 = 0
- 0x14: sw x3, 8(x0)        # mem[8] に 0 を書き込み
- 0x18: jal x0, +12         # END へジャンプ
- 0x1C: addi x3, x0, 1      # PASS: x3 = 1
- 0x20: sw x3, 8(x0)        # mem[8] に 1 を書き込み
- 0x24: jal x0, 0           # END: 無限ループ

**合格条件**: 200 サイクル後に mem[8] == 32'h1'

**テスト範囲**:
- Load word (LW) の即値オフセット
- Store word (SW) の即値オフセット
- ALU 即値演算 (ADDI)
- 条件分岐 (BEQ)
- 無条件ジャンプ (JAL)
- レジスタファイルの読み書き
- データメモリの読み書き
- パイプライン段レジスタ (_E/_M/_W) の基本動作

### デバッグ用テストベンチ
**ファイル**: tb_cpu1_stepA_debug.v

サイクルごとのトレース表示:
- プログラムカウンタ
- デコードされた命令 (ニーモニック)
- レジスタファイル状態 (非ゼロ値のみ)
- メモリ操作 (読み書きアドレスとデータ)

**用途**: 制御フローとデータパスの追跡に有効 (ハザード/フォワーディング未実装)。

---

## コンパイルと実行

### 標準テスト (Pass/Fail のみ)
- iverilog -g2012 -o sim_stepA.vvp tb_cpu1_stepA.v rv32i.v i_mem.v d_mem.v alu.v
- vvp sim_stepA.vvp

### デバッグテスト (命令トレース)
- iverilog -g2012 -o sim_stepA_debug.vvp tb_cpu1_stepA_debug.v rv32i.v i_mem.v d_mem.v alu.v
- vvp sim_stepA_debug.vvp

### Step B テスト (シグネチャ検証)
- iverilog -g2012 -o sim_stepB.vvp tb_cpu1_stepB.v rv32i.v i_mem.v d_mem.v alu.v
- vvp sim_stepB.vvp

### 波形解析
- gtkwave stepA.vcd

VCD に全信号遷移が記録されるため、GTKWave で可視化が可能。

---

## アーキテクチャ概要

### 5 段パイプライン (基本段レジスタ)

Fetch -> Decode -> Execute -> Memory -> Writeback

**段レジスタ**:
- _E: Execute 段 (opcode_E, rdata_E1, imm_E, pc_E)
- _M: Memory 段 (opcode_M, alu_res_M, rd_M)
- _W: Writeback 段 (opcode_W, rd_data_W, rd_W)

**制限事項**:
- ハザード検出、ストール、フォワーディング未実装
- パイプラインフラッシュ未実装
- 分岐は BEQ のみ実装
- JALR の bit0 クリア未実装
- PC 幅は 8bit (PC_W=8)

### 制御ハザード対策 (現実装)

**課題**: パイプラインで分岐やジャンプがあると誤った命令をフェッチする可能性。

**対応**: Decode 段での早期ジャンプ判定:
- JAL/JALR は opcode で即時判定
- pc_next に jal_target_D を即反映
- ただし明示的なフラッシュ/ストールは無し

---

## Step B 結合テスト

**目的**: PASS フラグとシグネチャ領域の整合性チェック

**プログラム内容**:
- data メモリ (0x00, 0x04) から定数をロード
- 0x80〜0x90 にシグネチャを書き込み
- PASS フラグとして 0x08 に 1 を書き込み
- 最後は無限ループ

**シグネチャ領域**:
- 0x80 = 0xDEADBEEF
- 0x84 = 0xCAFEBABE
- 0x88 = 0x00000000
- 0x8C = 0x00000000
- 0x90 = 0x00000001

**合格条件**:
- PASS フラグ確認 (mem[0x08] == 32'h1')
- 全シグネチャ一致

**注意**: CPU はパイプラインで動作するが、ハザード検出/フォワーディング無し。
そのため StepB プログラムには NOP を挿入して RAW ハザードを回避している。

---

## 検証結果記録の方針

### 1. コンパイル成功の証拠
- iverilog -g2012 -o sim_stepA.vvp tb_cpu1_stepA.v rv32i.v ...
- sim_stepA.vvp の生成を確認

### 2. 実行結果
- vvp sim_stepA.vvp の PASS 出力
- Warning はメモリサイズとプログラムサイズの差によるもの

### 3. 命令トレース抜粋
- LW → SW → BEQ → ADDI → SW の流れを抜粋
- PASS の書き込みタイミングを明示

### 4. 波形
- gtkwave で stepA.vcd を確認
- PC、instruction、dmem_we、u_dmem.ram[8] などを表示

---

**ドキュメント版**: 1.1
**最終更新**: 2026年2月1日
**状態**: Step A / Step B 結合テストともに PASS