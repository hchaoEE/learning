# 2.5 时序约束（SDC）（待写）

SDC 是综合与 STA 的 **共同输入**；建议在读 **04 映射 / 06 时序优化** 前至少通读一遍时钟与 IO 约束。

## 1. 在流程中的位置

```text
        05 SDC（create_clock, set_input_delay, …）
              │
              ├──────► compile 各阶段（驱动优化目标）
              │
              └──────► PrimeTime 签核
```

**阅读提示**：路径 B 可在 01 之前先读本章 **§2 时钟**。

## 2. 计划内容

| 节 | 主题 |
|----|------|
| 2.1 | SDC 在综合 vs STA 中的角色 |
| 2.2 | 时钟定义、`generated_clock` |
| 2.3 | IO delay、`set_drive` / `set_load` |
| 2.4 | 例外：`false_path`、`multicycle_path` |
| 2.5 | 与 Design DB 的关联（port/pin 名） |
| 2.6 | 输入/输出案例（SDC 片段 ↔ 违例报告） |

## 3. 与其它章边界

| 不写 | 见 |
|------|-----|
| 报告字段解读 | [07](./07-synthesis-reports.md) |
| 物理延时 | [03-pnr](../03-pnr/) |

## 4. 前置 / 后续

- 可与 [01](./01-rtl-parsing-and-elaboration.md) 并行
- 后续：[06](./06-timing-driven-optimization.md)、[07](./07-synthesis-reports.md)
