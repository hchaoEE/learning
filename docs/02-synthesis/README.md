# 02 逻辑综合

ASIC **标准单元逻辑综合**：以综合器 **内部 IR 与 pass 顺序** 为主线，而非 Tcl 命令堆砌。

> 工业工具（DC/Genus 等）仅作背景；正文以 **Design DB / pass** 为准。

---

## 1. 章节设计的核心原则

| 原则 | 说明 |
|------|------|
| **一条主链** | 按 **数据形态变化** 组织：RTL → AST → GTECH → 推断标签 → AIG → 门级网表 |
| **编号 = 主链顺序** | 文件序号与 **推荐学习顺序** 一致（03 优化在 04 映射 **之前**） |
| **机制优先** | 每章写「内部在做什么」；命令/报告放在节末 **附录级** 对照 |
| **案例内嵌** | 输入/输出案例写在 **对应知识点小节末**，不集中堆在章末 |
| **约束双读** | SDC 是 compile 的 **输入**，第 05 章可 **早读一遍**、映射后再读一遍 |

### 1.1 先修知识（初学者）

读 02-synthesis 前，建议已具备：

| 主题 | 用到的地方 | 最低要求 |
|------|------------|----------|
| Verilog 可综合子集 | 01、02 | `always_ff`、阻塞/非阻塞、端口与层次 |
| Setup / Hold 概念 | 05、06、07 | 知道「数据须在捕获沿前稳定」 |
| `.lib` / 单元延时 | 04、06、07 | 单元有输入 slew、输出 load、arc delay |
| SDC 是什么 | 05 | `create_clock`、`set_input_delay` 语义即可 |
| 门级网表长什么样 | 04、13 | `DFF`、`ND2` 等实例化 |

**不必先会**：Design Compiler Tcl、PrimeTime 全流程、UPF 工具命令——本目录 **不写 flow 教程**。

**最小阅读路径**（约 1–2 天概念扫盲）：[00 总览](./00-synthesis-overview.md) → [mini_chain](./examples/mini_chain/README.md) → 01 + 05 + 06 + 10 + 13。

### 1.2 术语小词典（本系列用法）

> **完整词汇表**（含 strash、CSA 树、resub、NPN 等机制详解）：[**docs/glossary.md**](../glossary.md)

| 术语 | 一句话 | 详见 |
|------|--------|------|
| **Design DB** | 综合器内存中的网表+属性+约束图 | [01 §2 走读 / §3](./01-rtl-parsing-and-elaboration.md#2-完整案例走读top--child一条龙) |
| **GTECH** | 工艺无关门（`GTECH_AND`、`SEQGEN`） | [01 §10](./01-rtl-parsing-and-elaboration.md#10-gtech通用工艺中间表示) |
| **Elaborate** | 展开 generate/参数，RTL→GTECH | [01 §2 步骤 E / §8](./01-rtl-parsing-and-elaboration.md#26-步骤-eelaboration--展开成-design-db) |
| **SEQGEN** | 时序元件通用壳，推断前形态 | [01](./01-rtl-parsing-and-elaboration.md)、[02](./02-inference.md) |
| **Inference** | 贴 REG/LATCH/RAM/MULT 标签 | [02](./02-inference.md) |
| **AIG** | 仅 AND+反相边的布尔图 | [03](./03-optimization.md) |
| **strash** | 结构哈希去重共享子图 | [03 §5](./03-optimization.md) |
| **cut / cover** | 映射窗口与单元覆盖选择 | [04](./04-technology-mapping.md) |
| **Mapped 网表** | 已实例化 `.lib` 单元 | [04](./04-technology-mapping.md) |
| **SDC** | 时序约束文本→timing graph | [05](./05-constraints-sdc.md) |
| **MCMM** | 多 mode×corner 场景 | [05 §6](./05-constraints-sdc.md)、[13 §2](./13-deliverables-and-handoff.md) |
| **粗 / 细优化** | 映射前改布尔 vs 映射后修 slack | [README §8](#8-粗粒度优化-vs-细粒度优化写在哪一章) |
| **Transform** | upsize/buffer 等改 mapped 网表 | [06](./06-timing-driven-optimization.md) |
| **Timing graph** | pin 为节点，arc/check 为边 | [05](./05-constraints-sdc.md)、[07](./07-internal-sta-and-qor.md) |
| **AT / RT** | 到达/要求时间；slack=RT−AT | [07 §3](./07-internal-sta-and-qor.md) |
| **WNS / TNS** | 最差 slack / 负 slack 和 | [07 §6](./07-internal-sta-and-qor.md)、[08](./08-synthesis-reports.md) |
| **derate** | 全局收紧 margin | [07 §7](./07-internal-sta-and-qor.md) |
| **Retiming** | 搬移 FF 平衡组合深度 | [06 §8](./06-timing-driven-optimization.md) |
| **Miter** | LEC 判差组合电路 | [10](./10-logical-equivalence-checking.md) |
| **ICG** | 时钟门控；02 推断、09 UPF | [02 §9](./02-inference.md)、[09](./09-low-power-synthesis.md) |
| **UPF** | 低功耗意图 | [09](./09-low-power-synthesis.md) |
| **Abstract / ILM** | 子块时序边界模型 | [11](./11-hierarchical-block-synthesis.md) |
| **SDFF / scan** | 带 SI/SE 的测试 FF | [12](./12-dft-and-scan.md) |
| **Manifest** | 重现 compile 的绑定表 | [13 §2.3](./13-deliverables-and-handoff.md) |
| **Recipe** | ABC/综合 pass 调用序列 | [03](./03-optimization.md)、[14](./14-academic-research-survey.md) |
| **TSV** | 垂直穿透连接；延时固定 | [15 §3](./15-3d-ic-synthesis.md#3-跨-die-timing-graph) |
| **bump / microbump** | die 间凸点电气连接 | [15 §2](./15-3d-ic-synthesis.md#2-design-db-扩展die--接口对象) |
| **interposer** | 2.5D 硅中介层走线 | [15 §1](./15-3d-ic-synthesis.md#11-三种集成形态综合视角) |
| **stack manifest** | die 顺序与 revision 锁步 | [15 §7](./15-3d-ic-synthesis.md#7-交付与签核3d-增项) |

更细的 pass 顺序见 [DESIGN.md](./DESIGN.md) §12 初学者规范；全章索引见 [00 §7](./00-synthesis-overview.md#7-知识点总树索引)。

---

## 2. 内部 IR 与章节映射

```text
  RTL 源文件
      │  01 预处理/解析/Elaboration/Lowering
      ▼
  GTECH + Design DB（含 SEQGEN / MULT / RAM 壳）
      │  02 推断：资源类型、端口语义、实现策略
      ▼
  带标签 GTECH + 组合逻辑准备布尔化
      │  03 优化：AIG、技术无关 rewrite/balance
      ▼
  AIG / 布尔网表
      │  04 工艺映射：cut/cover、.lib 单元
      ▼
  门级网表（mapped）
      │  06 时序驱动优化 ⇄ 07 内部 STA / QoR
      ▼
  08 报告 / 09 UPF
      │
      ├── 10 LEC（RTL ↔ 网表）
      ├── 11 层次（可选）
      ├── 12 DFT（可选）
      ▼
  13 交付 PnR
      ▲
      └── 05 SDC 全程输入
```

| IR / 产物 | 主要章节 |
|-----------|----------|
| AST、logical library | 01 |
| GTECH、SEQGEN | 01、02 |
| `resource_type`（REG/LATCH/RAM/MULT） | 02 |
| **AIG** | **03**（主）、04（映射用 AIG） |
| 标准单元实例 | 04、06 |
| 时序弧、违例 | 05、06、07 |

---

## 3. 章节导航

| 序号 | 文档 | 状态 | 内容 |
|------|------|------|------|
| 0 | [00-synthesis-overview.md](./00-synthesis-overview.md) | 已写 | IR 全景、compile 里程碑、阅读地图 |
| 1 | [01-rtl-parsing-and-elaboration.md](./01-rtl-parsing-and-elaboration.md) | **已写** | 前端：Analyze / Elaborate / Lowering → GTECH |
| 2 | [02-inference.md](./02-inference.md) | **已写** | 寄存器 / Latch / RAM / 乘除 / ICG 推断 |
| 3 | [03-optimization.md](./03-optimization.md) | **已写** | **AIG 主章**；技术无关布尔优化 |
| 4 | [04-technology-mapping.md](./04-technology-mapping.md) | **已写** | **cut/cover**、映射算法与案例 §11 |
| 5 | [05-constraints-sdc.md](./05-constraints-sdc.md) | **已写** | **SDC → timing graph**、MCMM |
| 6 | [06-timing-driven-optimization.md](./06-timing-driven-optimization.md) | **已写** | **STA/transform 引擎**、retiming |
| 7 | [07-internal-sta-and-qor.md](./07-internal-sta-and-qor.md) | **已写** | **内部 STA 引擎**：timing graph、AT/RT、QoR 聚合 |
| 8 | [08-synthesis-reports.md](./08-synthesis-reports.md) | **已写** | **报告解读与内部量索引** |
| 9 | [09-low-power-synthesis.md](./09-low-power-synthesis.md) | **已写** | **UPF/ICG DB 语义**、多电压 |
| 10 | [10-logical-equivalence-checking.md](./10-logical-equivalence-checking.md) | **已写** | **LEC 内部**：miter、匹配 |
| 11 | [11-hierarchical-block-synthesis.md](./11-hierarchical-block-synthesis.md) | **已写** | 分块、预算、abstract |
| 12 | [12-dft-and-scan.md](./12-dft-and-scan.md) | **已写** | **Scan IR 变换** |
| 13 | [13-deliverables-and-handoff.md](./13-deliverables-and-handoff.md) | **已写** | 交付清单、签核门控 |
| 14 | [14-academic-research-survey.md](./14-academic-research-survey.md) | **已写** | **学术界进展**：分阶段文献库 + recipe 时间线 + TODAES'25 对照 |
| 15 | [15-3d-ic-synthesis.md](./15-3d-ic-synthesis.md) | **已写** | **3D IC / Chiplet**：跨 die timing graph、06 约束、分 die 交付 |

---

## 4. 阅读路径

### 路径 A — 按综合主链（默认）

```text
00 → 01 → 02 → 03 → 04 → 06 → 07 → 08 → 10 → 13
              ↑    ↑
              05 SDC（建议 04 前通读约束；06 前精读时序例外）
```

### 初学者 7 天（与 [00 §3.1](./00-synthesis-overview.md#31-初学者-7-天计划概念扫盲) 对齐）

Day1 地图+mini_chain → Day2 01 → Day3 05 → Day4 06 → Day5 07+sta_walkthrough → Day6 10+13 → Day7 02–04 补读+各章 **知识点清单** 自检。

### 路径 B — 先建立约束观（有 STA 基础）

```text
00 → 05（SDC 基础）→ 01 → 02 → 03 → 04 → 06 → 07 → 08
```

### 路径 C — 只查专题

| 专题 | 章节 |
|------|------|
| Elaboration / GTECH | 01 |
| Latch / RAM 从哪来 | 02 |
| AIG 在哪、做什么 | 00 §3、[03](./03-optimization.md) |
| 粗 / 细优化在哪 | [README §8](./README.md#8-粗粒度优化-vs-细粒度优化写在哪一章) |
| 为何先优化再映射 | 本 README §2 |
| 内部 STA / QoR 聚合 | [07](./07-internal-sta-and-qor.md) |
| 内部量 / 阶段诊断 | 08 |
| **LEC** | [10](./10-logical-equivalence-checking.md) |
| 分块综合 | [11](./11-hierarchical-block-synthesis.md) |
| DFT/Scan | [12](./12-dft-and-scan.md) |
| 交付什么 | [13](./13-deliverables-and-handoff.md) |
| 学术界进展 / 读论文对照 | [14](./14-academic-research-survey.md) |
| **3D IC / Chiplet 跨 die** | [15](./15-3d-ic-synthesis.md) |
| **Mapping 怎么做** | [04](./04-technology-mapping.md) §4–11 |
| **Retiming** | [06 §8](./06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) |
| 方方面面索引 | [13 §9](./13-deliverables-and-handoff.md#9-综合方方面面索引) |

---

## 5. `compile` 里程碑（与章节对照）

| 里程碑 | 内部发生的事 | 章节 |
|--------|----------------|------|
| `elaborate` | GTECH 网表、层次展开 | 01 |
| `compile` 早期 | 推断、资源绑定 | 02 |
| `compile` 中期 | 组合 → AIG、布尔优化 | 03 |
| `compile` 中后期 | 工艺映射 | 04 |
| `compile` 迭代 | 用 SDC 修 setup/hold | 05、06 |
| 结束 | 网表 + 报告 | 07、08 |

---

## 6. 示例代码

| 目录 | 对应章节 |
|------|----------|
| [examples/mini_chain/](./examples/mini_chain/) | **端到端** 01→06 |
| [examples/elab_walkthrough/](./examples/elab_walkthrough/) | 01 |
| [examples/inference_walkthrough/](./examples/inference_walkthrough/) | 02 |
| [examples/aig_walkthrough/](./examples/aig_walkthrough/) | 03 |
| [examples/mapping_walkthrough/](./examples/mapping_walkthrough/) | 04 |
| [examples/sdc_walkthrough/](./examples/sdc_walkthrough/) | 05 |
| [examples/tdo_walkthrough/](./examples/tdo_walkthrough/) | 06 |
| [examples/retiming_walkthrough/](./examples/retiming_walkthrough/) | 06 §8 |
| [examples/power_walkthrough/](./examples/power_walkthrough/) | 02 §9、09 |
| [examples/sta_walkthrough/](./examples/sta_walkthrough/) | 07 内部 STA / AT·RT |
| [examples/lec_walkthrough/](./examples/lec_walkthrough/) | 10 LEC / miter |
| [examples/dft_walkthrough/](./examples/dft_walkthrough/) | 12 DFT / scan |
| [examples/hier_walkthrough/](./examples/hier_walkthrough/) | 11 层次 / budget |

完整索引见 [examples/README.md](./examples/README.md)。阅读顺序建议：**mini_chain** → 各专题 walkthrough。

---

## 7. 与相邻模块衔接

| 模块 | 关系 |
|------|------|
| [01-rtl](../01-rtl/) | 综合 **输入** |
| [03-pnr](../03-pnr/) | 综合 **输出** → PnR |
| [05-practice](../05-practice/) | Checklist（待扩充） |

---

## 8. 粗粒度优化 vs 细粒度优化（写在哪一章）

业界口语里的「粗 / 细」与 **是否已映射到 .lib 单元** 高度相关；本系列章节划分如下。

| 粒度 | 含义（本系列） | 主要章节 | 典型内部 pass |
|------|----------------|----------|----------------|
| **粗粒度** | **技术无关**、面向 **逻辑结构 / 布尔网络** 的全局或大块化简 | **[03 优化](./03-optimization.md)**（主） | GTECH→AIG、strash、rewrite/refactor、balance、算术重组、CSE、共享 |
| | 资源 **架构级** 选择（用宏还是用寄存器阵） | **[02 推断](./02-inference.md)**（部分） | RAM→macro/register array、MULT→IP/门阵 |
| | 前端常量传播 / DCE | **[01](./01-rtl-parsing-and-elaboration.md)**（少量） | elaboration 期死代码消除 |
| **细粒度** | **已映射** 门级网表上的 **局部** 调整，依赖 .lib 延时 | **[06 时序驱动优化](./06-timing-driven-optimization.md)**（主） | cell sizing、buffer/inverter 插入、VT 互换、hold 修复、pin swap |
| | 映射阶段的 **局部 cover 选择** | **[04 映射](./04-technology-mapping.md)**（交界） | 同一 AIG 窗口选不同单元组合，属「绑单元」而非纯化简 |

```text
  粗粒度 ──────────────────────────────────────► 细粒度

  01 DCE/常量   02 资源策略   03 AIG 全局优化   04 mapping   06 门级修时序
  ────┬────────────┬──────────────┬─────────────────┬──────────────┬──
      │            │              │                 │              │
   RTL/GTECH    推断标签      技术无关 IR          标准单元      mapped + SDC
```

**记忆口诀**：**没 `DFFRX1` 名字之前，多半是粗；有了库单元名之后，多半是细。**

| 常见说法 | 对应章节 |
|----------|----------|
| 逻辑优化 / 技术无关优化 | 03 |
| 工艺映射 | 04（不是优化「粒度」，是 **绑定**） |
| 门级优化 / 物理感知综合（早期） | 06 |
| 综合迭代 | 03 + 04 + **06** 交替，越往后越偏 **细** |

专题索引：[DESIGN.md §8](./DESIGN.md#8-粗粒度与细粒度优化)

---

## 9. 逻辑综合方方面面（速查）

| 主题 | 章 |
|------|-----|
| 读 RTL、Elaboration、GTECH | 01 |
| 寄存器/Latch/RAM/乘法器 | 02 |
| **FSM 推断 / 状态编码** | 02 §7 |
| **寄存器级优化**（常量/等价/无负载） | 02 §10 |
| **Datapath**（加法器架构、CSA、operator merging） | 02 §6.4、03 §5.8 |
| AIG、粗优化 | 03 |
| .lib、映射 | 04 |
| 时钟/IO/例外约束 | 05 |
| Setup/Hold、buffer | 06 |
| **Multibit FF banking** | 06 §2.7 |
| **Mapping 怎么做** | [04](./04-technology-mapping.md) §4–11 |
| **Retiming** | [06 §8](./06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) |
| **内部 STA / QoR** | 07 |
| 报告 | 08 |
| UPF、ICG | 09 |
| **逻辑等价 LEC** | **10** |
| 层次/预算、boundary optimization | 11 |
| **扫描链 DFT** | **12** |
| **交付 PnR** | **13** |
| **ECO / 增量综合** | 13 §8 |

完整签核：**时序（05–08）+ LEC（10）+ DFT（12 若适用）** → [13 门控](./13-deliverables-and-handoff.md#3-签核门控quality-gates)。

---

## 10. 历史调整说明

- **03 / 04 对调**：早期目录将「映射」标为 03、「优化」标为 04，与 **先布尔优化、后工艺映射** 的实际 pass 顺序相反，已修正。
- **AIG**：主文放在 **03**；04 只写基于 AIG 的 mapping。
- **新增 06**：映射后的 **时序驱动优化** 与 03 技术无关优化区分。

详细设计 rationale 见 [DESIGN.md](./DESIGN.md)。
