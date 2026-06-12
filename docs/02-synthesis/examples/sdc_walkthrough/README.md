# SDC / 时序图 walkthrough

与 [05 章](../../05-constraints-sdc.md) 对照。展示 **约束 → Timing Graph 内部状态**，非 SDC 脚本大全。

## 文件

| 文件 | 说明 |
|------|------|
| `simple_ff_path.sv` | 两级 FF，中间组合极短 |
| `cdc_sync.sv` | 双 FF 跨时钟域（05 §4.3） |

---

## 案例 A — 时钟与 setup check（05 §2）

### 前后对比（约束读入前 → 后）

| 前（mapped 网表，无 SDC） | 后（读入 `create_clock -period 1.0` 后） |
|----------------------------|-------------------------------------------|
| timing graph 仅有 cell/net 弧，**无 check** | `clk` 成为 clock 对象，FF/CK 挂传播边 |
| 路径无 required，WNS 无定义 | `reg_out/D` 上出现 setup/hold check，required=0.92 |
| compile 退化为纯结构映射 | 04/06 的 cost/slack 全部生效 |

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

## 案例 F — clock_groups / CDC（05 §4.3）

**RTL**：`cdc_sync.sv` — `clk_a` 域 `sync0` → `clk_b` 域双 FF 同步 → `data_b`。

| 约束 | 跨域路径 check | 典型 WNS |
|------|----------------|----------|
| 无 | 公倍周期 setup 检查 | **虚假负**（同步器段被当单周期数据路径） |
| `set_clock_groups -asynchronous -group {clk_a} -group {clk_b}` | check **删除** | 不报该路径 |

**注意**：同步器 **电路**保证安全；`clock_groups` 只告诉 STA **不要检查** — 二者缺一不可。

---

## 案例 G — max_transition / DRC 先于 timing（05 §7）

**场景**：某 driver net fanout=24，`set_max_transition 0.30`。

| 顺序 | 动作 | 结果 |
|------|------|------|
| 错误 | 先 upsize 修 setup | slew 仍超 → delay 表不可信 |
| 正确 | 先 buffer tree 修 slew → 0.28 | 再 STA → 再 sizing |

与 [06 §2.4](./../../06-timing-driven-optimization.md#24-候选生成与优先级启发式) 调度表第一行一致。

---

## 案例 H — generated_clock（05 §9.1）

**约束语义**（概念）：

```tcl
create_clock -name clk_ref -period 2.0 [get_ports clk_ref]
create_generated_clock -name clk_cpu -source [get_pins pll/CLKIN] \
  -divide_by 2 [get_pins pll/CLKOUT]
```

**内部 timing graph**：

| 对象 | 边 | 说明 |
|------|-----|------|
| `clk_ref` | 主时钟 | period 2.0 |
| `clk_cpu` | **派生** | period 4.0，边沿对齐 PLL 模型 |
| `reg_cpu/CK` | 挂 `clk_cpu` | setup check 用 **4.0 ns** 周期 |

**输出**：漏写 `generated_clock` → CPU 域按 2.0 ns 检查 → **虚假违例** 或错误闭合。

---

## 阅读顺序

```text
05 §1 编译流水线 → 案例 A → §3 B → §4 C/F → §7 G → §6 D → 06 章
```
