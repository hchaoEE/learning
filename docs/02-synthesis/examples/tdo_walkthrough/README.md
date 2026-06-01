# 细粒度优化（TDO）walkthrough

与 [06 章](../06-timing-driven-optimization.md) **§2–§5** 对照。本目录只提供 **RTL + 内部 IR/delay/slack 示意**，不包含工具 flow 脚本。

## 文件

| 文件 | 对应章节 | 说明 |
|------|----------|------|
| `setup_critical_chain.sv` | §2.5、§3 | 5 级组合 AND 链 → 映射后 setup 易负 |
| `hold_short_path.sv` | §4 | 单级组合 → fast corner hold 易负 |

---

## 案例 A — setup_critical_chain（§2.5）

### 1. RTL → 映射网表（片段）

```text
a ──┐
b ──┼── ND2 ── ND2 ── ND2 ── ND2 ── ND2 ── DFF/D
c ──┤   u1     u2     u3     u4     u5
d ──┤
e ──┘
```

### 2. 内部 delay 表（示意，period = 1.0 ns，slow max）

| 弧 ID | 从 → 到 | delay (ns) |
|-------|---------|------------|
| A0 | clk → reg_q/CK | 0.00 (ideal) |
| A1 | reg_q/Q → u1/A | 0.00 |
| A2–A6 | 每级 ND2D1 | 0.18 × 5 = 0.90 |
| A7 | u5/Z → reg_q/D | 0.00 |
| — | reg_q setup | 0.08 required |

**Arrival @ reg_q/D** ≈ 0.12 (CLK→Q) + 0.90 = **1.02 ns**  
**Required** ≈ 1.00 − 0.08 = **0.92 ns**  
**slack_setup** ≈ **−0.10 ns**（违例）

### 3. Transform 序列（引擎内部日志风格）

| 轮次 | Transform | 变更 | 新 WNS |
|------|-----------|------|--------|
| 0 | — | 初态 ND2D1×5 | −0.10 |
| 1 | upsize | u2,u3,u4 → ND2D4 | −0.02 |
| 2 | upsize | u1,u5 → ND2D2 | +0.04 |

### 4. 与 03/04 的分界

- **03** 不会在此网表上再 rewrite AIG（已 mapped）  
- **04** 已选定 ND2D1 cover；**06** 在 **同一拓扑** 上换 **ref**（sizing）

---

## 案例 B — hold_short_path（§4）

### 1. 拓扑

```text
reg_a/Q ── ND2D4 ── reg_b/D     （故意强驱动 + 极短组合）
```

### 2. 双 corner slack（示意）

| Corner | 组合 delay | setup slack | hold slack |
|--------|------------|-------------|------------|
| slow max | 0.25 ns | +0.15 ✓ | +0.05 ✓ |
| fast min | 0.06 ns | +0.34 ✓ | **−0.04** ✗ |

### 3. Transform

在 **reg_b/D 前** 插 `DELAYX1`（仅显著增加 min delay）：

| Corner | hold slack 后 |
|--------|---------------|
| fast min | +0.06 ✓ |
| slow max | +0.13 ✓（仍满足 setup） |

### 4. 与案例 A 的冲突提醒

若在案例 A 路径上 **无差别 upsize**，可能在 fast corner 引入 **hold 违例** — 06 引擎需 **multi-corner 接受判定**（06 §4.2）。

---

## 案例 C — 高 fanout net（§5，概念）

不单独 RTL：在任意 mapped 设计中，某 net fanout=32 → **transition/cap DRC 违例**。

**内部修复**：driver 后 buffer tree 1→4→8，再 incremental STA 确认 critical path 未恶化。

---

## 阅读顺序

```text
06 §1 对比 03 → §2 引擎 → 本目录案例 A → §3 setup
                              → 案例 B → §4 hold → §5 DRC
```
