# Worktree 治理债复盘 — 为什么只创建不清理 (2026-08-28)

> **触发**: 主公 2026-08-28 拍板"扩大检查范围, 所有的本地分支都要检查和清理", 引爆本复盘.
> **根因诊断**: 6 个月累积治理债, 多源叠加, 缺闭环.
> **联动**: [[feedback-worktree-isolation]], [[feedback-worktree-cleanup-local-only]], [[retrospective-2026-08-19-branch-flow-cleanup]], EPIC-224 (hook 体系失效), EPIC-227 (worktree-hook fix), EPIC-229 (testing 分支恢复)

---

## 1. 现象 (实测数据)

2026-08-28 session start 时 `git worktree list` 输出:

```
worktree: 79
本地 branch: 165
远端 miao 落后: 15 commits (本地 7cd5bc50, origin 0eed8ca4)
```

79 worktree 中:
- **68 branch-bound** (各 EPIC agent-XX 命名 + 命名 EPIC-XXX 目录)
- **11 detached HEAD** (含 `/private/tmp/kallax-*` 临时 audit 目录 5 个 + 内部 detached 6 个)

**本次清理 (4 批)**:

| 批 | 来源 | branch 数 | worktree 数 |
|----|------|----------|-------------|
| 1 | `git branch --merged miao` | 16 | 16 |
| 2 | `git branch --merged miao` 第二轮 (worktree-agent-* 孤儿) | 28 | 0 |
| 3 | `gh pr list --state merged` 交集 | 42 | 0 |
| 4 | 主公"扩大检查": 9 CLOSED-not-merged + 66 无 PR 记录 | 75 | 51 |
| **合计** | — | **161** | **67** |

最终: **4 branch + 12 worktree** (4 主分支 + 1 cwd + 5 /private/tmp + 6 stale .claude/worktrees/ 物理目录)

---

## 2. 为什么只创建不清理 — 多源根因

### 2.1 Performer 派单未带清理动作 (主因)

**机制**: 每次 performer 派单 (kallax:claim 或 sub-agent 调度) 走 `git worktree add .claude/worktrees/<name>` 自动创建, **从未强制带清理 hook**.

**证据**: 79 worktree 中绝大多数是 `agent-<uuid>` 命名 (每 subagent 启一个 worktree). 这些 UUID 命名一次性, 派单结束 performer 终止 session — **但 worktree 簿记永远留在 main repo**.

**Rule gap**: [[feedback-worktree-isolation]] 步骤5-6 写了 "merge PR 后必须立刻删 worktree + branch", 但:
- 步骤5-6 在文档里存在, 0 hook gate 强制
- performer session 跟 "merge PR" 间隔数天/数周, 派单完成时 PR 还在 open 状态, 不触发步骤5-6
- 步骤6 的 "after octopus merge" 是 miao 阶段, performer 拿不到这个上下文

### 2.2 squash merge 后 git --contains 失效 (技术债)

**机制**: GitHub PR 用 squash merge 后, feature branch 在 git 历史中不再是 miao 的 ancestor — `git branch --merged miao` / `--contains origin/miao` 全部返回空.

**证据**: 本次清理第 3 批 42 个 branch 必须用 `gh pr list --state merged --json headRefName` 反查才能命中, 第 4 批 75 个用 gh 仍查不出 (state=CLOSED 但 mergedAt=null, 实际工作已被其它 PR 合入).

**Rule gap**: 没文档说明 "squash merge 后 git ancestry 视角失效, 必须 gh 交叉验证". 历次清理 (EPIC-196/199/205/227/229) 都用 `git branch --merged`, **只能清零头, 漏大批**.

### 2.3 worktree-agent-* 自动分支从不删 (历史债)

**机制**: `git worktree add -b worktree-agent-<uuid> ...` 创建 worktree 同时创同名 branch (git 设计). 当 `git worktree remove <path>` 删 worktree 时, **branch 不自动删** — 需手动 `git branch -D`.

**证据**: 本次清 39 个 worktree-agent-* 孤儿分支, 都是同一 commit hash = miao tip,纯垃圾.

**Rule gap**: 0 文档教 "worktree remove 必须伴 branch -D". EPIC-227 修的是 KALLAX_ROOT (worktree 内 hook 检测), 没触及这个清理契约.

### 2.4 临时 audit 目录散落 (/private/tmp)

**机制**: 多次 retrospective / audit task 临时用 `/private/tmp/kallax-audit-<sha>` / `/private/tmp/kallax-epic<NNN>` 等目录做 detached HEAD 快照, **完成 audit 后未删**.

**证据**: `git worktree list` 仍显示5 个 `/private/tmp/kallax-*` 目录 (21df7d79 / ab4bc142 / 6c69b976 / 6b2490e9 / 07aa87c3 / 636ca885).

**Rule gap**: `/tmp` 物理清理通常靠 OS 重启或 cron, 但 git 簿记的 worktree 注册表是 main repo 持有的 (`.git/worktrees/`), 物理目录删了簿记还在 → `git worktree list` 仍能看到.

### 2.5 hook 体系曾整体失效 (EPIC-224)

**机制**: 2026-07-20 → 2026-08-08 共 19 天, `core.hooksPath` 指向已删临时目录 `/tmp/kallax-fix-epic131/.githooks`, **所有 pre-commit hook 从未运行** (含任何"创建 worktree 时强制带清理 hook"的潜在 gate).

**联动**: EPIC-224 修好后, **没人补建 "worktree 创建时登记待清理" gate**, 债没堵住.

### 2.6 testing 分支曾被 --delete-batch 删除 (EPIC-229 教训)

**机制**: testing 分支在某个清理中被 batch delete, 导致 EPIC-218~228 共 11 个 EPIC 跳过 testing 阶段直 main→miao, **全打"备案债"补丁**. 这暴露"清理是单原子动作"的问题, 后续没人愿再大规模清理 — 怕重复历史.

**证据**: `retrospective-2026-08-19-branch-flow-cleanup.md` 记录 9 个 PR batch清 27 EPIC, 是 8 月最大清理, 但**没清 worktree + branch** (只清 testing→main 路径).

---

## 3. 影响 (6 个月累积债)

| 维度 | 现状 | 风险 |
|------|------|------|
| `.git/worktrees/` 簿记 | 79 实体 | `git worktree list` 慢 / 误导 |
| `git branch --list` | 165 行 | 决策疲劳, 漏掉 active branch |
| `.claude/worktrees/` 物理目录 | 60+ GB 估 | disk pressure / 误打开 |
| detached HEAD commit | 12 个 | 跟某个 branch 重复 commit, 易混 |
| agent-* 孤儿 branch | 39 个 | 1 commit 指 miao tip,纯垃圾 |
| EPIC-* 衍生 branch | ~50 个 | 多为 PR squash 后 git 视角下"未合并", 实际已合 |

**用户痛点**: 每次 `git checkout <branch>` 在 165 选项中找目标, 等同翻垃圾堆. 新 EPIC 建卡时 `--merged origin/miao` 误把未合 EPIC 标 merged, 引发编号撞车 (见 [[feedback-check-origin-before-numbering]]).

---

## 4. 修复路径 (本轮 + 后续 EPIC)

### 4.1 本轮已做 (4 批清理, 2026-08-28)

- 161 branch + 67 worktree 全清 (本地)
- 远程 0 触碰 (审计链完整)
- 决策文档已 staged (`worktree-cleanup-2026-08-28.md`)

### 4.2 后续 EPIC 建议 (主公拍板起)

**EPIC-301 worktree-cleanup-followup** (建议):
1. **6 个 stale `.claude/worktrees/` 物理目录手工 `rm -rf`** (git 簿记已 prune)
2. **5 个 `/private/tmp/kallax-*` 临时 audit 目录确认无引用后删**
3. **`scripts/check-stale-worktree.sh` 新建**: 每次 `git worktree list` 输出 > N 时警告
4. **`scripts/install.sh` 加 hook**: `post-checkout` 监听, 当 `git checkout` 切到 main 分支时, 提示 `git worktree prune`
5. **CLAUDE.md §4 加 §4.5 Worktree 卫生**: 强制 "worktree add 必伴 worktree-agent-* 命名 → session 结束必删"

**EPIC-302 cleanup-routine-hook** (建议):
- `scripts/retrospective-routine.sh` (EPIC-161 已存在) 的 6 阶段中, **delete 阶段加 worktree/branch 检查**
- 触发: 每次 retrospective (release / quarter / governance-debt)
- 自动: dry-run 列出 stale worktree + 未 PR 本地 branch, 主公 `--apply` 才删

### 4.3 Rule 升级建议

- **[[feedback-worktree-isolation]]** 步骤5-6 升级为硬约束:
  - 当前: "after merge: cleanup"
  - 建议: "after worktree-add: 注册到 `.claude/state/worktree-registry.json`; after session-end: 校验孤儿 → 主公收到告警"
- **新增 `feedback-worktree-add-debt-tracking`**:
  - 每次 `git worktree add` 必带 git note (`git notes add -m "created_at=... agent=... ticket=..."`)
  - retrospective 阶段扫所有 git note, 找出 > 7d 未 prune 的 worktree

---

## 5. 跟现有 Rule / EPIC 联动 (0 冲突)

- **[[feedback-worktree-isolation]]**: 本复盘是该 Rule 的债复盘 + 升级建议
- **[[feedback-worktree-cleanup-local-only]]**: 本次 4 批严格执行, 远程 0 触碰
- **[[feedback-check-origin-before-numbering]]**: 关联 — 清理前先 ff miao 是前置 (本轮已做)
- **EPIC-224 hook 体系失效修复**: 因果链上游, 本债"清理无 gate"是下游
- **EPIC-227 worktree-hook fix**: 修 KALLAX_ROOT 解析, 跟本债"worktree 内 hook 检测不到"是同一谱
- **EPIC-229 testing 分支恢复**: 历史教训, 怕大规模清理的根因之一
- **EPIC-161 retrospective routine**: 后续 EPIC-301/302 应纳入 retrospective 触发器
- **EPIC-196/199/205**: 历次清理基线, 本复盘是它们的债总账

---

## 6. 0 改 source code / 0 触 immutable / 0 增 Rule (本复盘)

- 0 source code change (纯 retrospective docs + ops)
- 0 immutable script 触碰
- 0 Rule 改动
- 0 新 gate
- 0 sprint-metrics 改动

后续 EPIC-301/302 才涉及新 script + 新 gate, 走 Rule 35 + EPIC-207 4-PR 流程.

---

## 7. Reviewer

- 主公 (2026-08-28 拍板"扩大检查范围", 引爆本复盘)
- master (执行 4 批清理 + 起草本复盘)
- EPIC-224 (hook 体系失效债源)
- EPIC-227 (worktree KALLAX_ROOT 修复)
- EPIC-229 (testing 分支恢复 + 治理债恐惧源)
- EPIC-161 (retrospective routine, 后续 EPIC-301/302 的承载器)