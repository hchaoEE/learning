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

## 6. 待办优先级（已完成首版正文）（建议写作顺序）

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
