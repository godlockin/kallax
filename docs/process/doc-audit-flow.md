# 三步审计流 (3-Phase Doc Audit Flow)

> **固化自**: EPIC-196 → EPIC-197 → EPIC-199 (2026-08-07, 主公拍板)
> **原则**: audit first, action second. 证据驱动，不猜。

## 概述

三步审计流用于定期审查 `docs/` + `confluence/` 所有文档的健康状况。
每步产出独立交付物，可跨 EPIC 分拆执行。

```
Phase 1: 发现 (Discovery)   → 8 类 issue 分类
Phase 2: 删除 (Deletion)    → 冗余/过时删除
Phase 3: 刷新 (Refresh)     → stale content 刷新 + 归并
```

## Phase 1: 发现

**目标**: 100% Read 覆盖，不采样。产出分类报告。

**工具**:
```bash
# 每步至少 2 个 agent 独立验证
# sha256sum 对比确认 100% 相同
find docs/ confluence/ -name '*.md' -type f -exec sha256sum {} \; | sort
```

**8 类 issue 分类**:

| # | Issue 类型 | 定义 | 处理阶段 |
|---|-----------|------|---------|
| 1 | Cross-dir 100% duplicate | 同文件不同目录 sha256 相同 | Phase 2 删除冗余 |
| 2 | Stale reference (死链接) | 引用不存在的文件 | Phase 3 刷新 |
| 3 | Outdated content | 内容过时 v3.0 时代 | Phase 3 加 DEPRECATED header |
| 4 | Wrong directory | 主题放在错误子目录 | Phase 3 git mv |
| 5 | Redundant directory | docs/* 子目录可合并到 confluence/ | Phase 3 归并 |
| 6 | Missing DEPRECATED header | `_archived/` 无 redirect | Phase 3 加 header |
| 7 | Internal reference stale | git mv 后未更新 internal refs | Phase 3 更新引用 |
| 8 | Orphan index | `_index.md` 引用了已删除文件 | Phase 3 更新索引 |

**产出**: 分类报告 → `confluence/decisions/EPIC-XXX-doc-audit-YYYY-MM-DD.md`

## Phase 2: 删除

**目标**: 删除 100% 相同文件 (sha256sum 验证)、过时文件、空目录。

**规则**:
1. **sha256sum 双重验证**: 至少 2 个 agent 独立跑 sha256sum，结果一致才能删
2. **SoT 保护**: `confluence/` 是 Single Source of Truth，`docs/` 子目录冗余 → 删 docs/ 保留 confluence/
3. **ARCHIVED 归并**: `confluence/decisions/ARCHIVED/` 中文件如果跟 `confluence/_archived/` 100% 相同 → 删 ARCHIVED/，更新 README.md redirect
4. **0 改 source code**: docs-only changes，不碰 .ts/.rs/.js/.sh

**验证**:
```bash
# 删除前: sha256sum 确认
sha256sum path/A/file.md path/B/file.md
diff -q path/A/file.md path/B/file.md

# 删除后: git show --stat 确认只删了文件
git diff --stat HEAD~1
```

**产出**: 删除 commit + test script

## Phase 3: 刷新

**目标**: 7 类操作 — git mv 归并 + DEPRECATED headers + internal refs 更新 + index 更新。

**操作类型**:

### 3a: git mv 归并
```bash
# docs/* 子目录 → confluence/ SoT
git mv docs/adr/adr-001-*.md confluence/decisions/
git mv docs/be/*.md confluence/memory/lessons/
# ... etc
```

### 3b: DEPRECATED header
`docs/_archived/` 中每个文件加 4 行 header:
```markdown
> **DEPRECATED (YYYY-MM-DD, EPIC-XXX)**: <一句话为何过时>
> **现代替代**: `<替代文件路径>` + `<替代文件路径>`
> **保留原因**: 历史 reference, 0 删 (跟 EPIC-196 v2 1:1 archive-not-delete)
```

### 3c: Internal refs 更新
```bash
# git mv 后检查 stale references
node scripts/check-internal-refs.cjs --skip-archived
# 逐条更新引用路径
```

### 3d: Internal merge
独立文件 < 50 行仅做 redirect → 合并到 parent `_index.md`，rm 原文件。

### 3e: 空目录清理
```bash
# git mv 后原目录变空，需手动 rmdir
for d in docs/adr docs/be ...; do rmdir "$d" 2>/dev/null; done
```

**验证**:
```bash
node scripts/check-internal-refs.cjs --skip-archived
# exit 0 = 0 stale refs
```

**产出**: 21 files changed (+DEPRECATED headers, +mv, +index merge)

## 工具链

| 工具 | 用途 | Phase |
|------|------|-------|
| `find ... -exec sha256sum {} \;` | 发现 100% 重复 | 1 |
| `node scripts/check-internal-refs.cjs` | 检测 stale refs | 1, 3 |
| `git mv` | 归并到 SoT | 3 |
| `git rm` | 删除冗余 | 2 |
| `rmdir` | 清理空目录 | 3 |

## 真实案例

### EPIC-196 (Phase 1): 264 文件审计
- 产出: 8 类 issue 分类报告
- 拍板: `confluence/decisions/EPIC-196-v2-retrospective-2026-08-07.md`

### EPIC-197 (Phase 2): 10 冗余删除
- 6 `confluence/pitfalls/` 跟 `confluence/_archived/` 100% 相同 → 删
- 4 `confluence/decisions/ARCHIVED/` 跟 `confluence/_archived/` 100% 相同 → 删
- 产出: `tests/integration/epic-197-doc-audit-test.sh` (6 TC)

### EPIC-199 (Phase 3): 10 mv + 7 headers
- 10 git mv docs/* → confluence/
- 7 DEPRECATED headers
- 1 internal merge `_DEPRECATED.md` → `_index.md`
- 6 internal refs 更新
- 产出: `confluence/decisions/EPIC-199-retrospective-2026-08-07.md`

## 调度

**推荐频率**: 每 10-15 EPIC 或每次重大目录结构调整后
**触发条件**: `docs/` 子目录 ≥ 8 个，或 `_archived/` 无 DEPRECATED header 文件 ≥ 3 个
**前置条件**: EPIC-198 docs-only CI exempt (PR size + CHANGELOG 不阻塞纯 docs 变更)

---

Co-Authored-By: Claude <noreply@anthropic.com>
