# 逻辑综合与物理设计学习文档

面向数字 IC / FPGA 工程师的系统化自学路径：从 **可综合 RTL** 出发，经 **逻辑综合** 到 **布局布线（PnR）**，并串联 EDA 工具链与工程实践。

## 如何使用本文档

| 阶段 | 目录 | 前置知识 | 产出能力 |
|------|------|----------|----------|
| 0 | [00-preface](./00-preface/) | 数字电路基础 | 统一术语、了解工具链 |
| 1 | [01-rtl](./01-rtl/) | Verilog 入门更佳 | 写出可综合、可维护的 RTL |
| 2 | [02-synthesis](./02-synthesis/) | 完成 01-rtl | 理解综合报告、约束与优化 |
| 3 | [03-pnr](./03-pnr/) | 完成 02-synthesis | 理解时序收敛与物理效应 |
| 4 | [04-flow-and-tools](./04-flow-and-tools/) | 上述章节 | 跑通一条完整 EDA 流程 |
| 5 | [05-practice](./05-practice/) | 按需 | 实验、Checklist、面试题 |

建议按编号顺序阅读；每章末尾有 **小结** 与 **延伸阅读**。

## 完整目录结构

```text
docs/
├── README.md                          # 本文件：总索引与学习路径
│
├── 00-preface/                        # 前言与基础
│   ├── README.md
│   ├── glossary.md                    # 术语表（RTL、SDC、LEF/DEF…）
│   └── eda-toolchain-overview.md      # 综合 / PnR / STA 工具角色（待写）
│
├── 01-rtl/                            # ★ 当前重点：RTL 与可综合写法
│   ├── README.md
│   ├── 01-verilog-module-and-ports.md
│   ├── 02-data-types-and-operators.md
│   ├── 03-continuous-and-procedural.md
│   ├── 04-sequential-logic.md
│   ├── 05-fsm.md
│   ├── 06-generate-and-parameters.md
│   ├── 07-synthesizable-subset.md     # 可综合子集 vs 仿真专用构造
│   ├── 08-coding-guidelines.md        # 编码规范与反模式
│   └── examples/                      # 可综合示例（供仿真/综合实验）
│       └── README.md
│
├── 02-synthesis/                      # 逻辑综合（待展开）
│   ├── README.md
│   ├── 01-rtl-to-gates-overview.md
│   ├── 02-elaboration-and-inference.md
│   ├── 03-technology-mapping.md
│   ├── 04-optimization.md
│   ├── 05-constraints-sdc.md
│   ├── 06-timing-and-area-reports.md
│   └── 07-low-power-synthesis.md
│
├── 03-pnr/                            # 布局布线（待展开）
│   ├── README.md
│   ├── 01-floorplan.md
│   ├── 02-placement.md
│   ├── 03-clock-tree-synthesis.md
│   ├── 04-routing.md
│   ├── 05-physical-verification.md
│   └── 06-signoff-timing.md
│
├── 04-flow-and-tools/                 # 流程与脚本（待展开）
│   ├── README.md
│   ├── Makefile-and-filelists.md
│   └── from-rtl-to-gds-flow.md
│
└── 05-practice/                       # 练习与清单（待展开）
    ├── README.md
    ├── rtl-review-checklist.md
    └── lab-ideas.md
```

## 与工业流程的对应关系

```mermaid
flowchart LR
  RTL["01 RTL 设计"] --> SYN["02 逻辑综合"]
  SYN --> NET["门级网表"]
  NET --> PNR["03 布局布线"]
  PNR --> GDS["版图 / 比特流"]
  SDC["SDC 约束"] --> SYN
  SDC --> PNR
  LIB["工艺库 .lib"] --> SYN
  LEFDEF["LEF/DEF"] --> PNR
```

## 当前进度

- [x] 文档骨架与目录规划
- [x] **01-rtl**：RTL 语法与可综合写法（第一版）
- [ ] 02-synthesis：原理章节
- [ ] 03-pnr：原理章节
- [ ] 示例与实验脚本

## 参考与约定

- HDL 以 **Verilog-2001 / SystemVerilog 可综合子集** 为主；必要时提及 VHDL。
- 代码块默认 **可综合**；标注 `// simulation only` 的为仅仿真构造。
- 位宽、时钟域、复位策略在 RTL 阶段即应明确，避免留给综合/PnR “猜”。
