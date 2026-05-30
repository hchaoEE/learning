# 2.0 逻辑综合总览

ASIC **逻辑综合** 将 RTL 转换为满足 **时序、面积、功耗** 约束的 **门级网表**（标准单元 + 宏）。

本系列强调 **综合器内部机制**（前端 IR、elaboration、GTECH、映射与优化 pass），Tcl 命令仅作阶段对照。

## 1. 三阶段模型

```text
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│ RTL 解析与展开   │ → │ 推断 + 工艺映射  │ → │ 优化 + 约束驱动  │
│ Design DB+GTECH │   │ (.lib 绑定)     │   │ (STA 闭环)      │
└─────────────────┘   └─────────────────┘   └─────────────────┘
        ↑                       ↑                       ↑
   第 01 章（内部）        第 02–03 章（待写）      第 04–06 章（待写）
```

| 阶段 | 文档 | 状态 |
|------|------|------|
| RTL 解析、Elaboration、Lowering | [01-rtl-parsing-and-elaboration.md](./01-rtl-parsing-and-elaboration.md) | **已写（深入内部）** |
| 推断 | [02-inference.md](./02-inference.md) | 待写 |
| 工艺映射 | [03-technology-mapping.md](./03-technology-mapping.md) | 待写 |
| 优化 | [04-optimization.md](./04-optimization.md) | 待写 |
| SDC | [05-constraints-sdc.md](./05-constraints-sdc.md) | 待写 |
| 报告 | [06-timing-and-area-reports.md](./06-timing-and-area-reports.md) | 待写 |
| 低功耗 | [07-low-power-synthesis.md](./07-low-power-synthesis.md) | 待写 |

## 2. 主要输入与输出

| 类型 | 文件/对象 |
|------|-----------|
| 输入 | RTL、filelist、SDC、.lib（+ DB）、UPF（可选） |
| 输出 | 门级 Verilog、SDF（可选）、检查点、综合报告 |

## 4. AIG 在哪一步做？

**结论**：**AIG（And-Inverter Graph，与或非图）不在 RTL 解析 / Elaboration 阶段**；出现在 **compile 中段至工艺映射前后** 的 **逻辑优化（技术无关优化）** 里，是 GTECH/布尔逻辑 lowering 之后、或与之并行的一种 **布尔层 IR**。

### 4.1 内部 IR 链条（概念）

```text
RTL ──elab/lowering──► GTECH（含 MUX/加法/寄存器/与或非）
                              │
                              ▼ 布尔化 / 展平（部分工具）
                         布尔网络 / AIG
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        技术无关优化      技术映射         时序/面积优化
     (AIG rewrite…)    (cover on AIG)    (mapped 门级)
              │               │
              └───────┬───────┘
                      ▼
                 标准单元门级网表
```

| 阶段 | 常见 IR | 是否 AIG |
|------|---------|----------|
| Analyze / Elaborate | AST、Design DB | 否 |
| RTL lowering | GTECH、RTL 结构网表 | 否（含高层次算子） |
| 布尔优化 / 映射准备 | **AIG**、BDD、二元覆盖图 | **是** |
| 工艺映射后 | 门级实例 + .lib 延时 | 否（已绑定单元） |

### 4.2 AIG 上典型在做什么

- **结构共享（structural hashing）**：相同子图合并，减节点数。  
- **重写（rewriting）**：用更小 AIG 替换局部（如 ABC 的 `rewrite` / `refactor`）。  
- **平衡（balancing）**：控制逻辑深度，利于时序。  
- **技术映射输入**：在 AIG 上做 **cut enumeration**，选 cover 映射到 NAND/NOR/AND 门或标准单元。

寄存器、MUX、加法器通常 **先** 在 GTECH 层保留边界；组合逻辑云 **再** 转为 AIG 做布尔优化，时序元件在映射后仍对应 `.lib` 中的 DFF/ latch。

### 4.3 和本章（01 Elaboration）的边界

| 你看到的 | 阶段 |
|----------|------|
| `GTECH_FD1`、`GTECH_MUX`、`GTECH_MULT` | Elaboration / compile 早期 |
| 工具内部「节点数骤降、结构合并」报告 | 多为 **AIG 优化 pass** |
| 网表里出现 `ND2D1`、`INVX1` 等库单元名 | **映射之后**，已离开 AIG |

### 4.4 工具差异（了解即可）

- **开源典型路径**：Yosys 读 RTL → 内部 RTLIL → 导出/调用 **ABC** → **AIG** 优化 + `if -K` 映射。  
- **商业 DC / Genus**：对外仍以 GTECH/门级网表为主；内部布尔优化可能为 **专有图 + 部分 ABC 类算法**，不一定对用户暴露 “AIG” 文件名，但 **语义上等价阶段** 存在于 `compile` / `opt` 之中。

详细算法见后续 [04-optimization.md](./04-optimization.md)（待写）。

## 3. 工具链（ASIC）

Synopsys DC/Fusion、Cadence Genus 等架构类似：**前端共享 elaboration + GTECH 思想**，后端映射/优化各有实现。

## 下一节

[01 RTL 解析与 Elaboration（综合器内部）](./01-rtl-parsing-and-elaboration.md)
