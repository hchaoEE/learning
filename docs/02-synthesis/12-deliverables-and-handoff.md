# 2.12 综合交付物与后端交接

`compile`、LEC、DFT 完成后，需向后端（PnR）与签核团队交付 **一致、可重现** 的文件包。本章列出 **交付清单、版本一致性、签核门控**。

---

## 1. 标准交付清单

| 文件 | 内容 | DB / 内部语义 |
|------|------|---------------|
| **门级网表** `*.v` | mapped Verilog | Design DB 序列化 |
| **SDC** `*.sdc` | 约束 | timing graph 文本形式 |
| **UPF** `*.upf` | 低功耗意图 | power intent 层 |
| **DDC/NDM** | 工具数据库 | 同工具链增量 |
| **SDF**（可选） | 延时标注 | 仿真 |
| **SVF / 变换日志** | 综合结构变换记录 | LEC 匹配引导（[09 §6](./09-logical-equivalence-checking.md#6-综合引导信息transformation-log)） |
| **LEC 报告** | 等价性 | 质量门控 |
| **Scan DEF/CTL**（若 DFT） | 链定义 | ATPG、PnR |
| **综合报告** | QoR 摘要 | 项目管理 |

> **SPEF**（真实寄生）**不是综合产出** — 它是 PnR 后从布线结果抽取、回传给签核 STA 的文件，属交接链的下一环，不列入本清单。

### 输入/输出案例

**输入**：`release/synth_v1.2/` 目录

**输出**：PnR 脚本 `read_verilog ../synth_v1.2/chip.mapped.v` + `read_sdc ../synth_v1.2/chip.sdc`

| 缺件 | 后果 |
|------|------|
| 无 SDC | PnR **无目标** |
| 网表与 SDC 版本不一 | **虚假违例** |

---

## 2. 版本、Corner 与 MCMM 一致性

交付包须使 PnR/STA 与综合 **同一 topology、同一 corner/mode 集**。

### 2.1 必须对齐项

| 须一致 | 不一致后果 |
|--------|------------|
| `.lib` corner 集 | delay **系统性偏差** |
| max/min `operating_conditions` | setup/hold **签核错位** |
| **MCMM mode**（functional/test） | scan 路径 **未检** 或 **虚假违例** |
| RTL git tag | 无法追溯 **哪次 compile** |
| 工具 build id | DB 语义差异 |

### 2.2 MCMM 表（概念字段）

| 字段 | 含义 |
|------|------|
| **Mode** | functional / test → 不同 power state、clock |
| **Corner** | slow_max / fast_min → `.lib` + voltage + temperature |
| **Constraint view** | 该 mode 下 **生效的 SDC 子集** |
| **Delay annotation** | 该 corner 的 cell/net 查表 |

### 输入/输出案例 2.1

**综合 DB**：`slow_0p90_max` + `fast_0p90_min` 闭合。  
**PnR 后 STA**：须读 **同一对** `.lib` + **同一 mode**；若仅用 `typ` signoff → 与综合 **不可比**。

详见 [05 §6 MCMM](./05-constraints-sdc.md#6-mcmm多-corner-在-db-上的挂接)。

---

## 3. 签核门控（Quality Gates）

```text
□ Design DB：elaboration / check_design 无 ERROR
□ timing graph：无 unclocked FF（05 §2）
□ WNS/TNS / hold：各 MCMM corner 闭合（06）
□ transition/cap：DRC 无违例（06 §5）
□ LEC：miter UNSAT（09）
□ DFT：scan IR 完成（若适用）（11）
□ 推断：LATCH 计数=0（02/07）
□ UPF：域标注与 LS/ISO 实例一致（08）
```

### 输入/输出案例

**Release checklist 一项失败**：

```text
LEC: 3 failing points → 禁止 handoff
```

---

## 4. 网表交付格式注意

```verilog
// 须声明
`timescale 1ns/1ps
module chip ( clk, rst_n, ... );
  // 禁止手工编辑：no /* synthesis */
endmodule
```

| 项 | 说明 |
|----|------|
| 去 `translate_off` 区域 | 仅交付可综合网表 |
| 单元名 | 来自目标 `.lib` |
| 勿删 `dont_touch` 宏 | 与综合一致 |

---

## 5. SDC 交付

- **与网表同名** 或 `chip.sdc` 明确 `current_design`  
- 含 **clock、IO、exception、case_analysis**（若用）  
- **勿含** 仅综合临时 `set_max_area 0` 等实验命令  

### 输入/输出案例

**输入**：综合输出 `chip.final.sdc`（已 `write_sdc`）

**输出**：PrimeTime `read_sdc` 后 `check_timing` 无 **no clock** 警告。

---

## 6. 与 PnR 的物理信息

综合阶段可选交付：

| 文件 | 用途 |
|------|------|
| **Floorplan DEF**（早期） | 宏位置、拥塞预算 |
| **Physical constraints** | region、placement blockages |
| **TLU+** 早期估计 | 物理综合 |

见 [03-pnr](../03-pnr/)。

---

## 7. 仿真用网表

| 类型 | 说明 |
|------|------|
| Zero-wire SDF | 功能仿真 |
| 综合 SDF | 粗略时序 |
| 签核 SDF | PnR+SPEF 后 |

### 输入/输出案例

**输入**：`zero_wire_load` 综合

**输出**：SDF **偏乐观** — 仅用于 **bring-up**，签核必须用 **PnR SDF**。

---

## 8. ECO 与增量综合

交付（甚至 PnR）之后发现功能 bug 或小幅 spec 变更，**不重跑全量 compile**，走 ECO 流：

```text
RTL diff（新旧版本）
    │  定位受影响逻辑锥（fanin/fanout 闭包）
    ▼
Incremental compile：只重综合受影响锥
    │  未受影响区域 dont_touch（保持原网表名字与结构）
    ▼
ECO netlist（与旧网表差异最小化）
    │
    ├──► 增量 LEC：旧 I ↔ 新 I（仅比受影响锥；呼应 09 §1 表 ECO 行）
    └──► 新 RTL ↔ 新 I 全量或分治 LEC
```

| 内部要点 | 说明 |
|----------|------|
| **差异最小化** | 目标不是 QoR 最优，而是 **改动 cell/net 数最少** — 后端可手工/脚本 ECO，不必重新 PnR |
| **名字保持** | 未动区域 instance/net 名与旧网表一致，否则 PnR 侧无法对位 |
| **冻结约束** | 已布线区域（若 PnR 后 ECO）的 cell 位置/层资源受限 → 综合侧只允许 **同 footprint 换型 / 小锥重组** |
| **寄存器不可增删**（freeze 模式下） | 增 FF = 时钟树/scan 链都要改 → 通常禁止，或走完整 re-spin |
| **DFT 同步** | 受影响锥含 scan FF 时，scan 链顺序须保持或重新声明（11） |

**与 PnR 侧 spare cell ECO 的分工**：综合侧产出 **逻辑上正确且差异最小** 的 ECO netlist；如何用 spare cell / 金属层改动实现，属 PnR 范围（见 [03-pnr](../03-pnr/)）。

### 输入/输出案例 8.1

**输入**：v1.2 已交付；RTL 改一处比较条件 `>=` → `>`（单模块内）。

**输出（增量 compile）**：

| 指标 | 全量重综合 | ECO 增量 |
|------|-------------|----------|
| 改动 cell 数 | ~6200（全部重命名重排） | **3**（一个比较锥内换门） |
| LEC 范围 | 全设计 | 受影响锥 + 边界 |
| PnR 动作 | 重新布局布线 | 局部 ECO route |

---

## 9. 综合「方方面面」索引

| 你想了解 | 章节 |
|----------|------|
| RTL 怎么读入 | 01 |
| 寄存器/RAM/FSM 怎么来 | 02 |
| AIG / 粗优化 / datapath 重组 | 03 |
| 映射 | 04 |
| 约束 | 05 |
| 修 setup/hold、multibit banking | 06 |
| 读内部量 / 阶段诊断 | 07 |
| 低功耗 | 08 |
| **LEC** | **09** |
| 分块综合 / boundary optimization | 10 |
| **DFT/scan** | 11 |
| **交什么文件** | **12（本章）** |
| **交付后改 bug（ECO）** | 12 §8 |

---

## 10. 小结

交付 = **网表 + SDC +（UPF）+ LEC + 报告 + 版本说明**；**corner 一致** 是 PnR 成功前提；交付后小改走 **ECO 增量**（§8）而非全量重综合。

---

## 下一节

- [03-pnr](../03-pnr/)
- [09 LEC](./09-logical-equivalence-checking.md)
- [00 总览](./00-synthesis-overview.md)
