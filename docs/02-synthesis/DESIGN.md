# 02-synthesis 章节设计说明

本文档记录 **逻辑综合篇** 的结构决策，供后续增删章节时保持一致。

## 1. 为何要单独成篇

综合是 RTL 与 PnR 之间的 **语义 + 结构变换** 核心；仅写在 RTL 或 PnR 里会造成：

- RTL 章过深（elaboration 属于综合前端）
- PnR 章假设读者已懂 mapped netlist 从何而来

因此独立 `02-synthesis/`，与 `01-rtl`、`03-pnr` 三角分工。

## 2. 编号与 pass 顺序对齐

工业 `compile` 对 **组合逻辑** 的典型顺序：

```text
GTECH → [推断] → 布尔化 → AIG 优化 → technology mapping → 门级时序优化
```

故：

| 编号 | 主题 | 理由 |
|------|------|------|
| 03 | 优化（含 AIG） | 在 **未绑定 .lib** 前做技术无关化简 |
| 04 | 工艺映射 | 需要 **优化后的布尔结构** 做 cover |
| 06 | 时序驱动优化 | 必须在 **mapped + STA 弧** 之后 |
| 07 | 内部 STA 引擎 / QoR | 06/08/11 的共同地基；紧随 06 之后阅读 |

若将映射标为 03、优化标为 04，读者会误以为先出 `ND2D1` 再 merge 节点——与事实相反。

## 3. SDC 为何是 05 而非 07

SDC 不是「综合完成之后」才出现：

- `create_clock` 等在 `compile` **之前** 就要读入
- 映射/优化迭代由 **违例反馈** 驱动

因此 05 独立成章，阅读路径上允许 **05 提前**；07 只讲 **报告解读**，不重复约束语法。

## 4. 每章内容边界（避免重复）

| 禁止重复 | 应放在 |
|----------|--------|
| Elaboration、AST、GTECH lowering | 仅 01 |
| Latch/RAM 推断模式 | 仅 02 |
| AIG rewrite、strash | 仅 03 |
| cut/cover、.lib 单元 | 仅 04 |
| `set_input_delay`、`false_path` | 仅 05 |
| `compile_ultra` 迭代、DRV | 06 |
| Timing graph、AT/RT 传播、QoR 聚合 | 仅 07 |
| `report_timing` 字段 | 仅 08 |
| UPF、power intent | 仅 09 |

00 章只做 **地图 + 索引**；长文 AIG 细节在 03，00 保留简短 §3 指针即可。

## 5. 案例编写规范

- 每节末尾 `### 输入/输出案例`（01、02 已贯彻）
- 03–08 写作时沿用
- 示例 RTL 放 `examples/<topic>_walkthrough/`

## 6. 待办优先级（已完成首版正文）（建议写作顺序）

1. **05-constraints-sdc** — 后续章节依赖约束语言
2. **03-optimization** — AIG 主文
3. **04-technology-mapping**
4. **06-timing-driven-optimization**
5. **08-synthesis-reports**
6. **09-low-power-synthesis**

## 7. 文件名约定

```text
NN-<topic>.md     # NN 两位序号，与阅读顺序一致
examples/
  <topic>_walkthrough/
```

不使用的旧名：`02-elaboration-and-inference.md`（拆为 01+02）。第二轮重排：插入 `07-internal-sta-and-qor.md`（STA 引擎独立成章），原 07–12 顺延为 08–13。

## 8. 粗粒度与细粒度优化

### 8.1 定义（本系列用法）

| 术语 | 判定标准 | 为何这样分 |
|------|----------|------------|
| **粗粒度优化** | 在 **未绑定具体标准单元**（或仅 GTECH/AIG）上，改变 **逻辑结构或运算实现方式** | 不依赖真实走线延时，可做全局重写 |
| **细粒度优化** | 在 **mapped 网表** 上，用 **.lib 延时 + SDC** 做局部修补 | 必须知道单元延时、负载、时钟树估算 |

> 注意：**04 工艺映射** 不是「细粒度优化」本身，而是 **粗优化之后的绑定步骤**；映射时虽有「选哪种 ND2」，但时序闭环主要在 **06**。

### 8.2 章节归属表

| 内容 | 粗 / 细 | 章节 |
|------|---------|------|
| Elaboration 常量折叠、死代码 | 粗（前端） | 01 |
| RAM/乘法器实现策略 | 粗（资源） | 02 |
| AIG rewrite / balance / strash | **粗（主）** | **03** |
| 算术共享、逻辑化简 MUX 树 | 粗 | 03 |
| cut enumeration、选 cover | 映射 | 04 |
| 单元 initial mapping | 映射 | 04 |
| upsize / downsize、插 buffer | **细（主）** | **06** |
| hold 修、DRV 修 | 细 | 06 |
| 物理综合（拥塞、拓扑） | 细（偏物理） | 06 + PnR |

### 8.3 与 `compile` 的对应（概念）

```text
compile_ultra 一轮迭代（简化）:

  [粗] 03 类 pass  →  [映射] 04  →  [细] 06  →  STA  →  违例？回环
```

DC/Genus 内部 pass 名不对外暴露时，用 **报告** 判断：节点数骤降多在 **粗** 阶段；单元面积/延时突变多在 **细** 阶段。

### 8.4 写作时注意

- **03-optimization.md**：标题可写「粗粒度优化（技术无关）」  
- **06-timing-driven-optimization.md**：标题可写「细粒度优化（时序驱动、门级）」  
- 避免在 03 写 buffer 插入；避免在 06 写 AIG rewrite

## 9. 扩展章节（10–14）

| 章 | 主题 | 与主链关系 |
|----|------|------------|
| 10 LEC | RTL↔网表等价 | **签核**，非 transform pass |
| 11 层次 | 分块、预算、abstract | **流程**包装 01–07 |
| 12 DFT | Scan 插入 | **compile 后** 再优化/LEC |
| 13 交付 | 文件包、corner、门控 | **输出** 定义 |
| 14 学术前沿 | 研究脉络、文献对照 | **参考**，不描述工业 pass 实现 |

**编号**：10–13 在 **功能综合主链（01–09）之后** 阅读；10、13 对 **所有角色** 建议必读。**14** 在掌握 03–06 后 **选读**，供科研与读论文对照。

**07 为何独立成章**（第二轮重排）：06 的 transform 闭环、08 的报告解读、11 的 abstract 都依赖「综合内部怎么算时序」；STA 引擎（timing graph、AT/RT 传播、check 求值、QoR 聚合）原先散落 06 §2 与各章脚注，独立为 07 后，06/08 瘦身为消费视角 + 指针。

## 11. 写作与审视原则（内部机制优先）

| 写 | 不写 |
|----|------|
| Pass 输入/输出 IR、DB 字段 | Tcl flow 教程 |
| 算法步骤、启发式、冲突权衡 | `report_*` 字段大全 |
| 「输入/输出案例」= 拓扑/表格/ASCII 图 | 以「跑通工具」为唯一目标 |

**walkthrough 规范**：每目录 README 须含 **RTL → IR 前后对比表**；RTL 源文件可选。

## 10. 深化记录

| 项 | 状态 | 章节 |
|----|------|------|
| MCMM 专节 | 已写 | 05 §6、13 §2 |
| 内部 STA 引擎独立成章 | 已写 | 07 |
| 物理综合内部 | 已写 | 06 §6 |
| Formality Tcl 完整脚本 | **不做**（非内部机制目标） |
| 细粒度 STA/transform | 已写 | 06 §2–§5 |
| SDC → timing graph | 已写 | 05 |
| 内部量索引 | 已写 | 08 |
| ICG / UPF DB 语义 | 已写 | 02 §9、09 |
| LEC 算法加深 | 已写 | 10 |
| 层次 abstract/budget | 已写 | 11 |
| DFT scan IR | 已写 | 12 |
| 端到端 mini_chain | 已写 | examples/mini_chain |
| elab walkthrough | 已写 | examples/elab_walkthrough |
| 违例决策树 | 已写 | 08 §3 |
| RAM/MULT 决策树 | 已写 | 02 §5.4、§6.3 |
| NLDM / CSE / pin·VT swap | 已写 | 04 §3.1、03 §5.7、06 §2.6 |
| FSM 推断 / 状态编码 | 已写 | 02 §7 |
| 加法器架构 / CSA / operator merging | 已写 | 02 §6.4、03 §5.8 |
| 寄存器级优化（常量/等价/无负载） | 已写 | 02 §10、10 §3.2 |
| Multibit FF banking / debank | 已写 | 06 §2.7 |
| Boundary optimization | 已写 | 11 §6.1 |
| ECO / 增量综合 | 已写 | 13 §8 |
| P0/P1 机制小节 `### 输入/输出案例` 全覆盖 | 已写 | 01–13 各章 + examples/*_walkthrough |
| 学术界进展调研章 | 已写 | 14（ML-Assist/Agent 双轴 + 时间线 + 分表文献库 + §10 逐篇摘要） |
| Check 绑定 / ideal-propagated / clock_groups 三互斥 / generated clock 派生 | 已写 | 05 §2.2、§4.3、§9 |
| 报告解剖（路径/面积/功耗） | 已写 | 08 §4–§6 |
| LEC SAT 管线 / abort 四态 / debug 流 | 已写 | 10 §5、§7.1 |
| Isolation/LS 插入 pass、活动度传播 | 已写 | 09 §2.2–§2.3、§6.1 |
| Abstract characterize、budget 迭代 | 已写 | 11 §3.3、§4.2 |
| Don't-care/resub、virtual mapping、AOI 极性、修复调度 | 已写 | 03 §5.9/§7.1、04 §4.4/§5.1b、06 §2.4 |
| DFT stitching/lockup/压缩/OCC | 已写 | 12 §1.1、§3、§5.2–§5.3 |
| 层次分包 / 重现 manifest / waiver | 已写 | 13 §1.1、§2.3、§3 |
| **全章初学者深度细化**（导读/一句话/清单/易错） | 已写 | 00–14 + README §4/§1.2；`tools/enrich_beginner_docs.py`；05/06/07/10 易错 |

## 12. 初学者导读规范（深度细化）

00–14 正文统一结构（与机制正文并存，不删表/案例）：

| 位置 | 格式 |
|------|------|
| 章标题下 | `> **本章回答**` / `**读完应能**`（3 条）/ `**先修**` / `**难度**`★1–5 / `**walkthrough**` |
| 每个 `## N.` 首 | `> **一句话**：…`；难章可加 `> **类比**：…` |
| 关键 `###` 后 | `**初学者易错**：…`（≤5 行；05/06/07/10 强制至少 1 处/章） |
| 「小结」之前 | `## 知识点清单（自检）` — checkbox 链到本章节或 walkthrough |

改写约束：机制事实不改；单节 prose >25 行且无 `###` 时拆子节；类比用编译器 IR/队列等，避免错误物理比喻。
