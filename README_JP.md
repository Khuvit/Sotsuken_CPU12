## 新しいテスト基盤

### メモリモジュールの設定可能化
**対象ファイル**: `i_mem.v`, `d_mem.v`

複数のテストシナリオをサポートするために、以下のパラメータを追加:
```verilog
parameter MEM_INIT_FILE = "mem.bin"       // 命令メモリ
parameter DATA_INIT_FILE = "data_mem.dat" // データメモリ
```

### Step A 結合テスト

**目的**: Load/Store の往復と BEQ 分岐判定の検証

**テストシーケンス** (`mem_cpu1_stepA.bin`):
```
0x00: lw   x1, 0(x0)        # mem[0] から 0x11223344 を読み込み
0x04: sw   x1, 4(x0)        # mem[4] に書き込み
0x08: lw   x2, 4(x0)        # mem[4] を読み戻し
0x0C: beq  x1, x2, +16      # 一致なら PASS パスへ
0x10: addi x3, x0, 0        # FAIL: x3 = 0
0x14: sw   x3, 8(x0)        # mem[8] に 0 を書き込み
0x18: jal  x0, +12          # END へジャンプ
0x1C: addi x3, x0, 1        # PASS: x3 = 1
0x20: sw   x3, 8(x0)        # mem[8] に 1 を書き込み
0x24: jal  x0, 0            # END: 無限ループ
```

**合格条件**: 200 サイクル後に `mem[8] == 32'h1`

**テスト範囲**:
- Load word (LW) の即値オフセット ((x0) の横の数値など)
- Store word (SW) の即値オフセット
- ALU 即値演算 (ADDI)
- 条件分岐 (BEQ) レジスタ比較付き
- 無条件ジャンプ (JAL) オフセット付き
- レジスタファイルの読み書き
- データメモリの読み書き
- パイプライン段レジスタ (_E/_M/_W) の基本段分離

### Step B 結合テスト

**目的**: PASS フラグとシグネチャ領域の整合性チェック

**テストプログラム** (`mem_cpu1_stepB.bin` + `data_cpu1_stepB.dat`):
- データメモリ (0x00, 0x04) から定数をロード
- 0x80..0x90 にシグネチャを書き込み
- 0x08 に PASS フラグを書き込み
- 最後は無限ループ

**シグネチャマップ**:
- 0x80 = 0xDEADBEEF
- 0x84 = 0xCAFEBABE
- 0x88 = 0x00000000
- 0x8C = 0x00000000
- 0x90 = 0x00000001

**合格条件**: PASS フラグ確認 (`mem[0x08] == 32'h1`) かつ全シグネチャ一致

**注意**: CPU はパイプライン”らしい”動作するが、ハザード検出/フォワーディング無し。StepB プログラムには NOP を挿入して RAW ハザードを回避している。




### Step C 性能比較テスト

**目的**: PASS までのサイクル数計測と性能比較

**テストプログラム** (`mem_cpu12_stepC.bin` + `data_cpu12_stepC.dat`):
- データメモリからデータをロード (x2, x3)
- シグネチャ領域に計算結果を書き込み
- x5 = x2 + x3 の加算実行
- 計算結果をシグネチャとして保存
- PASS フラグを設定して終了

**シグネチャマップ**:
- 0x80 = 0x44332211 (入力データ 1)
- 0x84 = 0x88776655 (入力データ 2)
- 0x88 = 0xCCAA8866 (計算結果: 0x44332211 + 0x88776655)
- 0x8C = 0x00000001 (PASS フラグ)

**合格条件**: PASS フラグ確認かつ全シグネチャ一致、サイクル数計測完了

**パフォーマンス結果**: 39 サイクルで PASS (mem[0x08] が 1 に設定される)


## コンパイルと実行

### 標準テスト (Pass/Fail のみ)
```bash
iverilog -g2012 -o sim_stepA.vvp tb_cpu1_stepA.v rv32i.v i_mem.v d_mem.v alu.v

vvp sim_stepA.vvp
```

### Step B テスト (シグネチャ検証)
```bash
iverilog -g2012 -o sim_stepB.vvp tb_cpu1_stepB.v rv32i.v i_mem.v d_mem.v alu.v

vvp sim_stepB.vvp
```

### 波形解析
```bash
gtkwave stepX.vcd ( X は A または B または C)
```
VCD に全信号遷移が記録されるため、GTKWave で可視化が可能。

### アーキテクチャ概要

### 5 段パイプライン (基本段レジスタのみ、ハザード処理なし)

```
┌────────┐   ┌────────┐   ┌─────────┐   ┌────────┐   ┌───────────┐
│ Fetch  │──▶│ Decode │──▶│ Execute │──▶│ Memory │──▶│ Writeback │
└────────┘   └────────┘   └─────────┘   └────────┘   └───────────┘
    │            │              │             │              │
    pc         inst          alu_res       d_in/wr        wd/r_we
  _reg         rdata1/2       imm_E       _addr/data     rd_W
               opcode_E      funct3_E     opcode_M      opcode_W
```

**段レジスタ**:
- `_E` 接尾辞: Execute 段 (opcode_E, rdata_E1, imm_E, pc_E)
- `_M` 接尾辞: Memory 段 (opcode_M, alu_res_M, rd_M)
- `_W` 接尾辞: Writeback 段 (opcode_W, rd_data_W, rd_W)

**制限事項**:
- ハザード検出、ストール、フォワーディング/バイパス未実装
- パイプラインフラッシュ未実装
- 分岐は BEQ のみ実装
- JALR の bit0 クリア未実装 (仕様では (rs1+imm) & ~1 が必要)
- PC は 8bit (`PC_W=8`)、ターゲットは 8bit に切り詰められる

### 制御ハザード対策 (現実装)

**課題**: パイプラインで分岐やジャンプがあると誤った命令をフェッチする可能性。

**対応**: Decode 段での早期ジャンプ判定:
- JAL/JALR は `opcode` で組合せ論理的に即時判定
- PC 更新: `pc_next = jal_target_D`
- ジャンプペナルティを削減するが、明示的なフラッシュ/ストール機構は無い

**注記**: RTL にはフラッシュ、ストール、遅延スロット機構がなく、単に `pc_next` を選択している。

---

## 検証指標

### 機能カバレッジ
- [x] Load 即値オフセット指定 (I 型)
- [x] Store 即値オフセット指定 (S 型)
- [x] 分岐オフセット (B 型)
- [x] ジャンプオフセット (J 型)
- [x] ALU 即値演算
- [x] レジスタ間データフロー
- [x] メモリからレジスタへのデータフロー
- [x] レジスタからメモリへのデータフロー

### タイミング解析
- **総シミュレーション時間**: 1995 ns (199.5 サイクル @ 10ns 周期)
- **アクティブプログラムサイクル**: ~10 (サイクル 63-72)
- **無限ループ検出**: サイクル 131 (PC = 0x24 で停止)
- **パイプラインの深さ**: 5 段 (1 IPC が保証されない; ハザードは処理されない)

### バグ修正の検証
1. 即値デコード: LW offset=0 動作、SW offset=4 動作、BEQ offset=16 動作
2. PC 制御: BEQ 条件分岐実行、JAL 無条件ジャンプ実行
3. レジスタ書き込み: ADDI 結果が x3 に保存、LW 結果が x1/x2 に保存
4. Store 操作: SW が正常にデータメモリに書き込み (読み出しで検証)

## 付録: クイックコマンドリファレンス

### 全コンパイル
```bash
iverilog -g2012 -o sim_stepA.vvp tb_cpu1_stepA.v rv32i.v i_mem.v d_mem.v alu.v
```

### テスト実行
```bash
vvp sim_stepA.vvp
```

### 波形表示
```bash
gtkwave stepA.vcd &
```

デバッグ用ですが、ファイルは要らないと思って削除しています。
### 特定サイクルでの CPU 状態確認 (デバッグ用)
```bash
vvp sim_stepA_debug.vvp | sed -n '/Cycle 66/,/Cycle 67/p'
```

---

**ドキュメント版**: 1.1  
**最終更新**: 2026 年 2 月 1 日    
**状態**: Step A、Step B、Step C 結合テストすべて PASS