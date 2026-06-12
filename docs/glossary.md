# 专业词汇表（Glossary）

> **范围**：本仓库 **ASIC 标准单元** 流程（RTL → 逻辑综合 → PnR → 签核）。不含 FPGA 专有资源。
>
> **结构**：① [按主题索引](#按主题索引)（可 `Ctrl+F`）② **详解词条**（机制、为何需要、在本流程何处出现）③ [缩写 A–Z](#缩写-az-速查)

---

## 如何使用

| 你想… | 建议 |
|--------|------|
| 查一个词什么意思 | `Ctrl+F` 搜中文或英文 |
| 学优化 pass | 看 [§4 粗优化与 AIG pass](#4-粗优化与-aig-pass详解)（含 **strash、CSA 树**） |
| 学映射 | 看 [§6 工艺映射](#6-工艺映射) |
| 学时序 | 看 [§8 SDC](#8-时序约束-sdc) + [§9 STA](#9-静态时序分析-sta) |
| 快速扫缩写 | 跳 [缩写 A–Z](#缩写-az-速查) |

---

## 按主题索引

| 主题 | 跳转 |
|------|------|
| 流程、IR、Design DB | [§1](#1-流程与中间表示) |
| 前端 Elaboration | [§2](#2-综合前端) |
| 推断 Inference | [§3](#3-推断-inference) |
| **粗优化、AIG、CSA、strash** | [§4](#4-粗优化与-aig-pass详解) |
| 工艺映射 cut/cover | [§6](#6-工艺映射) |
| SDC / 时序图 | [§8](#8-时序约束-sdc) |
| STA / slack | [§9](#9-静态时序分析-sta) |
| TDO 细优化 | [§10](#10-时序驱动优化-tdo) |
| LEC 等价性 | [§11](#11-逻辑等价性检查-lec) |
| 低功耗 / DFT / 交付 | [§12](#12-低功耗-dft-与交付) |
| 算术 / Datapath | [§5](#5-算术与-datapath) |
| 物理 / 签核 | [§13](#13-物理设计与签核) |
| RTL 写法 | [§14](#14-rtl-与-hdl) |

---

## 1. 流程与中间表示

### RTL（寄存器传输级）

| | |
|--|--|
| **英文** | Register Transfer Level |
| **是什么** | 用 HDL 描述「数据在寄存器之间如何传送、如何运算」的设计层次；**综合的输入**。 |
| **不是什么** | 不是门级网表，也不是晶体管级；仍带 `always`、运算符等行为。 |
| **详见** | [01-rtl](../01-rtl/)、[02/01](./02-synthesis/01-rtl-parsing-and-elaboration.md) |

### 逻辑综合（Logic Synthesis）

| | |
|--|--|
| **是什么** | 将 RTL 映射为 **门级网表**，并在时序、面积、功耗、可测性目标下优化。 |
| **内部形态** | 不是一次变换，而是 Design DB 上多道 **pass** 的流水线（elaborate → 推断 → AIG → map → TDO…）。 |
| **详见** | [02/00](./02-synthesis/00-synthesis-overview.md) |

### Design DB（设计数据库）

| | |
|--|--|
| **是什么** | 综合器内存中的 **异构图**：Cell、Pin、Net、Port、属性、约束等；**所有 pass 读写同一 DB**。 |
| **与 logical library 区别** | library 存 **未展开** 的 module 模板；Design DB 存 **某次 elaborate 的展开结果**。 |
| **详见** | [02/01 §3](./02-synthesis/01-rtl-parsing-and-elaboration.md#3-内部核心数据结构design-database) |

### GTECH（通用工艺中间表示）

| | |
|--|--|
| **是什么** | **工艺无关** 原语网表：`GTECH_AND`、`GTECH_MUX`、`GTECH_FD*`、`GTECH_MULT` 等。 |
| **何时产生** | RTL **Lowering** 后；映射前的主要 IR。 |
| **为何需要** | 一次 lowering，可多次映射（换 corner、换工艺试算）；优化可在技术无关层做结构化简。 |
| **详见** | [02/01 §10](./02-synthesis/01-rtl-parsing-and-elaboration.md#10-gtech通用工艺中间表示) |

### AIG（与-反相器图）

| | |
|--|--|
| **英文** | And-Inverter Graph |
| **是什么** | **同构** 布尔图：节点几乎全是 2 输入 **AND**；逻辑反相画在 **边** 上（complement edge），不单独占 NOT 节点。 |
| **何时用** | 组合逻辑锥从 GTECH 提取后，在 **映射前** 做粗粒度布尔优化（03 章）。 |
| **与 GTECH 区别** | GTECH 保留 MUX、层次；AIG 把组合锥压成统一 AND 结构便于 rewrite/map。 |
| **详见** | [02/03](./02-synthesis/03-optimization.md) |

### Mapped 网表

| | |
|--|--|
| **是什么** | 已绑定 `.lib` **具体单元名** 的门级网表（如 `ND2X1`、`DFFRX1`）。 |
| **细优化在哪做** | **TDO**（06 章）在 mapped IR 上 upsize/buffer，不再回 AIG rewrite。 |
| **详见** | [02/04](./02-synthesis/04-technology-mapping.md)、[02/06](./02-synthesis/06-timing-driven-optimization.md) |

### pass / compile / recipe

| 术语 | 说明 |
|------|------|
| **compile** | 用户触发的一次综合运行 |
| **pass** | compile 内单步变换（strash、map、STA…） |
| **recipe** | pass 调用序列，如 ABC：`strash; rewrite; balance; map` |

---

## 2. 综合前端

### Elaboration（展开）

| | |
|--|--|
| **做什么** | 参数求值、`generate` 展开、子模块例化、Pin→Net 连接。 |
| **生成什么** | **Design DB** 实例树（Cell/Pin/Net 异构图）。 |
| **详见** | [02/01 §2 步骤 E](./02-synthesis/01-rtl-parsing-and-elaboration.md#26-步骤-eelaboration--展开成-design-db) |

### Lowering（行为降级）

| | |
|--|--|
| **做什么** | 把 `always`/`assign` **过程语义** 解释成 **结构网表**（GTECH 门、SEQGEN、LAT）。 |
| **例子** | `always_ff` → `GTECH_FD*`；`always_comb` 缺 else → `GTECH_LAT` 候选。 |
| **详见** | [02/01 §9](./02-synthesis/01-rtl-parsing-and-elaboration.md#9-阶段-frtl--结构-loweringrtl-interpretation) |

### SEQGEN

| | |
|--|--|
| **是什么** | GTECH 层 **时序元件抽象壳**（CK、D、Q、复位、使能等 pin），尚未绑定 `DFFRX1` 等具体单元。 |
| **下一步** | 02 **推断** 识别 CE、异步复位、扫描脚 → 04 **映射** 选具体 FF。 |

### 异构图 / 同构图

| 类型 | 节点 | 典型 IR | 阶段 |
|------|------|---------|------|
| **异构** | Cell、Pin、Net、Port 多种 | Design DB | Elaboration 起 |
| **同构** | 几乎全是 AND | AIG | 粗优化 |

---

## 3. 推断（Inference）

### Inference（推断）

| | |
|--|--|
| **做什么** | 映射前对 GTECH 子图 **模式识别**，贴 `resource_type`（REGISTER、LATCH、RAM、MULT…）并选实现策略。 |
| **详见** | [02/02](./02-synthesis/02-inference.md) |

### LATCH 推断

| | |
|--|--|
| **触发** | `always_comb` / `always` 组合块 **分支不完整**（缺 `else`/`default`）。 |
| **内部** | Lowering 建反馈 MUX/`GTECH_LAT`；推断二次确认；ASIC 内核常 **禁止**。 |

### ICG（集成时钟门控）

| | |
|--|--|
| **是什么** | 在寄存器 bank 的时钟入口插门控，空闲时停时钟降 **动态功耗**。 |
| **流程** | 02 推断插 ICG 壳 → 04 映射为 `CKLN*` 等库单元。 |

---

## 4. 粗优化与 AIG pass（详解）

> 本章术语多来自 [02/03 优化](./02-synthesis/03-optimization.md) 与 ABC 工具链。

### strash（结构性哈希）

| | |
|--|--|
| **英文** | Structural hashing；也称 **hash consing** |
| **是什么** | AIG 上对每个 `(AND, 左子, 右子)` 三元组（含子节点 **规范序** 与 **边反相标记**）算 **哈希键**，查表若已存在则 **复用同一节点**，不重复创建。 |
| **解决什么问题** | RTL 里同一子式多处书写（如两处 `a&b`）、或 lowering 产生重复锥 → 不 strash 则 AIG **节点膨胀**、后续 map 面积变差。 |
| **内部怎么做** | 遍历 AIG 时维护 `hash[(op, left_id, right_id, inv_flags)] → node_id`；命中则合并 fanout，未命中则插入新节点。 |
| **效果** | 节点数 ↓；**不改变** 布尔功能与 level（纯去重）。 |
| **在 ABC 中** | 通常作为优化管道 **第一步**：`strash` |
| **案例** | `aig_walkthrough/comb_dup.sv`：`(a&b)` 经 strash 后图中 **仅 1 个 AND**，fanout=2 |
| **详见** | [03 §5.1](./02-synthesis/03-optimization.md#51-strash结构性哈希) |

### rewrite（重写）

| | |
|--|--|
| **是什么** | 在 AIG 上取 **4–6 输入** 的小窗口，查 **NPN 等价类表**，用 **节点更少 / level 更低** 的等价 AIG 子图 **替换** 原窗口。 |
| **与 strash 区别** | strash 只 **去重**；rewrite **改结构** 化简逻辑。 |
| **详见** | [03 §5.2](./02-synthesis/03-optimization.md#52-rewriting) |

### refactor（重构）

| | |
|--|--|
| **是什么** | 与 rewrite 不同：把 **多个** 已有 AIG 节点 **合并** 成更大窗口，再 **重新分解** 成新结构，以跳出 rewrite 的局部最优。 |
| **典型效果** | 深链 AND 的 **level ↓**（关键路径变短），节点数可能略增。 |
| **详见** | [03 §5.3](./02-synthesis/03-optimization.md#53-refactoring) |

### balance（平衡）

| | |
|--|--|
| **是什么** | 在 **不改变布尔功能** 前提下，把 **链状** AND/OR（深而窄）拉成 **树状**（浅而宽）。 |
| **权衡** | level ↓（利于时序）↔ 节点数可能 ↑（面积略差）；引擎按权重折中。 |
| **例子** | `y = a&b&c&d` 链 level=3 → 平衡树 level=2 |
| **详见** | [03 §5.4](./02-synthesis/03-optimization.md#54-balancing) |

### resubstitution（resub，重代入）

| | |
|--|--|
| **是什么** | 判断目标节点能否用网中 **已有节点** 的函数表达（如已有 `t=b|c`，则 `y=a&b|a&c` 可化为 `y=a&t`），从而 **删掉私有锥**、增大 `t` 的 fanout。 |
| **与 CSE 区别** | CSE 找 **句法相同** 子式；resub 找 **功能可表达**（更强，常需 SAT/仿真验证）。 |
| **详见** | [03 §5.9](./02-synthesis/03-optimization.md#59-dont-care-优化与-resubstitution) |

### Don't-care 优化（无关项优化）

| 类型 | 英文 | 含义 |
|------|------|------|
| **SDC** | Satisfiability don't-care | 某些输入组合 **不会出现**（如 one-hot 互斥） |
| **ODC** | Observability don't-care | 节点在某些条件下 **不影响任何输出** |

利用无关项可在映射前选 **更小** 的实现；**LEC 须带同样输入约束**，否则可能假不等价。

### DCE / CSE

| 术语 | 说明 |
|------|------|
| **DCE** | Dead Code Elimination — 删除无 fanout 的逻辑锥 |
| **CSE** | Common Subexpression Elimination — 合并重复子表达式（如两处 `a*b`） |

### NPN 等价

| | |
|--|--|
| **是什么** | 布尔函数在 **取反（N）、置换输入（P）、输出取反（N）** 下的等价类；用于匹配库单元与 rewrite 查表。 |
| **详见** | [02/04 §4.2](./02-synthesis/04-technology-mapping.md#42-真值表与-npn-等价) |

### virtual mapping（虚拟映射）

| | |
|--|--|
| **是什么** | 映射前无真实 `.lib` 时，用 **虚拟单元** 估每级 delay，指导 balance/rewrite 的 **level 权重**。 |
| **详见** | [03 §7.1](./02-synthesis/03-optimization.md#71-无-lib-时-delay-从哪来virtual-mapping) |

### 典型 ABC recipe

```text
strash → rewrite → refactor → balance → (重复) → map
```

| pass | 一句话 |
|------|--------|
| strash | 去重 |
| rewrite | 小窗替换 |
| refactor | 大窗重组 |
| balance | 拉平深度 |
| resub | 复用已有信号 |
| map | 工艺映射（04 章） |

---

## 5. 算术与 Datapath

### CSA / CSA 树（进位保留加法 / 进位保留树）

| | |
|--|--|
| **英文** | Carry-Save Adder / Carry-Save tree |
| **是什么** | 一种 **不立即传播进位** 的加法结构：每位输出 `(sum_bit, carry_bit)` 两个向量，进位 **保留（save）** 到相邻位列，而非像行波加法那样逐级传递。 |
| **3:2 压缩器** | 常用 **全加器** 作为 3:2 compressor：3 个输入位 → 1 个 sum 位 + 1 个 carry 位（carry 送到下一列）。 |
| **CSA 树做什么** | 把 **多个操作数**（如 `a+b+c+d`）通过多层 3:2 压缩，先压成 **两个** 剩余向量，最后用 **一个** 普通加法器做 **一次** 进位传播。 |
| **为何比 ADD 链快** | `((a+b)+c)+d` 需要 **3 次** 完整进位传播（每级一个慢 ADD）；CSA 树把进位传播次数降到 **1 次**。 |
| **在综合哪一步** | 03 章 **Datapath 重组**（§5.8），在 `GTECH_ADD`/`GTECH_MULT` **算术壳层**，**不拆进 AIG**。 |
| **例子** | `sum = a + b + c`：重组前 2 个串行 ADD → 重组后 CSA(a,b,c) + 末级 ADD |
| **与 Wallace 树** | Wallace 树是乘法部分积累加的一种 CSA 网络；概念同属 **压缩树** 家族。 |
| **图示（概念）** | `a,b,c,d` 四个加数 → 第一层 3:2 压成两个向量 → 第二层再压 → 末级 **一个** RCA/CLA 得出最终结果 |
| **详见** | [03 §5.8](./02-synthesis/03-optimization.md#58-datapath-重组技术无关) |

```text
  重组前:  ADD(a,b) ──► ADD(·,c) ──► ADD(·,d)     ← 3 次完整进位传播
  重组后:  CSA_tree(a,b,c,d) ──► ADD(save,carry) ← 1 次进位传播
```

### RCA（行波进位加法器）

| | |
|--|--|
| **是什么** | Ripple-Carry Adder；最低位进位逐级传到最高位，结构简单，延时 **O(N)**，面积最小。 |
| **用途** | 窄位、非关键路径；宽位关键路径常用 CLA 或并行前缀。 |

### CLA（超前进位加法器）

| | |
|--|--|
| **是什么** | Carry-Lookahead Adder；用 generate/propagate 逻辑 **并行** 计算进位，延时约 **O(log N)** 到 O(N) 之间，面积中等。 |

### 并行前缀加法器（Kogge-Stone / Brent-Kung）

| | |
|--|--|
| **是什么** | 用 **树形** 并行计算所有进位；Kogge-Stone 快但布线多，Brent-Kung 面积更省。 |
| **用途** | 宽位高性能加法器推断（02 章）。 |

### Booth 编码 / Wallace 树

| 术语 | 说明 |
|------|------|
| **Booth** | 乘法中减少部分积数量的编码（看 multiplier 连续位） |
| **Wallace 树** | 部分积用 CSA 层压缩再最终相加 |

### strength reduction（强度削减）

| | |
|--|--|
| **是什么** | 把 `x * 常数` 化为 **移位 + 加减**（如 `*8` → `<<3`），避免通用乘法器。 |

### operator merging（运算融合）

| | |
|--|--|
| **是什么** | 把相邻运算合成一块 datapath（如 `a*b+c` → **MAC**），让 CSA 在更大窗口内全局重组。 |
| **详见** | [03 §5.8](./02-synthesis/03-optimization.md#58-datapath-重组技术无关) |

### GTECH_MULT / DesignWare

| | |
|--|--|
| **GTECH_MULT** | lowering 后的 **抽象乘法器** 壳，不进 AIG 拆解 |
| **DesignWare (DW)** | Synopsys 算术 IP（如 `DW02_mult`）；宽位高性能乘法常用 |

---

## 6. 工艺映射

### Technology mapping（工艺映射）

| | |
|--|--|
| **做什么** | 把 GTECH/AIG 布尔子图绑定到 `.lib` **标准单元**（ND2、AOI21、DFF…）。 |
| **详见** | [02/04](./02-synthesis/04-technology-mapping.md) |

### cut（切割）

| | |
|--|--|
| **是什么** | 在 AIG 上选一个 **k 输入** 的局部子图（一个 **feasible cut**），作为 **一次映射的单位**。 |
| **参数 K** | 最大 cut 大小；K 大可用复杂 AOI/OAI **单单元** cover，级数少，但映射搜索更贵。 |

### cover（覆盖）

| | |
|--|--|
| **是什么** | 用库单元（一个或多个）**实现** cut 的布尔功能；可选 **面积最优** 或 **延时最优** cover。 |

### AOI / OAI

| | |
|--|--|
| **是什么** | And-Or-Invert / Or-And-Invert **复合门**（如 AOI21：`!((a&b)|c)`）。 |
| **为何用** | 单 CMOS 级实现多级逻辑，比 AND+OR 两级 **少一次摆幅翻转**，延时/功耗更优。 |
| **映射注意** | 须处理 **极性匹配** 与 **pin 置换**（快 pin 接关键信号）。 |

### Liberty / NLDM / genlib

| 术语 | 说明 |
|------|------|
| **Liberty (.lib)** | 标准单元延时/面积/功耗的工业库格式 |
| **NLDM** | Non-Linear Delay Model — 用 input slew + output load **查表**得 delay |
| **genlib** | ABC 等工具用的 **简化** 单元库文本格式（教学/实验） |

### Link / Uniquify / analyze

| 术语 | 说明 |
|------|------|
| **analyze** | 读 RTL → 预处理 → 词法/语法/语义 → 写入 **logical library**（尚未 elaborate） |
| **Link** | 将 Cell 的 **ref** 绑定到 library 中的 module 定义 |
| **Uniquify** | 同一模板因 parameter 不同生成多个 **唯一 ref 变体**（如 `child_0`、`child_1`） |

### 黑盒 / bit-blast / check_design

| 术语 | 说明 |
|------|------|
| **黑盒 (black box)** | 只有端口、无内部网表的模块引用 |
| **bit-blast** | 总线 `[7:0]` 展开为 8 根单 bit net（或反向合并） |
| **check_design** | 遍历 DB 查多驱动、浮空、组合环等 |

---

## 7. 存储器与 FSM 推断

| 术语 | 说明 |
|------|------|
| **port schedule** | RAM 推断用的 **端口读写时序图**（何时读/写哪口） |
| **RAM_1P / 1R1W / 2P** | 单口、一写一读、真双口 RAM 内部类型 |
| **collision** | 同址同周期读写语义（write-first、读旧、读新） |
| **register array** | 小深度存储用 FF 阵而非 SRAM 宏 |
| **FSM / STG** | 状态机 / 状态转移图；可 **重编码** (re-encoding) |
| **state encoding** | Binary、One-hot、Gray 等状态位赋值 |

---

## 8. 时序约束（SDC）

### SDC

| | |
|--|--|
| **是什么** | Synopsys Design Constraints；事实上的时序约束语言，编译为 **Timing Graph** 上的 clock、check、例外。 |
| **详见** | [02/05](./02-synthesis/05-constraints-sdc.md) |

### Timing graph（时序图）

| | |
|--|--|
| **是什么** | 以 **pin** 为节点；**cell arc**、**net arc**、**check 边**、**clock 边** 为边的图，STA 在其上传播 AT/RT。 |

### setup / hold / slack

| 术语 | 说明 |
|------|------|
| **setup** | 数据须在 capture 沿 **之前** 稳定足够长 |
| **hold** | 数据须在 capture 沿 **之后** 仍保持足够长 |
| **slack** | `RT − AT`（setup）；负值 = 违例 |

### false_path / multicycle_path / clock_groups

| 命令 | 作用 |
|------|------|
| `false_path` | 不做 timing check |
| `multicycle_path` | 允许多周期到达 |
| `clock_groups` | 声明时钟域异步/互斥 |

### MCMM

| | |
|--|--|
| **是什么** | Multi-Corner Multi-Mode；多工艺角 × 多模式（func/test）共用拓扑、弧 delay 注解不同。 |

### WLM（线负载模型）

| | |
|--|--|
| **是什么** | Wire Load Model；综合期按 fanout **估 net delay** 的查表模型；签核用 SPEF 替代。 |

---

## 9. 静态时序分析（STA）

### AT / RT

| 术语 | 说明 |
|------|------|
| **AT** | Arrival Time — 数据到达 pin 的时刻 |
| **RT** | Required Time — 数据须到达的最晚时刻 |

### WNS / TNS / THS

| 缩写 | 含义 |
|------|------|
| **WNS** | Worst Negative Slack — 最差 slack |
| **TNS** | Total Negative Slack — 负 slack 之和 |
| **THS** | Total Hold Slack — hold 侧负 slack 和 |

### slew / unate / endpoint

| 术语 | 说明 |
|------|------|
| **slew** | 边沿转换时间；影响 NLDM 查表 |
| **unate** | 弧极性：正 unate 输入升→输出升；反相器负 unate |
| **endpoint** | 时序路径终点（常为 FF 的 D 或 output port） |

### derate / OCV / AOCV / POCV

| 术语 | 说明 |
|------|------|
| **derate** | 全局收紧 delay/margin，预留工艺偏差 |
| **OCV** | On-Chip Variation |
| **AOCV/POCV** | 签核 STA 更精细的 variation 模型 |

### 增量 STA

| | |
|--|--|
| **是什么** | TDO 每做一处 transform 后，只重算 **脏区域** 的 AT/RT，不全芯片重算。 |

---

## 10. 时序驱动优化（TDO）

### TDO

| | |
|--|--|
| **是什么** | Timing-Driven Optimization；**映射后** 根据 slack 做 upsize、插 buffer、VT swap、retiming 等 **transform**，与 STA 闭环迭代。 |
| **与粗优化区别** | 03 改 **布尔结构**（AIG）；06 改 **门级驱动强度/拓扑**（mapped）。 |

### Transform 常见类型

| 类型 | 作用 |
|------|------|
| **upsize/downsize** | 换更大/更小驱动单元 |
| **buffer insert** | 切分高 fanout net |
| **pin swap** | 对称输入脚交换，走更快 arc |
| **VT swap** | LVT↔SVT↔HVT |
| **retiming** | 搬移 FF 平衡组合深度 |
| **debanking** | 从 multibit FF 拆出关键 bit 单独 sizing |

### Retiming（寄存器搬移）

| | |
|--|--|
| **是什么** | 在不改功能前提下 **移动 FF** 位置，缩短组合关键路径；可能改变 I/O 延迟。 |
| **LEC** | 须 **流水线等价** 或 SVF 记录；与组合 LEC 不同。 |

### time borrowing（时间借用）

| | |
|--|--|
| **是什么** | **Latch** 路径上可利用透明相 **借用** 半周期的 STA 分析技术。 |

---

## 11. 逻辑等价性检查（LEC）

### LEC / Reference / Implementation

| 术语 | 说明 |
|------|------|
| **LEC** | 形式化证明 RTL（R）与网表（I）等价 |
| **R / I** | Reference / Implementation |
| **compare point** | 一一配对的观测点（FF Q、PO） |

### Miter

| | |
|--|--|
| **是什么** | R、I 同输入并联，输出 XOR 得 **差分信号**；差分为 0 则等价。 |

### SAT / UNSAT / SVF

| 术语 | 说明 |
|------|------|
| **SAT** | 有满足赋值 → 找到反例 |
| **UNSAT** | 无满足赋值 → 可证等价（组合） |
| **SVF** | 综合变换日志，助 LEC 匹配 rename/retime |

---

## 12. 低功耗、DFT 与交付

| 术语 | 说明 |
|------|------|
| **UPF** | Unified Power Format — 电源域、隔离、保持 |
| **ICG** | 时钟门控 |
| **DFT / Scan** | 可测性设计；扫描链 |
| **SDFF** | 带扫描 SI/SE 的测试 FF |
| **Abstract / ILM** | 子块时序边界模型 |
| **Manifest** | 重现 compile 的绑定表 |

---

## 13. 物理设计与签核

| 术语 | 说明 |
|------|------|
| **PnR** | Place & Route 布局布线 |
| **LEF/DEF** | 单元物理抽象 / 布局交换格式 |
| **CTS** | Clock Tree Synthesis 时钟树综合 |
| **SPEF** | 签核寄生参数 |
| **DRC/LVS** | 几何规则 / 版图网表一致性 |
| **GDSII** | 交付 Foundry 的版图流 |

---

## 14. RTL 与 HDL

| 术语 | 说明 |
|------|------|
| **always_ff / always_comb** | SV 时序/组合过程块 |
| **NBA** | 非阻塞赋值 `<=`，用于时序 |
| **完整赋值** | 组合块须覆盖所有分支，防 latch |
| **unique/priority case** | 影响 MUX lowering 结构 |
| **2-state / 4-state** | 综合 0/1 vs 仿真 X/Z |
| **CDC** | 跨时钟域；须同步器 + SDC |

---

## 缩写 A–Z 速查

| 缩写 | 英文 | 中文 |
|------|------|------|
| AIG | And-Inverter Graph | 与-反相器图 |
| AOCV | Advanced OCV | 先进片上变异 |
| AST | Abstract Syntax Tree | 抽象语法树 |
| AT | Arrival Time | 到达时间 |
| BMC | Bounded Model Checking | 有界模型检测 |
| Booth | Booth encoding | 布斯乘法编码 |
| CCS | Composite Current Source | 复合电流源（.lib 模型） |
| CDC | Clock Domain Crossing | 跨时钟域 |
| CLA | Carry-Lookahead Adder | 超前进位加法器 |
| CNF | Conjunctive Normal Form | 合取范式 |
| CSA | Carry-Save Adder | 进位保留加法器 |
| CSE | Common Subexpression Elimination | 公共子表达式消除 |
| CTS | Clock Tree Synthesis | 时钟树综合 |
| DCE | Dead Code Elimination | 死代码消除 |
| DEF | Design Exchange Format | 设计交换格式 |
| DFT | Design for Test | 可测性设计 |
| DRC | Design Rule Check | 设计规则检查 |
| DW | DesignWare | Synopsys 算术 IP |
| FSM | Finite State Machine | 有限状态机 |
| GTECH | Generic Technology | 通用工艺 IR |
| ICG | Integrated Clock Gating | 时钟门控 |
| ILM | Interface Logic Model | 接口逻辑模型 |
| IR | Intermediate Representation | 中间表示 |
| LEC | Logical Equivalence Checking | 逻辑等价检查 |
| LEF | Library Exchange Format | 库交换格式 |
| LRM | Language Reference Manual | 语言参考手册 |
| LVS | Layout Versus Schematic | 版图一致性 |
| MAC | Multiply-Accumulate | 乘累加 |
| MCMM | Multi-Corner Multi-Mode | 多角多模式 |
| MUX | Multiplexer | 多路选择器 |
| NBA | Non-Blocking Assignment | 非阻塞赋值 |
| NLDM | Non-Linear Delay Model | 非线性延时模型 |
| NPN | Negation-Permutation-Negation | 布尔等价变换类 |
| OCV | On-Chip Variation | 片上工艺偏差 |
| ODC | Observability Don't-Care | 可观测无关项 |
| PnR | Place and Route | 布局布线 |
| POCV | Parametric OCV | 参数化 OCV |
| QoR | Quality of Results | 结果质量 |
| RCA | Ripple-Carry Adder | 行波进位加法器 |
| resub | Resubstitution | 重代入优化 |
| RT | Required Time | 要求时间 |
| SAT | Boolean Satisfiability | 布尔可满足 |
| SDC | Synopsys Design Constraints | 时序约束 |
| SDF | Standard Delay Format | 标准延时格式 |
| SEQGEN | Sequential Generic | 时序通用壳 |
| SDC(DC) | Satisfiability Don't-Care | 可满足无关项 |
| SPEF | Standard Parasitic Exchange Format | 标准寄生交换 |
| STA | Static Timing Analysis | 静态时序分析 |
| STG | State Transition Graph | 状态转移图 |
| strash | Structural hashing | 结构性哈希 |
| SVF | Setup Verification Flow | 综合变换日志 |
| TDO | Timing-Driven Optimization | 时序驱动优化 |
| THS | Total Hold Slack | 总保持裕量 |
| TNS | Total Negative Slack | 总负裕量 |
| TSV | Through-Silicon Via | 硅通孔 |
| UPF | Unified Power Format | 统一功耗格式 |
| WLM | Wire Load Model | 线负载模型 |
| WNS | Worst Negative Slack | 最差负裕量 |

---

## 维护说明

- 各章新增术语请同步更新本表；**详解词条**优先写在对应主题 § 下。
- 简短入口：[00-preface/glossary.md](./00-preface/glossary.md)
- 02 章一句话索引：[02-synthesis/README §1.2](./02-synthesis/README.md#12-术语小词典本系列用法)
