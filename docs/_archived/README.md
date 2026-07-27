# docs/_archived Index

> **历史归档目录**: 33 file, 占 KALLAX docs 总数 17%, 归档的目的:
> 1. **未来读者**看 docs/ 时不被 v3.0-v3.27 时代 outdated 内容干扰
> 2. **不丢历史** — git log 仍可追踪每个 file
> 3. **新加入者**只看 active docs (root + subdir), 有需要的进 archived

## Last Active

| Release | 最后 active 状态 |
|---|---|
| v3.5.0 | docs/KARPATHY-VS-KALLAX-*, RTK-CAVEMAN-* 等 release-specific doc 归档 |
| v3.5.0 | docs/V350-ARCH-DELTA, V350-RELEASE release-specific schema |
| v3.5.0-v3.27.0 | phase-index / phase-review 是 Phase 评审索引 (expiry 后用 confluence/decisions/) |
| v3.27.0 | docs/architecture/_DEPRECATED + _index.md 旧 3-tier mark |
| v3.27.0 | docs/decisions/epic-132-dead-module-* (Phase A-G 后已经全收) |
| v3.x + 旧 plan | docs/superpowers/_archived (superpowers-pre-archive/) — 旧 plan/spec |

## Active Replacement

| Archived file | Active Replacement |
|---|---|
| `phase-index.md` (v3.22-3.27) | NONE (replaced by `confluence/decisions/`) — confluence/decisions/index.md 是 active |
| `phase-review.md` | (同上) |
| `RELEASE-INDEX.md` (v3.1-v3.5) | `confluence/decisions/release-automation-2026-07-20.md` 然后 archived by v3.31 trim — **整个 v3.x release 索引现在 needed 新 INDEX** (`confluence/decisions/index.md` 含全部 release doc, v3.31.0+ 看 GitHub release tab 直接) |
| `KARPATHY-VS-KALLAX-2026-06-27.md` | NONE (v3.5 era 反思一次性, 跟 KALLAX v3.31 已 drift) |
| `RTK-CAVEMAN-KALLAX-2026-06-29.md` | NONE (实验原型结果, v3.2 stable 后功能进 docs/token-economy.md) |
| `V350-ARCH-DELTA.md` / `V350-RELEASE-2026-06-30.md` | NONE (v3.5 spec 已 superseded) |
| `decisions/epic-132-dead-module-fixup-*.md` | NONE (5-Level Verify 现在 ref docs/reference/5-level-verify-harden.md) |
| `architecture/_DEPRECATED.md` / `_index.md` | NONE (info-only files, 占位 metadata) |
| `superpowers/_archived/**` | v2.6-v3.7 era plan/spec, 多数已 superseded by confluence/decisions/ 或 v3.x process/* doc. **仅历史参考** |
| `EPIC-113-A-and-EPIC-114-lessons-2026-07-11.md` (and 9 more EPIC retros) | NONE (lessons are merged into confluence/memory/layers.md + confluence/research/eket-borrow-methodology-2026-06-07.md) |
| `retrospective-v3.22.0 to v3.27.0` (5 files) | NONE (superceded by canary-chain pattern doc 跟 confluence/decisions/borrow-from-cindy-2026-07-26.md + fact-forcing-independent-repro-2026-07-26.md) |
| `branch-flow-governance-2026-07-09.md` / `branch-recovery-2026-07-20.md` / `branch-sync-2026-07-20.md` | `docs/reference/branch-flow-history.md` (v3.31.0 trim EPIC-154 落地) |
| `release-automation-2026-07-20.md` | NONE (already in confluence/decisions/) |
| `TODO-backlog-2026-07-19.md` | NONE (closeout, 已 replaced) |
| `epic-130-to-133-journey.md` + `epic-131-ts-strict-lessons-2026-07-20.md` + `epic-133-worktree-fix.md` + `epic-135-a-guided-research.md` | NONE (v3.28 era, EPIC 可以追溯 via git history) |
| `EPIC-117-simplicity-2026-07-14.md` ~ `EPIC-124-design-2026-07-18.md` (8 files) | NONE (v3.27 epic lessons captured in confluence/research/eket-surpass-strategy-2026-06-07.md) |
| `pitfalls/async-test-leak.md`, `conductor-single-point-failure.md`, `context-explosion.md`, `hallucination-deviation-log.md`, `epic-016-postmortem-2026-06-07.md`, `review-016-postresult-hang-2026-06-07.md` | NONE (v3.0-v3.7 era pitfalls, 已 7 release stable + 新 lessons 在 confluence/decisions/) |

## Use Cases

**未来加入**:
- 看 KALLAX docs/ 顶部目录 → 只看到 active docs (e.g. README/AGENTS/PROTOCOL etc.), 立刻 navigation
- 找历史 lesson → `docs/_archived/` + `confluence/_archived/` + `confluence/decisions/`

**Debug 历史 incident**:
- `git log --follow docs/_archived/file.md` 看历史 commit line

## 不动 guard

- **本目录的所有 file 仅 `git mv` 不编辑** (`docs/_archived/` 跟 `confluence/_archived/` 同样)
- 如果要 reference 历史某 file: `docs/_archived/PATH/TO/FILE.md` 或 `git log -p -- PATH/TO/FILE.md`
- 真正 important 内容已 extract 到 permanent docs (root CLAUDE.md / docs/reference/* / confluence/decisions/index.md), 历史仅补充
