# DEPRECATED 文件索引 (EPIC-199 + EPIC-200 落地)

> **目的**: 给 reader 1 页入口 — 所有 DEPRECATED header 文件 + 现代替代, 避免看历史内容时不知道是否过时。
> **维护**: EPIC-199/200 拍板, 每次新增 DEPRECATED header 时同步追加。
> **扫描**: `grep -l "^> \*\*DEPRECATED" docs/ confluence/ -r --include="*.md"`

## DEPRECATED 文件清单 (22 个, 按目录分组)

### docs/_archived/ (7, EPIC-199)

| 文件 | 现代替代 |
|------|---------|
| `docs/_archived/KARPATHY-VS-KALLAX-2026-06-27.md` | `docs/ARCHITECTURE.md` + `confluence/decisions/kallax-timeline-2026-08-07.md` |
| `docs/_archived/phase-index.md` | `confluence/decisions/` (L1 SoT) + `confluence/memory/lessons/` (L2 lessons) |
| `docs/_archived/phase-review.md` | `confluence/decisions/workflow-8step-2026-08-07.md` (8 步流程) + `docs/process/9-hard-rules.md` |
| `docs/_archived/RELEASE-INDEX.md` | GitHub Releases (https://github.com/godlockin/kallax/releases) + `CHANGELOG.md` |
| `docs/_archived/RTK-CAVEMAN-KALLAX-2026-06-29.md` | `docs/token-economy.md` + `docs/cli-rule.md` |
| `docs/_archived/V350-ARCH-DELTA.md` | `docs/ARCHITECTURE.md` + `CHANGELOG.md` |
| `docs/_archived/V350-RELEASE-2026-06-30.md` | GitHub Releases + `CHANGELOG.md` |

### docs/architecture/online-deploy-2026-06-30/ (3, EPIC-200)

| 文件 | 现代替代 |
|------|---------|
| `docs/architecture/online-deploy-2026-06-30/P-004-DECISION.md` | `docs/ARCHITECTURE.md` §"deployment" |
| `docs/architecture/online-deploy-2026-06-30/P-004-ERRATA.md` | `docs/ARCHITECTURE.md` §"deployment" |
| `docs/architecture/online-deploy-2026-06-30/README.md` | `docs/ARCHITECTURE.md` §"deployment" + `docs/reference/installation-2026-08-03.md` |

### docs/superpowers/_archived/ + plans/ + specs/ (6, EPIC-200)

| 文件 | 现代替代 |
|------|---------|
| `docs/superpowers/_archived/plans/2026-06-28-gap6-glossary-compress.md` | `confluence/memory/glossary/glossary.md` + `docs/CHEATSHEET.md` |
| `docs/superpowers/_archived/specs/2026-06-28-gap6-glossary-compress-design.md` | `docs/CHEATSHEET.md` + `docs/5-levels.md` + `docs/4-roles.md` |
| `docs/superpowers/plans/2026-06-27-8-gap-fix.md` | `docs/ARCHITECTURE.md` + `confluence/_archived/KARPATHY-VS-KALLAX-2026-06-27.md` |
| `docs/superpowers/plans/2026-06-29-rtk-caveman-kallax-integration.md` | `docs/RTK-CAVEMAN-KALLAX-2026-06-29.md` + `docs/cli-rule.md` |
| `docs/superpowers/plans/2026-06-29-rtk-caveman-v320-kallax-integration.md` | `docs/RTK-CAVEMAN-KALLAX-2026-06-29.md` + `docs/cli-rule.md` |
| `docs/superpowers/specs/2026-06-27-8-gap-fix-design.md` | `docs/ARCHITECTURE.md` + `confluence/_archived/KARPATHY-VS-KALLAX-2026-06-27.md` |

### 根级 docs/ (5, EPIC-200)

| 文件 | 现代替代 |
|------|---------|
| `docs/KARPATHY-VS-KALLAX-2026-06-27.md` | `docs/ARCHITECTURE.md` + `confluence/decisions/kallax-timeline-2026-08-07.md` |
| `docs/RELEASE-INDEX.md` | GitHub Releases + `CHANGELOG.md` |
| `docs/RTK-CAVEMAN-KALLAX-2026-06-29.md` | `docs/token-economy.md` + `docs/cli-rule.md` |
| `docs/V350-ARCH-DELTA.md` | `docs/ARCHITECTURE.md` (主架构) |
| `docs/V350-RELEASE-2026-06-30.md` | GitHub Releases + `CHANGELOG.md` |

### confluence/ (2, EPIC-200)

| 文件 | 现代替代 |
|------|---------|
| `confluence/memory/glossary/glossary.md` | `docs/CHEATSHEET.md` + `docs/5-levels.md` + `docs/4-roles.md` |
| `confluence/decisions/EPIC-199-cleanup-refresh-move-2026-08-07.md` | (拍板记录, 本身保留作为 EPIC-199 audit trail) |

## DEPRECATED 原因分类

| 原因 | 数量 |
|------|------|
| v3.x era release doc (V310-V350) | 5 |
| v2.x era design / plan | 6 |
| 历史 glossary 压缩 (64→35) | 3 |
| v3.3.0 部署决策 | 3 |
| Karpathy gap 分析 | 2 |
| rtk+caveman 整合 | 2 |
| phase review SOP | 2 |
| 拍板记录 (保留作 audit trail) | 1 |

## 总计

- **22 个文件 DEPRECATED**
- **0 删** (跟 EPIC-196 v2 1:1 archive-not-delete)
- **0 隐** (每个文件头 4 行 header 含现代替代 + 保留原因)

## 验证

```bash
# 列出所有 DEPRECATED header 文件
grep -l "^> \*\*DEPRECATED" docs/ confluence/ -r --include="*.md" | wc -l
# 期望: 22
```

---

Co-Authored-By: Claude <noreply@anthropic.com>