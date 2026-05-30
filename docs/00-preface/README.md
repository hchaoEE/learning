# 00 前言

## 目标读者

- 已学过数字逻辑、了解组合/时序电路，希望系统掌握 **ASIC：RTL → 综合 → PnR → 签核** 的工程师或研究生。
- 数字 IC 前端 / 综合 / 后端工程师巩固方法论。

## 设计范围

- **仅 ASIC 标准单元流程**（含 IO、宏单元、MCMM 等概念）。
- 不涉及 FPGA、可编程逻辑阵列或比特流实现。

## 本章内容

| 文件 | 说明 |
|------|------|
| [glossary.md](./glossary.md) | 全文术语表，阅读各章时可随时查阅 |
| eda-toolchain-overview.md | （待写）Synopsys/Cadence/Siemens 等工具在流程中的位置 |

## 学习建议

1. 先浏览 [术语表](./glossary.md)，避免后文缩写歧义。
2. 进入 [01-rtl](../01-rtl/)，用编辑器对照 `examples/` 里的代码。
3. 每学完一章，用 [05-practice](../05-practice/) 中的 Checklist 自检（该目录待补充）。
