# 2.13 综合交付物与后端交接

> **本章回答**：综合结束要交什么、如何保证 PnR 能接上。
> **读完应能**：① 列出最小交付包 ② 说清 corner/MCMM 锁步 ③ 知道 ECO 与 manifest 关系
> **先修**：[05](./05-constraints-sdc.md)、[10](./10-logical-equivalence-checking.md) · **难度**：★★☆☆☆ · **walkthrough**：—

`compile`、LEC、DFT 完成后，需向后端（PnR）与签核团队交付 **一致、可重现** 的文件包。本章列出 **交付清单、版本一致性、签核门控**。

---

## 1. 标准交付清单
> **一句话**：标准交付清单——本章核心机制点。

| 文件 | 内容 | DB / 内部语义 |
|------|------|---------------|
| **门级网表** `*.v` | mapped Verilog | Design DB 序列化 |
| **SDC** `*.sdc` | 约束 | timing graph 文本形式 |
| **UPF** `*.upf` | 低功耗意图 | power intent 层 |
| **DDC/NDM** | 工具数据库 | 同工具链增量 |
| **SDF**（可选） | 延时标注 | 仿真 |
| **SVF / 变换日志** | 综合结构变换记录 | LEC 匹配引导（[10 §6](./10-logical-equivalence-checking.md#6-综合引导信息transformation-log)） |
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

### 1.1 层次化设计的分包结构

分块综合（[11 章](./11-hierarchical-block-synthesis.md)）时交付不是一个包，而是 **块包 × N + 顶层包**，且版本须 **锁步**：

```text
release/synth_v1.2/
├── blocks/
│   ├── cpu_core/   ── netlist + block SDC + abstract(ILM/ETM) + 块 LEC 报告 + scan CTL
│   └── dsp/        ── 同上
├── top/            ── glue netlist + 顶层 SDC + 块实例化关系 + 顶层 LEC（块黑盒化）
└── manifest        ── 各块 revision ↔ abstract revision ↔ 顶层所引版本 的绑定表（§2.3）
```

| 锁步规则 | 违反后果 |
|----------|----------|
| 顶层引用的 abstract 必须由 **同 revision 块网表** characterize（11 §3.3） | 顶层 STA 数字与真实块不符 — 最隐蔽的交付事故 |
| 块重综合 → abstract、块 LEC、scan CTL **三件同步重发** | 旧 abstract + 新网表 = 接口时序假闭合 |
| 块 SDC 的 budget 版本与顶层分配记录一致（11 §4.1） | 双方对同一接口各自假设 → timing debt 无人认领 |

| **DFT 交付细项**（呼应 [12 章](./12-dft-and-scan.md)） | 内容 |
|---|------|
| Scan protocol 文档 | 链数、每链长度、SI/SO/SE 端口映射、压缩结构（内链数、压缩比） |
| **Test mode SDC**（独立 constraint view） | test clock、shift/capture case 设定 — 与 functional SDC 配对交付（05 §6 mode 表） |
| OCC 控制说明 | at-speed capture 时钟序列 |

### 输入/输出案例 1.1 — abstract 与块 revision 锁步

**输入**：`cpu_core` 重综合为 `rev_B`；顶层仍引用 `abstract_rev_A`。

| manifest 项 | rev_A（旧） | rev_B（新） | 顶层引用 |
|-------------|-------------|-------------|----------|
| 块网表 | v1.1 | **v1.2** | v1.1 |
| abstract | ILM_A | **须重发 ILM_B** | **ILM_A** ← 错 |

**输出**：顶层 STA 用旧 ILM → 接口 **假闭合**；须 manifest 绑定 **同 revision 三件**（网表 + abstract + 块 LEC）。

---

## 2. 版本、Corner 与 MCMM 一致性
> **一句话**：版本、Corner 与 MCMM 一致性——本章核心机制点。

交付包须使 PnR/STA 与综合 **同一 topology、同一 corner/mode 集**。

### 2.1 必须对齐项

| 须一致 | 不一致后果 |
|--------|------------|
| `.lib` corner 集 | delay **系统性偏差** |
| max/min `operating_conditions` | setup/hold **签核错位** |
| **MCMM mode**（functional/test） | scan 路径 **未检** 或 **虚假违例** |
| RTL git tag | 无法追溯 **哪次 compile** |
| 工具 build id | DB 语义差异 |

### 输入/输出案例 2.1 — corner 集错位

**输入**：综合 signoff `slow_max`+`fast_min`；PnR STA 仅读 `typ`。

**输出**：WNS 符号可能 **翻转** — 综合 +0.05、签核 −0.08 并非「退化」，是 **lib 未对齐**。

### 2.2 MCMM 表（概念字段）

| 字段 | 含义 |
|------|------|
| **Mode** | functional / test → 不同 power state、clock |
| **Corner** | slow_max / fast_min → `.lib` + voltage + temperature |
| **Constraint view** | 该 mode 下 **生效的 SDC 子集** |
| **Delay annotation** | 该 corner 的 cell/net 查表 |

### 输入/输出案例 2.2 — functional vs test mode

**输入**：MCMM 表仅列 `func_slow_max`；漏 `test_fast_min`（scan shift）。

| mode | constraint view | 后果 |
|------|-----------------|------|
| functional | `chip_func.sdc` | 功能闭合 |
| **test** | **缺失** | shift 路径 **未 STA** → 硅片 fail |

**输出**：交付须 **mode × corner** 全表 + 各 mode 的 SDC 子集（[12 §6](./12-dft-and-scan.md#6-约束语义test-mode)）；corner 对齐见上 **案例 2.1** 与 [05 §6 MCMM](./05-constraints-sdc.md#6-mcmm多-corner-在-db-上的挂接)。

### 2.3 可重现性 manifest（compile 重现包）

「能 `read_verilog` 」≠「能 **重现这次 compile**」— ECO 增量（§8）与事故追溯都要求后者。重现最小集：

| 项 | 为什么少了不行 |
|----|------------------|
| RTL 文件清单 + **内容 hash**（或 git tag） | tag 可被移动；hash 才唯一 |
| `.lib` 全集（含版本号）+ corner→lib 映射 | 同名 lib 不同 patch → delay 不同 → transform 序列分叉 |
| MCMM scenario 表（mode × corner × SDC 文件） | 缺一个 mode → hold 修复行为不同 |
| UPF 版本 | 特殊单元插入位置变 |
| 工具 build id + 关键策略变量 | 启发式版本不同 → 结果不可比 |
| **属性导出**：`dont_touch` / `dont_use` / `size_only` 全集 | 这些常在交互式会话设置，**不在 SDC 里** — 丢失后 ECO 重综合会动不该动的区域 |
| 原始约束 vs `write_sdc` 导出的 **差异说明** | 工具导出会展开通配/补默认值 — 两者语义近似但不相同，回读须用哪份要写明 |

### 输入/输出案例 2.3

**场景**：流片前 ECO（§8）需对 v1.2 做增量 compile。

| manifest 完整 | manifest 缺 dont_touch 导出 |
|----------------|------------------------------|
| 重建会话 → 增量 compile 只动目标锥 → 3 cell 差异 | 重建会话丢失 36 个 dont_touch → compile「顺手优化」了冻结区 → 6,200 cell 差异，PnR 侧 ECO 不可行 |

---

## 3. 签核门控（Quality Gates）
> **一句话**：签核门控（Quality Gates）——本章核心机制点。

```text
□ Design DB：elaboration / check_design 无 ERROR
□ timing graph：无 unclocked FF（05 §2）
□ WNS/TNS / hold：各 MCMM corner 闭合（06）
□ transition/cap：DRC 无违例（06 §5）
□ LEC：miter UNSAT（10）
□ DFT：scan IR 完成（若适用）（12）
□ 推断：LATCH 计数=0（02/08）
□ UPF：域标注与 LS/ISO 实例一致（09）
```

**对外交付的不只是布尔 checklist** — 后端需要「带证据的 release」：

| 附件 | 内容 | 呼应 |
|------|------|------|
| **STA/QoR 摘要** | 每 MCMM corner 的 WNS/TNS/THS、违例 endpoint 数、面积/功耗分项 | 07 §6、08 §5–§6 |
| **Waiver 清单** | 已知且接受的违例（路径、原因、批准人）— timing/DFT/UPF 各一节 | LEC abort 的 waiver 见 10 §5.3 |
| **约束完整性报告** | unclocked FF 数、空对象集 SDC 命令、unconstrained endpoint 列表 | 05 §8、07 §5 |

Waiver 不是「忽略」：PnR/签核侧须 **继承同一份 waiver**，否则下游重新发现 → 重复诊断成本。

### 输入/输出案例

**Release checklist 一项失败**：

```text
LEC: 3 failing points → 禁止 handoff
LEC: 2 aborted points + 已批准 waiver（datapath 宏，块级已证）→ 可放行，waiver 随包交付
```

---

## 4. 网表交付格式注意
> **一句话**：网表交付格式注意——本章核心机制点。

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

### 输入/输出案例 4.1 — 网表可读性门控

**输入**：`write_verilog` 输出缺 `` `timescale ``、单元名 `*/` 通配未展开。

| 检查项 | 通过 | 失败后果 |
|--------|------|----------|
| `` `timescale 1ns/1ps `` | ✓ | 仿真/STA delay 单位歧义 |
| 单元名 = `.lib` cell | ✓ | PnR **找不到 ref** |
| 无 `translate_off` 残留 | ✓ | 综合垃圾进网表 |

**输出**：PnR `read_verilog` 报错或静默错连 — 交付前跑 **lint + 抽样 instantiate**。

---

## 5. SDC 交付
> **一句话**：SDC 交付——本章核心机制点。

- **与网表同名** 或 `chip.sdc` 明确 `current_design`  
- 含 **clock、IO、exception、case_analysis**（若用）  
- **勿含** 仅综合临时 `set_max_area 0` 等实验命令  

### 输入/输出案例

**输入**：综合输出 `chip.final.sdc`（已 `write_sdc`）

**输出**：PrimeTime `read_sdc` 后 `check_timing` 无 **no clock** 警告。

---

## 6. 与 PnR 的物理信息
> **一句话**：与 PnR 的物理信息——本章核心机制点。

综合阶段可选交付：

| 文件 | 用途 |
|------|------|
| **Floorplan DEF**（早期） | 宏位置、拥塞预算 |
| **Physical constraints** | region、placement blockages |
| **TLU+** 早期估计 | 物理综合 |

见 [03-pnr](../03-pnr/)。

---

## 7. 仿真用网表
> **一句话**：仿真用网表——本章核心机制点。

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
> **一句话**：ECO 与增量综合——本章核心机制点。

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
    ├──► 增量 LEC：旧 I ↔ 新 I（仅比受影响锥；呼应 10 §1 表 ECO 行）
    └──► 新 RTL ↔ 新 I 全量或分治 LEC
```

| 内部要点 | 说明 |
|----------|------|
| **差异最小化** | 目标不是 QoR 最优，而是 **改动 cell/net 数最少** — 后端可手工/脚本 ECO，不必重新 PnR |
| **名字保持** | 未动区域 instance/net 名与旧网表一致，否则 PnR 侧无法对位 |
| **冻结约束** | 已布线区域（若 PnR 后 ECO）的 cell 位置/层资源受限 → 综合侧只允许 **同 footprint 换型 / 小锥重组** |
| **寄存器不可增删**（freeze 模式下） | 增 FF = 时钟树/scan 链都要改 → 通常禁止，或走完整 re-spin |
| **DFT 同步** | 受影响锥含 scan FF 时，scan 链顺序须保持或重新声明（12） |

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
> **一句话**：综合「方方面面」索引——本章核心机制点。

| 你想了解 | 章节 |
|----------|------|
| RTL 怎么读入 | 01 |
| 寄存器/RAM/FSM 怎么来 | 02 |
| AIG / 粗优化 / datapath 重组 | 03 |
| 映射 | 04 |
| 约束 | 05 |
| 修 setup/hold、multibit banking | 06 |
| 内部 STA / QoR 聚合 | 07 |
| 读内部量 / 阶段诊断 | 08 |
| 低功耗 | 09 |
| **LEC** | **10** |
| 分块综合 / boundary optimization | 11 |
| **DFT/scan** | 12 |
| **交什么文件** | **13（本章）** |
| **交付后改 bug（ECO）** | 13 §8 |
| **学术界 LS / AI+EDA 进展** | [14](./14-academic-research-survey.md) |
| **3D IC / Chiplet 分 die 交付** | [15](./15-3d-ic-synthesis.md) |

---


## 知识点清单（自检）

- [ ] 网表+SDC 最小集
- [ ] corner/MCMM 锁步
- [ ] manifest 重现 compile
- [ ] 签核门控清单
- [ ] ECO 增量与名字保持

---

## 10. 小结
> **一句话**：小结——本章核心机制点。

交付 = **网表 + SDC +（UPF）+ LEC + 报告 + 版本说明**；**corner 一致** 是 PnR 成功前提；交付后小改走 **ECO 增量**（§8）而非全量重综合。

---

## 下一节

- [03-pnr](../03-pnr/)
- [10 LEC](./10-logical-equivalence-checking.md)
- [00 总览](./00-synthesis-overview.md)
