# 2.7 综合内部 STA 引擎与 QoR

> **本章回答**：综合器内部的 timing graph、AT/RT 与 WNS/TNS 怎么算。
> **读完应能**：① 手推一小图 AT/RT ② 解释 check 边不传播 delay ③ 区分内嵌 STA 与签核 PT
> **先修**：[05](./05-constraints-sdc.md)、[06](./06-timing-driven-optimization.md) · **难度**：★★★★★ · **walkthrough**：[sta_walkthrough](./examples/sta_walkthrough/)

[06 细粒度优化](./06-timing-driven-optimization.md) 的 transform 闭环、[08 报告](./08-synthesis-reports.md) 的每一行数字、[11 层次化](./11-hierarchical-block-synthesis.md) 的 abstract 模型，都依赖同一个地基：**综合器内部怎么算时序**。本章把这台 **内嵌 STA 引擎** 单独拆开讲：timing graph 怎么建、arrival/required 怎么传播、check 怎么求值、千万个 slack 怎么聚合成 WNS/TNS。

> 本章讲 **引擎机制**；约束如何变成图上标注属 [05 SDC](./05-constraints-sdc.md)，transform 如何消费 slack 属 [06](./06-timing-driven-optimization.md)，报告怎么读属 [08](./08-synthesis-reports.md)。

> 配套跟练：[examples/sta_walkthrough/](./examples/sta_walkthrough/)（五节点 AT/RT 手算表，对齐 §3.1、§4.1）。

---

## 1. 定位：一台引擎，多个消费者
> **一句话**：定位：一台引擎，多个消费者——本章核心机制点。

```text
            ┌────────────────────────────┐
 05 SDC ──► │  内嵌 STA 引擎（本章）       │ ──► 06 Transform Planner（slack 驱动）
 04 网表 ─► │  graph + AT/RT + check 求值 │ ──► 08 报告（WNS/TNS/路径）
 .lib  ───► │  + QoR 聚合                 │ ──► 11 abstract characterize（边界弧）
            └────────────────────────────┘
```

| 消费者 | 消费什么 | 章节 |
|--------|----------|------|
| Transform Planner | 违例 endpoint 列表、per-pin slack | 06 §2.4 |
| 报告生成 | 路径分解、QoR 汇总 | 08 |
| Abstract characterize | 边界 pin 的 max/min 弧 | 11 §3 |
| 交付门控 | 各 corner WNS/TNS/THS | 13 §3 |

**与签核 STA（PrimeTime 类）的边界**：

| 维度 | 综合内嵌 STA | 签核 STA |
|------|---------------|----------|
| Net 延时 | WLM / 物理估计 | **SPEF 真实寄生** |
| Clock | 多为 **ideal**（§4.3） | CTS 后 **propagated** |
| Derate / OCV | global derate（§7） | AOCV/POCV 表 |
| 目的 | **驱动 transform**（快、增量） | **签核**（准、全量） |

LEC（[10](./10-logical-equivalence-checking.md)）**不依赖** 本引擎——等价性与时序正交。

---

## 2. Timing Graph 数据结构
> **一句话**：Timing Graph 数据结构——本章核心机制点。
> **类比**：像双向标注每个路口的「最早到达」和「最晚必须到达」。

从 mapped Design DB 建图（04 结束即建，06 全程维护）：

| 图元素 | 来源 | 内容 |
|--------|------|------|
| **节点** | 每个 port / cell pin | 存 AT、RT、slew、所属 clock id |
| **Cell arc** | `.lib` timing arc（NLDM 查表，[04 §3.1](./04-technology-mapping.md#31-nldm-延时查表)） | `delay = f(input_slew, output_load)`，分 rise/fall |
| **Net arc** | WLM 或物理估计 | `f(fanout, length, layer)` |
| **Check 边** | `.lib` 时序检查（setup/hold/recovery/removal） | **不传播延时**，只产生约束（§4） |
| **Clock 边** | 05 的 clock 定义 | clock 源 → 各时序元件 CK pin |

```text
        cell arc          net arc        cell arc      check 边
reg_a/CK ──► reg_a/Q ──────► u1/A ──► u1/ZN ──► reg_q/D ◄┄┄┄ reg_q/CK
   ▲                                                          ▲
   └────────────── clock 边（ideal：delay=0）──────────────────┘
```

**Unate 性**：每条 cell arc 带极性（positive/negative unate）— INV 的 arc 把 rise 接到 fall。引擎对每个节点维护 **rise/fall 两套 AT/RT**，max 与 min 分析又各一套 → 每 pin 4 组值。

### 输入/输出案例 2.1

**输入**：mapped 网表 `reg_a → u1(ND2D1) → reg_q`（+第二输入 b 来自 port）。

**输出（建图后 DB）**：

| 元素 | 个数 | 说明 |
|------|------|------|
| 节点 | 8 | 2 FF × (CK,D,Q 取 2~3 pin) + u1 的 A/B/ZN + port b |
| cell arc | 3 | reg_a CK→Q、u1 A→ZN、u1 B→ZN |
| net arc | 3 | Q→A、b→B、ZN→D |
| check 边 | 2 | reg_q D 的 setup、hold（各对 CK） |

---

## 3. AT / RT 传播算法
> **一句话**：AT / RT 传播算法——本章核心机制点。
> **类比**：像双向标注每个路口的「最早到达」和「最晚必须到达」。

### 3.1 Forward：arrival time（AT）

```text
按拓扑序（PI / FF Q → PO / FF D）：
  AT(pin) = max over 入边 { AT(源 pin) + delay(arc) }     — max 分析（setup 用）
  AT_min(pin) = min over 入边 { … }                        — min 分析（hold 用）
  slew(pin) 同步传播（NLDM 输出 slew 作下游输入 slew）
```

起点：FF 的 Q 从 **clock 边沿 + CK→Q arc** 出发；PI 从 **`set_input_delay`**（05 §3）出发。

### 3.2 Backward：required time（RT）

```text
按逆拓扑序（PO / FF D → PI / FF Q）：
  RT(pin) = min over 出边 { RT(目标 pin) − delay(arc) }    — max 分析
```

起点：FF 的 D 从 **capture 沿 − setup**（§4），PO 从 **period − output_delay**。

### 3.3 Slack

```text
slack(pin) = RT(pin) − AT(pin)        （max 分析；负 = setup 违例）
slack_hold(pin) = AT_min(pin) − RT_hold(pin)
```

每个 **pin 都有 slack**，不只 endpoint——这正是 06 §2.4「沿路径收集可改 instance」的依据：路径上 slack 最负的弧就是瓶颈弧。

**初学者易错**：只看 endpoint slack 而忽略路径中间 pin——瓶颈常在 **中间 net/cell**；修 06 时应沿 AT/RT 最负的弧下刀，而不是盲目 upsize 最后一级。

### 3.4 组合环

组合反馈环会让拓扑序失效。引擎 **检测环 → 自动断开一条弧**（`disabled arc` 标记），并告警；被断弧不再传播 AT。`set_disable_timing`（05）是同一机制的手动入口。

### 输入/输出案例 3.1 — 5 节点小图全表推演

**图**：`reg_a/Q ─0.2─► u1/ZN ─0.3─► u2/ZN ─0.2─► reg_q/D`，clk→Q = 0.1，period = 1.0，setup = 0.1（数字含 net arc，已合并示意）。

| pin | AT（forward） | RT（backward） | slack |
|-----|----------------|-----------------|-------|
| reg_a/Q | 0.1 | 0.2 | +0.1 |
| u1/ZN | 0.1+0.2 = 0.3 | 0.4 | +0.1 |
| u2/ZN | 0.3+0.3 = 0.6 | 0.7 | +0.1 |
| reg_q/D | 0.6+0.2 = 0.8 | 1.0−0.1 = 0.9 | **+0.1** |

整条路径 slack 同为 +0.1（单路径无分叉时处处相等）；若 u1/ZN 另有一条更慢的扇入，则 u1/ZN 的 AT 取 max，上游各 pin slack 出现分化。

---

## 4. Check 求值
> **一句话**：Check 求值——本章核心机制点。
> **类比**：像双向标注每个路口的「最早到达」和「最晚必须到达」。

### 4.1 各类 check 绑哪对边

| Check | 约束谁 | 公式（ideal clock） |
|-------|--------|----------------------|
| **Setup** | D 的 **max AT** | `AT_max(D) ≤ T_capture − t_setup − uncertainty` |
| **Hold** | D 的 **min AT** | `AT_min(D) ≥ T_capture(同沿) + t_hold` |
| **Recovery/Removal** | 异步复位释放沿 | 同 setup/hold 形式，作用于 RN/SN pin |

`t_setup/t_hold` 本身也是 NLDM 查表（依赖 D 与 CK 的 slew）——**FF 换型（06 sizing）会改 check 值**，不只改 arc。

### 4.2 Launch / capture 配对

每个 check 边求值时，引擎枚举 **launch clock 沿 × capture clock 沿** 的合法组合：

- 同频同 clock：默认 **下一沿** capture（setup）、**同沿** capture（hold）
- 不同 clock：按两 clock 波形展开到 **最小公倍周期**，取 **最紧的沿对**
- 05 的例外（multicycle/false path）在此处 **改沿对或删 check**（[05 §4](./05-constraints-sdc.md#4-路径例外改图而非改-rtl)）

### 4.3 Ideal vs propagated clock

| 模式 | clock 边 delay | skew 来自 | 阶段 |
|------|----------------|-----------|------|
| **ideal** | 0 | SDC `set_clock_latency/uncertainty` 属性 | 综合主体 |
| **propagated** | 沿 clock tree cell arc 累加 | 真实树 | CTS 后（PnR） |

综合阶段 launch 与 capture 的 clock 网络延时 **同为 0** → skew 被 uncertainty 一刀切近似。这是综合 WNS 与签核 WNS 偏差的第一来源（第二来源是 net 寄生，第三是 derate，§7）。

### 输入/输出案例 4.1

**输入**：`clk` 1.0 ns，`set_clock_uncertainty 0.05`，案例 3.1 的图。

**输出（check 求值）**：`required = 1.0 − 0.1(setup) − 0.05 = 0.85`，slack 从 +0.1 收紧为 **+0.05** — uncertainty 直接从 RT 扣除，全 endpoint 生效。

---

## 5. 路径分组与 endpoint 桶
> **一句话**：路径分组与 endpoint 桶——本章核心机制点。
> **类比**：像双向标注每个路口的「最早到达」和「最晚必须到达」。

引擎把所有 endpoint（FF/D、PO）按 **起点/终点类型与 clock** 分桶：

| 桶（path group） | 起点 → 终点 | 默认权重 |
|-------------------|--------------|----------|
| `reg2reg`（每 clock 一组） | FF/Q → FF/D | **最高**（核心逻辑） |
| `in2reg` | PI → FF/D | 中（依赖 input_delay 假设） |
| `reg2out` | FF/Q → PO | 中 |
| `in2out` | PI → PO | 低（纯组合 feedthrough） |
| 异步组（clock_groups 切开） | 跨异步域 | **不进桶**（check 已删，05 §4.3） |

**桶的作用**：

- **WNS 按桶归属**：每桶有自己的 worst slack；06 修复队列 **按桶权重排序**——IO 桶的 −0.3 不会抢 reg2reg 桶 −0.1 的修复预算（IO 预算常是假设值）
- **unconstrained endpoint**（无 clock 标注、05 §8 对象解析失败）**不进任何桶** → 不贡献 WNS，但在 08 报告中单独列出（沉默漏洞）

### 输入/输出案例 5.1

**输入**：双 clock 设计，`clk_a` reg2reg WNS = −0.10，`in2reg` WNS = −0.30，3 个 unclocked FF。

**输出（桶视图）**：

| 桶 | WNS | 06 动作 |
|----|-----|---------|
| `clk_a/reg2reg` | −0.10 | **优先修**（权重高） |
| `in2reg` | −0.30 | 后修 / 先核对 input_delay 是否过悲观 |
| unconstrained | — | 不修；08 报告标红，回 05 补约束 |

全局 WNS 报 −0.30，但引擎的修复焦点在 −0.10——**读 QoR 必须带桶视角**。

---

## 6. QoR 聚合
> **一句话**：QoR 聚合——本章核心机制点。

Violation Scanner 之后，引擎对 endpoint 级 slack 做聚合：

| 指标 | 定义 | 导向 |
|------|------|------|
| **WNS** | min over endpoints (slack) | **单点瓶颈**——修最深的锥 |
| **TNS** | Σ 负 slack endpoint 的 slack | **违例总量**——大量小违例时比 WNS 更有信息 |
| **THS** | hold 侧 total negative slack | min corner 聚合 |
| 违例 endpoint 数 | count(slack<0) | 收敛趋势（每轮迭代应单调降） |

**WNS vs TNS 的优化语义**：

```text
设计 A：WNS = −0.30，TNS = −0.30（1 个 endpoint）   → 局部深锥，retiming/重构一处
设计 B：WNS = −0.05，TNS = −5.00（100 个 endpoint） → 系统性偏紧，全局 sizing/降频更现实
```

06 §9 的停止判据（连续 N 轮 ΔWNS < ε）读的就是这套聚合值。

**MCMM 聚合**（[05 §6](./05-constraints-sdc.md#6-mcmm多-corner-在-db-上的挂接)）：每 corner/mode 一张 **独立 timing graph 标注**（同一拓扑），QoR 先 per-corner 算，再取 **跨 corner worst** 作为接受判据——transform 必须 **所有 corner 不恶化** 才被接受（06 §4.2）。

### 输入/输出案例 6.1

**输入**：双 corner（slow_max / fast_min），一轮 upsize。

| 指标 | slow_max 前→后 | fast_min 前→后 |
|------|------------------|------------------|
| WNS(setup) | −0.10 → −0.02 | +0.4 → +0.4 |
| WNS(hold) | — | +0.02 → **−0.01** |

**输出（聚合判定）**：跨 corner worst 出现新 hold 违例 → transform **回滚**，换候选（06 §4.3 同一机制的 transform 侧视角）。

---

## 7. Derate / OCV（概念层）
> **一句话**：Derate / OCV（概念层）——本章核心机制点。

实际硅片上同 die 内单元有快慢差异（on-chip variation）。签核 STA 用 AOCV/POCV 表；**综合内嵌 STA 只用 global derate**：

```text
setup 分析：launch/data 路径 delay × (1 + derate_late)，capture clock × (1 − derate_early)
hold 分析：方向相反
```

| 后果 | 机制 |
|------|------|
| 综合「看起来闭合」签核却违例 | 综合 derate 比 AOCV 乐观（或没开） |
| 防御 | 综合阶段加 **margin**（uncertainty 加大 / 目标 WNS > 0 余量） |

不展开 AOCV 表结构——属签核 STA 范围。

### 输入/输出案例 7.1 — derate 前后 slack

**输入**（与 [06 案例 2.1](./06-timing-driven-optimization.md#输入输出案例-21--映射后初态) 同路径，period=1.0，setup=0.08）：

| 阶段 | data 路径 delay | capture 处理 | slack |
|------|-----------------|--------------|-------|
| 无 derate（综合内嵌） | 1.02 | required=0.92 | **−0.10** |
| +5% late derate on data | 1.02×1.05=1.071 | required 不变 | **−0.151** |
| 签核 AOCV（示意更悲观） | +8% OCV margin | +uncertainty | **−0.22** |

**输出（判读）**：综合 WNS=+0.02（刚闭合）+ 未开 derate → 签核可能 **−0.15**；交付须留 **WNS margin** 或综合期启用 global derate 与签核对齐。

---

## 8. 增量 STA 机制
> **一句话**：增量 STA 机制——本章核心机制点。

06 每轮 transform 后不重算全图。引擎维护 **脏标记传播**：

```text
transform 触点（换 ref / 插 buffer / 改 net）
    │ ① 触点 pin 标脏
    ▼
② 前向：脏 pin 的 fanout 锥 AT/slew 失效（slew 变 → 下游 delay 全变）
③ 后向：fanin 侧 RT 失效（required 反向依赖）
④ 重算：仅失效区域按 level 序重查 NLDM / 重传播
⑤ 截断：若某 pin 重算后 AT/slew 变化 < ε，停止向下传播
```

| 关键点 | 说明 |
|--------|------|
| **slew 传播是扩散源** | delay 只依赖本弧，slew 影响 **所有下游弧** → 失效区域比直觉大 |
| **ε 截断** | 变化小于阈值即停——精度换速度，compile 数百轮迭代的前提 |
| **QoR 增量** | endpoint slack 变化 → 仅更新所属桶的 WNS/TNS（堆/有序结构维护） |

06 §2.5 从 transform 视角描述同一机制；本节是引擎侧实现。

### 输入/输出案例 8.1

**输入**：案例 3.1 的图，u1 upsize（ND2D1→ND2D2）。

**输出（脏区域）**：

| pin | 是否重算 | 原因 |
|-----|----------|------|
| u1/A（输入） | 是 | 输入 cap 变 → 上游 net delay / reg_a/Q slew 变 |
| u1/ZN、u2/*、reg_q/D | 是 | fanout 锥（slew 链） |
| reg_a/CK、port b 之外的逻辑 | **否** | 不在失效闭包内 |

全图 8 节点重算 6 个；真实设计中比例通常 < 1%。

---


## 知识点清单（自检）

- [ ] timing graph 四类边
- [ ] AT forward / RT backward
- [ ] slack = RT − AT
- [ ] path group 权重
- [ ] derate 收紧 margin
- [ ] sta_walkthrough 案例 A 手推

---

## 9. 小结
> **一句话**：小结——本章核心机制点。

- 一台引擎四个消费者：**06 transform、08 报告、11 abstract、13 门控**
- Graph = pin 节点 + cell/net arc + check 边；AT 前向 max/min、RT 后向，**slack 每 pin 都有**
- Check 求值 = NLDM 查表 + launch/capture 沿配对；综合阶段 clock **ideal**，skew 靠 uncertainty 近似
- QoR 读法：**先分桶再看 WNS**；WNS 指单点瓶颈，TNS 指系统性偏紧；MCMM 取跨 corner worst
- 增量 STA 的失效扩散源是 **slew**，ε 截断换速度

---

## 下一节

- [08 综合报告解读](./08-synthesis-reports.md) — 引擎输出怎么读
- [06 细粒度优化](./06-timing-driven-optimization.md) — 引擎输出怎么消费
- [05 SDC](./05-constraints-sdc.md) — 约束怎么进入引擎
