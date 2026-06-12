# 术语表（入口）

**完整专业词汇表**（含 **strash、CSA 树、cut/cover** 等详解）：

**[→ docs/glossary.md（完整版）](../glossary.md)**

## 本页速查（10 条）

| 术语 | 一句话 |
|------|--------|
| **strash** | AIG 结构性哈希，合并相同 `(AND,子节点)`，去重不减逻辑 |
| **CSA 树** | 多操作数加法用进位保留压缩，最后只做一次进位传播 |
| **AIG** | 全是 2 输入 AND + 边反相的布尔图，映射前优化用 |
| **cut / cover** | 映射时选的 AIG 子图窗口 / 用库单元实现该窗口 |
| **GTECH** | 工艺无关中间网表（映射前） |
| **Elaborate** | 展开 parameter/generate，建 Design DB |
| **Lowering** | `always` → GTECH 门/SEQGEN |
| **TDO** | 映射后按时序修 slack（upsize、buffer…） |
| **LEC** | 形式化证明 RTL 与网表等价 |
| **WNS** | 最差时序裕量（负值=违例） |

更多词条与机制说明见 [完整词汇表](../glossary.md)。
