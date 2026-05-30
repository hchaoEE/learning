# 2.6 细粒度优化：时序驱动门级优化

> **本章 = 细粒度优化主章**：在 **mapped 网表 + .lib 延时 + SDC** 上迭代，修 setup/hold/DRC。  
> **粗粒度**见 [03](./03-optimization.md)。

映射 [04 章](./04-technology-mapping.md) 产出初版门级网表后，**真实单元延时** 已知；本章用 **时序 slack** 驱动 **局部** 变换。

---

## 1. 与 03 章对比

| | 03 粗粒度 | 06 细粒度 |
|---|-----------|-----------|
| IR | AIG / 未映射 | Mapped gates |
| 依据 | 节点数、level | **.lib delay、SDC slack** |
| 操作 | rewrite、balance | **sizing、buffer、retiming、VT swap** |
| 典型命令阶段 | `compile` 中期 | `compile_ultra` 迭代后期 |

### 输入/输出案例

**输入**：映射后 WNS = -0.35ns（setup 违例）

**输出**：插 3 级 buffer、2 处 upsize 后 WNS = +0.05ns。

---

## 2. `compile` 迭代模型（概念）

```text
loop:
  STA（WLM 或 物理估计）
  找 critical path / 违例端点
  应用 transform（细粒度）
  until 收敛或 达到 effort 上限
```

| Transform | 作用 |
|-----------|------|
| **Upsize** | 换更大驱动单元 → delay↓ |
| **Downsize** | 面积回收 |
| **Buffer insertion** | 切分 net，降 transition / delay |
| **Pin swap** | 交换等价输入脚，均衡延时 |
| **VT swap** | LVT ↔ HVT 权衡漏电与速度 |

### 输入/输出案例

**输入**：关键路径仅含 `ND2D1` 链

**输出**：关键单元换 `ND2D2` / `ND2D4`，slack 改善。

---

## 3. Setup 修复

**Setup 违例**：数据路径太长，launch→capture 来不及。

| 手段 | 说明 |
|------|------|
| 减小组合延时 | upsize、减 level（有限） |
| 减 fanout | 插 buffer 树 |
| 减线负载估计 | 物理综合（见下） |

**不能** 单靠加大时钟周期（除非改 SDC）。

### 输入/输出案例

**输入**：`report_timing -max` 显示 `u_alu/U123` 为 critical

**输出**：该单元及下游 2 级 upsize；WNS 从负变正。

---

## 4. Hold 修复

**Hold 违例**：数据 **太快** 到达，capture 沿前稳定时间不足。

| 手段 | 说明 |
|------|------|
| **Delay cell** | 插入专用缓冲/delay |
| 降驱动 | downsize 数据路径 |
| 增 min delay 路径 | 与 max corner 配合 |

Hold 常在 **fast corner** 出现；需 `set_operating_conditions -min`。

### 输入/输出案例

**输入**：`report_timing -min` hold slack = -0.08ns

**输出**：在违例捕获 FF 前插 `DELAYX1` 链。

---

## 5. 转换与电容 DRC

```tcl
set_max_transition 0.5 [current_design]
set_max_capacitance 0.2 [current_design]
```

| 违例 | 修复 |
|------|------|
| Max transition | 插 buffer、upsize driver |
| Max capacitance | 同上 |

### 输入/输出案例

**输入**：net `n123` transition = 0.8ns，limit 0.5ns

**输出**：在该 net 上插 2 个 `BUFFD1`。

---

## 6. 物理感知（Physical Synthesis，简述）

Fusion / DC-topographical、Genus 等可读 **拥塞 / 布线估计**：

| 输入 | 细粒度动作 |
|------|------------|
| 高拥塞区域 | 降密度、插 buffer、换 footprint |
| 长线 net | 更强驱动 |

完整 **布线延时** 在 PnR 后 STA；综合阶段为 **估计**。

---

## 7. 与 05 SDC、07 报告

- **05**：定义时钟、例外；06 消费 slack  
- **07**：`report_constraint`、`report_timing` 解读违例来源  

### 输入/输出案例

**输入**：`report_constraint -all_violators`

**输出**：

```text
max_transition  (violating nets: 12)
setup            (WNS: -0.12)
hold             (THS: -0.03)
```

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

**工具**：DC `set_optimize_registers` / `compile_ultra` 内 **auto retime**；Genus 等效选项。

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

**若系统要求固定 latency**：在 RTL 固定流水级，或 `set_dont_retime` 禁止搬移。

### 输入/输出案例 8.2 — 与 sizing 分工

**输入**：关键路径已 upsize 仍 WNS = -0.05ns

**输出**：工具启用 retime 后 **插入/搬移 1 级 FF**，WNS = +0.15ns，**面积** +N 个 DFF。

| 手段 | 适用 |
|------|------|
| sizing/buffer | 组合仍过深但 **不宜加周期** |
| retiming | 允许 **增加寄存器级数** 换频率 |

### 8.3 约束与控制

```tcl
# Synopsys 概念示例
set_optimize_registers true
set_optimize_registers -design cpu_core
# 禁止某区域 retime
set_dont_retime [get_cells u_ctrl/*]
# 与 dont_touch 配合
set_dont_touch [get_cells u_mem_macro]
```

| 命令/属性 | 作用 |
|-----------|------|
| `set_optimize_registers` | 允许综合 **自动 retime** |
| `set_dont_retime` | 保护 **latency 敏感** 逻辑（握手、配置寄存器） |
| `set_multicycle_path` | 与 retime 交互需 **人工核对** |

### 输入/输出案例 8.3

**输入**：FIFO 指针逻辑 `set_dont_retime [get_cells u_fifo/*]`

**输出**：retime 仅发生在 `u_datapath`，FIFO **指针时序不变**。

### 8.4 与 LEC（[09 章](./09-logical-equivalence-checking.md)）

| 情况 | LEC |
|------|-----|
| RTL 无流水、网表 retime 后 | 常需 **SVF + retime 标注** 或 **cycle-accurate 等价** 配置 |
| RTL 已含同等流水 | 易 pass |
| 失败 | 比对点 **FF 数量/位置** 不一致 — 非功能错，是 **映射点** 问题 |

**签核实践**：对允许 retime 的 block，用 **Formality `set_verification` retiming** 模式，或 **RTL 也启用对应 pipeline**。

### 输入/输出案例 8.4

**输入**：RTL 1 级 FF，网表 3 级 FF（retime 插入）

**输出**：无 SVF 时 LEC **unmatched points**；读 SVF 后 **sequential equivalence PASS**。

### 8.5 与 DFT、层次化

| 交互 | 说明 |
|------|------|
| **DFT** | Scan 链在 retime **之后** 插入；retime 改变 FF 顺序 → **重排 scan** |
| **层次** | 子块 `dont_retime` 后做顶层 retime 仅 **胶水逻辑** |

见 [11 DFT](./11-dft-and-scan.md)、[10 层次](./10-hierarchical-block-synthesis.md)。

### 8.6 报告与调试

```tcl
report_timing -retime
# 或 QoR 日志中 "Retiming: moved N registers"
```

| 现象 | 含义 |
|------|------|
| 寄存器数增加 | 插入 pipeline |
| WNS 改善、latency 变 | 正常；查规格 |
| retime 无效 | `dont_retime`、路径已平衡、或组合环 |

---

## 9. 何时停止迭代

| 状态 | 含义 |
|------|------|
| WNS/TNS ≥ 0 | setup 满足（当前 corner） |
| Hold 满足 | min corner 通过 |
| `max_area` 触顶 | 面积约束阻止继续 upsize |
| `compile` effort 用尽 | 需改 RTL/约束/流程 |

---

## 10. 小结

细粒度 = **mapped 网上的局部修补**（含 **retiming** 搬移寄存器）；依赖 **SDC + .lib**；与 03 **互补**。

---

## 下一节

- [07 综合报告](./07-synthesis-reports.md)
- [03 粗粒度](./03-optimization.md)
