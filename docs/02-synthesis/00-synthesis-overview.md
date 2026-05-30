# 2.0 逻辑综合总览

ASIC **逻辑综合** 将 RTL 转换为满足 **时序、面积、功耗** 约束的 **门级网表**（标准单元 + 若干宏），供 PnR 与 STA 使用。

## 1. 三阶段模型

```text
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│ RTL 解析与展开   │ → │ 推断 + 工艺映射  │ → │ 优化 + 约束驱动  │
│ (Elaboration)   │   │ (Mapping)       │   │ (Optimization)  │
└─────────────────┘   └─────────────────┘   └─────────────────┘
        ↑                       ↑                       ↑
   本章 01 文档            推断 / mapping 章节        优化 / SDC 章节
```

| 阶段 | 文档（计划/状态） |
|------|-------------------|
| RTL 解析与 Elaboration | [01-rtl-parsing-and-elaboration.md](./01-rtl-parsing-and-elaboration.md) **已写** |
| 推断 | [02-inference.md](./02-inference.md) 待写 |
| 工艺映射 | [03-technology-mapping.md](./03-technology-mapping.md) 待写 |
| 优化 | [04-optimization.md](./04-optimization.md) 待写 |
| SDC | [05-constraints-sdc.md](./05-constraints-sdc.md) 待写 |
| 报告 | [06-timing-and-area-reports.md](./06-timing-and-area-reports.md) 待写 |
| 低功耗 | [07-low-power-synthesis.md](./07-low-power-synthesis.md) 待写 |

## 2. 主要输入与输出

| 类型 | 文件/对象 |
|------|-----------|
| 输入 | RTL（.v/.sv）、filelist、SDC、.lib（+ DB）、UPF（可选）、工艺 tie cell 等 |
| 输出 | 门级 Verilog/VHDL、.sdf（可选）、DDC/NDM 检查点、综合报告 |

## 3. 工具链（ASIC）

- **Synopsys**：Design Compiler / Fusion Compiler + PrimeTime 签核  
- **Cadence**：Genus + Innovus + Tempus  

本章系列以流程概念为主；具体 Tcl 选项以各项目 **Flow 脚本** 为准。

## 下一节

[01 RTL 解析与 Elaboration](./01-rtl-parsing-and-elaboration.md)
