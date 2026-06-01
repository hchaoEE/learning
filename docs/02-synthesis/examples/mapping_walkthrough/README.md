# 工艺映射 walkthrough — 内部 cover 对照

与 [04 章 §11](../04-technology-mapping.md#11-案例集锦逐步理解-mapping) 对应。

| 文件 | 主题 | 映射关注点 |
|------|------|------------|
| `map_and_or.sv` | `(a&b)\|c` | cut 选 2 级 ND2 vs 单 OAI |
| `map_mux.sv` | 2:1 MUX | 库 MUX2 vs NAND 分解 |
| `map_xor_chain.sv` | XOR 链 | K=4 分级 vs K=6 单门 |

---

## 案例 A — map_and_or.sv

**AIG 节点**：`n = OR(AND(a,b), c)`

| cut 方案 | cover（示意） | 单元数 |
|----------|---------------|--------|
| 小 cut 分级 | ND2 + OR2 | 2 |
| 大 cut + OAI | OAI21（吸收 inv） | 1 |

**delay 模式**：倾向 **单 OAI**；**area 模式**：倾向 **双 ND2**。

---

## 案例 B — map_mux.sv

**GTECH MUX** → 映射器查菜单：

- 有 `MUX2D1` → 1 单元  
- 无 MUX → 4× NAND 或 AND/OR 网（§5）

---

## 案例 C — map_xor_chain.sv（K 对比）

5 输入 XOR 锥：

| K | 内部结果 |
|---|----------|
| 4 | 至少 **2 级** 标准门 |
| 6 | 可能 **1 个** 复杂 XOR/AOI cover |

---

## 与 06 分界

本目录只到 **初映射**；`ND2D1→ND2D4` 属 [06 tdo_walkthrough](../tdo_walkthrough/)。
