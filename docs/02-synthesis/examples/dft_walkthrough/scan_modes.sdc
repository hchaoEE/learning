# 12 §6 — test mode 子模式（概念片段，非完整签核 SDC）
create_clock -period 10.0 [get_ports test_clk]
create_clock -period 1.0  [get_ports clk]

# functional mode（默认）
set_case_analysis 0 [get_ports scan_en]

# test shift mode（另建 mode 视图时）
# set_case_analysis 1 [get_ports scan_en]
# 激活 Q→SI 链 hold check @ test_clk
