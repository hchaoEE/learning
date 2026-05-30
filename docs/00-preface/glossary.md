# 术语表

| 术语 | 英文 | 简要说明 |
|------|------|----------|
| RTL | Register Transfer Level | 用 HDL 描述寄存器之间的数据传送与运算 |
| 可综合 | Synthesizable | 能被综合工具映射到库单元的 RTL 构造 |
| 综合 | Logic Synthesis | 将 RTL 映射为门级网表并优化 |
| 工艺库 | Technology Library (.lib) | 单元延时、面积、功耗等特性 |
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
