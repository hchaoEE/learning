# DFT / scan walkthrough

与 [12 章](../../12-dft-and-scan.md) **§5–§6** 对照。

| 文件 | 说明 |
|------|------|
| `scan_modes.sdc` | functional / shift / capture 子模式（概念） |

---

## 案例 A — 50:1 scan compression（§5.2）

| 指标 | 20 链×5k | 100 内链 + 50:1 压缩 |
|------|----------|----------------------|
| shift 周期 | 5,000 | 1,000 |
| 新增 XOR 门 | 0 | ~12k |
| 压缩后 test WNS | — | 常需重跑 06 |

---

## 案例 B — lockup latch（§5.3）

```text
FF_a (clk 晚 0.3ns) ──Q──► LOCKUP_LAT ──► FF_b/SI (clk 早)
```

shift hold：直连 −0.08 → 插 lockup 后 +0.12。

---

## 案例 C — test mode 子模式（§6）

见 `scan_modes.sdc`：`scan_en=0` functional vs `scan_en=1` shift hold 检查。

---

## 阅读顺序

```text
12 §2 scan 换型 → §5.2 A → §5.3 B → §6 C → 06 再优化
```
