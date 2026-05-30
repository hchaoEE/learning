# 03 布局布线（Place & Route）

> **状态：待编写** — 以 **Cadence Innovus** / **Synopsys ICC2** 等标准单元后端流程为准。

## 计划章节

1. Floorplan：芯片/模块布局规划
2. Placement：标准单元摆放
3. CTS：时钟树综合与 skew
4. Routing：全局布线与详细布线
5. 物理验证：DRC / LVS 概念
6. Signoff STA 与后端时序收敛

## 与 02-synthesis 的衔接

综合输出的 **门级网表 + SDC** 是 PnR 的输入；RTL 阶段的时钟/复位定义会影响 CTS 与 SI/PI 分析。
