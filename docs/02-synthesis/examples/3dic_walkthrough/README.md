# 3D IC / Chiplet walkthrough

与 [15 章](../../15-3d-ic-synthesis.md) **§1–§7** 对照。本目录提供 **RTL + SDC 示意 + 内部 DB/timing 表**，不包含可运行综合脚本。

## 文件

| 文件 | 对应章节 | 说明 |
|------|----------|------|
| `chiplet_top.sv` | §2、§3 | die0 计算 + die1 存储，经 `die_bus` 跨 die |
| `inter_die.sdc` | §4 | bump 上的 `set_input_delay` 示意 |

---

## RTL → DB 对象对照

| RTL | die_id | timing 对象 |
|-----|--------|-------------|
| `u_compute/*` | D0 | on-die cell/net |
| `u_mem/*` | D1 | on-die cell/net |
| `die_bus[*]` | — | `inter_die_net` + TSV/bump 弧 |

---

## 案例 A — 跨 die 路径 slack（§3.1）

### 路径拓扑

```text
reg(sum_r)/Q (D0) → ND2 → bump_out ──[TSV 0.18ns]── bump_in → ND2 → reg(mem_r)/D (D1)
```

### delay / AT 表（period = 1.0 ns，slow max，示意）

| 段 | delay (ns) | 累计 AT @ capture |
|----|------------|-------------------|
| clk→Q (D0) | 0.10 | 0.10 |
| u_compute 组合 | 0.20 | 0.30 |
| TSV 弧 | **0.18** | 0.48 |
| u_mem 组合 | 0.15 | 0.63 |
| setup | 0.08 | required = 0.92 |

**slack_setup** = 0.92 − 0.63 = **+0.29 ns**

### TSV 恶化场景（§5.1）

若 TSV 模型更新为 **0.35 ns**（封装工艺变更）：

| 操作 | ΔWNS | 说明 |
|------|------|------|
| upsize u_mem 内 ND2 | +0.02 | 仅修 on-die 段 |
| upsize TSV 弧 | **0** | 弧不可 transform |
| retime 在 D0 出口插 FF | +0.12 | 允许时架构级修 |

---

## 案例 B — abstract 迭代（§6.1）

| 事件 | 顶层 WNS |
|------|----------|
| 初版 abstract_d0，bump_out max_delay = 0.30 | +0.05 |
| die0 重 compile 后 max_delay = 0.38 | **−0.03** |
| 回 die0 修路径或谈判 budget | 目标回到 ≥ 0 |

---

## 与邻章分界

| 主题 | 本章 walkthrough | 详见 |
|------|------------------|------|
| 通用 upsize/buffer | 仅示意 on-die 段 | [06](../../06-timing-driven-optimization.md) |
| AT/RT 算法 | 表格式推演 | [07](../../07-internal-sta-and-qor.md) |
| abstract characterize | 案例 B | [11](../../11-hierarchical-block-synthesis.md) |
| 交付 manifest | 概念 YAML | [15 §7](../../15-3d-ic-synthesis.md#7-交付与签核3d-增项) |
