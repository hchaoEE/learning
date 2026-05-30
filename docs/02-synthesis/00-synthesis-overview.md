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

## 3. 工具链（ASIC）

Synopsys DC/Fusion、Cadence Genus 等架构类似：**前端共享 elaboration + GTECH 思想**，后端映射/优化各有实现。

## 下一节

[01 RTL 解析与 Elaboration（综合器内部）](./01-rtl-parsing-and-elaboration.md)
