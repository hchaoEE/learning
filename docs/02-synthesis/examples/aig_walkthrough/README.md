# AIG / 粗粒度优化 walkthrough — 内部 IR 对照

与 [03 章 §4–§5、§11](../../03-optimization.md) 对照。

| 文件 | Pass | 内部变化 |
|------|------|----------|
| `comb_dup.sv` | strash | 重复 `(a&b)` **合并为单节点** |
| `comb_const.sv` | 常量传播 | 子锥 **折叠** 为 0/1 |
| `comb_mux.sv` | lowering | MUX → AND/OR AIG |
| `reg_comb_boundary.sv` | 边界 | 加法器 **算术壳**，不进 AIG 拆解 |
| `chain_and.sv` | balance | 六输入链 AND → 树状拉宽（03 §5.4） |

---

## 案例 A — comb_dup.sv（strash）

**RTL**：`y = a & b;`、`z = (a & b) | c;` — `(a&b)` 出现两次。

**Lowering 后**（2 份相同子表达式，前 IR）：

```text
n1 = AND(a,b) ──► y
n2 = AND(a,b) ──!──┐
                   AND ──!── z     （OR 经德摩根 = 反相 AND）
c ───────────!─────┘
```

**strash 后**（后 IR）：

```text
t = AND(a,b) ──┬──► y              （fanout = 2）
               └─!─┐
                   AND ──!── z
c ────────────!────┘
```

| 指标 | 前 | 后 |
|------|----|----|
| `AND(a,b)` 节点 | 2 | 1 |
| 共享节点 fanout | — | `t` fanout=2 |

与 [03 §4.1](../../03-optimization.md) 一致。

---

## 案例 B — comb_mux.sv

**RTL**：`unique case (sel)` 二选一 — lowering 后即 `GTECH_MUX(sel, a, b)`（每位一个）。

**AIG（示意，`!` = 边反相）**：`y = (a∧¬sel) ∨ (b∧sel) = ¬(¬(a∧¬sel) ∧ ¬(b∧sel))`

```text
t1 = AND(a, !sel)
t2 = AND(b,  sel)
y  = !AND(!t1, !t2)
```

| 阶段 | 前 IR | 后 IR |
|------|-------|-------|
| lowering | `GTECH_MUX` ×4（每位） | AND×3 + inv 边 ×4（每位，示意） |
| rewrite 后 | — | sel 扇出共享，节点数下降 |

---

## 案例 C — reg_comb_boundary.sv

**RTL**：组合锥为 `sum = a ^ b`（XOR）；`q <= sum + 1'b1` 的 **+1 加法** 在算术边界。

```text
[PI a,b] ──► AIG 组合锥（XOR 分解为 AND+inv） ──► sum
                                                  │
                                            GTECH_ADD (+1)（保留，不拆成 AND 阵列）
                                                  │
                                             [SEQGEN.D] → q
```

| 前 IR | 后 IR |
|-------|-------|
| `GTECH_XOR` + `GTECH_ADD` + SEQGEN | XOR 锥进 AIG；ADD 与 SEQGEN 原样保留 |

---

## 阅读顺序

03 §2 为何 AIG → 本目录 → 03 §5 pass 表 → 04 映射
