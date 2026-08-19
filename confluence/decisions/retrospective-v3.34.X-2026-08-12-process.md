# Sprint 流程与交付复盘 (PR #369-#421, 2026-08-10 → 2026-08-17)

> 视角: 流程与交付。只写自己跑命令核实过的事实。
> Sprint 基线 commit: `bbdac044` (2026-08-10, PR #365 合入 miao)
> Sprint 终点: `53d3e2aa` (2026-08-17, PR #421 EPIC-255 main→miao)
> 核实环境: 临时 worktree checkout `origin/miao` (主仓工作副本落后 origin/miao 21 commit, 不可直接用来核实)

---

## 交付统计 (带具体数字 + 命令来源)

### 主干交付量

| 指标 | 实测值 | 命令 |
|---|---|---|
| miao 新增 commit | **17** | `git rev-list --count bbdac044..origin/miao` |
| 其中 merge commit | **0** (全部 squash) | `git log --merges bbdac044..origin/miao` = 空 |
| 变更文件 | **68** | `git diff --name-only bbdac044 origin/miao \| wc -l` |
| 净增删 | **+4079 / -6647** (净 -2568) | `git diff --shortstat bbdac044 origin/miao` |
| 净增删 (排除 `node/package-lock.json` 的 -6525) | **+4079 / -122** (净 +3957) | `git show --numstat 53d3e2aa` |
| 合并 PR | **53** (#369 → #421 全部 MERGED) | `gh pr list --state all` |
| 题目所指 #371-#421 区间 | **51** | 同上, 按编号过滤计数 |

### 交付单元结构

- PR-1 (feature → testing): **18** 个 — #369 372 375 378 381 384 387 390 393 396 399 402 405 408 410 413 416 419
- PR-2 (testing → main): **18** 个 — #370 373 376 379 382 385 388 391 394 397 400 403 406 409 411 414 417 420
- PR-3 (main → miao): **17** 个 — #371 374 377 380 383 386 389 392 395 398 401 404 407 412 415 418 421
- 18 × 3 = 54, 实际 53 → **少 1 个 PR-3** (见违规清单 V4)

### EPIC 数

`git log bbdac044..origin/miao` 提到的 EPIC 编号共 25 个, 其中**本 sprint 实际交付 16 个 EPIC**:

| 类别 | EPIC | 数量 |
|---|---|---|
| 收口历史 in_progress | 157 / 158 / 159 / 160 / 170 / 171 / 172 / 174 | 8 |
| 本 sprint 新建 | 248 / 249 / 250 / 251 / 252 / 253 / 254 / 255 | 8 |
| 非 EPIC 交付单元 | Retro (#393-395) / Upgrade (#396-398) / ticket status sync (#413-415) | 3 |
| **合计交付单元** | | **19** |

(EPIC-247 的 fix `0ee8d400` 在 sprint 基线时已在 testing, 不计入; 但其 PR #368 仍 OPEN, 见 V5)

### 单 commit 体量 (miao 落地版, insertions+deletions)

```
53d3e2aa EPIC-255           6927  (396 + 6531)   ← 超标
0d11044c EPIC-248/249/250    860  (832 + 28)     ← 超标
ccc55f84 EPIC-253            558  (537 + 21)     ← 超标
48430ef1 EPIC-254            470
4aaec77e EPIC-159            411
43de131c EPIC-251            405
a5427125 EPIC-252            382
daf13aae Retro               334
d1278ade EPIC-157            273
e9efd516 ticket sync         181
其余 6 个                    ≤ 30
```
命令: `git show --shortstat --format='%h|%s' <commit>` 逐个跑 (脚本 `/tmp/retro-scripts/s10.sh`)

---

## Rule 违规清单

### V1 — Rule 35 «≤5 EPIC / Sprint» 超 3.2 倍 [严重]

- **实际值**: 16 个 EPIC + 3 个非 EPIC 交付单元 = 19 个交付单元
- **阈值**: ≤ 5 EPIC / Sprint
- **超标幅度**: EPIC 数 16 vs 5 → 超 11 个 (320%)
- **证据**: `git log bbdac044..origin/miao --format='%s'` 17 条 squash commit, 逐条对应 1 个交付单元; ticket 目录 `git ls-tree origin/miao jira/tickets/` 存在 EPIC-248~255 共 8 个新 ticket

### V2 — Rule 35 «≤500 行 / commit» 3 次超标 [中]

| commit | EPIC | 实际行数 | 阈值 | 超标 |
|---|---|---|---|---|
| `53d3e2aa` | EPIC-255 | 6927 | 500 | 13.9× |
| `0d11044c` | EPIC-248/249/250 | 860 | 500 | 1.7× |
| `ccc55f84` | EPIC-253 | 558 | 500 | 1.1× |

- EPIC-255 的 6525 行是删 `node/package-lock.json`, 属机械删除, 但 Rule 35 文本无「删除行豁免」条款 → 按字面算超标, 需要备案或改 Rule
- `0d11044c` 把 3 个 EPIC (248/249/250) 塞进 1 个 commit, 属打包超标
- 命令: `git show --shortstat --format='' <commit>`

### V3 — Rule 35 §3.2 «触及 5+ 文件必须拆 EPIC» 未执行 [中]

| EPIC | 文件数 | 是否拆 |
|---|---|---|
| EPIC-255 | 9 (含 3 个 workflow yml) | 未拆 |
| EPIC-254 | 18 (15 个 scripts + 1 个 ts + test + ticket) | 未拆 |
| EPIC-248/249/250 | 10 | 未拆 (反而 3 EPIC 合 1 PR) |
| EPIC-253 | 8 | 未拆 |
| EPIC-252 | 8 | 未拆 |

- 命令: `git show --numstat <commit>`
- 注: 上个 sprint 的复盘文档 `confluence/decisions/retrospective-batch-8-EPIC-2026-08-12.md:122` (L13) 已经把这条记为「阈值过严, 主公 override 5 次」, 并提出「修订 Rule 35 §3.2 排除 docs-only 模式」。本 sprint **既没修订 Rule, 也继续 override** → 规则文本与实际执行持续脱节

### V4 — Rule 4 «4-PR 全程» EPIC-253 补丁缺 PR-3 [中]

- **实际值**: EPIC-253 补丁 (#408 → testing, #409 → main) 之后**没有独立 main→miao PR**
- **阈值**: 每个交付单元必走 PR-1 / PR-2 / PR-3
- **证据**:
  - `gh pr list` 显示 #408 base=testing, #409 base=main, 无 #410 之外的 miao PR
  - `EPIC-253/ticket.json` 的 `pr_chain` = `['#405','#406','#408','#409','#407']` — #407 (PR-3) 编号早于补丁 #408/#409, 说明补丁内容是被后续 PR #412 (EPIC-248 的 PR-3) 顺带带上 miao 的, 不是自己走的 PR-3
  - 命令: `git show origin/miao:jira/tickets/EPIC-253/ticket.json`

### V5 — Rule 4 «0 静默跳过» PR #368 悬空 7 天 [中]

- **实际值**: PR #368 (EPIC-247 main→miao) 创建于 2026-08-10T09:49Z, 至今 state=OPEN
- **问题**: 同期 17 个 main→miao PR 已合入, EPIC-247 的内容早已随 #371 之后的 PR-3 上了 miao, 但 #368 无人关掉 → PR 列表里留一个假的「未完成阶段」
- **证据**: `gh pr view 368 --json state,createdAt` → `{"state":"OPEN","createdAt":"2026-08-10T09:49:25Z"}`

### V6 — Rule 4 «master + 4 sub-roles review» 0 执行 [最严重]

- **实际值**: 53 个 PR 中, **reviews = 0, comments = 0, 无一例外**
- **阈值**: CLAUDE.md §4 «0 容忍 auto-merge; 4-PR 任一必走 master + 4 sub-roles review (Architect / Backend / Frontend / Security 各 1 份)»
- **证据**: 对 #369-#421 全部 36 个 PR-1/PR-2 + 17 个 PR-3 逐个跑
  `gh pr view <n> --json reviews,comments --jq '...'` → 全部 `reviews=0 comments=0`
  (脚本 `/tmp/retro-scripts/s11.sh` + `s12.sh`, 输出 `/tmp/claude-tasks/retro-s11.log`, `retro-s12.log`)
- 补充: `gh pr view --json reviewDecision` 因 token 缺 `read:org` scope 报错, 但 `reviews` 数组长度 0 已足够判定
- Rule 37 (小 effort auto-approve) 可以解释一部分小 PR, 但 EPIC-254 (18 文件 / 15 脚本) 和 EPIC-255 (删 6525 行 lockfile + 改 3 个 CI workflow) 不属于「小 effort」

### V7 — Rule 36 «Sprint 结束必跑 4 北极星» 未跑, 且上个 sprint 的 PASS 结论已被推翻 [严重]

- **未跑证据**:
  - `grep -c sprint-metrics state/run-history.jsonl` → **0**
  - `git diff --name-only bbdac044 origin/miao` 68 个文件里没有任何 metric 输出产物
  - `confluence/decisions/EPIC-248-249-250-triple-2026-08-10.md` grep `sprint-metrics|北极星|Rule 36` → **0 命中**
  - 5 个新 EPIC (251-255) 的决策文档同样无 metric 记录
- **上个 sprint 结论被推翻**: `retrospective-batch-8-EPIC-2026-08-12.md:22` 记「4 北极星 sprint-metrics → ALL_PASS (8/8)」。我在 miao tree 实跑 16 个 EPIC:

```
EPIC-157 exit=1   EPIC-158 exit=0   EPIC-159 exit=1   EPIC-160 exit=1
EPIC-170 exit=1   EPIC-171 exit=1   EPIC-172 exit=1   EPIC-174 exit=1
EPIC-248 exit=0   EPIC-249 exit=0   EPIC-250 exit=1   EPIC-251 exit=1
EPIC-252 exit=1   EPIC-253 exit=1   EPIC-254 exit=1   EPIC-255 exit=1
```
  → **13/16 exit=1 (HAS_FAIL)**, 声称 8/8 exit 0 的那 8 张里有 7 张现在 exit=1
- **为什么翻**: EPIC-253 修了 `collect_filescope` root ticket bug + 加了 `cross_epic_docs_reuse_rate`。修完之后原来返回 NO_DATA 的指标变成有数据的 FAIL。例 EPIC-160: `cross_epic_reuse_rate = 42% < 60% FAIL`, `cross_epic_docs_reuse_rate FAIL`。也就是上个 sprint 的 ALL_PASS 建立在一个后来被自己修掉的 bug 上
- **`--docs-only` 也不能救**: 8 张 docs EPIC 加 `--docs-only` 全部 exit=3 (DOCS_ONLY_SKIP), 等于跳过, 不产生指标数据
- **新 EPIC 也不达标**: EPIC-254 实测 `cross_epic_reuse_rate=47% < 60%`, `expert_activation_rate=0 < 5 (NO_DATA)`
- 命令: `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX` (在 `/tmp/retro-wt-miao` = origin/miao 的 detached worktree 里跑, 脚本 `/tmp/retro-scripts/s23.sh` / `s24.sh`)

### V8 — ticket 卫生: EPIC-254/255 status 与交付不符 (第 2 次同类) [严重]

`git show origin/miao:jira/tickets/EPIC-25*/ticket.json`:

| EPIC | origin/miao status | origin/main status | pr_chain | 实际交付 |
|---|---|---|---|---|
| 248 | done | done | #410 #411 #412 | 已合 miao |
| 249 | done | done | #410 #411 #412 | 已合 miao |
| 250 | done | done | #410 #411 #412 | 已合 miao |
| 251 | done | done | #399 #400 #401 | 已合 miao |
| 252 | done | done | #402 #403 #404 | 已合 miao |
| 253 | done | done | #405 #406 #408 #409 #407 (顺序错) | 已合 miao |
| **254** | **in_progress** | **in_progress** | **None** | **PR #418 已合 miao** |
| **255** | **in_progress** | **in_progress** | **None** | **PR #421 已合 miao** |

- 第 1 次: 13 张 ticket 漏同步 → 靠 #413-415 补
- 第 2 次: EPIC-254/255 同一症状, 在 main 和 miao 两个分支上都是 in_progress
- **为什么没被拦**: 在 miao tree 跑 `bash scripts/verify/check-ticket-schema.sh --all` → **exit 0, "OK: all tickets > EPIC-222 schema 齐"**, 包括 EPIC-254/255 都报 OK。原因是该 gate 只查 `new_ticket_required_fields` 字段**是否存在**, 不查 `status` 值是否与合并状态相符, 也不查 `pr_chain` (`pr_chain` 根本不在 required_fields 里 — `git show origin/miao:jira/tickets/.archive-baseline.json`)
- **额外发现的 gate 盲区**: EPIC-247 在 miao 上**根本没有 ticket 目录** (`git ls-tree origin/miao jira/tickets/EPIC-247/` → 空), 编号 247 > 222 本该强制建卡, 但 `--all` 只遍历已存在的目录, 所以仍然 exit 0。缺失的卡永远查不出来

### V9 — 分支残留 52 条 [低]

`git branch -r` 里本 sprint 产生并保留的分支:
- 晋级用临时分支 **35** 条 (`epic1xx-testing-to-main` / `epic1xx-main-to-miao` / `e25x-*` / `retro-*` / `upgrade-*` / `tickfix-*` / `epic253b-testing-to-main` / `epic159-rebased-for-main`)
- feature 分支 **17** 条 (`feature/EPIC-157-expert-binding` … `feature/EPIC-255-root-lockfile` + `fix/ticket-status-sync`)
- 与 MEMORY.md 「worktree 清理只删本地, 远程 branch 保留作审计链」相符, 所以只算噪声不算违规; 但 35 条纯搬运分支没有审计价值

### 反向核实: 通过项

| 项 | 结果 | 命令 |
|---|---|---|
| 三主干树相同 | testing == main == miao (diff 为空) | `git diff --stat origin/main origin/testing` / `origin/miao origin/main` |
| 无 force-push 断链 | 无 | main 比 miao 多的 21 个 commit 全是待晋级的 FF 记录, 无重写痕迹 |
| PR-2 走 FF push + comment 模式 | 符合 §4 PR-2 v2 修正 | 18 个 PR-2 title 全带 "FF push" |
| ticket schema 字段齐 | exit 0 | `check-ticket-schema.sh --all` (miao tree) |

---

## 流程缺口 (最严重在前)

### 1. review 门整体空转 (V6)
53 个 PR 零 review 零 comment。CLAUDE.md §4 写的「master + 4 sub-roles 各出 1 份 review」在 GitHub 上没有任何痕迹。这意味着 §4 表格里的四阶段验证站目前只是文档, 没有可核实的执行记录。EPIC-207 立这条规则本身就是为了防 v3.8.0 的假 PASS, 现在规则本身变成了同一类问题: 声明存在, 证据不存在。

### 2. Rule 36 既不跑, 跑了也不达标, 而上次「达标」是 bug 造成的 (V7)
三层问题叠在一起:
- 本 sprint 16 个 EPIC 零次 metric 记录 (`run-history.jsonl` 0 命中)
- 实跑 13/16 exit=1
- 上个 sprint 记录的 8/8 exit 0 是 `collect_filescope` bug 的产物, EPIC-253 修完 bug 后同样的 EPIC 变 FAIL
这三条合起来说明: 指标机制目前不产生可信信号, 「跑指标」这一步在实际流程里可以省掉而不被发现。

### 3. ticket status 漂移已复发, 且 gate 结构上查不到 (V8)
不是执行者忘了, 是 `check-ticket-schema.sh` 的检查维度里没有「status 与合并状态相符」和「pr_chain 非空」这两项, 也没有「新 EPIC 必须存在 ticket 目录」的反向扫描 (EPIC-247 缺卡未被发现)。同类问题第 2 次出现, 补的方式还是人工再开一条 PR 链 (#413-415), 下次仍会第 3 次。

### 4. Rule 35 与实际节奏差 3 倍以上, 且上个 sprint 已识别却未修 (V1/V2/V3)
19 个交付单元 vs 阈值 5。上个 sprint 复盘 L13 已经写明「阈值过严 / 主公 override 5 次 / 建议修订 §3.2」, 本 sprint 既没修规则也没收敛节奏。规则失效比规则严格更危险: 每次 override 都要人工拍板, 拍板变常态之后阈值就不再有拦截作用。

### 5. 交付粒度打包与 PR 链条断点 (V2 的 `0d11044c` / V4 / V5)
3 个 EPIC 合 1 个 commit, 1 个补丁缺 PR-3, 1 个 PR 悬空 7 天。单看每一项都不大, 但共同后果是: 从 PR 编号无法反推交付单元边界, `pr_chain` 出现乱序 (EPIC-253), 追溯成本上升。

---

## 建议

1. **给 review 门加机器可查的证据要求**。要么在 GitHub 上落 4 条 review (即使是自评), 要么把 §4 改成「PR 描述里必须有 4 sub-roles 段落」并写一个扫 PR body 的 gate。现状是规则和证据脱钩 — 二选一, 不要留第三种「写了但查不到」的状态。

2. **`check-ticket-schema.sh` 加 3 项检查**: (a) `pr_chain` 进 `new_ticket_required_fields`; (b) ticket 在 main/miao 上且 `pr_chain` 非空时 `status` 必须是 `done`/`blocked`/`archived`, 不能是 `in_progress`; (c) 反向扫 — 从 commit message 提取 `EPIC-\d{3}`, 编号 > 222 而无 ticket 目录则 FAIL (可抓出 EPIC-247 这类缺卡)。这是 ticket 漂移第 2 次, 不加就会有第 3 次。

3. **修 Rule 35 阈值, 或明确它是软阈值**。上个 sprint 的 L13 已经给出方案 (docs-only 视为 1 模块), 本 sprint 又超 3 倍。要么把 EPIC 上限提到与实际节奏相符的数字并补「删除行不计入 500 行」条款, 要么把 §3.2 降级成 advisory。保留一条每次都要 override 的硬规则没有收益。

4. **先修 Rule 36 的数据源再要求跑指标**。当前 `expert_activation_rate` 恒为 NO_DATA (无 invocation 数据源), `cross_epic_reuse_rate` 在新 EPIC 上实测 42%-47% 达不到 60%。建议这个 sprint 只做一件事: 把 sprint-metrics 的一次真实运行结果 (含 exit code) 提交进仓库作为基线, 承认 FAIL, 后续按基线改进 — 不要再出现「ALL_PASS 但数据是 bug 产生的」。

5. **收敛晋级分支**。35 条 `*-testing-to-main` / `*-main-to-miao` 搬运分支不含独有 commit, 无审计价值, 可安全删除 (feature 分支按 MEMORY.md 保留)。同时清掉 PR #368 这类悬空 PR, 让 PR 列表能反映真实进度。
