# Retro Sprint Plan — KALLAX v3.35.0

**日期**: 2026-08-11
**依据**: `/tmp/kallax-vs-deepseek-harness-report.md` + `/tmp/kallax-dashboard-research.md` + 实测仓库状态
**规划人**: 规划专家 (subagent)
**基线**: `origin/miao = 53d3e2aa` (本地 `miao` 落后 21 commits, 见下文 P0 发现)

---

## 0. 侦查先行 — 3 个必须先说的实测事实

规划前跑了 7 轮实测脚本。有 3 项跟任务描述给的前提不符，先纠正，否则整份计划建在错的地基上。

### 事实 1 — 本地 `miao` 落后 origin 21 commits，编号已被吃掉

| 项 | 值 | 命令 |
|----|----|----|
| 本地 `miao` | `97c4d45f` | `git rev-parse --short miao` |
| `origin/miao` | `53d3e2aa` | `git rev-parse --short origin/miao` |
| 落后 | 21 commits | `git log --oneline miao..origin/miao \| wc -l` |

`origin/miao` 上 **EPIC-248 / 249 / 250 / 251 / 252 / 253 已 done**，但语义跟 EPIC-245 worktree 里那份计划文档写的整体是两码事：

| 编号 | origin/miao 上的实际内容 | EPIC-245 计划文档里写的 |
|------|------------------------|----------------------|
| EPIC-248 | EPIC-170 判定推翻 — 测试计数 bug (TOTAL_COUNT 双计) | "migrate-decisions.sh 迁移 98 个 decisions" |
| EPIC-249 | scan-dead-code.sh 加 Stage 4 | — |
| EPIC-250 | CLAUDE.md 黑话 26→0 + check-jargon X/Y 例外 | — |

**含义**: EPIC-245 worktree 里那份 `EPIC-245~248` 计划文档的 §0 "EPIC 编号纠正" 本身已经过期。它自称"实测最大 = 244"，但那是在旧 base 上测的。245/246/247 号仍空，248 已被占。**这份计划里的 EPIC-248 (decisions 迁移) 必须重新编号。**

### 事实 2 — EPIC-258 号已被占用，新编号应从 259 起

任务描述说"从 258 起"。实测已有第三个 worktree 在跑：

```
kallax-wt-EPIC-258  d95d3b66  [feature/v3.35.0-EPIC-258-ticket-status]
  d95d3b66 fix(ticket): EPIC-254/255 status 补落 done + pr_chain
```

即"ticket 卫生: EPIC-254/255 status 仍 in_progress"这条债 **已经有人在 EPIC-258 里修好了 1 个 commit**，只差走 4-PR。本计划新编号从 **259** 起。

### 事实 3 — EPIC-256 / EPIC-257 有编号无 ticket.json

`origin/miao` 上 `jira/tickets/` 最大真实目录是 EPIC-255。EPIC-256 / 257 只存在于口头待办，**没有 ticket.json，没有 branch**。要做必须先建卡（受 `check-ticket-schema.sh` required_fields 强 gate，因为 256 > archive baseline 222）。

### 附带实测：3 个 worktree 在 3 个不同 base 上

| worktree | HEAD | 相对 origin/miao |
|----------|------|-----------------|
| kallax (主) | `97c4d45f` | 落后 21 |
| kallax-wt-EPIC-245 | `97c4d45f` | 落后 21，0 commits，仅 4 个 untracked ticket 目录 + 1 决策文档 |
| kallax-wt-EPIC-258 | `d95d3b66` | 领先 1 |

---

## 调研报告可落地项 (含"不建议做"的判断)

### A. DSH 报告 — TOP 10 gaps 逐条判断

| # | Gap | 判断 | 理由 |
|---|-----|------|------|
| 7 | 文档分层 + word budget | **建议做** | KALLAX `CLAUDE.md` 实测 **200/200 行，正好卡在硬上限**。下一次加 Rule 就溢出，目前靠人记。这是当下就在流血的伤口，不是预防性投资。9 个 `.claude/rules/*.md` 共 655 行，`recent-epics.md` 已 127 行且只会长。S effort，独立无依赖。 |
| 4 | keyless snapshot 接受测试 | **建议做** | 直指 v3.8.0 "25/25 假 PASS" 事故根因。KALLAX 现有 65 个 verify 脚本全是"检查形式"，没有一个"冻结输出"。且 snapshot 命令天然就是 Rule 34 要的 `reproduction_command` + `reproduction_exit_code`，一份投入服务两条规则。实测 `node/tests/snapshots/` 不存在。 |
| 3 | Agent Note ADR 三态 lifecycle | **建议做，但拆两卡** | 实测 `confluence/decisions/` **101 个平面文件 + 1 个 ARCHIVED 目录**（已经有人手动开始分层了，说明痛点真实）。但"立规范 + 写脚本"跟"迁移 101 文件"风险等级差一个量级：迁移要动 101 个路径，`git mv` + 全仓引用扫描，属破坏性改动，必须单独一卡且默认 dry-run。 |
| 1 | capability-seam 三角色契约 | **不建议本 Sprint 做，改成 research-only** | 需重构 `scripts/` (65 verify) + `node/` 双栈边界。触及模块数 >> Rule 35 的"4 模块 / 5 文件"上限。而且 gaps #2 / #8 全都依赖它 —— 先出设计稿再谈实现，跟 EPIC-222 persistent-supervisor 的 research-only 做法同型。 |
| 2 | microkernel 双事件轨 | **不建议做** | KALLAX 已有 `run-history.jsonl` + span。升级到 `sourceEventSeqs` 精度前提是先有 seam (依赖 #1)。当前没有任何消费者要求这个精度 —— 造了没人用。 |
| 5 | 三向投影 render-intent | **不建议做** | KALLAX 没有原生 GUI，`ticket-board` 是静态 HTML。投影层没有消费者。若 dashboard 卡真落地了，再回来看这条。 |
| 6 | sandbox seam + secret scrub | **不建议本 Sprint 做，但 secret scrub 单独提取** | 完整 sandbox seam 触及 AUTO-PERMS 白名单 + 65 脚本入口，超单卡上限。**但报告里 "默认 drop `*KEY*/*SECRET*/*TOKEN*`" 这一小块可以独立做**，不需要 seam —— 这是 backlog 里性价比被报告本身低估的一项。 |
| 8 | 4-waterfall tool pipeline | **不建议做** | KALLAX pre-commit hook 链已经是简化版 waterfall。全量 monotonic guards 依赖 #1。 |
| 9 | hook-bridge 协议层 | **不建议做（定位不符）** | KALLAX 是 Claude Code 的治理层，不是多 harness 运行时。做 codex/其他 adapter 是替不存在的用户解不存在的问题。 |
| 10 | runtime invariants 启动 fail-fast | **部分已有，不建议单独立卡** | KALLAX 的 `install.sh --verify` + 9 immutable fail-closed 已覆盖大半。DSH 的 "assert owned relationships" 前提是有事件流对象可 assert (依赖 #2)。 |

### B. Dashboard 报告 — 逐条判断

| 项 | 判断 | 理由 |
|----|------|------|
| 借 Planka / Wekan / Kanboard / Focalboard / Taskwarrior | **同意不借** | 报告的淘汰理由站得住：Fair-code license + 引第二份 DB 必然双写漂移，跟 ticket.json 单真相源冲突。这部分结论直接采纳，不重新调研。 |
| Phase 1 静态站 MVP | **建议做，但降优先级到 backlog 头部** | 报告把它排成主路径 (1 周 MVP / Rule 37 auto-approve)。我不同意它优先于 doc budget 和 snapshot。理由：Master 已有 `scripts/metrics/sprint-metrics.sh` 出 Rule 36 四指标，dashboard 是把已有数据换个渲染，属体验改善；而 CLAUDE.md 卡 200/200 和"没有输出冻结"是会直接导致下次事故的。dashboard 值得做，排第 6。 |
| Phase 2 TUI | **不建议本 Sprint 做** | 报告估 ~300 LOC / 1 周，且要选 Textual/ratatui/bubbletea 新栈。在 Phase 1 静态站还没有真实使用者反馈前就投 TUI，是在没数据的情况下押注 view 层形态。等 Phase 1 用一个 Sprint 再定。 |
| Phase 3 写路径 + multi-user | **不建议做** | 报告自己标了 ASK 主公 + R8 HIGH risk。KALLAX 的角色模型是单 Master 仲裁，multi-user 冲突策略是在解一个 KALLAX 架构上不存在的问题。建议直接否掉而不是挂着。 |
| dashboard render 前跑 immutable 子集 fail-closed | **同意，且这条是 Phase 1 的真价值点** | 报告 §3.6 auditor 提的 `🔒/⚠️` 双态标识 —— 让 evidence gap 可见，比多一个 kanban 视图有用。 |
| 报告 §6.2 Q7 "借鉴 loopx / book_intelligent_analyzer" | **不建议追** | 报告自己写"调研待补"。为一个体验改善卡再开一轮跨仓调研，成本高于收益。 |

### C. 两份报告共有的一个问题（提请注意）

两份报告都大量使用 `一对一` / `全程` / `沿用` / `已上线` 等表述，而 `check-jargon.sh` 是 9 immutable 之一（EPIC-225，主公 2026-08-08 拍板"以后都要禁止使用黑话"）。**这两份报告若原样进 `confluence/`，会被 pre-commit hook 拦。** 建议归档前先过 `check-jargon.sh`。这也反证了 doc budget / doc hygiene 自动 gate 的必要性。

---

## EPIC-245 现状

**结论：0 代码产出，只有计划。且计划文档的编号部分已过期。**

### 实测

```
$ git worktree list
kallax-wt-EPIC-245  97c4d45f  [feature/v3.35.0-EPIC-245-dsh-borrow]

$ git log --oneline miao..feature/v3.35.0-EPIC-245-dsh-borrow
(空 — 0 commits)

$ git diff --stat miao...feature/v3.35.0-EPIC-245-dsh-borrow
(空 — 0 变更)

$ git -C kallax-wt-EPIC-245 status --porcelain
?? confluence/decisions/EPIC-245-dsh-borrow-2026-08-17.md
?? jira/tickets/EPIC-245/
?? jira/tickets/EPIC-246/
?? jira/tickets/EPIC-247/
?? jira/tickets/EPIC-248/
```

分支 `feature/v3.35.0-EPIC-245-dsh-borrow` 从未 commit 过，**且没有推到 origin**（`git branch -a` 里只有本地）。所有产出都是 untracked 文件，一旦误删 worktree 就全丢。

### 4 张 untracked ticket 的内容与状态

| ticket | status | 标题 |
|--------|--------|------|
| EPIC-245 | `in_progress` | check-doc-budgets.sh + budgets.manifest.json 自动文档预算 gate |
| EPIC-246 | `todo` | keyless snapshot harness — /kallax-list + /kallax-help 输出冻结 |
| EPIC-247 | `todo` | verify-agent-note-format.sh + ADR 三态 lifecycle 目录规范 |
| EPIC-248 | `blocked` | migrate-decisions.sh — 98 个平面 decisions 迁移 (dry-run 优先) |

### 计划文档的质量评价

`confluence/decisions/EPIC-245-dsh-borrow-2026-08-17.md` 内容质量高，值得保留：
- §1 "优势守恒清单" 8 项 + 4 条守恒红线 —— 明确写了借鉴不得破坏什么，这是好的约束设计
- 每卡 DoD 都要求 raw output 贴 PR
- EPIC-246 的"先冻结输出契约再录基线"顺序判断正确（避免基线随格式漂移）
- EPIC-248 记了 `git mv` 前必 `mkdir -p` 的已知反模式
- §5 明确列了"本 Sprint 不做的 6 项 + 理由"

**但有 3 处必须改**：
1. **编号冲突**：EPIC-248 号已被 origin/miao 上的"测试计数 bug"占用 → decisions 迁移卡必须改号
2. **数字过期**：文档说 decisions 98 个 / verify 脚本 66 个 / CLAUDE.md 194 行；实测 origin/miao 上是 **101 / 65 / 200**
3. **0 交付验证**：4 张卡里 EPIC-245 标 `in_progress`，但实测 `scripts/check-doc-budgets.sh` / `budgets.manifest.json` / `verify-agent-note-format.sh` / `migrate-decisions.sh` / `node/tests/snapshots/` **在两个 worktree 上全部 MISSING**。`in_progress` 名不副实。

### 建议处置

1. **立刻抢救**：把 untracked 的 5 个文件 commit 到 `feature/v3.35.0-EPIC-245-dsh-borrow` 并 push origin，防丢
2. **rebase 到 origin/miao** (追上 21 commits)，重测 3 个过期数字
3. **拆卡改号**：245 保留（doc budgets，wt 已在）；246 保留（snapshot，号仍空）；247 保留（ADR 规范，号仍空）；原 248 → **改为 EPIC-260**（decisions 迁移）
4. **EPIC-245 status 从 `in_progress` 改回 `todo`** —— 0 文件产出不算 in_progress，这正是 EPIC-258 在修的同类 ticket 卫生问题

---

## 候选清单 (影响力排序表格)

| 排名 | EPIC | 一句话目标 | effort | docs-only | 影响力理由 (做 / 不做的代价) |
|------|------|-----------|--------|-----------|---------------------------|
| 1 | **EPIC-259** (新) | 三个 worktree rebase 到 origin/miao + 加 `scripts/next-epic-id.sh` 编号注册器 | **S** (2-3 commits / 3-4 文件) | 否 | **不做的代价已经发生了**：EPIC-245 计划文档在落后 21 commits 的 base 上算出"最大编号 244"，导致 EPIC-248 号双重占用。同类事故会随每个新 worktree 复发。加一个查编号的脚本 + 一次 rebase 就止血。这是唯一一张"不做则后续所有卡的编号都不可信"的卡。 |
| 2 | **EPIC-258** (在跑) | EPIC-254/255 ticket status 补落 done + pr_chain，走完 4-PR | **S** (1 commit 已有 / 2 文件) | 否 | 已有 1 个 commit 待推。Rule 36 指标 #1/#4 从 ticket.json 取数，status 挂在 `in_progress` 会让 `sprint-metrics.sh` 出错数或 NO_DATA 触发 ASK。沉没成本近零，收益立即。不做则 Sprint 收尾时四指标不可信。 |
| 3 | **EPIC-245** (在跑) | `check-doc-budgets.sh` + `budgets.manifest.json`，文档字数硬 gate | **S** (3-4 commits / 12 文件, 主要是 manifest 条目) | 否 | **CLAUDE.md 实测 200/200 行，一行都不剩**。Anthropic 硬阈值 200 是外部约束，超了就是 memory 加载行为退化。现在靠人每次手数行，Rule 35/36/37 都是最近加的，下次加 Rule 必溢出。9 个 `.claude/rules/*.md` 共 655 行且 `recent-epics.md` 单文件已 127 行。不做的代价：某次 PR 悄悄把 CLAUDE.md 推到 210 行，没人发现。 |
| 4 | **EPIC-246** (号空) | keyless snapshot harness — `/kallax-list` + `/kallax-help` 输出冻结基线 | **M** (5-7 commits / 6-8 文件) | 否 | 现有 65 个 verify 脚本全在"检查形式"（有没有数字、有没有引用），没有一个"这个命令的输出必须长这样"。v3.8.0 "25/25 假 PASS" 事故就是形式检查全绿而实际输出错。snapshot 是唯一能抓输出回归的手段。附带收益：snapshot 命令直接就是 Rule 34 要的 `reproduction_command`，exit code 就是 `reproduction_exit_code`，一份投入喂两条规则。实测 `node/tests/snapshots/` 不存在。 |
| 5 | **EPIC-256** (待建卡) | 清 9 个 shell dead function + 收尾 EPIC-254 残留 3 处 `grep -c \|\| echo` | **S** (2-3 commits / 4-6 文件) | 否 | 实跑 `scan-dead-code.sh` 确认 Stage 4 报 **9/60 无外部引用**：`invocation-core.sh` 2 个 (`set_last_error` `cancel_invocations`)、`workspace.sh` 7 个 (`workspace_fs_list` `workspace_fs_stat` `workspace_vcs_log` `workspace_vcs_diff` `workspace_checkpoint_list` `workspace_checkpoint_load` `workspace_health`)。另实测 EPIC-254 声称清完的 `grep -c ... \|\| echo` 污染 **仍剩 3 处**。dead code 每次都出现在 Stage 4 报告里但不 fail，等于每个 Performer 都要看一遍噪音再判断"这个我不管"。不做的代价：报告可信度衰减，真 dead code 混在里面看不见。 |
| 6 | **EPIC-247** (号空) | ADR 三态 lifecycle 目录规范 + `verify-agent-note-format.sh` (只立规范不迁移) | **M** (4-6 commits / 20+ 文件, 多为 `.gitkeep`) | 否 (脚本+目录) | `confluence/decisions/` 实测 **101 个平面文件**，且已有人手动建了 `ARCHIVED/` 目录 —— 痛点真实且已在自发解决。三态 × 6 class 双轴让归档路径自带来源信息。不做的代价：文件数已过百，靠文件名找决策的成本随时间线性上升，且新决策文档格式各写各的（两份调研报告格式就不同）。 |
| 7 | **EPIC-260** (原 248 改号) | `migrate-decisions.sh` 迁移 101 个 decisions 到三态目录 (默认 dry-run) | **M** (4-5 commits / 101+ 文件路径变更) | 是 (纯 .md 移动) | 依赖 EPIC-247 先落。价值实现在这一卡（247 只立规范）。**但风险最高**：动 101 个路径，CLAUDE.md / `.claude/rules/` / ticket.json 里的引用全可能断链。必须 dry-run 出 101 条 from→to 映射给主公 review 后才 `--apply`。docs-only 意味着 Rule 36 走 `--docs-only` flag (exit 3 DOCS_ONLY_SKIP)。 |
| 8 | **EPIC-257** (待建卡) | 扩 `scan-dead-code.sh` Stage 4 覆盖 `scripts/verify/` + `scripts/hooks/` | **S** (2 commits / 2-3 文件) | 否 | 当前 Stage 4 只扫 `scripts/lib/` (60 函数)。`scripts/verify/` 有 65 个脚本整体没被 dead-function 扫过 —— 而这恰恰是最容易堆废脚本的目录（历史 EPIC 各加一个）。**建议排在 EPIC-256 之后**：先按现有覆盖面把 9 个已知的处理完，再扩面，否则一次涌出的报告量没人愿意读。 |
| 9 | **EPIC-261** (新) | ticket dashboard 静态站 MVP — `emit.sh` + 单页 HTML + render 前 immutable fail-closed | **M** (5-8 commits / 6 文件, ~200 LOC) | 否 | dashboard 报告的 Phase 1。真价值不在多一个 kanban（`sprint-metrics.sh` 已出四指标），而在报告 §3.6 提的 `🔒/⚠️` 双态标识 —— 让 evidence gap 可见。降到第 9 是因为它是体验改善，而 1-8 是在防事故。不做的代价：Master 早会 triage 继续靠跑脚本读文本，可接受。 |
| 10 | **EPIC-262** (新) | secret scrub policy — 子进程环境默认 drop `*KEY*` / `*SECRET*` / `*TOKEN*` | **S** (2-3 commits / 3-4 文件) | 否 | 从 DSH 报告 gap #6 里单独提取的一小块（报告把它跟完整 sandbox seam 捆在一起估成 M，我认为可拆）。不需要 seam 抽象就能做。KALLAX 有 `KALLAX_HOOK_API_KEY`，worktree 隔离是 git 层不是进程层，子进程继承全环境。不做的代价：低概率但高后果 —— 某个工具输出把 key 写进 log 或 ticket。 |
| 11 | **EPIC-263** (新) | capability-seam **research-only** 设计稿（不实现） | **M** (2-3 commits / 1-2 文档) | 是 | DSH 报告 gaps #1/#2/#8 全部依赖它。研究卡的价值是把"要不要做 seam"从"每次 retro 重新讨论"变成"有一份可批可否的设计稿"。同 EPIC-222 persistent-supervisor 做法。不做的代价：这三条 gap 每次 retro 都被重提，每次都得出"超上限，下次再说"。 |
| 12 | **EPIC-208** (已在办) | re-promote 4 commits (EPIC-203/204/205/206 testing→main 丢失) | **M** (4 commits / 未知文件数) | 未知 | 主公 2026-08-08 已拍板**接受丢失**。挂在 CLAUDE.md:151 作为审计记录。排最后：既然已拍板接受，re-promote 的收益只是历史完整性。**建议要么执行要么从"待办"改成"已接受"**，不要长期挂着一条名义待办。 |
| — | dashboard Phase 2 TUI | — | **L** | 否 | **不建议立卡**。要引 Textual/ratatui/bubbletea 新栈，且在 Phase 1 拿到真实使用反馈前押注 view 形态。等 EPIC-261 用一个 Sprint 再定。 |
| — | dashboard Phase 3 写路径 | — | **L** | 否 | **不建议立卡**。报告自标 R8 HIGH risk + ASK 主公。multi-user 冲突策略在单 Master 仲裁模型下是解不存在的问题。建议明确否掉而非挂着。 |
| — | DSH gaps #2 / #5 / #8 / #9 / #10 | — | — | — | **不建议立卡**。理由见上文「调研报告可落地项 §A」逐条判断。 |
| — | `dual-engine.yml` cache-dependency-path 验证 | — | **XS** | 否 | **不建议单独立卡**。实测已 `cache-dependency-path: package-lock.json` 且 `node/package-lock.json` 已被 EPIC-255 删掉，两边已相符。挂在 EPIC-246 (会改 node/ 下测试) 里顺带验证即可。 |

---

## 下一 sprint 5 张卡 (+ 取舍理由)

Rule 35 上限：5 EPIC / Sprint，10 commits / EPIC，500 行 / commit。

| # | EPIC | 目标 | effort | docs-only | Performer 专精建议 | worktree |
|---|------|------|--------|-----------|------------------|----------|
| 1 | **EPIC-259** | 3 worktree rebase 到 origin/miao + `scripts/next-epic-id.sh` 编号注册器 | S | 否 | process-engineering | 主仓直接做 (它自己就是修 worktree 的) |
| 2 | **EPIC-258** | EPIC-254/255 status 补落 done + pr_chain (1 commit 已备) | S | 否 | auditor | `kallax-wt-EPIC-258` (已在) |
| 3 | **EPIC-245** | `check-doc-budgets.sh` + `budgets.manifest.json` 文档字数硬 gate | S | 否 | process-engineering | `kallax-wt-EPIC-245` (已在) |
| 4 | **EPIC-246** | keyless snapshot harness (`/kallax-list` + `/kallax-help` 冻结基线) | M | 否 | backend | `kallax-wt-EPIC-246` (新建) |
| 5 | **EPIC-256** | 清 9 个 shell dead function + 收尾 EPIC-254 残留 3 处 | S | 否 | backend | `kallax-wt-EPIC-256` (新建) |

**容量核算**: 5 EPIC = 上限。effort 4S + 1M，估 15-20 commits 总量，远低于 5×10=50 上限。留了余量，因为 EPIC-259 的 rebase 可能带出冲突。

### 取舍理由

**为什么 EPIC-259 排第 1 而不是直接开发**
它是唯一一张"不做则后面 4 张都建在不可信基础上"的卡。实测证据：EPIC-245 那份计划文档在落后 21 commits 的 base 上算出"最大编号 = 244"，于是把 decisions 迁移编成 EPIC-248 —— 而 origin/miao 上 EPIC-248 早已是"测试计数 bug"并 done。这不是假设风险，是已经发生的事故。而且现在同时有 3 个 worktree 在 3 个不同 base 上，下一次编号冲突只是时间问题。`next-epic-id.sh` 是十几行脚本，一次投入永久止血。

**为什么 EPIC-258 排第 2**
它已经有 1 个 commit 躺在 worktree 里没推。沉没成本近零，只差走 4-PR。而且它挡着 Rule 36 —— 四指标从 ticket.json 取数，status 挂 `in_progress` 会让 `sprint-metrics.sh` 出错数或 NO_DATA 触发 ASK。先把度量工具的输入修对，本 Sprint 结束才有可信的四指标。

**为什么 EPIC-245 (doc budgets) 优先于 dashboard**
dashboard 报告把静态站 MVP 排成主路径。我不同意。判据是"哪个不做会出事"：
- CLAUDE.md 实测 **200/200 行**，卡在 Anthropic 硬阈值上。超了 memory 加载行为退化，而现在的防线是"人每次手数行"。最近连加了 Rule 35/36/37，下次必溢出。
- dashboard 不做，Master 继续跑 `sprint-metrics.sh` 读文本 triage。慢，但不出错。

一个是防事故，一个是提效率。Sprint 容量只有 5 张时，防事故先。

**为什么 EPIC-246 (snapshot) 入选而不是排到下 Sprint**
它是 5 张里唯一的 M，占容量。但它解的是 KALLAX 最贵的一次事故类型：v3.8.0 声称 "25/25 exit 0 已上线"，reviewer 实测 11 errors。事后加的防线（`check-claim-evidence.sh` / `check-decorative-claim.sh`）全是**形式检查** —— 查有没有数字、有没有 raw_output 引用，但不查输出内容对不对。现有 65 个 verify 脚本没有一个能抓输出回归。snapshot 是补这个洞的唯一手段。附加价值：snapshot 命令天然就是 Rule 34 要的 `reproduction_command` + `reproduction_exit_code`，一卡喂两条规则。
风险已在 EPIC-245 计划文档里被正确识别：**先冻结输出契约，再录基线**，否则基线随格式漂移每次红。这个顺序要求写进 AC。

**为什么 EPIC-256 (dead code) 入选而 EPIC-257 (扩面) 不入选**
两张卡都便宜，但有先后关系。EPIC-256 处理 Stage 4 已经报出来的 9 个具体函数（实跑确认）；EPIC-257 把扫描面从 `scripts/lib/` 60 函数扩到 `scripts/verify/` 65 脚本 + `scripts/hooks/`。**若先扩面**，报告量一次涌出且旧的 9 个还没清，Performer 面对一大坨报告更倾向全部忽略 —— 这恰好是 EPIC-256 想解决的"报告可信度衰减"问题被放大。先清干净再扩面。
EPIC-256 里顺带收尾 EPIC-254 残留的 3 处 `grep -c ... || echo`（实测仍在），因为同属 shell 卫生，同一个 Performer 同一次上下文成本最低。

**为什么 EPIC-247 / EPIC-260 (ADR 三态 + 101 文件迁移) 不入选**
两张都是 M，加起来吃掉 2/5 容量。而 EPIC-260 是全部候选里风险最高的一张（动 101 个文件路径，断链风险遍及 CLAUDE.md / `.claude/rules/` / ticket.json）。在同一个 Sprint 里既跑 EPIC-259 的 rebase（也可能有冲突）又跑 101 文件迁移，两个"大范围动文件"的卡撞在一起，冲突排查成本会失控。放下个 Sprint，且 EPIC-247 先单独落一个 Sprint 让规范稳定后，EPIC-260 再动迁移。

**明确不进本 Sprint 也不进 backlog 的**
- dashboard Phase 3 写路径 + multi-user —— 建议直接否掉。单 Master 仲裁模型下 multi-user 冲突策略无适用场景，挂在 backlog 只会每次 retro 重新讨论一遍。
- DSH gaps #2 / #5 / #8 / #9 / #10 —— 见上文逐条理由。#9 (hook-bridge) 尤其：KALLAX 是 Claude Code 治理层，不做多 harness 适配。

---

## Backlog

按建议启动顺序。

| 顺位 | EPIC | 目标 | effort | docs-only | 前置条件 / 说明 |
|------|------|------|--------|-----------|---------------|
| B1 | **EPIC-247** | ADR 三态 lifecycle 目录规范 + `verify-agent-note-format.sh` | M | 否 | 无前置。下 Sprint 首选。规范先稳定一个 Sprint 再动迁移。 |
| B2 | **EPIC-257** | 扩 Stage 4 覆盖 `scripts/verify/` (65 脚本) + `scripts/hooks/` | S | 否 | 前置 EPIC-256 落地（先清完已报的 9 个再扩面）。 |
| B3 | **EPIC-260** | `migrate-decisions.sh` 迁 101 decisions 到三态目录，默认 dry-run | M | **是** | 前置 EPIC-247。**风险最高**：dry-run 出 101 条 from→to 映射 + 全仓引用扫描 0 断链，主公二次拍板后才 `--apply`。`git mv` 前必 `mkdir -p`。Rule 36 走 `--docs-only`。 |
| B4 | **EPIC-261** | ticket dashboard 静态站 MVP (`emit.sh` + 单页 HTML + immutable fail-closed) | M | 否 | 无前置。价值点是 `🔒/⚠️` evidence gap 双态标识，不是多一个 kanban 视图。 |
| B5 | **EPIC-262** | secret scrub — 子进程环境默认 drop `*KEY*` / `*SECRET*` / `*TOKEN*` | S | 否 | 无前置。从 DSH gap #6 拆出的独立小块，不需要 sandbox seam。 |
| B6 | **EPIC-263** | capability-seam **research-only** 设计稿 | M | **是** | 无前置。产出设计稿供主公批/否，解锁 DSH gaps #1/#2/#8 的讨论。同 EPIC-222 research-only 做法。 |
| B7 | **EPIC-208** | re-promote 4 commits (EPIC-203/204/205/206) | M | 未知 | 主公已拍板接受丢失。**建议要么执行、要么从 CLAUDE.md:151 的"待办"改成"已接受"**，不长期挂名义待办。 |
| — | dashboard Phase 2 TUI | 终端 view + filter + drill-down | L | 否 | **不立卡**。等 EPIC-261 拿到真实使用反馈再定 view 形态与栈选型。 |
| — | dashboard Phase 3 | 写路径 + multi-user + SSE | L | 否 | **建议否掉**。R8 HIGH risk；multi-user 在单 Master 仲裁模型下无适用场景。 |
| — | DSH gap #2 微内核双事件轨 | — | L | 否 | **不立卡**。依赖 seam；当前无消费者要求 `sourceEventSeqs` 精度。 |
| — | DSH gap #5 render-intent 三向投影 | — | M | 否 | **不立卡**。无 GUI 消费者。若 EPIC-261 落地后有需求再议。 |
| — | DSH gap #6 完整 sandbox seam | — | L | 否 | **不立卡**。触及 AUTO-PERMS + 65 脚本入口，超单卡上限。已拆出 EPIC-262 取小块价值。 |
| — | DSH gap #8 4-waterfall pipeline | — | L | 否 | **不立卡**。pre-commit hook 链已是简化版；全量依赖 seam。 |
| — | DSH gap #9 hook-bridge 协议层 | — | L | 否 | **不立卡**。KALLAX 定位是 Claude Code 治理层，不做多 harness 适配。 |
| — | `dual-engine.yml` cache 验证 | — | XS | 否 | **不立卡**。实测已相符（root `package-lock.json` 存在，`node/package-lock.json` 已删）。挂 EPIC-246 顺带验证。 |

---

## 附：本次规划的实测命令清单

| 侦查项 | 实测值 | 命令 |
|--------|--------|------|
| `origin/miao` HEAD | `53d3e2aa` | `git rev-parse --short origin/miao` |
| 本地 `miao` 落后 | 21 commits | `git log --oneline miao..origin/miao \| wc -l` |
| worktree 数 | 3 (主 / EPIC-245 / EPIC-258) | `git worktree list` |
| EPIC-245 分支 commits | **0** | `git log --oneline miao..feature/v3.35.0-EPIC-245-dsh-borrow` |
| EPIC-245 untracked | 5 项 (1 doc + 4 ticket 目录) | `git -C kallax-wt-EPIC-245 status --porcelain` |
| EPIC-258 分支 commits | 1 (`d95d3b66`) | `git log --oneline origin/miao..feature/v3.35.0-EPIC-258-ticket-status` |
| ticket 目录数 | 191 (最大真实 EPIC-255) | `ls jira/tickets \| wc -l` |
| EPIC-256/257 ticket | **不存在** | `git show origin/miao:jira/tickets/EPIC-256/ticket.json` → NO_TICKET |
| `CLAUDE.md` 行数 | **200 / 200 上限** | `wc -l CLAUDE.md` |
| `.claude/rules/*.md` | 9 文件 / 655 行 | `wc -l .claude/rules/*.md` |
| `confluence/decisions/` | **101** 项 (含 1 `ARCHIVED/`) | `ls confluence/decisions \| wc -l` |
| `scripts/verify/` | **65** 脚本 | `ls scripts/verify \| wc -l` |
| Stage 4 dead functions | **9/60** | `bash scripts/scan-dead-code.sh` → exit 2 (BLOCKED-env: node_modules 缺失, Stage 2/3 SKIP) |
| EPIC-254 残留污染 | **3** 处 `grep -c ... \|\| echo` | `grep -rn 'grep -c' scripts --include='*.sh' \| grep -c '\|\| echo'` |
| `node/tests/snapshots/` | 不存在 | `ls node/tests/snapshots` |
| `check-doc-budgets.sh` | 不存在 (两个 worktree 均 MISSING) | `ls scripts/check-doc-budgets.sh` |
| `dual-engine.yml` cache | `cache-dependency-path: package-lock.json` (root) | `grep -n cache-dependency-path .github/workflows/dual-engine.yml` |
| `node/package-lock.json` | 已删 (EPIC-255 done) | `ls node/package-lock.json` → No such file |

**注**: `scan-dead-code.sh` exit 2 是 BLOCKED-env（`node/node_modules` 缺失导致 Stage 2 tsc + Stage 3 sentinel 跳过），非真违规。`FAIL_COUNT=0 / BLOCKED_COUNT=2`。Stage 4 本身正常跑出了 9/60 结果。
