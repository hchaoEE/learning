# 端到端迷你链 — 全 pass IR 快照

一条 RTL 走通 **01→06** 的内部形态变化（数字为 **示意**，用于对照章节）。

**RTL**：`mini_chain.sv` — `q <= (a*b)+1`，4×4 乘法 + 8 位 FF。

---

## 总表

| Pass | 章节 | 内部量（示意） |
|------|------|----------------|
| Elaborate | 01 | GTECH_MULT + GTECH_ADD + 1×SEQGEN |
| Inference | 02 | MULT 4×4→8b；REGISTER×8 |
| AIG opt | 03 | 组合锥 AIG nodes≈40→28；MULT **不拆** |
| Map | 04 | MULT 宏或 IP；ADD mapped；8×DFFX1 |
| STA+TDO | 05–06 | WNS 初值可能负 → upsize ADD 驱动 |

---

## 1. Elaborate 后（01）

```text
GTECH_MULT u_mul (.A(a), .B(b), .Y(prod))
GTECH_ADD  u_add (.A(prod), .B(8'd1), .Y(nxt))
SEQGEN     u_q   (.CK(clk), .D(nxt), .Q(q))
```

---

## 2. 推断后（02）

```text
u_mul:  resource_type=MULT, width=4x4
u_q:    resource_type=REGISTER, width=8
```

**实现策略（示意）**：4×4 → **门级阵列或 DW 宏**（依策略阈值）。

---

## 3. 粗优化后（03）

- `u_add` 与 `prod` 间组合锥 → **AIG**（若未与 MULT 合并）
- **MULT 壳保持**；AIG node 仅统计 ADD 锥

| 指标 | 示意 |
|------|------|
| AIG nodes（ADD 锥） | 28 |
| MULT | 仍为 GTECH/IP 壳 |

---

## 4. 映射后（04）

```text
DW02_mult / booth_array  u_mul
ND2D1/OAI* + XOR*         u_add 组合
DFFX1×8                   u_q
```

**内部检查**：无残留 `GTECH_*` 组合（MULT 除外壳名）。

---

## 5. 初 STA + 细优化（05–06）

**timing graph（示意，period=1.0 ns）**：

| 路径段 | delay |
|--------|-------|
| MULT | 0.45 |
| ADD  | 0.22 |
| DFF  | 0.12+0.08 |

**WNS 初值 ≈ −0.05** → 06 对 ADD 输出 **upsize** → WNS ≈ +0.03。

---

## 6. 签核侧（09，概念）

- **Compare points**：`q[7:0]` ↔ 8 FF Q；PO 若仅 `q` 则 8+1 点
- **MULT 宏**：R/I 均须 **同黑盒** 或同 IP 模型

---

## 阅读链接

```text
mini_chain → 01 elab → 02 推断 → 03 AIG → 04 map → 05 SDC → 06 TDO → 09 LEC
```

各阶段详述见对应章 + 专题 walkthrough。
