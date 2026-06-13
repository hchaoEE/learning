# 工艺映射 walkthrough — 内部 cover 对照

与 [04 章 §11](../../04-technology-mapping.md#11-案例集锦逐步理解-mapping) 对应。

| 文件 | 主题 | 映射关注点 |
|------|------|------------|
| `map_and_or.sv` | `(a&b)\|c` / `!(a&b)\|c` | cut 选 2 级门 vs 单 **AOI21/OAI21** |
| `map_mux.sv` | 2:1 MUX（2 位总线） | 库 MUX2 vs NAND 分解 |
| `map_xor_chain.sv` | 3 输入 XOR 链 | cut 大小决定分级 vs 单门 |
| `demo.genlib` | 手写门库（AOI21/OAI21） | 见 [04 §5.4](../../04-technology-mapping.md#54-手写-genlib--abc-map理解-cover-从哪来) |
| `run_abc_map.sh` | ABC 映射实验脚本 | AIG 导出 + `abc` 对比 cover |

## AOI/OAI

阅读 [04 章 §5.3](../../04-technology-mapping.md#53-aoi--oai--oa为何工艺库爱用复杂门)：`!(a&b)|c` 用 **OAI21** 单单元 vs 多级 ND2/INV；极性匹配见 [04 §5.1b](../../04-technology-mapping.md#51b-aoioai-极性匹配与-pin-置换)。

---

## 案例 A — map_and_or.sv

**前后对比（AIG → mapped 网表）**：

| 前（优化后 AIG） | 后（mapped） |
|-------------------|---------------|
| `y = ¬(¬(a∧b) ∧ ¬c)`，2 AND + 3 inv 边 | 见下两种 cover |

| cut 方案 | cover（示意） | 单元数 |
|----------|---------------|--------|
| 小 cut 分级 | AN2 + OR2（或 ND2 + 反相输入门） | 2 |
| 大 cut 单门 | AO21（inv 边吸收进单元极性） | 1 |

**delay 模式**：倾向 **单 AO21**；**area 模式**：依库面积，两者皆可能。

---

## 案例 B — map_mux.sv

**前后对比**：

| 前（lowering/AIG） | 后（mapped） |
|---------------------|---------------|
| 每位 `GTECH_MUX(sel, a[i], b[i])`，共 2 位 | 有 `MUX2D1` → 2 个单元 |
| 同上 | 无 MUX 单元 → 每位 3–4 个 NAND 网络 |

---

## 案例 C — map_xor_chain.sv（cut 大小对比）

3 输入 XOR 锥 `q = (a^b)^c`（另有中间输出 `p = a^b`）：

| 前（AIG） | K | 后（mapped） |
|------------|---|---------------|
| 每个 XOR 分解为 3 AND + inv 边，两级共 ~6 节点 | 2 | 2×`XOR2D1` 级联（`p` 锥复用第一级） |
| 同上 | ≥3 | `q` 锥可整体进一个 cut → 库有 `XOR3` 时 **单单元**；`p` 仍需独立 `XOR2`（它是 PO） |

---

## 与 06 分界

本目录只到 **初映射**；`ND2D1→ND2D4` 属 [06 tdo_walkthrough](../tdo_walkthrough/)。
