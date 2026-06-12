# 跨 die 约束示意 — 与 15 章 §4 对照（非可运行 flow 脚本）

create_clock -name clk -period 1.0 [get_ports clk]

# die0 内 IO（示意）
set_input_delay  0.10 -clock clk [get_ports a]
set_input_delay  0.10 -clock clk [get_ports b]

# 跨 die：bump 当作特殊 input（相对 die1 捕获域）
# 工具内部绑定到 u_mem/bump_in[*] 而非 package pin
set_input_delay 0.25 -clock clk [get_pins u_mem/die_bus_in*]

# 若 die 间为异步域，应使用 clock_groups（见 05 §4.3）
# set_clock_groups -asynchronous -group {clk_d0} -group {clk_d1}
