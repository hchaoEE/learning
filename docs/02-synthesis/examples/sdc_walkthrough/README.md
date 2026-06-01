# SDC / 时序图 walkthrough

与 [05 章](../05-constraints-sdc.md) 对照。展示 **约束 → Timing Graph 内部状态**，非 SDC 脚本大全。

## 文件

| 文件 | 说明 |
|------|------|
| `simple_ff_path.sv` | 两级 FF，中间组合极短 |

---

## 案例 A — 时钟与 setup check（05 §2）

### 拓扑

```text
din ──► reg_mid/D ──Q──► reg_out/D ──Q──► dout
         ↑ CK              ↑ CK
         └── clk ──────────┘
```

### 约束语义（概念）

| 项 | 值 |
|----|-----|
| `create_clock -period` | 1.0 ns |
| reg setup | 0.08 ns |

### 内部 timing graph 边（示意）

| 边 | 类型 | delay |
|----|------|-------|
| clk → reg_mid/CK | clock | 0 (ideal) |
| reg_mid/Q → reg_out/D | data | 0.05 (组合+net) |
| reg_out setup | check | required = 1.0 − 0.08 = 0.92 @ capture |

**Arrival @ reg_out/D** ≈ 0.12 (CLK→Q) + 0.05 = **0.17 ns**  
**slack_setup** ≈ 0.92 − 0.17 = **+0.75 ns** ✓

---

## 案例 B — IO 预算（05 §3）

在案例 A 上，`din` 为 input port：

| 约束语义 | 内部扣减 |
|----------|----------|
| `set_input_delay 0.4` | port→reg_mid 外部分配 0.4 ns |
| period 1.0 ns | 芯片内 reg_mid→reg_out 可用 ≈ 1.0 − 0.4 − setup ≈ **0.52 ns** |

若组合段 delay 估 0.55 ns → **内部已判 setup 违例**，06 需介入。

---

## 案例 C — false_path（05 §4.1）

**约束语义**：`set_false_path -from [get_ports rst_n] -to [all_registers]`

**内部**：

```text
rst_n ──► reg_*/async pin   路径标记 no_check
```

异步复位路径 **不出现在 WNS**；06 **不为复位路径插 buffer**。

---

## 案例 D — MCMM 双 corner（05 §6）

同一 mapped 网表，两套 delay annotation：

| Corner | reg CLK→Q + 组合 | setup slack |
|--------|------------------|-------------|
| slow_max | 0.17 ns | +0.75 ✓ |
| fast_min | 0.06 ns | +0.86 ✓（hold 另检）|

若 upsize 组合驱动使 fast_min 组合 delay → 0.02 ns，hold 可能变负 → 06 **multi-corner 拒绝** 该 transform。

---

## 案例 E — multicycle（05 §4.2）

**约束语义**：某慢路径 setup=2 周期。

**内部 timing graph**：

```text
required @ capture ← 单周期 required + 1×period
slack 变大 → 该路径不再驱动 WNS
```

---

## 阅读顺序

```text
05 §1 编译流水线 → 案例 A → §3 案例 B → §4 案例 C → §6 案例 D → 06 章
```
