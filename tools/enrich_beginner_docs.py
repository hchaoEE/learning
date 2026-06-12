#!/usr/bin/env python3
"""Add beginner intro, section one-liners, and checklists to 02-synthesis chapters."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "docs" / "02-synthesis"

INTROS = {
    "00-synthesis-overview.md": (
        "综合全流程在脑子里有一张地图。\n"
        "> **读完应能**：① 画出 RTL→交付主链 ② 说出签核三角 ③ 按角色选阅读路径\n"
        "> **先修**：无 · **难度**：★☆☆☆☆ · **walkthrough**：[mini_chain](./examples/mini_chain/README.md)"
    ),
    "01-rtl-parsing-and-elaboration.md": (
        "RTL 如何变成 GTECH 与 Design DB。\n"
        "> **读完应能**：① 说清 elaborate 各子阶段 ② 区分 AST/GTECH/SEQGEN ③ 知道仿真与综合语义差\n"
        "> **先修**：Verilog 可综合子集 · **难度**：★★★☆☆ · **walkthrough**：[elab_walkthrough](./examples/elab_walkthrough/)"
    ),
    "02-inference.md": (
        "GTECH 时序元件如何贴上 REG/LATCH/RAM/MULT 等标签。\n"
        "> **读完应能**：① 判断 latch 推断条件 ② 说清 RAM 实现决策 ③ 理解 ICG 在 DB 的表示\n"
        "> **先修**：[01](./01-rtl-parsing-and-elaboration.md) · **难度**：★★★☆☆ · **walkthrough**：[inference_walkthrough](./examples/inference_walkthrough/)"
    ),
    "03-optimization.md": (
        "映射前如何用 AIG 做技术无关布尔优化。\n"
        "> **读完应能**：① 解释 AIG 只有 AND+反相边 ② 列举 strash/rewrite/balance ③ 区分粗优化与 06 细优化\n"
        "> **先修**：[02](./02-inference.md) · **难度**：★★★★☆ · **walkthrough**：[aig_walkthrough](./examples/aig_walkthrough/)"
    ),
    "04-technology-mapping.md": (
        "AIG 如何绑定到标准单元库。\n"
        "> **读完应能**：① 说清 cut/cover ② 解释映射 cost 含什么 ③ 知道映射后才有真实 cell delay\n"
        "> **先修**：[03](./03-optimization.md) · **难度**：★★★★☆ · **walkthrough**：[mapping_walkthrough](./examples/mapping_walkthrough/)"
    ),
    "05-constraints-sdc.md": (
        "SDC 如何变成 timing graph 上的 clock/check/例外。\n"
        "> **读完应能**：① 画 reg2reg setup 检查 ② 区分 false_path 与 clock_groups ③ 理解 MCMM 多 mode\n"
        "> **先修**：setup/hold 概念 · **难度**：★★★★☆ · **walkthrough**：[sdc_walkthrough](./examples/sdc_walkthrough/)"
    ),
    "06-timing-driven-optimization.md": (
        "映射后引擎如何用 slack 驱动 upsize/buffer 等 transform。\n"
        "> **读完应能**：① 说清违例队列调度 ② 区分 setup/hold/DRC 修复 ③ 知道 retiming 改 FF 位置\n"
        "> **先修**：[04](./04-technology-mapping.md)、[05](./05-constraints-sdc.md) · **难度**：★★★★★ · **walkthrough**：[tdo_walkthrough](./examples/tdo_walkthrough/)"
    ),
    "07-internal-sta-and-qor.md": (
        "综合器内部的 timing graph、AT/RT 与 WNS/TNS 怎么算。\n"
        "> **读完应能**：① 手推一小图 AT/RT ② 解释 check 边不传播 delay ③ 区分内嵌 STA 与签核 PT\n"
        "> **先修**：[05](./05-constraints-sdc.md)、[06](./06-timing-driven-optimization.md) · **难度**：★★★★★ · **walkthrough**：[sta_walkthrough](./examples/sta_walkthrough/)"
    ),
    "08-synthesis-reports.md": (
        "报告里的 WNS/面积/功耗对应 DB 里哪些内部量。\n"
        "> **读完应能**：① 从报告判断卡在哪个 pass ② 读懂路径分解 ③ 避免未对齐 SDC 的假变\n"
        "> **先修**：[06](./06-timing-driven-optimization.md)、[07](./07-internal-sta-and-qor.md) · **难度**：★★★☆☆ · **walkthrough**：—"
    ),
    "09-low-power-synthesis.md": (
        "UPF/ICG 如何在 DB 里变成可综合的功耗语义。\n"
        "> **读完应能**：① 分项读动态/漏电 ② 说清 retention/isolation 插入点 ③ 区分 02 ICG 推断与 09 UPF\n"
        "> **先修**：[02 §9](./02-inference.md)、[05](./05-constraints-sdc.md) · **难度**：★★★☆☆ · **walkthrough**：[power_walkthrough](./examples/power_walkthrough/)"
    ),
    "10-logical-equivalence-checking.md": (
        "RTL 与网表如何在 miter 上做等价证明。\n"
        "> **读完应能**：① 画 miter 结构 ② 列举匹配失败原因 ③ 知道 retiming 要 pipeline 等价\n"
        "> **先修**：[01](./01-rtl-parsing-and-elaboration.md)、[04](./04-technology-mapping.md) · **难度**：★★★★☆ · **walkthrough**：[lec_walkthrough](./examples/lec_walkthrough/)"
    ),
    "11-hierarchical-block-synthesis.md": (
        "大设计如何分块综合、预算与 abstract。\n"
        "> **读完应能**：① 说清 bottom-up 交付物 ② 解释 budget 迭代 ③ 知道 abstract 须与块 revision 锁步\n"
        "> **先修**：[06](./06-timing-driven-optimization.md)、[07](./07-internal-sta-and-qor.md) · **难度**：★★★★☆ · **walkthrough**：[hier_walkthrough](./examples/hier_walkthrough/)"
    ),
    "12-dft-and-scan.md": (
        "Scan 如何改 FF 结构与 test mode 时序。\n"
        "> **读完应能**：① 说清 DFF→SDFF 变换 ② 区分 shift/capture ③ 知道须在 mapped 后插入\n"
        "> **先修**：[06](./06-timing-driven-optimization.md) · **难度**：★★★☆☆ · **walkthrough**：[dft_walkthrough](./examples/dft_walkthrough/)"
    ),
    "13-deliverables-and-handoff.md": (
        "综合结束要交什么、如何保证 PnR 能接上。\n"
        "> **读完应能**：① 列出最小交付包 ② 说清 corner/MCMM 锁步 ③ 知道 ECO 与 manifest 关系\n"
        "> **先修**：[05](./05-constraints-sdc.md)、[10](./10-logical-equivalence-checking.md) · **难度**：★★☆☆☆ · **walkthrough**：—"
    ),
    "14-academic-research-survey.md": (
        "学术界在 logic synthesis 上做什么、如何对照本系列主链读论文。\n"
        "> **读完应能**：① 区分 ML-Assist 与 ML-Agent ② 用主链章定位一篇论文 ③ 警惕 EPFL 与量产指标不可横比\n"
        "> **先修**：[03](./03-optimization.md)–[06](./06-timing-driven-optimization.md) · **难度**：★★★☆☆（选读） · **walkthrough**：—"
    ),
}

CHECKLISTS = {
    "00-synthesis-overview.md": [
        "能画出 RTL→01→…→13 主链",
        "能说出时序/LEC/DFT 签核三角",
        "知道 03 在 04 之前的原因",
        "能按角色选 README 阅读路径",
        "读过 [mini_chain](./examples/mini_chain/README.md)",
    ],
    "01-rtl-parsing-and-elaboration.md": [
        "Design DB 与 GTECH 的关系",
        "elaborate 与 parse 的区别",
        "`always_ff` → SEQGEN 路径",
        "generate/param 在何时求值",
        "仿真 X 与综合 2-state 差异",
        "check_design 常见 ERROR 含义",
        "[elab_walkthrough](./examples/elab_walkthrough/) 至少一例",
    ],
    "02-inference.md": [
        "REGISTER vs LATCH 判定",
        "RAM 推断与 macro 决策",
        "MULT 宽度与实现策略",
        "FSM 编码对 03/10 的影响",
        "ICG 推断与 09 分工",
        "寄存器级优化（常量/merge）",
    ],
    "03-optimization.md": [
        "AIG 仅 AND+反相边",
        "strash / rewrite / balance 各改什么",
        "粗优化不改 FF 拓扑",
        "与 04 mapping 的接口",
        "AIG 案例或 aig_walkthrough 一例",
    ],
    "04-technology-mapping.md": [
        "cut enumeration 概念",
        "cover 选择看 delay+area",
        "映射后出现 `.lib` 单元名",
        "映射不等于 06 修时序",
        "mapping_walkthrough 一例",
    ],
    "05-constraints-sdc.md": [
        "create_clock 挂到哪些 pin",
        "setup check 在 FF/D",
        "false_path vs clock_groups",
        "multicycle 改 required 而非 RTL",
        "MCMM functional vs test",
        "sdc_walkthrough 案例 A–F",
    ],
    "06-timing-driven-optimization.md": [
        "WNS 桶 vs TNS 桶",
        "DRC 先于 timing 的原因",
        "setup 与 hold 修复手段",
        "增量 STA 脏区概念",
        "retiming 与 RTL 流水区别",
        "tdo_walkthrough 一例",
    ],
    "07-internal-sta-and-qor.md": [
        "timing graph 四类边",
        "AT forward / RT backward",
        "slack = RT − AT",
        "path group 权重",
        "derate 收紧 margin",
        "sta_walkthrough 案例 A 手推",
    ],
    "08-synthesis-reports.md": [
        "WNS/TNS 从哪聚合",
        "面积分项指纹",
        "功耗分项可信度",
        "QoR 对比须对齐 SDC",
        "违例标签→06 分支",
    ],
    "09-low-power-synthesis.md": [
        "动态 vs 漏电分项",
        "ICG 降 clock toggle",
        "retention/isolation 语义",
        "UPF 编译到 DB 标注",
        "综合期功耗仅相对比较",
    ],
    "10-logical-equivalence-checking.md": [
        "miter = R/I 并联 XOR",
        "compare point 配对来源",
        "ungroup/retime 破坏匹配",
        "abort 四态含义",
        "LEC pass 与 WNS 无关",
    ],
    "11-hierarchical-block-synthesis.md": [
        "bottom-up vs top-down",
        "abstract/ILM 用途",
        "budget 迭代闭环",
        "块 LEC 与顶层黑盒",
        "boundary optimization 与 LEC",
    ],
    "12-dft-and-scan.md": [
        "scan 在 mapped 后插入",
        "shift vs capture 模式",
        "ICG TE 旁路",
        "lockup 与 hold",
        "test mode SDC 须交付",
    ],
    "13-deliverables-and-handoff.md": [
        "网表+SDC 最小集",
        "corner/MCMM 锁步",
        "manifest 重现 compile",
        "签核门控清单",
        "ECO 增量与名字保持",
    ],
    "14-academic-research-survey.md": [
        "ML-Assist vs ML-Agent",
        "recipe 时间线 2019–2025",
        "OpenABC-D 用途",
        "读论文八步清单",
        "知悉 EPFL≠量产 signoff",
    ],
}

# Section one-liner: default from title after "## N. "
ANALOGY_HINTS = {
    "05": "像给地图标红绿灯与禁行线——不改路，只改能不能算路程。",
    "06": "像交通调度：先清障（DRC），再疏通最堵路口（WNS）。",
    "07": "像双向标注每个路口的「最早到达」和「最晚必须到达」。",
    "10": "像两版图纸叠在一起，用 XOR 灯看哪里不一致。",
}


def has_intro_block(text: str) -> bool:
    return "**本章回答**" in text[:2500]


def insert_intro(text: str, fname: str) -> str:
    if has_intro_block(text) or fname not in INTROS:
        return text
    intro_body = INTROS[fname]
    # After first --- following title block
    m = re.search(r"(^# .+?\n\n)(.+?)(\n---\n)", text, re.DOTALL)
    if not m:
        return text
    block = (
        f"{m.group(1)}> **本章回答**：{intro_body}\n\n"
        f"{m.group(2)}{m.group(3)}"
    )
    return text[: m.start()] + block + text[m.end() :]


def insert_section_oneliners(text: str, fname: str) -> str:
    ch = re.match(r"(\d+)", fname)
    ch_num = ch.group(1) if ch else ""
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        out.append(lines[i])
        m = re.match(r"^## (\d+)\.\s+(.+)$", lines[i])
        if m and i + 1 < len(lines):
            nxt = lines[i + 1].strip()
            if not nxt.startswith("> **一句话**"):
                title = m.group(2).strip()
                one = f"> **一句话**：{title}——本章核心机制点。"
                out.append(one)
                if ch_num in ("05", "06", "07", "10") and m.group(1) in ("2", "3", "4", "5"):
                    out.append(f"> **类比**：{ANALOGY_HINTS.get(ch_num, '像编译器不同 pass 改不同 IR。')}")
        i += 1
    return "\n".join(out)


def insert_checklist(text: str, fname: str) -> str:
    if "## 知识点清单（自检）" in text or fname not in CHECKLISTS:
        return text
    items = CHECKLISTS[fname]
    block = "## 知识点清单（自检）\n\n" + "\n".join(f"- [ ] {it}" for it in items) + "\n\n---\n\n"
    # Before ## N. 小结 or ## 下一节
    for pat in [r"\n## \d+\. 小结\n", r"\n## 下一节\n"]:
        m = re.search(pat, text)
        if m:
            return text[: m.start()] + "\n\n" + block + text[m.start() + 1 :]
    return text + "\n\n" + block


def process_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    orig = text
    text = insert_intro(text, path.name)
    text = insert_section_oneliners(text, path.name)
    text = insert_checklist(text, path.name)
    if text != orig:
        path.write_text(text, encoding="utf-8")
        print(f"updated {path.name}")


def main():
    for p in sorted(ROOT.glob("[0-9]*.md")):
        process_file(p)


if __name__ == "__main__":
    main()
