# 2.6 细粒度优化：时序驱动门级优化

> **本章 = 细粒度优化主章**：在 **mapped 网表 + .lib 延时 + SDC** 上迭代，修 setup/hold/DRC。  
> **粗粒度**见 [03](./03-optimization.md)。  
> **配套案例**：[examples/tdo_walkthrough/](./examples/tdo_walkthrough/)（内部 delay/slack 表，非工具脚本）。

映射 [04 章](./04-technology-mapping.md) 产出初版门级网表后，综合器进入 **mapped IR + STA 驱动 transform** 阶段：在 **不改变布尔功能** 的前提下，局部调整单元类型、net 拓扑与（可选）寄存器位置，使 **时序图上的 slack 收敛**。

---

## 1. 与 03 章对比

| | 03 粗粒度 | 06 细粒度 |
|---|-----------|-----------|
| IR | AIG / 未映射 GTECH | **Mapped 标准单元网表** |
| 延时来源 | 逻辑 **level**、节点数 | **.lib cell arc + net delay 估计** |
| 优化依据 | 布尔结构代价 | **Timing graph 上的 slack / DRC 违例** |
| 典型操作 | strash、rewrite、balance | sizing、buffer、pin swap、VT swap、retiming |
| 搜索范围 | 全局 AIG 节点 | **违例锥附近的 instance / net** |

### 输入/输出案例

**输入**（04 映射刚结束）：时序图上 worst setup slack = **−0.35 ns**。

**输出**（06 若干轮 transform 后）：同一 check 的 slack = **+0.05 ns**；网表 instance 数略增（buffer / 更大驱动单元）。

---

## 2. 细粒度优化引擎（内部）

04 映射结束时，Design DB 中已有 **mapped netlist**。06 的核心是一个 **STA ↔ transform 闭环**：

```text
┌─────────────────────────────────────────────────────────────┐
│  Mapped netlist + SDC → 构建 / 更新 Timing Graph            │
│       ↓                                                     │
│  Delay Annotator：cell arc（.lib）+ net delay（WLM/物理估计）│
│       ↓                                                     │
│  STA：沿 graph 传播 AT / RT / slew → 计算 slack             │
│       ↓                                                     │
│  Violation Scanner：setup/hold/transition/cap 违例端点      │
│       ↓                                                     │
│  Transform Planner：为每个违例生成候选 transform + 优先级   │
│       ↓                                                     │
│  Apply + Incremental STA（局部重算）                        │
│       ↓                                                     │
│  until 收敛 或 effort / area 预算耗尽                        │
└─────────────────────────────────────────────────────────────┘
```

### 2.1 Mapped IR 上的时序图

时序图 **节点** = pin（port、cell pin）；**有向边** = 延时弧 + 时钟边。

| 边类型 | 延时从哪来 | 06 能否改 |
|--------|------------|-----------|
| **Cell arc** | `.lib` 中 `cell_rise/fall`（依赖 input slew、output load） | **能** — sizing / VT swap 换单元曲线 |
| **Net arc** | WLM 或物理估计：`f(length, fanout, layer)` | **能** — 插 buffer 切 net、改 fanout |
| **Clock edge** | SDC 理想时钟或 propagated skew | 综合早期多为 **ideal**；06 一般不造 skew |

**Slack 定义**（setup，max 分析）：

```text
slack_setup(pin) = required_time(pin) − arrival_time(pin)
  required  ← capture FF 的 clock 边 − setup_time + 路径例外调整
  arrival   ← launch FF 的 Q 沿 + 组合/ net 弧累加
```

Hold 用 **min** 分析：数据 **过早** 到达则 slack 为负（见 §4）。

### 2.2 延时标注的分层

| 层次 | 04 映射后 | 06 迭代中 | PnR 后 |
|------|-----------|-----------|--------|
| Cell | .lib NLDM 表 | 随 sizing **换表** | 同左 + OCV 等 |
| Net | **WLM**（线负载模型） | 物理感知时可换 **预估 RC** | **真实寄生** |
| Clock | ideal | ideal / 粗估计 | CTS 后 propagated |

04 映射已用 WLM 参与 **cut cost**；06 在 **同一 WLM 假设** 上迭代，直到换 footprint / 物理估计更新 net weight。

### 2.3 Transform 类型与内部语义

| Transform | 改什么 | 主要影响的弧 | 典型触发 |
|-----------|--------|--------------|----------|
| **Upsize** | 同功能更大驱动单元 | cell arc ↓；可能 net transition ↓ | setup 违例、critical cell |
| **Downsize** | 更小单元 | cell arc ↑；面积 ↓ | 非 critical、回收面积 |
| **Buffer insert** | 在 net 上插 BUF/INV | 原 net 拆成多段；fanout 分摊 | 高 fanout、transition/cap 违例 |
| **Pin swap** | 交换对称输入脚 | 改变 **哪条输入弧** 在关键路径上 | 单元内路径不平衡 |
| **VT swap** | LVT ↔ SVT ↔ HVT | cell delay ↔ leakage 权衡 | setup 仍负且 upsize 触顶 |
| **Retiming** | 移动 FF 位置 | **重组组合段**（见 §8） | setup 负且允许增 latency |

每个 transform 在 DB 里是 **局部 rewrite**：替换 `ref`、插入 instance、重连 net，然后 **增量 STA** 只重算受影响锥。

### 2.4 候选生成与优先级（启发式）

内部通常 **不是** 全图穷举，而是：

```text
1. 取 worst slack 路径（或 top-K critical paths）
2. 沿路径从 capture 往 launch 走，收集可改 instance / net
3. 对每个位置枚举有限候选（如 ND2D1→D2/D4，或 1~3 级 buffer）
4. 用 incremental delay 估算 Δslack，选收益/面积比最高者
5. 若 setup 与 hold 冲突，进入 multi-corner 权衡（§4.3）
```

| 优先级因子 | 含义 |
|------------|------|
| \|Δslack\| | 对 WNS 改善越大越优先 |
| 面积增量 | upsize / buffer 消耗 `max_area` 预算 |
| 副作用 | 修 setup 的 buffer 是否恶化 hold（fast corner） |
| 可逆性 | 失败 transform 回滚，试下一候选 |

### 2.5 增量 STA

每做一次 transform，若 **全芯片 STA** 代价过高。综合器维护 **timing graph 脏标记**：

- 仅 **fanout 锥** 内 pin 的 AT/RT 重算  
- cell 换型 → 该 cell 所有 arc 的 delay/slew 表重查  
- 新 buffer → 新增 node/edge，父 net 负载拆分  

这使 06 能在 compile 迭代中跑 **数百轮** 局部 transform。

### 输入/输出案例 2.1 — 映射后初态

**RTL**（见 [tdo_walkthrough/setup_critical_chain.sv](./examples/tdo_walkthrough/setup_critical_chain.sv)）：

```systemverilog
// 5 级组合 AND 链 + 1 级 FF
always_ff @(posedge clk) q <= a & b & c & d & e;
```

**04 映射后网表（片段）**：

```text
a ──► ND2D1 ──► ND2D1 ──► ND2D1 ──► ND2D1 ──► ND2D1 ──► DFF/D
```

**内部 delay 表（示意，单位 ns）**：

| 弧 | delay | 备注 |
|----|-------|------|
| clk→DFF/Q | 0.12 | launch |
| 每级 ND2D1 | 0.18 | 5 级 ≈ 0.90 |
| DFF/D setup | 0.08 | capture 要求 |
| **clock period** | 1.00 | SDC |

**Slack**：0.12 + 0.90 + 0.08 − 1.00 = **−0.35**（与 §1 案例一致）。

### 输入/输出案例 2.2 — 一轮 upsize 后

**Transform**：路径上 3 个 `ND2D1` → `ND2D4`（cell arc 各 −0.04 ns）。

**增量 STA 后**：

| 指标 | 前 | 后 |
|------|----|----|
| 组合段 delay | 0.90 | 0.78 |
| WNS | −0.35 | −0.11 |

引擎 **未停止**：仍负，继续选 buffer 或 further upsize，直至 WNS ≥ 0 或 effort 用尽。

---

## 3. Setup 修复（内部）

**Setup 违例** = 在 **max delay**  corner 下，数据 **太晚** 到达 capture FF 的 D 脚：`slack_setup < 0`。

### 3.1 关键路径上的「可改弧」

```text
launch FF ──Q──► [cell][net][cell][net]… ──► capture FF ──D
                  ↑           ↑
            upsize 这些    buffer 切 net
```

综合器从 **capture 端回溯**，标记 **slack 贡献最大** 的 arc（常是 **高 load net** 或 **弱驱动 cell**）。

### 3.2 Transform 与 setup 的对应

| 现象（内部） | 根因 | 优先 transform |
|--------------|------|----------------|
| 单 cell arc 慢 | 驱动弱 / load 大 | upsize 该 cell |
| net delay 大 | fanout 多、WLM 负载高 | buffer tree |
| 路径级数多 | 映射选深 cover | 有限 upsize；或 **retiming**（§8） |
| 全路径都 critical | period 过紧 | 需改 SDC/RTL，非纯 06 能解 |

### 3.3 与 04 mapping 的衔接

04 用 ** arrival time (AT)** 选 cover；06 发现 **实际 WNS 仍负** 时，在 **已选 cover 之上** 做 **局部 sizing**，不再回到 AIG rewrite（那是 03 的事）。

### 输入/输出案例 3.1 — critical cell 标记

**违例路径（内部 trace）**：

```text
reg_a/CK → reg_a/Q → u_u1/Z → n12 → u_u2/Z → … → reg_b/D
                              ↑
                         slack 贡献 −0.12 ns（最大）
```

**Transform 队列（示意）**：

| 顺序 | 位置 | 候选 | 预估 ΔWNS |
|------|------|------|-----------|
| 1 | u_u2 | ND2D1→ND2D4 | +0.10 |
| 2 | n12 | 插 BUFFD2 | +0.06 |
| 3 | u_u1 | pin swap | +0.02 |

应用 #1 后增量 STA → 若 WNS 仍负，继续 #2。

---

## 4. Hold 修复（内部）

**Hold 违例** = 在 **min delay** corner 下，数据 **太早** 到达 capture FF：`slack_hold < 0`。

### 4.1 Setup 与 Hold 的方向相反

| Check | 怕什么 | 修什么 |
|-------|--------|--------|
| Setup (max) | 路径 **太慢** | 加快路径：upsize、减 load |
| Hold (min) | 路径 **太快** | **拖慢** 路径：delay cell、downsize、插 buffer |

同一 net 上：**修 setup 的 upsize** 可能 **恶化 hold**（数据更快到达）。

### 4.2 多 corner 内部聚合

Design DB 上同时挂 **多套 delay annotation**（slow/max、fast/min 等）：

```text
transform T 被接受 ⟺
  在相关 corner 上 setup slack ≥ 0（或改善 WNS）
  AND hold slack ≥ 0（或 THS 不恶化）
  AND DRC 满足
```

故 06 常在 **fast min** 上发现 hold 违例，而 setup 在 **slow max** 上已勉强闭合 — 引擎在 **hold 违例 net 近 capture 端** 插 **delay chain**。

### 4.3 Setup/Hold 冲突案例

**场景**：修 setup 在 `n48` 上 upsize driver，`n48` 直连 capture FF。

| Corner | 操作前 | upsize 后 |
|--------|--------|-----------|
| slow max setup | −0.05 | +0.08 ✓ |
| fast min hold | +0.02 | **−0.06** ✗ |

**内部决策**：回滚 upsize，或在该 FF 前 **专用 hold buffer / DELAY 单元**（只增 min delay，对 max 影响较小）。

### 输入/输出案例 4.1 — hold 违例定位

**路径（min 分析）**：

```text
launch ──► 2 级 ND2 ──► capture FF/D
组合 delay（fast corner）= 0.08 ns ≪ hold 要求 0.15 ns
→ slack_hold = −0.07 ns
```

**Transform**：capture 前插入 `DELAYX1`（min delay +0.10 ns），setup 路径仅 +0.02 ns → 两 corner 均闭合。

---

## 5. 转换与电容 DRC（内部）

除 setup/hold 外，时序图上还有 **电气 DRC**：**max transition**、**max capacitance** 等。它们在 DB 里是 **pin/net 上的约束节点**，违例时 slack 优化可能 **无法进行**（slew 无效导致 .lib  extrapolation）。

### 5.1 违例如何进入引擎

| DRC | 内部检查点 | 常见根因 |
|-----|------------|----------|
| Max transition | driver output slew > limit | fanout 过大、弱驱动 |
| Max capacitance | net 总 C > limit | 长 net（WLM）、多 fanout |

Violation Scanner 与 timing 违例 **同一队列**；有时 **先修 DRC** 再修 WNS（否则 delay 表不可信）。

### 5.2 Buffer tree 生成（概念）

对高 fanout net `n`：

```text
        driver
       /  |  \
      B   B   B      ← 插入 buffer 层，使每段 fanout ≤ F_max
     /|\ /|\ /|\
   loads ...
```

算法目标（启发式）：

- 每段 net **cap / transition** 低于 limit  
- buffer 级数尽量少（面积）  
- 尽量 **不** 使原 critical setup 路径变长太多  

与 **clock tree** 不同，这是 **数据 net 的局部 buffer tree**，在 06 pass 内完成。

### 输入/输出案例 5.1

**内部状态**：net `n123` fanout=32，estimated C=0.35 pF，limit=0.20 pF，transition 违例。

**Transform**：在 driver 后插 1→4 buffer，再各自驱动 8 load → 每子 net C≈0.08 pF。

**副作用检查**：incremental STA 确认 critical path 未经过 `n123` → 接受；若 critical → 选 **更大驱动 + 更浅树** 或 upsize driver。

---

## 6. 物理感知（内部）

综合后期，部分工具在 DB 中增加 **布局/布线估计层**（非 PnR 真结果）：

```text
Mapped netlist
    + floorplan 粗框 / 宏位置 / 密度图
    + global route 估计（拥塞热力图）
    → 更新 net delay / net weight
    → 06 transform 优先修「又长又 congested」的 net
```

| 估计量 | 如何影响 06 |
|--------|-------------|
| **Net length** | 替换 WLM 常数 → 更长 net 更高 delay 惩罚 |
| **Congestion** | 高拥塞区域 **提高插入 buffer 的成本** 或禁止过密 sizing |
| **Cell density** | 引导换 **更小 footprint** 单元 |

**边界**：综合阶段仍是 **估计**；真寄生与 SI 在 PnR 后 STA。06 的目标是把 **明显不可布** 的长线/高扇出 提前修掉，减少后端迭代。

### 输入/输出案例 6.1

**内部**：net `ddr_addr[15]` 估计 length=800 μm，拥塞 score=0.9（高）。

**无物理感知**：WLM 仅按 fanout 估 delay → slack 看似满足。

**有物理感知**：该 net delay **×1.4 权重** → WNS 变负 → 06 在其 driver 插 buffer 并 upsize，或建议 RTL 寄存器切分（与 retiming 协同）。

---

## 7. 与 05 约束、07 内部量

| 模块 | 06 消费什么 |
|------|-------------|
| [05 SDC](./05-constraints-sdc.md) | clock 边、IO delay、false/multicycle → **required time** |
| [07 报告](./07-synthesis-reports.md) | WNS/TNS、buffer 占比 — 反映 **哪类 transform** 曾大量发生 |

### 输入/输出案例 7.1 — 违例类型 → 引擎分支

| 内部违例标签 | 06 主分支 |
|--------------|-----------|
| `setup_violation` | §3 sizing / buffer；必要时 §8 retiming |
| `hold_violation` | §4 delay / downsize |
| `transition_violation` | §5 buffer tree |
| `cap_violation` | §5 同左 |

---

## 8. Retiming（寄存器搬移 / 流水线重平衡）

**Retiming** 在 **不改变每个逻辑锥布尔功能** 的前提下，**移动寄存器位置**（或增删寄存器），以 **平衡组合逻辑级数**、改善 setup。**属于时序驱动的顺序优化**，在 **mapped 网表** 上执行，与 [03](./03-optimization.md) 的 AIG 组合优化 **正交**。

### 8.1 在做什么（内部）

```text
组合云 C1 ──FF── 组合云 C2 ──FF── 组合云 C3

        │ retiming（把 FF 跨过组合逻辑）
        ▼
组合云 C1' ──FF── 组合云 C2' ──FF── 组合云 C3'
  （C1+C2 变短、C3 变长，或中间多/少一级 FF）
```

| 概念 | 说明 |
|------|------|
| **搬移方向** | 将 FF 从 **快段** 移到 **慢段** 前/后，削峰填谷 |
| **功能** | 同一时钟沿下 **逻辑关系** 保持（在形式化假设下） |
| **延迟（latency）** | 输入到输出 **周期数可能变化** — 与 RTL 流水线设计不同 |
| **面积** | 寄存器总数可能 **略增/略减** |

**内部实现要点**：在 **时序图** 上识别 **可移动 FF**（无 async 控制冲突、无 dont_retime 属性），做 **min-cut / 平衡组合 delay** 的寄存器重分配，然后 **重建 timing graph** 再进入 §2 的 sizing 环。

### 8.2 与 RTL 流水线、粗优化的区别

| | RTL 手写 pipeline | Retiming（综合） | 03 AIG balance |
|---|-------------------|------------------|----------------|
| 谁加寄存器 | 设计师 | 工具自动 | 不加 FF，只改 AND 树深度 |
| 接口 latency | 规格定义 | **可能变** — 需系统确认 | 不变 |
| 依据 | 架构 | **STA slack** | 节点/level |

### 输入/输出案例 8.1 — 长组合链

**RTL 输入**（单周期大组合）：

```systemverilog
always_ff @(posedge clk) q <= f(g(h(a)));
// 假设 h→g→f 组合过深，单周期 WNS 负
```

**Retiming 后网表（概念）**：

```text
a ──FF── h ──FF── g ──FF── f ──FF── q   （2 周期 latency，每段组合变浅）
```

| 指标 | Retiming 前 | 后 |
|------|-------------|-----|
| 组合 depth | 整条路径 | 分段 |
| WNS | -0.2ns | +0.1ns（示意） |
| 周期延迟（I/O） | 1 cycle | **可能 2+ cycles** |

**若系统要求固定 latency**：RTL 固定流水级，或在 DB 上对 instance 设 **dont_retime** 属性（综合器跳过该 FF）。

### 输入/输出案例 8.2 — 与 sizing 分工

**输入**：关键路径已 upsize 仍 WNS = -0.05ns

**输出**：retime 后 **搬移/插入 1 级 FF**，WNS = +0.15ns，**寄存器数** +N。

| 手段 | 适用 |
|------|------|
| sizing/buffer | 组合仍过深但 **不宜加周期** |
| retiming | 允许 **增加寄存器级数** 换频率 |

### 8.3 内部控制属性

| DB 属性 / 约束语义 | 对 retiming 引擎 |
|--------------------|------------------|
| **dont_retime** | 该 FF/区域 **不可移动** |
| **dont_touch** | 常连带禁止 retime |
| **multicycle** | 改变有效 period，与 retime 交互需 **一致化** |
| **latency 敏感接口** | Handshake/FIFO 指针等应标记 dont_retime |

### 输入/输出案例 8.3

**输入**：FIFO 指针逻辑带 dont_retime。

**输出**：retime 仅发生在 datapath；指针 **FF 拓扑不变**，时序图该子图 **隔离**。

### 8.4 与 LEC（[09 章](./09-logical-equivalence-checking.md)）

| 情况 | LEC 内部问题 |
|------|--------------|
| RTL 无流水、网表 retime 后 | **FF 数量/位置** 变化 → 需 **sequential equivalence** 与状态映射 |
| RTL 已含同等流水 | compare point 易对齐 |
| 失败 | 常为 **比对点不匹配**，非组合功能错 |

### 输入/输出案例 8.4

**输入**：RTL 1 级 FF，网表 3 级 FF（retime 插入）。

**输出**：LEC 需 **识别 retiming 配对**（综合器可导出 **等价性引导信息**）；否则 miter 中 **unmatched FF**。

### 8.5 与 DFT、层次化

| 交互 | 说明 |
|------|------|
| **DFT** | Scan 在 retime **之后** 插入；FF 顺序变 → **scan 链重排** |
| **层次** | 子块 dont_retime 后，顶层 retime 仅 **胶水逻辑** |

见 [11 DFT](./11-dft-and-scan.md)、[10 层次](./10-hierarchical-block-synthesis.md)。

### 8.6 内部可观测信号

| 现象 | 含义 |
|------|------|
| 寄存器数增加 | 插入 pipeline |
| WNS 改善、I/O latency 变 | 正常；需与规格对照 |
| retime 无效 | dont_retime、路径已平衡、或组合环 |

---

## 9. 何时停止迭代

| 状态 | 含义 |
|------|------|
| 各 corner setup slack ≥ 0 | max 分析闭合 |
| 各 corner hold slack ≥ 0 | min 分析闭合 |
| DRC 无违例 | transition/cap 等 |
| `max_area` 触顶 | upsize/buffer 预算耗尽 |
| effort 上限 | 需改 RTL / 约束 / 架构 |

---

## 10. 小结

细粒度优化 = 在 **mapped IR** 上运行 **STA ↔ transform 闭环**（§2），按违例类型分支（§3–§5），可选 **物理估计**（§6）与 **retiming**（§8）。依赖 [05](./05-constraints-sdc.md) 建立的时序图语义，与 [03](./03-optimization.md) **互补**。

---

## 下一节

- [07 综合报告](./07-synthesis-reports.md)
- [03 粗粒度](./03-optimization.md)
- [examples/tdo_walkthrough/](./examples/tdo_walkthrough/)
