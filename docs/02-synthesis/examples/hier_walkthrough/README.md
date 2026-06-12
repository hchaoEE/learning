# 层次化综合 walkthrough

与 [11 章](../../11-hierarchical-block-synthesis.md) **§4** 对照。

## 文件

| 文件 | 说明 |
|------|------|
| `cpu_core.sv` | 子块：累加器，输出 `out_data` |
| `top.sv` | 顶层：例化 `cpu_core` + glue `host_result = core_out + 1` |

```text
host_data ──► cpu_core ──► core_out ──► (+1) ──► host_result
                  ↑ clk
```

顶层 STA 在 **`core_out` 接口** 上分配 budget；子块内闭合后 characterize 出 abstract 供顶层引用。

---

## 案例 A — budget 迭代（§4.2）

**顶层** period = 2.0 ns；子块 `cpu_core` 初分配 `out_budget=0.60`（偏松）。

| 轮次 | 子块 WNS | 接口 slack | 动作 |
|------|----------|------------|------|
| 1 | +0.12 | −0.25 | 收紧 out_budget → 0.40 |
| 2 | +0.01 | −0.04 | 顶层 glue sizing |
| 3 | +0.02 | +0.02 | 收敛 + freeze budget |

每轮子块重综合后须 **重 characterize** abstract（§3.3）。

---

## 案例 B — 层次化 LEC（见 [lec_walkthrough](../lec_walkthrough/)）

子块 proven → 顶层仅比边界 + glue。

---

## 阅读顺序

```text
11 §3 abstract → §4 案例 A → 10 §8 LEC
```
