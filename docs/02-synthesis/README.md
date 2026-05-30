# 02 逻辑综合

ASIC **标准单元逻辑综合**：以综合器 **内部 IR 与 pass 顺序** 为主线，而非 Tcl 命令堆砌。

工具参照：Design Compiler / Fusion Compiler、Cadence Genus、PrimeTime 签核。

---

## 1. 章节设计的核心原则

| 原则 | 说明 |
|------|------|
| **一条主链** | 按 **数据形态变化** 组织：RTL → AST → GTECH → 推断标签 → AIG → 门级网表 |
| **编号 = 主链顺序** | 文件序号与 **推荐学习顺序** 一致（03 优化在 04 映射 **之前**） |
| **机制优先** | 每章写「内部在做什么」；命令/报告放在节末 **附录级** 对照 |
| **案例内嵌** | 输入/输出案例写在 **对应知识点小节末**，不集中堆在章末 |
| **约束双读** | SDC 是 compile 的 **输入**，第 05 章可 **早读一遍**、映射后再读一遍 |

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
      │  06 时序驱动优化
      ▼
  07 报告 / 08 UPF
      │
      ├── 09 LEC（RTL ↔ 网表）
      ├── 10 层次（可选）
      ├── 11 DFT（可选）
      ▼
  12 交付 PnR
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
| 4 | [04-technology-mapping.md](./04-technology-mapping.md) | **已写** | .lib、AIG/网表 → 标准单元 |
| 5 | [05-constraints-sdc.md](./05-constraints-sdc.md) | **已写** | SDC、时钟、IO、例外路径 |
| 6 | [06-timing-driven-optimization.md](./06-timing-driven-optimization.md) | **已写** | 映射后 WLM/拓扑、迭代收敛 |
| 7 | [07-synthesis-reports.md](./07-synthesis-reports.md) | **已写** | 面积/时序/约束/资源报告 |
| 8 | [08-low-power-synthesis.md](./08-low-power-synthesis.md) | **已写** | UPF、ICG、多电压 |
| 9 | [09-logical-equivalence-checking.md](./09-logical-equivalence-checking.md) | **已写** | **LEC**、Formality/Conformal |
| 10 | [10-hierarchical-block-synthesis.md](./10-hierarchical-block-synthesis.md) | **已写** | 分块、预算、abstract |
| 11 | [11-dft-and-scan.md](./11-dft-and-scan.md) | **已写** | Scan、DFT 与再收敛 |
| 12 | [12-deliverables-and-handoff.md](./12-deliverables-and-handoff.md) | **已写** | 交付清单、签核门控 |

---

## 4. 阅读路径

### 路径 A — 按综合主链（默认）

```text
00 → 01 → 02 → 03 → 04 → 06 → 07 → 09 → 12
              ↑    ↑
              05 SDC（建议 04 前通读约束；06 前精读时序例外）
```

### 路径 B — 先建立约束观（有 STA 基础）

```text
00 → 05（SDC 基础）→ 01 → 02 → 03 → 04 → 06 → 07
```

### 路径 C — 只查专题

| 专题 | 章节 |
|------|------|
| Elaboration / GTECH | 01 |
| Latch / RAM 从哪来 | 02 |
| AIG 在哪、做什么 | 00 §3、[03](./03-optimization.md) |
| 粗 / 细优化在哪 | [README §9](./README.md#9-粗粒度优化-vs-细粒度优化写在哪一章) |
| 为何先优化再映射 | 本 README §2 |
| 综合报告怎么读 | 07 |
| **LEC** | [09](./09-logical-equivalence-checking.md) |
| 分块综合 | [10](./10-hierarchical-block-synthesis.md) |
| DFT/Scan | [11](./11-dft-and-scan.md) |
| 交付什么 | [12](./12-deliverables-and-handoff.md) |
| 方方面面索引 | [12 §8](./12-deliverables-and-handoff.md#8-综合方方面面索引) |

---

## 5. `compile` 里程碑（与章节对照）

| 里程碑 | 内部发生的事 | 章节 |
|--------|----------------|------|
| `elaborate` | GTECH 网表、层次展开 | 01 |
| `compile` 早期 | 推断、资源绑定 | 02 |
| `compile` 中期 | 组合 → AIG、布尔优化 | 03 |
| `compile` 中后期 | 工艺映射 | 04 |
| `compile` 迭代 | 用 SDC 修 setup/hold | 05、06 |
| 结束 | 网表 + 报告 | 07 |

---

## 6. 示例代码

| 目录 | 对应章节 |
|------|----------|
| [examples/elab_walkthrough/](./examples/elab_walkthrough/) | 01 |
| [examples/inference_walkthrough/](./examples/inference_walkthrough/) | 02 |
| [examples/aig_walkthrough/](./examples/aig_walkthrough/) | 03 |

---

---

## 9. 粗粒度优化 vs 细粒度优化（写在哪一章）

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
| `compile_ultra` 迭代 | 03 + 04 + **06** 交替，越往后越偏 **细** |

专题索引：[DESIGN.md §8](./DESIGN.md#8-粗粒度与细粒度优化)

---

## 13. 逻辑综合方方面面（速查）

| 主题 | 章 |
|------|-----|
| 读 RTL、Elaboration、GTECH | 01 |
| 寄存器/Latch/RAM/乘法器 | 02 |
| AIG、粗优化 | 03 |
| .lib、映射 | 04 |
| 时钟/IO/例外约束 | 05 |
| Setup/Hold、buffer | 06 |
| 报告 | 07 |
| UPF、ICG | 08 |
| **逻辑等价 LEC** | **09** |
| 层次/预算 | 10 |
| **扫描链 DFT** | **11** |
| **交付 PnR** | **12** |

完整签核：**时序（05–07）+ LEC（09）+ DFT（11 若适用）** → [12 门控](./12-deliverables-and-handoff.md#3-签核门控quality-gates)。

## 7. 与相邻模块衔接

| 模块 | 关系 |
|------|------|
| [01-rtl](../01-rtl/) | 综合 **输入**；决定 elaboration / 推断 |
| [03-pnr](../03-pnr/) | 综合 **输出** 门级网表 → PnR |
| [05-practice](../05-practice/) | Checklist、实验（待扩充） |

---

## 8. 历史调整说明

- **03 / 04 对调**：早期目录将「映射」标为 03、「优化」标为 04，与 **先布尔优化、后工艺映射** 的实际 pass 顺序相反，已修正。
- **AIG**：主文放在 **03**；04 只写基于 AIG 的 mapping。
- **新增 06**：映射后的 **时序驱动优化** 与 03 技术无关优化区分。

详细设计 rationale 见 [DESIGN.md](./DESIGN.md)。
