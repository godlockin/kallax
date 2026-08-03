# KALLAX Retrospective Routine — EPIC-161

> **Reference doc** (lazy load, manual): 阶段性回顾 6 阶段 routine. 主公 2026-08-03 拍板.

## 6 阶段 (跟主公拍板顺序 1:1)

1. **retrospect** (复盘) — release 触发
2. **consolidate** (整理) — quarter 触发
3. **review-docs** (review 文档) — governance-debt 触发
4. **upgrade** (升级) — quarter 触发
5. **archive** (归档) — governance-debt 触发
6. **delete** (删除) — governance-debt 触发

## Usage

```bash
# Dry-run (default, fail-safe)
scripts/retrospective-routine.sh

# Apply (实际执行)
scripts/retrospective-routine.sh --apply

# 部分跑
scripts/retrospective-routine.sh --stages=retrospect,archive

# Trigger mode
scripts/retrospective-routine.sh --phase=release
scripts/retrospective-routine.sh --phase=quarter
scripts/retrospective-routine.sh --phase=governance-debt

# JSON 输出
scripts/retrospective-routine.sh --json
```

## 跟 Post-Process 11 步骤 1:1 互补

| 触发 | EPIC | Routine |
|------|------|---------|
| EPIC/Sprint 完成 | EPIC-059-E Post-Process 11 步骤 | 自动 |
| 阶段 / 季度 / 治理债 threshold | **EPIC-161 Retrospective Routine** | manual / schedule |

## 6 阶段详细 (Stage function)

| Stage | 检测内容 | 工具 |
|-------|----------|------|
| 1. retrospect | CHANGELOG.md 最近 10 release | `grep "^## \["` |
| 2. consolidate | CLAUDE.md 行数 (≤ 200 Anthropic 硬阈值), duplicate files, _archived/ size | `wc -l`, `find` |
| 3. review-docs | .claude/rules/, docs/reference/, confluence/decisions/ count + paths: frontmatter check | `find`, `grep` |
| 4. upgrade | node/rustc version, Cargo.toml/package.json version, install.sh --inventory | `node --version`, `jq` |
| 5. archive | DEPRECATED/ABANDONED markers, _archived/ dir | `grep -E "DEPRECATED|ABANDONED"` |
| 6. delete | 0-byte files, scan-dead-code.sh exit | `find -size 0`, `scripts/scan-dead-code.sh` |

## Reference

- EPIC-161 ticket: `jira/tickets/EPIC-161/`
- `.claude/rules/retrospective.md` (path-scoped)
- Tests: `bash tests/integration/retrospective-routine.test.sh` (17/17 PASS)
- Inventory: `bash scripts/retrospective-routine.sh --json`
- 跟 EPIC-059-E Post-Process 兼容 (Case 6 test PASS)