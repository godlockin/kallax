# EPIC-285 — 经验教训 13 判据

> 日期: 2026-08-22 | 来源: 准入 4 条 (主公拍板) + 质量 9 条 (master 从本 Sprint PR #474 / #479 / #481 / #484 真实失败提炼)
> 用途: 判定一条经验教训是否配得上进错题集 (`confluence/manifesto/04-lessons.md`) / 正例集 (`05-best-practices.md`)
> 本文档自身受判据 8 约束: ≤ 250 行

## 用法

一条候选教训依次过 A 层 4 条 (准入) → B 层 9 条 (质量)。

- A 层任一条不过 → 不进错题集, 归 `confluence/_archived/retrospectives/`
- B 层不过 → 改写或降级到 reference 层, 不硬删
- 判定结果写在教训条目末尾: `判据: A1-4 ✓ / B5-13 ✓ (except B10 → 见 AC5 gate backlog)`

---

## A 层 — 准入 4 条 (主公 2026-08-22 拍板)

### 判据 1 — 可迁移到非 KALLAX 项目

- **定义**: 教训的因果结构在没有 KALLAX 分支流程 / Rule 编号 / hook 体系的项目里仍然成立。
- **检验方式**: 删掉条目里所有 `EPIC-xxx` / `Rule N` / 分支名 / 脚本文件名后重读。若句子还能读懂且仍有指导性 → 过; 若变成空句 → 不过。
- **本 Sprint 反面教材**: PR #479 的教训若写成 "`scripts/hooks/check-claim-evidence.sh` 的 STAGED glob 不含 `.json`", 剥离专有名词后剩下 "某脚本某参数漏了某类型" = 空句。可迁移写法是 "为一条从未触发的假想风险写豁免代码 = YAGNI 的知识版"。
- **失效边界**: 纯基础设施约定 (如 `.claude/worktrees/` 路径) 本身不可迁移但必须留存 — 这类进 reference 层, 不套本判据。推翻本判据的证据: 出现一条剥离专有名词后失效、却确实降低了其他项目缺陷率的教训。

### 判据 2 — 降低同类问题复发概率

- **定义**: 教训针对的是一类问题, 不是一个实例。
- **检验方式**: 问 "下一次这类问题长什么样"。答得出 ≥ 2 个不同形态 → 过; 只能复述原始事件 → 不过。
- **本 Sprint 反面教材**: `.github/workflows/pr-size-check.yml:72` 的 jq 拼接 `(.path // "") + " " + (.filename // "")` 产生尾随空格, `$` 锚点永不匹配。写成 "注意 jq 拼接别留空格" 只覆盖一个实例; 写成 "gate 的判定逻辑本身没有测试时, 它的 PASS 不构成证据" 覆盖锚点失配 / glob 漏类型 / 阈值写死 3 类形态。
- **失效边界**: 一次性历史迁移 (如 EPIC-178 re-promote) 确实不会复发, 这类记 decision 记录而非错题集。推翻本判据的证据: 某条只发生过一次且不会再发生的教训, 后续被证明持续影响决策。

### 判据 3 — 质量提升有可测指标

- **定义**: 采纳该教训后, 有一个数字会变化。
- **检验方式**: 写出指标名 + 当前值 + 目标方向。写不出数字 → 不过。
- **本 Sprint 反面教材**: pr-size-check 教训的指标是 "gate 误判率": CI log 实测 PR #474 raw 613 行 → `net=100`, PR #484 raw 701 行 → `net=100`, 即 2/2 被测 PR 误判 docs-only, Rule of 500 gate 静默失效。EPIC-282 的 `node/src/core/event-log/event-store.ts:58,65` template literal 违规同样可测: eslint errors 3 → 0。
- **失效边界**: 判断类教训 (如冲突优先级) 的指标只能是间接的 (误判次数)。允许用间接指标, 但必须写明是间接的。推翻本判据的证据: 某条无任何指标的教训, 被证明比有指标的教训更有效。

### 判据 4 — 长远影响非一次性

- **定义**: 教训在下一个 Sprint 仍会被用到。
- **检验方式**: 指出下一个 Sprint 里哪个具体动作会因它改变 (对应 AC8)。指不出 → 不过。
- **本 Sprint 反面教材**: PR #481 的根因是 PR base SHA 过时, CI `git diff --shortstat $BASE_SHA $HEAD_SHA` 反向包含 testing 已合的 #484/#486/#487/#492, 算出 `37 files changed, 95 insertions(+), 1781 deletions(-)`, NET_LINES=1876 > 100 触发 T1 REJECT。这条长远: 每个后续 PR 开卡前都要先 rebase。对照 PR #479 的 exemption 防的是假想的未来 regex 演进, 0 真实触发记录, 下个 Sprint 无任何动作会因它改变。
- **失效边界**: 版本相关的临时约束 (如某依赖某版本的 bug) 有效期到升级为止 — 这类允许带 `expires:` 字段进错题集。推翻本判据的证据: 某条被判一次性的教训在后续 3 个 Sprint 反复被引用。

---

## B 层 — 质量 9 条 (master 提炼)

### 判据 5 — 根因层

- **定义**: 停在可行动的根因, 不停在症状, 也不上升到哲学。
- **检验方式**: 对候选结论连问 "为什么" 直到答案变成一个可改的文件 / 配置 / 流程步骤。答案还是现象 → 症状层; 答案是价值观 → 哲学层。
- **本 Sprint 反面教材**: PR #481 我先试图改 PR body 补字段 — 那是症状层, 因为 check-review-tier FAIL 的直接原因是 NET_LINES 计算包含了不属于本 PR 的 4 个已合 PR, 可行动根因是 rebase 而非改 body。PR #479 同样停在症状 "CI 可能误判 X/Y", 未追到 "`.json` 不在 STAGED glob", 结果写出 25 LOC + 62 行配套文件的 dead code。
- **失效边界**: 根因跨组织边界 (如上游依赖 bug) 时只能停在 workaround 层, 此时必须标注 `根因在外部: <链接>`。推翻本判据的证据: 一条停在症状层的教训比其根因版本更常被正确应用。

### 判据 6 — 证据链

- **定义**: 每条绑真实 commit hash / PR 号 / CI log / `file:line`。禁预防性教训。
- **检验方式**: 逐条查引用是否可点开验证。若引用指向 "假想的未来场景" → 不过。
- **本 Sprint 反面教材**: PR #479 的 commit message 自己承认 "snapshot expected.json NOT in staged-md/sh scope (json files filtered), exemption is defensive only" — 作者知道 0 触发仍然提交。技术事实: `PATTERN_NUMERIC='[0-9]+/[0-9]+ (PASS|FAIL|passed|failed)'` 对 snapshot 内容 `"Core Experts (5)"` 0 命中, 双重 dead code。对照 pr-size-check bug 有 CI log 实证 (#474 raw 613 → net=100), 证据链成立。
- **失效边界**: 安全类风险允许在 0 触发时预防 (攻击者不会先报案)。此类需标注 `威胁模型: <描述>`。推翻本判据的证据: 某条 0 证据的预防性教训阻止了一次真实事故。

### 判据 7 — 可反驳性

- **定义**: 说得出 "什么证据能推翻它"。说不出 = 不可反驳的正确废话。
- **检验方式**: 为条目写一行 `反驳条件:`。写不出 → 删条目。
- **本 Sprint 反面教材**: A/B 双组 review 中我在 PR body 写 "EPIC-275 §1 testing→main master 自合" 为 PR #488 辩护, 被 B 组用 `scripts/verify/check-branch-flow.sh:6-16` allowlist 直接证伪 — 那条要求 head=`testing`, 而 #488 的 head 是 `feature/*`, 属张冠李戴。可反驳的断言 (有 allowlist 可查) 才能被纠正; 若我当时写的是 "这个 PR 符合流程精神", 无从证伪。
- **失效边界**: 主公拍板的价值取向 (如 "产出物是减法") 是前提不是断言, 不套本判据。推翻本判据的证据: 某条不可反驳的原则性表述持续产出正确决策。

### 判据 8 — 数量上限硬约束

- **定义**: `04-lessons.md` ≤ 15 条错题, `05-best-practices.md` ≤ 15 条正例, 各文件 ≤ 300 行。本文档 ≤ 250 行。
- **检验方式**: `wc -l` + 条目计数。超出必须合并或砍, 不允许新开文件分流。
- **本 Sprint 反面教材**: 现状 55 份经验文档分散 4 处 (ticket EPIC-285 `verification.reproduction_raw_output`: decisions/ 24 份 retrospective + memory/lessons/ 28 份 + 3 主文件 679 行)。分散本身就是上限缺失的后果 — 没有上限时每次复盘都新增一份, 无人做减法。
- **失效边界**: 上限是逼迫做减法的机制, 若某次审计后剩余条目确实 < 15, 不需要凑满。推翻本判据的证据: 达到上限后被砍掉的条目里出现了后续造成事故的关键教训。

### 判据 9 — 失效边界

- **定义**: 每条写 "什么情况下不适用", 防教条化。
- **检验方式**: 条目必须有 `失效边界:` 段且不为 "无"。写 "无例外" 视为未写。
- **本 Sprint 反面教材**: `CLAUDE.md:76` Rule 8 "每个 commit ≤ 500 行" 未写边界, 我在 PR #474 据此判违规, 而 4 个 commit 各自合规 — 边界 (管 commit 不管 PR 总量) 缺失直接导致误判。经典例: "fail-fast 优先" 在批处理场景要让位于 "收集全部错误再报"。
- **失效边界** (本判据自指): 物理约束类教训 (如 "不能对已 push 的公共分支 force-push") 边界为空集, 此时写 `失效边界: 无 (物理约束)` 并附理由。推翻本判据的证据: 写了边界的教训被更频繁地误用为借口跳过。

### 判据 10 — 自动化优先

- **定义**: 能做成 hook / CI job / 脚本的不进错题集, 去做成 gate。错题集只留无法自动检查的判断类教训。
- **检验方式**: 问 "能否用 grep / AST / exit code 判定"。能 → 进 AC5 gate backlog, 不进错题集。
- **本 Sprint 反面教材**: 两个方向都有实证。正向: EPIC-282 的 `event-store.ts:58,65` `${number}` 违反 `@typescript-eslint/restrict-template-expressions` 已由 eslint 自动拦, 无需人记, 但 3 errors 合进 testing 后传染所有新 PR — 说明 gate 存在不等于债不扩散, 需要合并前阻断。反向: `pr-size-check.yml:72` 证明 gate 自身可能坏且坏得静默, 所以做成 gate 之后仍需一条判断类教训 "gate 需要 meta 验证"。
- **失效边界**: 判定需要人类语境 (如 "这个抽象是否过早") 时无法自动化, 留在错题集。推翻本判据的证据: 某条做成 gate 后误报率高到被普遍 bypass, 不如留作人读。

### 判据 11 — 冲突优先级

- **定义**: 教训间矛盾必须显式标注谁 override + 拍板来源。
- **检验方式**: 新增条目时检索是否与既有条目冲突。有冲突且未标 override → 不过。
- **本 Sprint 反面教材**: PR #474 我判 "违 Rule 8 + Rule 35 §3", A 组纠正: Rule 8 (`CLAUDE.md:76`) 管单个 commit 行数, 4 个 commit 各自合规; Rule 35 §3 "必走 4-PR 全程" 指 4 个分支晋升 PR (feature→testing→main→miao), 不是按内容拆 4 个 PR。两条规则的管辖对象不同却被我混为一谈。已知真冲突例: EPIC-207 "0 容忍 auto-merge" vs Rule 37 "小 effort auto-approve" — 主公 2026-08-08 拍板 Rule 37 override。
- **失效边界**: 同层同源规则的表述差异不算冲突, 属 DRY 问题走判据 8 合并。推翻本判据的证据: 标了 override 的冲突仍反复被误判, 说明问题在规则本身该改而非标注。

### 判据 12 — 读者分层

- **定义**: 明确目标读者 (新接手 agent / 人类 / 其他项目开发者), 决定语言粒度。给其他项目的教训剥离 KALLAX 专有名词。
- **检验方式**: 条目带 `读者:` 字段。给 "其他项目开发者" 的条目再过一次判据 1 的删名词测试。
- **本 Sprint 反面教材**: A/B 双组 review 分歧即读者分层的实证 — A 组只审代码层判 "PASS", B 组审仓库管理层发现 PR #488 的 head=`feature/*` → main 不在 `scripts/verify/check-branch-flow.sh:6-16` allowlist。同一个 PR, 两个视角看到不同问题。教训若只写给代码层读者, 仓库管理层的失败模式不会被记录。
- **失效边界**: 面向单一读者的操作手册不需要分层标注。推翻本判据的证据: 分层后条目被拆成多份重复表述, 违反判据 8。

### 判据 13 — 认知成本

- **定义**: 标注理解一条教训需要多少上下文。需读 3 份 EPIC 才懂的进 reference 层, 不进错题集。
- **检验方式**: 数条目里的外部引用数。> 2 份外部文档 → 降级 reference 层, 错题集只留一句摘要 + 链接。
- **本 Sprint 反面教材**: PR #474 的完整教训需要同时读 `CLAUDE.md:76` (Rule 8) + Rule 35 §3 + EPIC-207 auto-merge 条款三处才能理解为何我的判定是错的 — 3 份外部引用, 超阈值。错题集里应只留 "规则管辖对象 (commit / PR / 分支) 必须在规则文本里写明, 否则误判", 细节进 reference。
- **失效边界**: 高价值低频教训 (如事故复盘) 允许高认知成本, 但必须放 reference 层并从错题集单向链接。推翻本判据的证据: 被降级到 reference 层的教训因此再无人读, 导致同类问题复发。

---

## 判据文档自检

| 判据 | 本文档自身 |
|------|-----------|
| 8 数量上限 | 本文件行数受 250 行约束 (`wc -l` 验) |
| 13 认知成本 | 每条判据独立可读, 引用只指向 `file:line` 不指向其他 EPIC 全文 |
| 7 可反驳性 | 13 条均写了 "推翻本判据的证据" |
| 6 证据链 | 反面教材全部引真实 PR 号 / `file:line` / CI log 实测值, 0 编造 |

## 关联

- ticket: `jira/tickets/EPIC-285/ticket.json` (AC1 + AC1a-AC1i)
- 下游: AC2 分类矩阵 / AC3 `04-lessons.md` + `05-best-practices.md` / AC5 gate backlog
