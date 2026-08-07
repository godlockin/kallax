# EPIC-199: docs/ 子目录 refresh + 归并 — Retrospective (2026-08-07)

> **跟 EPIC-197 1:1 pattern** (264 文件 audit → 10 删), EPIC-199 是 follow-through: audit 发现 refresh candidates → 执行 refresh + merge。

## Metrics

| 指标 | 数值 |
|------|------|
| 文件变更 | 21 files (+209/-43) |
| git mv | 10 docs/* → confluence/ |
| DEPRECATED headers | 7 `docs/_archived/` |
| Internal merge | 1 (`_DEPRECATED.md` → `_index.md`) |
| Internal refs updated | 6 |
| PRs | 3 (testing + main + miao) |
| 工时 | 1 session (跟 audit + EPIC-197 连续) |

## 5 Lessons

### 1. 先 audit 再 refresh — 证据驱动
**教训**: EPIC-197 audit (264 files, sha256sum 验证) → EPIC-199 refresh/merge。audit 结论是 refresh/merge 的单一证据来源。没 audit 就没法精确定位哪些文件 stale、哪些目录冗余。
**应用**: future EPIC: audit-first, action-second.

### 2. 内部引用更新是高估工作
**教训**: 10 git mv 后更新 6 处内部引用，每处都是手动 Edit。EPIC-199 中没有自动检测工具，依赖 grep + 逐条验证。
**建议**: 考虑 `scripts/check-internal-refs.sh` — 检测 stale cross-doc references.

### 3. EPIC-198 docs-only exempt 覆盖 EPIC-199
**教训**: EPIC-198 (PR size docs-only exempt) 在 EPIC-197 中落地，EPIC-199 直接受益 — 纯 docs changes 不受 Rule of 500 限制。跨 EPIC 协同验证了模式。
**应用**: docs-only 模式已固化，future docs cleanup EPIC 可直接复用。

### 4. `_DEPRECATED.md` 独立文件冗余
**教训**: `docs/architecture/_DEPRECATED.md` 33 行独立文件记录 4 个已删子文档的替代位置 — 内容 100% 可归入 `_index.md`。独立文件增加 navigation 负担。EPIC-199 将内容并入 `_index.md` §6 并 rm。
**建议**: 审查其他 `_DEPRECATED.md` / `README.md` 单文件 — 如果 < 50 行且仅做 redirect，合并到 parent `_index.md`。

### 5. 7 DEPRECATED headers = 7 历史保护
**教训**: `docs/_archived/` 中 7 个文件加了 DEPRECATED header（含现代替代 + 保留原因），确保 future reader 不会被过期内容误导。不删 = 尊重 git history，不加 header = 陷阱。
**应用**: `scripts/check-stale-content.sh` — 扫 `docs/_archived/` 检测无 DEPRECATED header 的文件。

## 跟 EPIC-197 联合

EPIC-197 (audit + delete redundant) → EPIC-199 (refresh + merge):
- 197 发现: 7 stale `_archived/` 文件需 refresh
- 197 发现: 3 docs/* 子目录冗余 (docs/adr, docs/decisions, docs/{be,expert-extension,...})
- 199 执行: 7 headers + 10 moves + 1 internal merge

## 8-step 流程位置

EPIC-199 处于 step 4 (实施) 跟 step 5 (4-PR) 交接点。
下一步 (step 6-8): PR merge → retrospective 写完 → worktree cleanup。

---

Co-Authored-By: Claude <noreply@anthropic.com>
