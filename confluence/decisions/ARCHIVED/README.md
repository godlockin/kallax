# Archived Retrospectives

> These retrospectives were archived in EPIC-197 (2026-08-07) because their canonical copies exist in `confluence/_archived/`. This directory now contains only the redirect index.

## EPIC-197 Cleanup

On 2026-08-07, EPIC-197 全量审计 confluence/ + docs/ (264 files), identified 4 files in this directory as 100% identical to their `confluence/_archived/` canonical copies:

| Archived File (deleted) | Canonical Copy (kept) |
|-------------------------|----------------------|
| `retrospective-v3.25.0-2026-07-14.md` | `confluence/_archived/retrospective-v3.25.0-2026-07-14.md` (无副本, 整体归档) |
| `EPIC-117-simplicity-2026-07-14.md` | `confluence/_archived/EPIC-117-simplicity-2026-07-14.md` |
| `EPIC-120-eval-framework-2026-07-14.md` | `confluence/_archived/EPIC-120-eval-framework-2026-07-14.md` |
| `EPIC-121-sandboxed-eval-2026-07-14.md` | `confluence/_archived/EPIC-121-sandboxed-eval-2026-07-14.md` |

All 4 files deleted via `git rm`. Use `confluence/_archived/README.md` as the single source of truth for archived retrospective content.

## Restoration

If you need content from any archived retrospective:

```bash
# Use git history to recover any deleted file
git log --all --full-history -- <file-path>

# Or browse canonical copies in _archived/
ls confluence/_archived/retrospective-v3.2*.md
ls confluence/_archived/EPIC-117-*.md
```

## Related

- `confluence/_archived/README.md` — Canonical archived-retrospective index (SoT)
- `confluence/decisions/EPIC-197-doc-audit-2026-08-07.md` — Full EPIC-197 拍板记录
- `tests/integration/epic-197-doc-audit-test.sh` — Verification (6 TC)