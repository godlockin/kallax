---
paths:
  - .github/PULL_REQUEST_TEMPLATE.md
  - scripts/ci/check-review-tier.sh
  - scripts/agent-save-report.sh
  - CLAUDE.md
---

# Review 分级 (EPIC-270, 主公 2026-08-18 拍板)

> **Path-scoped rule**: 只在 PR template / tier gate / agent-save-report / CLAUDE.md 修改时加载.
> **取代**: EPIC-207 §2 的 "4 sub-roles review" (Architect/Backend/Frontend/Security 各 1 份).

## 1. 起因 — 规则空转的实测证据

流程组复盘实测 (报告: `confluence/decisions/retrospective-v3.34.X-2026-08-12-process.md` V6):

对 PR #369-#421 全部 53 个 PR 逐个跑 `gh pr view <n> --json reviews,comments`:

```
结果: 全部 reviews=0 comments=0, 无一例外
```

CLAUDE.md §4 写 "0 容忍 auto-merge; 4-PR 任一必走 master + 4 sub-roles review".
EPIC-207 立这条规则就是为了防 v3.8.0 的假 PASS. 现在规则本身成了同一类问题:
**声明存在, 证据不存在**.

## 2. 为什么 4 sub-roles review 做不到

### 2.1 物理限制

```
$ gh pr review 423 --approve
failed to create review: GraphQL: Review Can not approve your own pull request (addPullRequestReview)
exit=1

$ gh pr review 423 --comment --body "[Architect] ..."
exit=0   (reviews 数组 0 → 1, state=COMMENTED)
```

单人项目下所有 PR 都是同一个 GitHub 账号开的, **4 条 APPROVE 物理上做不到**.
只能是 4 条 `COMMENTED` —— 而 COMMENTED 不 block merge, 不产生任何拦截力.

### 2.2 更根本的问题: 自评买不到独立性

我扮演 4 个角色写 review 时, **4 份意见共享同一条推理路径**. 我认定
"merge-validator fail-open" 的时候, 4 个角色都会认定.

subagent 是**独立 context**, 看不到我的推理过程, 只能自己跑命令.

**本 sprint 实证**:
- 3 组复盘 subagent 推翻我 3 处结论 (ALL_PASS 8/8 / 全仓清 32 处 / fail-open 严重度)
- 2 轮 T2 核实推翻我 8 处声明 (过程记录在 PR #426 body 的 review_summary)

这是自评永远拿不到的.

## 3. 分级判据 (复用 Rule 37 阈值, 0 新造)

| 档 | 条件 | review 方式 | evidence |
|----|------|------------|----------|
| **T1 自评** | 0 源码改动 + ≤100 行 + 单 commit | 我自己审, PR body 写验证 raw output | 不需要 |
| **T2 单 subagent** | 有源码改动 **或** >100 行 | 1 个独立 subagent 核实我的声明 | **必填**, 内联 summary |
| **T3 多 subagent** | ≥5 文件 **或** >500 行 **或** 改 immutable/Rule/CI | 3 个不同视角 | **必填**, 内联 summary |

T1 判据跟 Rule 37 §2.1 的 4 项阈值同源 (0 改 source / ≤100 行 / 单 commit / 决策 doc).
分级是把 Rule 37 从"要不要等主公"扩展到"谁来 review".

## 4. subagent prompt 的关键设计

**任务是"核实", 不是"评审"**.

如果 prompt 写 "请 review 这个 PR", subagent 会读我的 PR 描述然后说"看起来合理" ——
因为 PR 描述是我写的, 里面已经埋了我的结论.

**正确的 prompt**: "这是我声称的 X, 你独立复现, 不吻合就报 mismatch".

这正是 Rule 34 对 Performer 的要求, 只是把对象从 bugfix ticket 换成我自己的
review 结论. 事故组指出的缺口正是这个: **"Rule 34 要求 Performer 复现, 但
Master 自己写的 diagnosis 没人复现"**.

## 5. review_summary 内联 (主公 2026-08-18 拍板)

### 5.1 为什么不落库

核实报告是**过程描述** (单次核实: 某 branch 某时刻的 git status / test 输出 /
测试沙箱构造细节 / 变异体编号), 不是决策文档.

- 决策结论 (值得反复引用) → 走 `confluence/decisions/` 文档
- 过程凭证 (一次性, 跟具体 commit 绑定) → 不落库

把过程凭证塞进 `confluence/decisions/` 会让决策目录被一次性内容淹没,
且触发 disclaimer gate (报告正文天然提到 isolation/授权/防护 等词, 那是
技术描述不是对外声明).

### 5.2 review_summary 形态

PR body 内联字段 (T2/T3 必填), 写清: 核实了什么 / 发现什么 / 怎么处理.

```yaml
review_tier: T2
review_summary: |
  独立核实者复现 pattern 边界, 发现 AC2 描述错 (matched 修前就是 8).
  已修 ticket AC2 + 补 env var 覆盖 bug.
```

### 5.3 为什么不用 /tmp

同上——subagent 输出是临时缓存, 任务结束或机器重启即丢, 且 CI runner 上
`/tmp/xxx.md` 根本不存在. 内联 summary 直接进 PR body, GitHub 永久保存,
gate 也能校验非空.

## 6. Gate 校验

`scripts/ci/check-review-tier.sh <pr-body-file> <diff-stat-line>`

| 检查 | 拒的条件 |
|------|---------|
| tier 字段存在 | PR body 缺 `review_tier:` |
| T1 规模 | T1 但 >100 行 (提示改 T2) |
| T2/T3 review_summary | 缺 `review_summary:` 字段 或 空 |
| review_summary | (内联字段, 无文件校验) |
| T3 规模 | T3 但 <5 文件 且 ≤500 行 (提示改 T2) |

退出码: 0 = 通过 / 1 = 拒 / 2 = 用法错误.

## 7. 历史债备案

**53 个 PR (#369-#421) 不回溯**. 它们 `reviews=0` 是既有状态, 追溯改写没有意义
(GitHub review 记录无法补录到过去的时间点).

本 sprint 后续 PR (#422+) 起按分级执行. 本 sprint 我在 6 个 PR 里标了
"T1 自评" 但那只是 PR body 一行文字 —— 本卡把它变成 gate 可查的结构化字段.

## 8. 跟现有 Rule 的关系 (0 冲突)

- **Rule 37** (小 effort auto-approve): 4 项阈值复用作 T1 判据. Rule 37 管"要不要等主公", 本 Rule 管"谁来 review"
- **EPIC-207** (4-PR governance): 4-PR 流程不变, 只换 review 方式
- **EPIC-242** (未来分工): `main → miao` 主公亲自 —— 这条不受影响, 分级只管 review 不管 merge 权
- **EPIC-198** (docs-only exempt): docs-only PR 通常落 T1 (0 源码改动)
- **Rule 34** (bugfix 独立复现): subagent prompt 设计沿用它的"独立复现"要求
- **EPIC-069-D** (5-Level Verify): review 是 L3, 本 Rule 定 L3 怎么做

## 9. 已知限制

1. **subagent 的独立性有边界** —— 我写 prompt, prompt 里的框架会限制它看什么.
   本 sprint 3 组能推翻我, 部分是因为我明确写了"独立核实, 不要照抄"和"主动扫残留".
   prompt 写得含糊, subagent 大概会顺着我的结论走.

2. **成本不低** —— 本 sprint 3 组复盘跑了 862s / 2062s / 2777s, 工具调用 31 / 68 / 117 次.
   T3 每张卡都这样, 一个 sprint 5 张 T3 就是 15 个 agent. 所以分级必须严格.

3. **subagent 可能挂** —— EPIC-268 的核实者因 API 连接中断挂了, 只留下一条关键发现.
   这时 Master 接管 (主公 2026-08-18 指示: "subagent 不可靠的时候你接管").
   接管时要做完核实者本该做的验证, 不是跳过.

4. **review_summary 是自述, 不是独立证据** —— 它写在 PR body 里, 是我(或核实者)写的文字, gate 只验非空不验真伪. 比 4 sub-roles review 强的地方是: T2/T3 的 summary 内容来自独立 context 的 subagent, 不是我自己扮演角色. 但文字本身还是人写的, 不构成机器可验的证据. 真正的机器证据是 raw output (test 输出, 已在 7-class 风险 checklist 的自动验证段要求).

5. **gate 不判 T1/T2 边界** —— 80 行的 T2 claim 会放行 (T1 阈值是 ≤100 行).
   这是设计选择: claim 自负责, 不强制降级. 后续可加自动选档.

## 10. Reviewer

- 主公 (2026-08-18 拍板分级方案 + evidence 落仓)
- master (执行 + 本 Rule 起草)
- 流程组复盘 subagent (53 PR reviews=0 的实测证据源)
- EPIC-207 (4-PR governance 源, 本 Rule 是 override)
- EPIC-037 (Rule 37 阈值源)
