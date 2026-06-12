# 内部 STA walkthrough — AT / RT / slack 跟练

与 [07 章](../../07-internal-sta-and-qor.md) **§3–§4** 对照。用 **手算表** 建立「引擎在算什么」的直觉，非 PrimeTime 教程。

## 文件

| 文件 | 说明 |
|------|------|
| （拓扑示意） | 案例 A 五节点图，无独立 RTL |
| [../sdc_walkthrough/simple_ff_path.sv](../sdc_walkthrough/simple_ff_path.sv) | 案例 B 简化：两级 FF 真实 RTL |

---

## 案例 A — 五节点全表推演（07 §3.1）

**拓扑**（mapped 网表片段）：

```text
reg_a/Q ──0.2──► u1/ZN ──0.3──► u2/ZN ──0.2──► reg_q/D
   ↑ CK                                              ↑ CK
   └── clk ──────────────────────────────────────────┘
```

**假设**：`clk` period = 1.0 ns；`reg_a` CLK→Q = 0.1 ns（含在第一条 data arc 起点）；FF setup = 0.1 ns；ideal clock。

### Step 1 — Forward AT（max 分析）

| pin | 计算 | AT |
|-----|------|-----|
| reg_a/Q | launch 沿 + CLK→Q | **0.1** |
| u1/ZN | 0.1 + 0.2 | **0.3** |
| u2/ZN | 0.3 + 0.3 | **0.6** |
| reg_q/D | 0.6 + 0.2 | **0.8** |

### Step 2 — Backward RT（max 分析）

capture 沿在 1.0 ns；`required(D) = 1.0 − setup = 0.9`。

| pin | 计算 | RT |
|-----|------|-----|
| reg_q/D | 锚点 | **0.9** |
| u2/ZN | 0.9 − 0.2 | **0.7** |
| u1/ZN | 0.7 − 0.3 | **0.4** |
| reg_a/Q | 0.4 − 0.2 | **0.2** |

### Step 3 — Slack

```text
slack(pin) = RT(pin) − AT(pin)
```

| pin | slack |
|-----|-------|
| reg_a/Q | 0.2 − 0.1 = **+0.1** |
| u1/ZN | 0.4 − 0.3 = **+0.1** |
| u2/ZN | 0.7 − 0.6 = **+0.1** |
| reg_q/D | 0.9 − 0.8 = **+0.1** |

**结论**：单路径、无分叉时 **沿途 slack 相同**；WNS = +0.1。若 `u1/ZN` 另有更慢扇入，则 AT 取 max，slack 在分叉处开始分化（07 §3.3）。

---

## 案例 B — uncertainty 收紧 slack（07 §4.1）

在案例 A 上增加：`set_clock_uncertainty 0.05`（setup 侧）。

| 量 | 无 uncertainty | 有 uncertainty |
|----|----------------|----------------|
| required @ reg_q/D | 0.9 | 1.0 − 0.1 − **0.05** = **0.85** |
| slack @ reg_q/D | +0.1 | 0.85 − 0.8 = **+0.05** |

**结论**：uncertainty **直接从 required 扣除**，全 endpoint 同步收紧 — 与 latency 在同 clock 域常抵消不同（[05 案例 9.2](../05-constraints-sdc.md)）。

---

## 案例 C — RTL 对照（两级 FF）

**RTL**：[simple_ff_path.sv](../sdc_walkthrough/simple_ff_path.sv) — `din → reg_mid → reg_out`。

| 抽象 | 对应案例 A |
|------|------------|
| reg_mid / reg_out | reg_a / reg_q |
| 中间组合 | 可折叠为一条 arc（若仅连线） |

读入 SDC 后引擎自动建图；手算时把 **cell arc + net arc** 合并为表中的数字即可（与 [sdc_walkthrough 案例 A](../sdc_walkthrough/README.md#案例-a--时钟与-setup-check052) 同一 RTL）。

---

## 阅读顺序

```text
07 §2 timing graph → 本目录案例 A → 07 §4 check → 案例 B → 06 transform 消费 slack
```
