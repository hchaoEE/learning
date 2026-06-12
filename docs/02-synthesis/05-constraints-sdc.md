# 2.5 时序约束（SDC）— 综合器内部语义

> **本章回答**：SDC 如何变成 timing graph 上的 clock/check/例外。  
> **读完应能**：① 画 reg2reg setup 检查 ② 区分 false_path 与 clock_groups ③ 理解 MCMM 多 mode  
> **先修**：setup/hold 概念 · **难度**：★★★★☆ · **walkthrough**：[sdc_walkthrough](./examples/sdc_walkthrough/)

**SDC** 是 **约束语言**，综合器读入后编译成 **Timing Graph 上的语义**（时钟边、required/arrival 规则、例外剪枝），供 [04 映射](./04-technology-mapping.md) 的 cost 函数与 [06 细粒度优化](./06-timing-driven-optimization.md) 的 slack 驱动使用。

> 本章讲 **SDC 在 Design DB 里变成什么**；语法仅作索引。  
> 配套案例：[examples/sdc_walkthrough/](./examples/sdc_walkthrough/)

---

## 1. 在流程中的位置
> **一句话**：SDC 被编译成附在 timing graph 上的约束层，供 04/06/签核 STA 共用同一语义。

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
> **一句话**：SDC → Timing Graph：编译流水线——本章核心机制点。
> **类比**：像给地图标红绿灯与禁行线——不改路，只改能不能算路程。

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

**Slack** = required(D) − arrival(D)（求值与传播机制见 [07 §3](./07-internal-sta-and-qor.md#3-at--rt-传播算法)）。

### 2.2 Check 节点绑定与 ideal / propagated

**Pin 级标注**：编译流水线第 4 步在每个时序 check 上挂三样东西：

| 标注 | 内容 | 来源 |
|------|------|------|
| `launch_clock_id` | 数据起点 FF 绑定的 clock 对象 | clock 传播边可达性分析 |
| `capture_clock_id` | check 所在 FF 的 CK 绑定 | 同上 |
| check 类型 + 库值 | setup/hold/recovery/removal 的 `.lib` 查表入口 | FF 的 timing arc |

一个 D pin 可能有 **多对 (launch, capture)** 组合（多 clock 扇入经 MUX）——每对独立成 check，分析时各自求值（[07 §4.2](./07-internal-sta-and-qor.md#42-launch--capture-配对)）。

**例外的两种内部实现**（§4 的例外语义落到数据结构上）：

| 例外 | 内部动作 | 后果 |
|------|----------|------|
| `false_path` / 异步 `clock_groups` | **删 check 边**（或标 disabled） | endpoint 退出路径分组桶，不再产生 slack |
| `multicycle_path` / `max_delay` | **改 required**（换 capture 沿 / 覆盖预算） | check 仍在，约束松紧改变 |

「删边」与「改 required」对 06 的影响完全不同：前者让违例 **消失**，后者让违例 **变小** — 误用 false_path 掩盖真实路径属「删边」类事故。

**Ideal vs propagated**：

| 模式 | clock 传播边 delay | skew/latency 来自 | 谁在用 |
|------|--------------------|---------------------|--------|
| **ideal** | 0 | `set_clock_latency`（显式建模）+ `set_clock_uncertainty`（margin） | 综合主体 |
| **propagated** | clock tree cell arc 累加 | 真实树 | CTS 后签核 |

切换只改 **clock 边的 delay 语义**，SDC 对象与 check 绑定不变 — 这就是「综合 SDC 与签核 SDC 同一份」可行的内部原因。综合 WNS 与签核 WNS 的偏差根因之一即在此（[07 §4.3](./07-internal-sta-and-qor.md#43-ideal-vs-propagated-clock)）。

### 输入/输出案例 2.2

**输入**：`reg_b/D` 有两个时钟域扇入（`clk_a` 直接路径、`clk_b` 经 MUX），加 `set_false_path -from clk_b -to clk_a`。

**输出（check 绑定变化）**：

| check (launch→capture) | false_path 前 | 后 |
|--------------------------|----------------|-----|
| clk_a → clk_a setup/hold | 有效 | 有效 |
| clk_b → clk_a setup/hold | 有效（按公倍周期最紧沿对） | **边删除**，endpoint 从该桶消失 |

---

## 3. IO 延时：路径预算如何切分
> **一句话**：IO 延时：路径预算如何切分——本章核心机制点。
> **类比**：像给地图标红绿灯与禁行线——不改路，只改能不能算路程。

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
> **一句话**：路径例外：改图而非改 RTL——本章核心机制点。
> **类比**：像给地图标红绿灯与禁行线——不改路，只改能不能算路程。

例外约束在内部 **修改 check 规则或剪枝**，不改变布尔功能。

### 4.1 false_path

| 内部语义 | 效果 |
|----------|------|
| 标记路径 **不做 timing check** | 该路径 **不参与 WNS/TNS**；06 **不为其修时序** |

典型：`async_rst → FF`、静态配置、已用同步器隔离的 CDC（配合设计）。

### 输入/输出案例 4.1 — async 复位 false_path

**输入**：`set_false_path -from [get_ports rst_n] -to [all_registers]`

**输出**：`rst_n → FF/RN` 弧 **check 删除**；WNS 不再包含复位释放路径；06 **不**对复位锥插 buffer。见 [sdc_walkthrough 案例 C](./examples/sdc_walkthrough/README.md#案例-c--false_path0541)。

### 4.2 multicycle_path

| 内部语义 | 效果 |
|----------|------|
| setup：允许 **N 个周期** 到达 | capture required **后移** (N−1)×period |
| hold：常需配对 `-hold` 调整 | 避免 hold 过检 |

**与 retiming 交互**：multicycle 改变 **有效 period**，retime 引擎读同一 DB 属性（见 [06 §8.3](./06-timing-driven-optimization.md#83-内部控制属性)）。

### 输入/输出案例 4.2 — setup=2 周期

**输入**：慢路径 `launch clk_a` → `capture clk_b`，`set_multicycle_path -setup 2`

**输出**：`required(D) += 1×T_clk_b`；该路径 slack 从 −0.40 → **+0.60**（示意）；**不得**与单周期路径混比 WNS。见 [sdc_walkthrough 案例 E](./examples/sdc_walkthrough/README.md#案例-e--multicycle0542)。

### 4.3 clock_groups：三种互斥的不同图语义

三个选项在内部 **不是同一张 false 表**：

| 选项 | 物理含义 | 图语义 | 与 crosstalk 分析（签核） |
|------|----------|--------|-----------------------------|
| `-asynchronous` | 两域真异步（各自 PLL） | 跨组 **所有 data check 删除**（§2.2「删边」类） | 仍当作可同时翻转（噪声要算） |
| `-physically_exclusive` | 同一 pin 上二选一的 clock（mux 后只可能有一个存在） | 跨组 check 删除 **且** 同 pin 多 clock 标注合法化 | **不可能同时存在** → 噪声也不算 |
| `-logically_exclusive` | 两 clock 物理都在树上，但 **逻辑上不同时 active**（mux 选择） | 跨组 check 删除 | 物理共存 → 噪声仍算 |

综合阶段三者效果接近（都剪 check）；区别主要传递给 **签核 STA / SI 分析** — 但约束在综合期就写错，签核就继承错误。

**与逐条 `false_path` 的对比**：

| 方式 | 粒度 | 风险 |
|------|------|------|
| `clock_groups -asynchronous` | **整域 × 整域**，新加路径自动覆盖 | 误把同步关系声明为异步 → 真路径失检 |
| 逐条 `false_path -from A -to B` | 单路径 | RTL 改动新增跨域路径 **漏标** → 虚假违例（06 浪费预算去修）|

**两种 failure mode**（无标注或错标注时）：

```text
漏标（无 groups）：STA 用公倍周期最紧沿对算跨域 setup
   → 虚假违例 → 06 对不可能满足的路径疯狂加 buffer/upsize（面积浪费）
错标（同步域误声明异步）：真实路径 check 被删
   → 虚假满足 → 综合/签核全绿，silicon 上偶发错误（最危险）
```

同步器本身的安全性靠 **电路结构**（双 FF）而非约束 — 约束只是告诉引擎「这里不要检查」。

### 输入/输出案例 4.3 — CDC 漏标 vs 错标

**输入**（RTL 见 [examples/sdc_walkthrough/cdc_sync.sv](./examples/sdc_walkthrough/cdc_sync.sv)）：`clk_a` 域 FF → 双 FF 同步器 → `clk_b` 域 FF。

| 约束方案 | 内部（跨域路径 check） | WNS / 06 行为 |
|----------|------------------------|---------------|
| **无 clock_groups** | 公倍周期最紧沿对 setup 检查 | WNS = **−0.35**（虚假违例）；06 对同步器锥 upsize |
| `clock_groups -asynchronous {clk_a clk_b}` | 跨域 check **删边** | 该路径不进 WNS；06 **不浪费**预算 |
| 误把 **同频同步**路径也声明 async | 真数据路径 check 删除 | WNS 全绿 → **silicon 风险**（错标 failure mode） |

**输出（判读）**：有同步器结构 ≠ 可省略约束；须用 `clock_groups` 或精确 `false_path` 覆盖 **CDC 段**，且不能把仍须检查的同步路径一并 async 掉。

**初学者易错**：以为「做了双 FF 同步器」就不必写 SDC——同步器保证电路，**clock_groups 告诉 STA 别误报**；二者缺一不可。

### 4.4 max_delay / min_delay

直接给 **组合路径** 或 **指定点集** 设 required/arrival 界；内部等价于 **自定义 check** 绑在路径端点。

### 输入/输出案例 4.4 — 组合路径 max_delay

**输入**：`set_max_delay 0.5 -from [get_ports a] -to [get_ports y]`（纯组合锥）

**输出**：在 `y` 上绑定 **自定义 required=0.5**（非 FF setup）；违例时 06 修组合锥而非 FF check。

### 输入/输出案例 4.5 — 同一拓扑，不同例外对比

**拓扑**：`clk_a` 域 FF → 组合 → `clk_b` 域 FF（与 §4.3 CDC 案例同形，此处强调 **三种约束语义差异**）。

| 约束语义 | 内部 | WNS 行为 |
|----------|------|----------|
| 无 | 跨域 setup 检查 | 常 **虚假违例** |
| clock_groups asynchronous | 路径剪枝 | 不报该路径 |
| multicycle setup=2 | `required(D) += (2−1)×T_clk_b`（见案例 4.2） | 允许慢路径 |

**04/06**：multicycle 放宽后的路径 **不应与单周期路径混比 WNS**；CDC 须优先区分「删 check」与「延 period」（§4.3）。

---

## 5. 约束 → 04/06 的代价函数
> **一句话**：约束 → 04/06 的代价函数——本章核心机制点。
> **类比**：像给地图标红绿灯与禁行线——不改路，只改能不能算路程。

### 5.1 映射阶段（04）

04 的 cut cost 概念形式：

```text
cost(cut) = α·area(cover) + β·delay(cover, AT_from_fanin)
```

**AT_from_fanin** 来自 **已标注时序图**（SDC clock + 上游 arrival）。  
SDC 更紧 → 同一 AIG 结构倾向选 **更快但更贵** 的 cover。

### 输入/输出案例 5.1 — period 收紧改变 cover

**输入**：同一 AIG 锥，`period` 1.2 ns → **0.9 ns**（仅改 SDC）。

**输出（04 cost）**：

| period | 选中 cover | 关键路径 delay |
|--------|------------|----------------|
| 1.2 | 2× ND2（area） | 0.95 ns ✓ |
| 0.9 | AOI21 + ND2（timing） | 0.82 ns ✓ |

### 5.2 细粒度阶段（06）

06 读 **同一 timing graph** 上的 slack；transform 接受条件含 **所有绑定 corner** 的 check（见下节 MCMM）。

### 输入/输出案例 5.2 — 同一 SDC、06 消费 slack

**输入**：mapped 网表不变；`report_timing` 显示 `reg_q/D` slack = −0.08。

**输出**：06 队列选中 `u3` upsize；**不**重读 RTL/不重 04 全图 — 仅 transform + 增量 STA。

### 输入/输出案例 5.3 — period 全局收紧

**约束收紧**：period 1.0 → 0.8 ns，其余不变。

**内部**：同一 mapped 网表，WNS 由 +0.05 → **−0.15** → 06 触发 upsize/buffer 队列，**无需重新 elaboration**。

---

## 6. MCMM：多 corner 在 DB 上的挂接
> **一句话**：MCMM：多 corner 在 DB 上的挂接——本章核心机制点。

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
> **一句话**：电气与优化约束（内部属性）——本章核心机制点。

以下 SDC 语义在 DB 中变为 **pin/net 上的 limit 或 cell 属性**：

| 语义 | 内部挂载 | 06 行为 |
|------|----------|---------|
| `set_max_transition` | driver output slew limit | transition 违例 → buffer/upsize |
| `set_max_capacitance` | net total C limit | 同左 |
| `set_dont_touch` | instance **不可 transform** | 06 跳过 |
| `set_dont_use` | lib cell **不可绑定** | 04/06 候选集中删除 |
| `set_case_analysis` | pin 固定 0/1 | 常量传播 → 时序图剪枝 |

Wire load / operating conditions 决定 **net arc 与 cell arc 查表 corner**，与 MCMM 表一致。

### 输入/输出案例 7.1 — transition 违例先于 timing 修

**输入**（mapped 网表片段）：`u_drv/Z` fanout=24，`set_max_transition 0.30` on `clk` 域。

| 扫描阶段 | 违例标签 | slack 是否可信 |
|----------|----------|----------------|
| DRC 扫描 | `n_wide` slew = **0.42** > 0.30 | **否** — NLDM 在 limit 外外推 |
| timing 扫描（若先跑） | setup WNS = −0.08 | 数字不可采信 |

**输出（06 队列）**：

```text
1. 先修 n_wide：插 BUFFD2 树（fanout 1→4→6）→ slew 0.28 ✓
2. 再重算 STA → setup WNS = −0.05（真实值）
3. 再进 upsize 队列
```

与 [06 §2.4](./06-timing-driven-optimization.md#24-候选生成与优先级启发式)「DRC 先于 timing」调度一致；详见 [sdc_walkthrough 案例 F](./examples/sdc_walkthrough/README.md#案例-f--clock_groupscdc05-43)。

---

## 8. 对象解析与 Elaboration 名
> **一句话**：对象解析与 Elaboration 名——本章核心机制点。

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

## 9. 生成时钟与 uncertainty（内部）
> **一句话**：生成时钟与 uncertainty（内部）——本章核心机制点。

### 9.1 generated_clock：波形派生机制

**语义**：从 **master clock** 派生子 clock 对象，子 clock 波形 **由 master 波形计算**，而非独立声明。

**内部派生步骤**：

```text
1. 解析 source pin（分频器 FF 的 Q、mux 输出等）
2. 检查 master → source pin 存在 clock 传播路径（否则告警：无波形可派生）
3. 按 -divide_by / -multiply_by / -edges / -invert 从 master 沿表算出子沿表
4. 子 clock 成为独立 clock 对象（独立 id），从 source pin 起继续传播
```

| 派生参数 | 沿表变换（master period = T） |
|----------|--------------------------------|
| `-divide_by 2` | 取 master 每隔一个上升沿 → period 2T |
| `-edges {1 3 5}` | 用 master 第 1/3/5 个沿构造一个周期 |
| `-invert` | 沿表整体反相 |

**为何不直接 `create_clock`**：generated clock 的沿 **锚定 master 时刻表** — launch 在 master、capture 在 generated 的路径，沿配对（[07 §4.2](./07-internal-sta-and-qor.md#42-launch--capture-配对)）用 **同一时间轴**，相位关系自动正确；独立 create_clock 则两轴无关，跨域 check 全错。

**级联与环路**：generated 可再派生 generated（沿表逐级计算）；若 source pin 的扇入锥含自身 clock 网络 → **派生环**，引擎检测后拒绝并要求显式 create_clock 截断。

**与 mux 后时钟**：mux 选择多个 master 时，每个输入派生一个 generated clock 挂在同一 pin → 配合 §4.3 `-physically_exclusive` 剪掉互斥组合。

### 9.2 uncertainty 与 latency 的分量语义

两者都是 ideal 模式下 **对未来 clock tree 的建模**，但落点不同：

| 属性 | 落在公式哪里 | 建模什么 |
|------|--------------|----------|
| `set_clock_latency -source` | launch/capture 沿 **整体平移**（PLL→clock 根） | 时钟源插入延时 |
| `set_clock_latency`（network） | 同上（clock 根→FF/CK），CTS 后被 propagated 实测替代 | 树延时估计 |
| `set_clock_uncertainty -setup` | **required 减**：`required = capture − setup − U_setup` | skew + jitter + margin |
| `set_clock_uncertainty -hold` | **required 加**：hold check 更难过 | skew（jitter 对同沿 hold 影响小） |
| inter-clock uncertainty（跨 clock 对） | 仅对特定 launch/capture clock 对生效 | 两棵树间 skew 更大 |

```text
setup:  required(D) = T_capture + latency − t_setup − U_setup
hold:   required(D) = T_capture(同沿) + latency + t_hold + U_hold
```

**关键区别**：latency 同时平移 launch 与 capture（同 clock 时 **互相抵消**，跨 clock 时不抵消）；uncertainty 是 **单边 margin**，永远收紧。CTS 后 network latency 被真实树取代，**uncertainty 应当调小**（只留 jitter）——否则双重悲观。

**06 视角**：uncertainty 越大 → 全 endpoint slack 越紧 → sizing 越激进、面积越大；这是「margin 换鲁棒性」的显式旋钮。

### 输入/输出案例 9.2 — uncertainty vs latency

**输入**：同路径，`period=1.0`，`U_setup=0.05`，`network_latency=0.10`（launch/capture 同 clock）。

| 只加 latency | 只加 uncertainty | 对同 clock reg2reg |
|--------------|------------------|---------------------|
| launch/capture **同移** | required **单边减** | latency **抵消**；uncertainty **收紧 slack** |

**输出**：综合 signoff margin 主要靠 **uncertainty**；latency 在 ideal 下同域路径常 **不影响 slack**。

### 输入/输出案例 9.1 — generated_clock 派生

**派生时钟**：PLL 输出 `clk_cpu` from `clk_ref` / 2

**内部**：`clk_cpu` period=2×`clk_ref`；跨 ref/cpu 域路径须 **例外或多周期**（§4）。

---


## 知识点清单（自检）

- [ ] create_clock 挂到哪些 pin
- [ ] setup check 在 FF/D
- [ ] false_path vs clock_groups
- [ ] multicycle 改 required 而非 RTL
- [ ] MCMM functional vs test
- [ ] sdc_walkthrough 案例 A–F

---

## 10. 小结
> **一句话**：小结——本章核心机制点。

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
- [08 内部量索引](./08-synthesis-reports.md)
- [examples/sdc_walkthrough/](./examples/sdc_walkthrough/)
