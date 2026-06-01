# Retiming walkthrough — 内部 timing graph 对照

与 [06 章 §8 Retiming](../06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) 对照。

| 文件 | 说明 |
|------|------|
| `long_comb.sv` | 单 always 块内多级组合；retime 可 **切分组合段** |

---

## 案例 A — long_comb.sv（retime 前）

**RTL 结构**（单周期）：

```text
clk ──► FF(t1) ── comb1 ──► FF(t2) ── comb2 ──► FF(q)
              └── 同一 always 内连续赋值
```

**映射后 timing graph**（示意）：

```text
one launch-capture 路径含 comb1+comb2 全段
WNS = -0.15 ns（组合过深）
```

---

## 案例 B — retime 后（内部）

**动作**：在 comb1/comb2 之间 **插入或搬移 FF**（允许 latency 变）。

```text
clk ──► FF ── comb1 ── FF ── comb2 ── FF(q)
              （2 段组合变浅）
```

| 指标 | 前 | 后 |
|------|----|----|
| 组合 depth | 全路径 | 分段 |
| WNS | -0.15 | +0.08（示意） |
| I/O latency | 1 cycle | **可能 2+** |
| FF 数 | 3 | 4 |

---

## 案例 C — dont_retime 属性

**DB**：`u_ctrl/* .dont_retime = true`

**引擎**：仅 **datapath** 可搬移 FF；控制逻辑 **FF 拓扑冻结**。

---

## 与 sizing 分工

| 手段 | 适用 |
|------|------|
| 06 sizing/buffer | 不宜增 latency |
| retime | 允许 **增周期数** 换频率 |

→ 与 [tdo_walkthrough](../tdo_walkthrough/) 互补。
