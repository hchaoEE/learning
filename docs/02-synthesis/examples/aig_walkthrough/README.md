# AIG / 粗粒度优化 walkthrough — 内部 IR 对照

与 [03 章 §4–§5、§11](../03-optimization.md) 对照。

| 文件 | Pass | 内部变化 |
|------|------|----------|
| `comb_dup.sv` | strash | 重复 `(a&b)` **合并为单节点** |
| `comb_const.sv` | 常量传播 | 子锥 **折叠** 为 0/1 |
| `comb_mux.sv` | lowering | MUX → AND/OR AIG |
| `reg_comb_boundary.sv` | 边界 | 加法器 **算术壳**，不进 AIG 拆解 |

---

## 案例 A — comb_dup.sv（strash）

**Lowering 后**（2 份相同子表达式）：

```text
n1 = AND(a,b)    n2 = AND(a,b)    y = AND(n1,n2)
```

**strash 后**：

```text
t  = AND(a,b)    y = AND(t,t)  → 优化为 y = t
```

| 指标 | 前 | 后 |
|------|----|----|
| AND 节点 | 3 | 1 |

---

## 案例 B — comb_mux.sv

**GTECH**：`GTECH_MUX(sel, a, b)`

**AIG（示意）**：

```text
t1 = AND(a, sel)
t2 = AND(b, NOT(sel))
y  = OR(t1, t2)
```

---

## 案例 C — reg_comb_boundary.sv

```text
[PI] ──► AIG 组合锥 ──► [SEQGEN.D]
         加法 GTECH_ADD（保留）
              ↑ 不拆成 AND 阵列
```

---

## 阅读顺序

03 §2 为何 AIG → 本目录 → 03 §5 pass 表 → 04 映射
