# 2.7 综合阶段内部量索引

`compile` 各阶段在 Design DB 上留下 **可观测的内部量**。本章是 **「看到什么变化 → 对应哪条 pass / 哪一章」** 的索引，**不是** 工具报告命令教程。

> 时序 slack 的 **计算语义** 见 [05 SDC 内部](./05-constraints-sdc.md)、[06 细粒度引擎](./06-timing-driven-optimization.md)。  
> 签核仍依赖 STA/LEC 等外部工具；此处只说明 **综合器内部在优化什么**。

---

## 1. 内部量 ↔ 章节 ↔ pass 阶段

| 内部量（概念） | 典型变化时机 | 章节 | 说明 |
|----------------|--------------|------|------|
| GTECH 节点数 | elaboration 后、03 粗优化后 | 01、03 | 仍无 `.lib` 单元名 |
| AIG node / level | 03 strash、rewrite、balance | 03 | 映射前布尔 IR |
| `resource_type` 计数 | 02 推断 | 02 | REG/LATCH/RAM/MULT 标签 |
| Mapped instance 数 | 04 cover 绑定 | 04 | 出现 `ND2D*`、`DFF*` 等 |
| Buffer/INV 占比 | 06 插 buffer、hold 修 | 06 | 细粒度指纹 |
| **WNS / TNS** | 04 初 STA、06 迭代 | 05、06 | timing graph 聚合 slack |
| Hold worst slack | 06 min corner | 05 §6、06 §4 | 与 setup 可能冲突 |
| Transition/cap 违例数 | 06 DRC 修复 | 05 §7、06 §5 | 电气 limit |
| ICG 实例数 | 02 推断 + 08 意图 | 02 §8、08 | `CKLN*` 等 |
| LS/ISO 实例数 | 08 UPF 标注后映射 | 08 | 跨电压边界 |
| Compare point 数（LEC） | 09 签核 | 09 | 非 compile pass 产物 |

---

## 2. 用内部量判断「还在哪一阶段」

| 观测 | 推断阶段 | 下一步读 |
|------|----------|----------|
| 网表仅有 `GTECH_*` | elaboration 后、未映射 | 01、02 |
| 有 AIG 统计、无 lib 单元 | 03 中、未 04 | 03 |
| 出现库单元名，WNS 很粗 | 04 刚结束 | 04、05 |
| buffer 数激增、slack 阶梯改善 | 06 迭代中 | 06 |
| 寄存器数变、组合段变短 | 06 retiming | 06 §8 |
| LATCH 标签存在 | 02 推断 | 02、RTL |

---

## 3. 违例诊断决策树

```text
                    内部违例标签
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
   setup_violation   hold_violation    no_clock
        │                 │                 │
        ▼                 ▼                 ▼
     06 §3 sizing     06 §4 delay      05 §2 clock
     buffer/retime    capture前delay   对象解析
        │                 │
        └────────┬────────┘
                 ▼
        仍负？→ 05 period/IO budget
                 或 RTL 架构
```

| 违例 | 先读 | 常见内部根因 |
|------|------|--------------|
| setup | 06 §3 | 组合过深、驱动弱 |
| hold | 06 §4 | fast corner、过强驱动 |
| transition/cap | 06 §5 | fanout 过大 |
| unconstrained | 05 §4、§8 | CDC 无 groups、SDC 悬空 |

→ 与 [00 §7 pass 表](./00-synthesis-overview.md#7-compile-内部-pass-时间线全景) 对照。

---

## 4. 违例类型 → 引擎分支（与 06 对齐）

| 内部违例标签 | 根因（机制） | 引擎分支 |
|--------------|--------------|----------|
| `setup_violation` | 数据路径太慢（max corner） | 06 §3 sizing/buffer；§8 retiming |
| `hold_violation` | 数据太快（min corner） | 06 §4 delay |
| `transition_violation` | slew 超限 | 06 §5 buffer tree |
| `cap_violation` | 负载电容超限 | 06 §5 |
| `no_clock` | SDC 未绑 clock | 05 §2、§8 |
| `unconstrained_path` | 例外缺失或对象未解析 | 05 §4、§8 |

---

## 5. QoR 对比（版本间）注意

对比两次 compile 内部结果时，须 **对齐**：

| 须一致 | 否则内部量不可比 |
|--------|------------------|
| SDC 语义（period、例外） | WNS/TNS 假变 |
| MCMM corner 集 | setup/hold 各看不同 corner |
| `.lib` / dont_use | 单元集变 |
| RTL 功能 | 非同一设计 |

---

## 6. 内部量与 LEC 的关系

| 内部量 | 含义 |
|--------|------|
| WNS ≥ 0 | **不保证** RTL↔网表等价 |
| 无意外 LATCH | **不保证** LEC pass（复位/常数/X） |
| 推断 RAM→macro | LEC 需 **memory 映射** 对齐 compare point |

签核：**时序（05–07 内部量）+ [09 LEC](./09-logical-equivalence-checking.md)**。

---

## 7. 小结

本章 = **compile 仪表盘索引**；深入机制读 **05（约束图）**、**06（transform）**、对应 **walkthrough**。

---

## 下一节

- [05 SDC 内部](./05-constraints-sdc.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
- [09 LEC](./09-logical-equivalence-checking.md)
- [12 交付](./12-deliverables-and-handoff.md)
