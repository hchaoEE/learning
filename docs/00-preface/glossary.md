# 术语表

> 本文档术语均围绕 **ASIC 标准单元设计**，不涉及 FPGA 资源类型。

| 术语 | 英文 | 简要说明 |
|------|------|----------|
| RTL | Register Transfer Level | 用 HDL 描述寄存器之间的数据传送与运算 |
| 可综合 | Synthesizable | 能被综合工具映射到 **标准单元库** 的 RTL 构造 |
| 综合 | Logic Synthesis | 将 RTL 映射为 **门级网表**（.v/.ddc）并优化 |
| 工艺库 | Technology Library (.lib) | 标准单元延时、面积、功耗；含 wire load / CCS 等模型 |
| 标准单元 | Standard Cell | 来自 Foundry 的预制逻辑单元（AND、DFF、MUX 等） |
| 硬宏 / 软宏 | Hard / Soft Macro | SRAM、PLL、IO 等；硬宏带 GDS，软宏为布局布线块 |
| 网表 | Netlist | 综合或 PnR 后的门级/晶体管级连接描述 |
| GDSII | GDSII Stream | 交付 Foundry 的版图数据格式 |
| 约束 | Constraints (SDC) | 时钟、IO 延时、例外路径等时序要求 |
| STA | Static Timing Analysis | 静态时序分析，不跑向量 |
| PnR | Place and Route | 布局布线 |
| LEF/DEF | Library/D Design Exchange Format | 物理抽象与布局布线交换格式 |
| CTS | Clock Tree Synthesis | 时钟树综合 |
| SDC | Synopsys Design Constraints | 事实上的时序约束文件格式 |
| 扇出 | Fanout | 一个驱动源驱动的负载数量 |
| 时钟域 | Clock Domain | 由同一时钟（或同源派生时钟）驱动的逻辑 |
| CDC | Clock Domain Crossing | 跨时钟域路径，需专门同步结构 |
| 异步复位 | Asynchronous Reset | 复位与时钟无关（敏感列表含 posedge reset） |
| 同步复位 | Synchronous Reset | 复位仅在时钟沿生效 |
| 锁存器 | Latch | 电平敏感存储元件；综合常由不完整 `if`/`case` 推断 |
| 多驱动 | Multiple Drivers | 同一 net 被多处赋值，通常非法或可综合子集外 |

后续章节遇到新术语会补充本表。
