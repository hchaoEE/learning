# 低功耗 / ICG walkthrough

与 [02 §9](../../02-inference.md#9-时钟门控icg推断--asic-低功耗)、[08 章](../../08-low-power-synthesis.md) 对照。

## 案例 A — ICG 推断（icg_bank.sv）

### 推断前 GTECH

```text
clk ──────────────────────► SEQGEN[31:0].CK
en  ──► (组合) ──► SEQGEN[i].EN
d   ─────────────► SEQGEN[31:0].D
```

### 推断后 GTECH

```text
clk ──► ICG_shell(en_sync) ──► clk_g ──► SEQGEN[31:0].CK
```

### 映射后

```text
clk ──► CKLNQD1/E ──► clk_g ──► 32 × DFFX1
```

| 指标（内部趋势） | 无 ICG | 有 ICG |
|------------------|--------|--------|
| clock net 活动度 | 100% toggle | ∝ P(en) |
| 面积 | 32 DFF | 32 DFF + 1 ICG |

---

## 案例 B — 跨电压域（08 §2）

**DB 标注（概念，无真实 .upf 文件）**：

| 对象 | 属性 |
|------|------|
| `PD_CPU` | voltage=0.9V，可关断 |
| `PD_IO` | voltage=1.0V，always_on |
| net `cpu_irq` | crossing={PD_CPU, PD_IO} |

**映射 cut point**：`LEVEL_SHIFTER` +（关断时）`ISOLATION_CELL`

**时序图**：LS arc 增加 setup/hold；MCMM 各 corner 用对应电压 `.lib`。

---

## 阅读顺序

```text
02 §9 → 本目录案例 A → 08 §2–§4 → 05 §6 MCMM
```
