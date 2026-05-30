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
| `report_timing` 字段 | 仅 07 |
| UPF、power intent | 仅 08 |

00 章只做 **地图 + 索引**；长文 AIG 细节在 03，00 保留简短 §3 指针即可。

## 5. 案例编写规范

- 每节末尾 `### 输入/输出案例`（01、02 已贯彻）
- 03–08 写作时沿用
- 示例 RTL 放 `examples/<topic>_walkthrough/`

## 6. 待办优先级（建议写作顺序）

1. **05-constraints-sdc** — 后续章节依赖约束语言
2. **03-optimization** — AIG 主文
3. **04-technology-mapping**
4. **06-timing-driven-optimization**
5. **07-synthesis-reports**
6. **08-low-power-synthesis**

## 7. 文件名约定

```text
NN-<topic>.md     # NN 两位序号，与阅读顺序一致
examples/
  <topic>_walkthrough/
```

不使用的旧名：`02-elaboration-and-inference.md`（拆为 01+02）、`07-synthesis-reports.md`（改为 07）。
