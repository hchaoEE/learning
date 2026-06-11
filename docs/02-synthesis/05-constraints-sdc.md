# 2.5 时序约束（SDC）— 综合器内部语义

**SDC** 是 **约束语言**，综合器读入后编译成 **Timing Graph 上的语义**（时钟边、required/arrival 规则、例外剪枝），供 [04 映射](./04-technology-mapping.md) 的 cost 函数与 [06 细粒度优化](./06-timing-driven-optimization.md) 的 slack 驱动使用。

> 本章讲 **SDC 在 Design DB 里变成什么**；语法仅作索引。  
> 配套案例：[examples/sdc_walkthrough/](./examples/sdc_walkthrough/)

---

## 1. 在流程中的位置

```text
  SDC 文本
      │  parse + bind to DB objects (port/pin/clock)
      ▼
  Constraint Graph Layer（附在 Timing Graph 上）
      │
      ├──► 04 mapping：cut cost 中的 arrival_time / required
      ├──► 06 TDO：slack 计算、违例分类
      └──► 签核 STA：同一语义（corner 更全）
```

| 阶段 | 内部消费什么 |
|------|--------------|
| 04 | **max** 分析下的 AT，驱动选 **快 cover** |
| 06 | setup/hold slack、DRC limit |
| 无有效 clock | 时序图 **无 check** → compile 退化为 **纯结构映射** |

### 输入/输出案例

**输入**（SDC 文本，2 行）：

```tcl
create_clock -period 1.0 [get_ports clk]
set_input_delay 0.3 -clock clk [get_ports din]
```

**输出**（timing graph 上的最小变化）：

```text
clk 端口   → clock 对象（period=1.0，launch/capture 波形）
所有 FF/CK → 挂上该 clock 的传播边
din 端口   → 虚拟 launch：arrival(din) 起点 = 0.3
FF/D 引脚  → setup/hold check 节点（required 规则生效）
```

---

## 2. SDC → Timing Graph：编译流水线

```text
1. Object Resolution：字符串 → DB 中的 port / pin / cell / clock 对象
2. Clock Creation：定义 clock source、period、waveform、generated 关系
3. Exception Overlay：false / multicycle / min-max delay 修改边或 required
4. Check Binding：setup/hold/recovery/removal 挂在 FF pin 对上
5. Corner Binding：MCMM 下每 mode×corner 一套 delay annotation 引用
```

**Timing Graph 节点** = pin；**边** = cell arc + net arc + **clock propagation edge**。

### 2.1 时钟在内部的表示

| SDC 语义 | Timing Graph 内部 |
|----------|-------------------|
| `create_clock -period T` | 时钟源 pin 上周期为 **T** 的 **launch/capture 波形** |
| Launch edge | 数据从 FF **Q** 出发的参考时刻 |
| Capture edge | 数据必须在 FF **D** 稳定的参考时刻 |
| Generated clock | 父 clock 边 + **分频/相移** 派生子 clock 对象 |

综合早期 clock 多为 **ideal**（零 skew）；CTS 后 STA 换 **propagated clock**，但 **SDC 对象 ID** 不变。

### 输入/输出案例 2.1

**约束**：`create_clock -period 1.0 [get_ports clk]`

**内部**（单 FF→FF 路径）：

```text
launch:  reg_a/CK @ 0.0, 1.0, 2.0 …
capture: reg_b/CK @ 1.0, 2.0, 3.0 …
setup check: reg_b/D required @ capture − setup_time
```

**Slack** = required(D) − arrival(D)（见 [06 §2.1](./06-timing-driven-optimization.md#21-mapped-ir-上的时序图)）。

---

## 3. IO 延时：路径预算如何切分

IO 约束不直接「加延时单元」，而是 **从 period 中扣掉外部预算**，缩小 **芯片内组合逻辑可用 slack**。

| SDC 语义 | 内部效果 |
|----------|----------|
| `set_input_delay` | 外部到 **input port** 的到达时间 → 减少 **port→首 FF** 的内部分配 |
| `set_output_delay` | **output port** 到外部采样点的剩余时间 → 减少 **末 FF→port** 分配 |
| `set_drive` / `set_load` | 影响 port 的 **transition / cap** 估计，进而影响 **首/末级 cell arc** |

```text
period T
  − input_delay
  − output_delay
  − FF setup/hold
  − clock uncertainty（若定义）
  ≈ 芯片内组合逻辑 budget B
```

### 输入/输出案例 3.1

**约束**：period=2.0 ns，`set_input_delay 0.5`，`set_output_delay 0.3`，setup=0.1

**内部 budget** B ≈ 2.0 − 0.5 − 0.3 − 0.1 = **1.1 ns** 留给 **in→FF→…→FF→out** 组合段。

04 映射时若组合估计 delay=1.3 ns → **映射 cost 已判违例**，06 需 sizing 或改 RTL。

---

## 4. 路径例外：改图而非改 RTL

例外约束在内部 **修改 check 规则或剪枝**，不改变布尔功能。

### 4.1 false_path

| 内部语义 | 效果 |
|----------|------|
| 标记路径 **不做 timing check** | 该路径 **不参与 WNS/TNS**；06 **不为其修时序** |

典型：`async_rst → FF`、静态配置、已用同步器隔离的 CDC（配合设计）。

### 4.2 multicycle_path

| 内部语义 | 效果 |
|----------|------|
| setup：允许 **N 个周期** 到达 | capture required **后移** (N−1)×period |
| hold：常需配对 `-hold` 调整 | 避免 hold 过检 |

**与 retiming 交互**：multicycle 改变 **有效 period**，retime 引擎读同一 DB 属性（见 [06 §8.3](./06-timing-driven-optimization.md#83-内部控制属性)）。

### 4.3 clock_groups

| 内部语义 | 效果 |
|----------|------|
| `-asynchronous` | 两 clock 域间路径 **默认 false** |
| `-physically_exclusive` | 互斥时钟，不同时活跃 |

CDC 路径若无此标注，STA 会 **错误地** 做跨域 setup → **虚假违例** 或 **虚假满足**。

### 4.4 max_delay / min_delay

直接给 **组合路径** 或 **指定点集** 设 required/arrival 界；内部等价于 **自定义 check** 绑在路径端点。

### 输入/输出案例 4.1 — 同一拓扑，不同例外

**拓扑**：`clk_a` 域 FF → 组合 → `clk_b` 域 FF

| 约束语义 | 内部 | WNS 行为 |
|----------|------|----------|
| 无 | 跨域 setup 检查 | 常 **虚假违例** |
| clock_groups asynchronous | 路径剪枝 | 不报该路径 |
| multicycle setup=2 | capture required 后移 1 周期 | 允许慢路径 |

### 输入/输出案例 4.2 — multicycle setup

**约束语义**：launch `clk_a` → capture `clk_b`，**setup=2 周期**（慢路径）。

**内部**：

```text
required(D) ← capture_edge + (2-1)×T_clk_b − setup_time
（相对单周期，组合预算 +≈1 个 clk_b 周期）
```

**04/06**：该路径 WNS 计算用 **放宽后的 required**；不应与单周期路径混比 WNS。

---

## 5. 约束 → 04/06 的代价函数

### 5.1 映射阶段（04）

04 的 cut cost 概念形式：

```text
cost(cut) = α·area(cover) + β·delay(cover, AT_from_fanin)
```

**AT_from_fanin** 来自 **已标注时序图**（SDC clock + 上游 arrival）。  
SDC 更紧 → 同一 AIG 结构倾向选 **更快但更贵** 的 cover。

### 5.2 细粒度阶段（06）

06 读 **同一 timing graph** 上的 slack；transform 接受条件含 **所有绑定 corner** 的 check（见下节 MCMM）。

### 输入/输出案例 5.1

**约束收紧**：period 1.0 → 0.8 ns，其余不变。

**内部**：同一 mapped 网表，WNS 由 +0.05 → **−0.15** → 06 触发 upsize/buffer 队列，**无需重新 elaboration**。

---

## 6. MCMM：多 corner 在 DB 上的挂接

**MCMM**（Multi-Corner Multi-Mode）在内部 **不是** 多份 SDC 文件简单叠加，而是：

```text
Mode（functional / test / …）
  × Corner（slow_max / fast_min / …）
    → 一套 operating_conditions + .lib delay annotation
    → 同一 topology timing graph，弧 delay 不同
```

| 分析 | 典型 corner | 主要 check |
|------|-------------|------------|
| **Max delay** | slow, hot | **Setup** |
| **Min delay** | fast, cold | **Hold** |

**06 transform 接受判定**（与 [06 §4.2](./06-timing-driven-optimization.md#42-多-corner-内部聚合) 一致）：

```text
接受 T ⟺ 在所有相关 mode×corner 上
         setup/hold/DRC 不恶化（或 WNS/THS 改善）
```

### 6.1 为何综合必须双 corner

仅 slow max：setup 闭合但 **fast min hold 未检** → 06 可能大量 upsize → **silicon hold 失败**。  
内部引擎在 **min corner** 上单独扫描 hold 违例端点。

### 输入/输出案例 6.1

**DB 状态**（同一 net `n48`）：

| Corner | cell+net delay | setup slack | hold slack |
|--------|----------------|-------------|------------|
| slow_max | 0.85 ns | −0.05 | +0.10 |
| fast_min | 0.22 ns | +0.40 | **−0.04** |

**06 决策**：upsize 修 setup 恶化 fast hold → 改为 **capture 前 delay**（见 [06 §4.3](./06-timing-driven-optimization.md#43-setuphold-冲突案例)）。

---

## 7. 电气与优化约束（内部属性）

以下 SDC 语义在 DB 中变为 **pin/net 上的 limit 或 cell 属性**：

| 语义 | 内部挂载 | 06 行为 |
|------|----------|---------|
| `set_max_transition` | driver output slew limit | transition 违例 → buffer/upsize |
| `set_max_capacitance` | net total C limit | 同左 |
| `set_dont_touch` | instance **不可 transform** | 06 跳过 |
| `set_dont_use` | lib cell **不可绑定** | 04/06 候选集中删除 |
| `set_case_analysis` | pin 固定 0/1 | 常量传播 → 时序图剪枝 |

Wire load / operating conditions 决定 **net arc 与 cell arc 查表 corner**，与 MCMM 表一致。

---

## 8. 对象解析与 Elaboration 名

SDC 字符串必须通过 **Object Resolution** 绑到 DB：

```text
[get_ports clk]           → top-level port object
[get_pins u_alu/U1/D]     → hierarchical pin
[get_clocks clk]          → clock object（非 port 本身）
```

Elaboration 后 **generate 路径、uniquify 后缀** 必须与 SDC 一致（见 [01 章](./01-rtl-parsing-and-elaboration.md)）。解析失败 → 约束 **悬空**，内部等价于 **未约束**。

### 输入/输出案例 8.1

**SDC**：`get_cells u_child`  
**DB 实际名**：`genblk1.u_child`  
**内部**：空 object set → 该约束 **不生效**。

---

---

## 9. 生成时钟与 uncertainty（内部）

### 9.1 generated_clock

**语义**：从 **master clock** 或 **pin 波形** 派生子 clock 对象。

```text
master clk @ 100MHz
  └── generated clk_div2 @ 50MHz（分频）
        └── FF 的 launch/capture 可绑不同 clock 对象
```

**内部**：timing graph 上 **边延迟 + 波形相位** 决定跨域路径是否检查。

### 9.2 clock uncertainty

**语义**：在 required 或 launch 上 **减 margin**（setup/hold 各可不同）。

```text
required(D) ← capture_edge − setup − uncertainty_setup
```

**06**：uncertainty 越大 → slack 越小 → **更激进 sizing**。

### 输入/输出案例 9.1

**派生时钟**：PLL 输出 `clk_cpu` from `clk_ref` / 2

**内部**：`clk_cpu` period=2×`clk_ref`；跨 ref/cpu 域路径须 **例外或多周期**（§4）。

---

## 10. 小结

| 要点 | |
|------|--|
| SDC 产物 | Timing Graph 上的 **clock / check / exception / limit** |
| 04 消费 | arrival → mapping **delay cost** |
| 06 消费 | slack → **transform 队列** |
| MCMM | 同一图，**多套 delay**；setup/hold 分 corner |
| 语法索引 | clock §2、IO §3、例外 §4、MCMM §6 |

---

## 下一节

- [04 映射](./04-technology-mapping.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
- [07 内部量索引](./07-synthesis-reports.md)
- [examples/sdc_walkthrough/](./examples/sdc_walkthrough/)
