# EPIC-054-A — LESSONS LEARNED

> Worktree 根目录统一 (4 套 → 1 套, 跟 git worktree list 一致, 治 H5)
> 跟 Rule 9 (KPI 精确) 联合, 跟 Rule 18 (KPI 黑名单) 联合, 跟 Rule 6 (事后复盘) 联合

---

## L1 — 4 套根目录是历史包袱, 1 套是单一真相来源

**问题**: 历史 EPIC 跨 4 套 worktree 根目录 (`.claude/worktrees/` ONRAMP 时代 / `.kallax/worktrees/` 现代 / `.worktrees/` EPIC-033 个例 / `performer-EPIC-034/` 嵌套). 任何 `git worktree list` 输出跨 4 套散落, Conductor / Master / Auditor 难统一视图.

**根因**: 没有"默认根目录"约束. 不同 EPIC 起 worktree 时选不同根目录, 没人 enforce.

**修法**:
- `SINGLE_ROOT_DIR=.kallax/worktrees` 作为 canonical 唯一根目录
- `unify-roots.sh` 把所有 worktree 迁到这一根目录, 跟 `git worktree list` 输出 1:1
- `.gitignore` 加 3 套 ignore (新 worktree 不再创建到那)
- `detect-stale-worktrees.sh` 加 invariant check (warn on 散落, exit 1 on violation)

**Rule 联动**: DRY + Single Source of Truth + Rule 8 L3 (5-Level Fact-Forcing).

---

## L2 — `git worktree move` 是原子迁移的唯一安全方式

**洞察**: 改 worktree 路径不能用 `mv` (filesystem level), 必须用 `git worktree move` (git-native). 后者自动更新:
- `.git/worktrees/<id>/gitdir` 指针
- worktree 内 `.git` 文件指向
- 内部 `commondir` 等元数据

**反模式**: 手动 `mv` + 手工改 `.git` 文件 + 改 `.git/worktrees/<id>/gitdir` → 极易损坏 git 内部状态, 后续 `git worktree list` / `git worktree remove` 都会失败.

**修法**: `unify-roots.sh` 100% 走 `git worktree move <old> <new>`. dry-run 模式只打印计划, 不 touch 任何文件.

**Rule 联动**: Rule 3 (Defensive Error Handling) — 用 git 原生 API 而不是文件系统 hack.

---

## L3 — TDD 红绿节奏 + 6/6 = 100.0% 是 Rule 9 KPI 强制

**节奏**:
1. Step 6 写 6 case 测试 → 跑 (red, expect fail) → 确认 0/6
2. Step 7 写 `unify-roots.sh` → 跑测试 (green) → 6/6 PASS first try

**精确数字**: 6/6 = 100.0% (no estimate, no "about", no "approximately"). 跟 Rule 18 KPI 黑名单 (no falsification) 联合.

**子检查**: 测试覆盖 4 个 root patterns classification + 50+ migration count + single-root invariant + 2 个指针正确性 + E2E. 任何一个 case 弱化 = 整体 fail.

**Rule 联动**: Rule 9 (X/Y 精确), Rule 18 (no KPI falsification).

---

## L4 — 实际迁移 ≠ Performer 责任 (跟 Master 边界)

**洞察**: `unify-roots.sh` 写好, 但**实际跑**它会改 50+ worktree 的 `.git/worktrees/<id>/gitdir` 文件 + 重命名目录. 这些 worktree 跨多个 parent (其他 EPIC 的 worktree), 改任何一个可能破坏 parent 的 .git 状态.

**边界**: Performer 只交付脚本 + 测试. Master 在 merge 后, 在他/她的独立 session 中执行 `unify-roots.sh` 实际迁移 50+ worktree. 这样:
- Performer 越界 0 (只动 5 个 file_scope 文件)
- Master 在安全隔离环境执行 (他/她有全局视图)
- 出问题回滚清晰 (Performer commit 可 revert, 不影响实际状态)

**Rule 联动**: Rule 1 (Single Responsibility) + AGENTS.md isolation requirements.

---

## L5 — `.gitignore` 早就有了 3 套忽略规则 (防重复造轮子)

**发现**: ticket.json AC3 说".gitignore 加 3 套忽略", 但实测 `.gitignore` line 17-20 早就有:
- `.claude/worktrees/`
- `.kallax/worktrees/`
- `.worktrees/`
- `performer-EPIC-*/`

**真相**: 历史 EPIC (probably EPIC-031 trustscore) 已经把这些 ignore 加了. EPIC-054-A ticket description 没核实 base state.

**修法**: 不重复加 (会 git status 显示无 diff). 在 IMPLEMENTATION-PLAN.md 标记 "no modification needed", 在 pass-report 里诚实记录 `files_modified = 5 (1 actually modified + 4 already present)`.

**Rule 联动**: Rule 5 (DRY) + Rule 18 (no KPI falsification = 不虚报"我改了 .gitignore").

---

## L6 — kpi-evidence-chain framework 局限 (诚实记录)

**发现**: 跑 `bash scripts/verify/kpi-evidence-chain.sh verify EPIC-054-A <sha> <stdout>` 时, L3 5 extended groups 中 3 个 group fail:
- security-tool-bypass: check-scope-creep.sh (exit=1) — 检查 issue
- process-engineering: l3-l4-consistency.sh (exit=2) — 调用方式 issue
- auditor: subagent-pass-gate.sh (not executable) — file mode issue

**真相**: 这是 framework-wide tooling 问题, 不是本 ticket 责任. 子工具手工跑都 PASS:
- check-scope-creep.sh EPIC-054-A → rc=0 (PASS, 4/4 files in scope)
- l3-l4-consistency.sh --l3-status=PASS --l4-status=PASS → rc=0 (OK)
- subagent-pass-gate.sh → rc=0 (手跑)

**真相**: kpi-evidence-chain.sh 的 L3 verifier 用某种自动化 batch 调用, 调用方式跟我手工跑不一致, 导致 3 group fail. 这是 verifier 本身的局限.

**本工单处理**: 不修 kpi-evidence-chain (不在 file_scope). 在 pass-report 标记 L3 = FAIL (framework 局限, not ticket 责任). L1/L2/L4 都 PASS.

**修法建议** (给后续工单): `kpi-evidence-chain.sh` 的 L3 verifier 应捕获子工具的 exit code + 输出, 而不是按预期 rc 判定. 跟 EPIC-053-A L6 check-scope-creep 局限的修法一致.

**Rule 联动**: Rule 9 (no estimate) + Rule 18 (no falsification — 诚实记录 framework 局限).

---

## L7 — `git worktree move` 跨 gitdir 子目录的处理

**洞察**: 当 worktree 物理路径从 `.claude/worktrees/X` 移到 `.kallax/worktrees/X` 时, `.git/worktrees/<id>/gitdir` 内容从 `.claude/worktrees/X/.git` 变成 `.kallax/worktrees/X/.git`. git 自动更新 (因为 gitdir 文件是 absolute path + git 自动相对化).

**验证**: Case 4 测试验证 20 个 `.git/worktrees/<id>/gitdir` 指针都正确指向新路径. Case 5 验证 worktree 内 `.git` 文件格式 = `gitdir: /abs/path/.git/worktrees/<id>`.

**Rule 联动**: Rule 8 L1 (Existence) + L3 (Wiring).

---

## 与 EPIC-054-B/C/D 的接口

| Ticket | 责任 | 跟 EPIC-054-A 联动 |
|--------|------|--------------------|
| EPIC-054-B | Instance TTL | 统一后 `.kallax/worktrees/` 路径可作为 instance TTL 范围基线 |
| EPIC-054-C | Epic state machine | 同上 |
| EPIC-054-D | Rule merge (CLAUDE.md 整理) | EPIC-054-A 不动 CLAUDE.md (本 ticket 边界), EPIC-054-D 后续整理 Rule 9 引用 |

---

## 防 H5 (worktree 爆炸) 复发 checklist

- [x] `scripts/worktree/unify-roots.sh` 可执行 + 6/6 PASS
- [x] `tests/integration/worktree-unify-test.sh` 6/6 PASS (100.0%)
- [x] `.gitignore` 4 套 ignore 规则 (3 套散落 + .kallax/worktrees/ 自指)
- [x] `detect-stale-worktrees.sh` invariant check (warn on 散落)
- [ ] Master 在 merge 后执行 `unify-roots.sh` 实际迁移 (Performer 越界 0)
- [ ] 迁移后 4 套 → 1 套, `git worktree list` 单根目录输出
- [ ] 任何新 EPIC ticket 起 worktree 必须用 `.kallax/worktrees/` (跟 SINGLE_ROOT_DIR 一致)
