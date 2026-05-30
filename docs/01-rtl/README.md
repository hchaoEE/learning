# 01 RTL：语法与可综合写法

RTL 是 ASIC 逻辑综合的输入。本章目标：**写得对仿真、写得对综合（Design Compiler / Genus）、写得对 PrimeTime 签核与后端收敛**。

> 本章示例与叙述均针对 **标准单元 ASIC**，不涉及 FPGA。

## 章节导航

| 序号 | 文档 | 内容 |
|------|------|------|
| 1 | [01-verilog-module-and-ports.md](./01-verilog-module-and-ports.md) | 模块、端口、层次化 |
| 2 | [02-data-types-and-operators.md](./02-data-types-and-operators.md) | 数据类型、位宽、运算符 |
| 3 | [03-continuous-and-procedural.md](./03-continuous-and-procedural.md) | `assign`、always、阻塞/非阻塞 |
| 4 | [04-sequential-logic.md](./04-sequential-logic.md) | 触发器、复位、时钟使能 |
| 5 | [05-fsm.md](./05-fsm.md) | 状态机编码与两段式/三段式 |
| 6 | [06-generate-and-parameters.md](./06-generate-and-parameters.md) | parameter、generate |
| 7 | [07-synthesizable-subset.md](./07-synthesizable-subset.md) | 可综合子集与仿真专用语法 |
| 8 | [08-coding-guidelines.md](./08-coding-guidelines.md) | 规范、反模式、Review 要点 |
| 9 | [09-systemverilog-vs-verilog.md](./09-systemverilog-vs-verilog.md) | **SV 与 Verilog 对比**（ASIC 可综合视角） |
| — | [examples/](./examples/) | 示例代码 |

## 阅读顺序

```text
模块与端口 → 类型与运算 → 组合/过程块 → 时序逻辑 → FSM → generate
                                    ↓
                          可综合子集 + 编码规范

可选：熟悉 Verilog 后，尽早阅读 09（SV 对比）；新 ASIC 项目可直接按 SV 写法实践。
```

## 核心原则（贯穿全章）

1. **一个 always 块只驱动一种逻辑**：纯组合用阻塞赋值；时序用非阻塞赋值。
2. **完整赋值**：组合 `if`/`case` 必须覆盖所有分支，否则可能推断出锁存器。
3. **复位策略项目级统一**：异步复位同步释放、或纯同步复位，勿混用风格。
4. **位宽显式**：端口与内部信号尽量写清位宽，避免隐式截断与符号扩展陷阱。
5. **时钟域在 RTL 标明**：跨域路径用同步器，并文档化。

学完本章后，应能独立编写可被主流综合工具接受的 RTL，并识别常见不可综合写法。
