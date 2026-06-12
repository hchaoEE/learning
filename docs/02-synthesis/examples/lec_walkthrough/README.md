# LEC walkthrough

与 [10 章](../../10-logical-equivalence-checking.md) **§4–§5、§8** 对照。

| 文件 | 说明 |
|------|------|
| `reset_polarity.sv` | async reset；I 侧 `.RN` 极性错 → Cycle0 反例 |

---

## 案例 A — reset_polarity（§4.2、§5.1）

**R**：`rst_n` active-low，`!rst_n` 时 `q<=0`。

**I（错误网表）**：`DFFRX1` 的 `.RN` 接到 `rst_n`（未取反）→ 复位极性反。

| Cycle | 赋值 | R.q | I.Q | diff |
|-------|------|-----|-----|------|
| 0 | rst_n=0 | 0 | **1** | 1 |

**引擎**：SAT **falsified**；最小反例集 `{rst_n=0}` → §7.1 复位期分支。

---

## 案例 B — 层次化 LEC（§8）

```text
cpu_core:  A_R ↔ A_I  proven（50k 门）
top:       仅 glue + cpu_core 边界 pin  compare（800 门）
```

块内 ECO 后须 **重证 cpu_core** 再跑 top。

---

## 阅读顺序

```text
10 §2 miter → §4 时序 → 案例 A → §5 SAT → §8 案例 B
```
