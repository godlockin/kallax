# 5-Phase Doc Audit Flow (5 阶段文档审计流)

> **固化自**: EPIC-196 → EPIC-197 → EPIC-199 → EPIC-200 → EPIC-201 (2026-08-07, 主公拍板)
> **EPIC-202-C 修 (Architect 对抗式 review)**: 原文档写 3-Phase, 实际 5 EPIC 完整闭环.
> **原则**: audit first, action second. 证据驱动，不猜。

## 概述

5 阶段审计流用于定期审查 `docs/` + `confluence/` 所有文档的健康状况。
每步产出独立交付物，可跨 EPIC 分拆执行。

```
Phase 1: 发现 (Discovery)   → 8 类 issue 分类 (EPIC-196 + EPIC-197)
Phase 2: 删除 (Deletion)    → 冗余/过时删除 (EPIC-197 + 续)
Phase 3: 刷新 (Refresh)     → stale content 刷新 + 归并 (EPIC-199)
Phase 4: 补扫 (補 Sweep)     → 100% Read 闭环 (EPIC-200)
Phase 5: 极致扩展 (Extension) → tool scope 扩展 + DEPRECATED index (EPIC-201)
```

## Phase 1: 发现 (EPIC-196 + EPIC-197)

**目标**: 100% Read 覆盖，不采样。产出分类报告。

**工具**:
```bash
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

**产出**: `confluence/decisions/EPIC-{197,200}-doc-audit-*.md`

## Phase 2: 删除 (EPIC-197)

**目标**: 删除 100% 相同文件 (sha256sum 验证)、过时文件、空目录。

**规则**:
1. **sha256sum 双重验证**: 至少 2 个 agent 独立跑 sha256sum, 结果一致才能删
2. **SoT 保护**: `confluence/` 是 Single Source of Truth, `docs/` 子目录冗余 → 删 docs/ 保留 confluence/
3. **ARCHIVED 归并**: `confluence/decisions/ARCHIVED/` 中文件如果跟 `confluence/_archived/` 100% 相同 → 删 ARCHIVED/, 更新 README.md redirect
4. **0 改 source code**: docs-only changes, 不碰 .ts/.rs/.js/.sh

**验证**:
```bash
sha256sum path/A/file.md path/B/file.md
diff -q path/A/file.md path/B/file.md
```

**产出**: 删除 commit + test script

## Phase 3: 刷新 (EPIC-199)

**目标**: 7 类操作 — git mv 归并 + DEPRECATED headers + internal refs 更新 + index 更新。

**操作类型**:
- `git mv docs/* → confluence/` (SoT 归并)
- DEPRECATED header (4 行: DEPRECATED + 现代替代 + 保留原因)
- Internal refs 更新 (跟 git mv 同步)
- Internal merge (独立文件 < 50 行 → parent `_index.md`)
- 空目录清理 (`rmdir`)

**产出**: 21 files changed (跟 EPIC-199 1:1 pattern)

## Phase 4: 补扫 (EPIC-200)

**目标**: 100% Read 闭环 (Phase 1 漏的子目录、孙目录、根级 .md)。

**触发条件**: Phase 1 后发现 `find docs/ confluence/ -name '*.md' | wc -l` 跟实际扫描目录数不符。

**方法**:
- 4 并行 agent 扫各目录 (每 agent 一组子目录)
- 每个文件 Read 一次 + 评估 8 类 issue
- 产出 CSV-style audit report: `path|status|purpose|scope|placement|recommendation|categories`

**操作**: 跟 Phase 3 同模式 (git mv + DEPRECATED header + internal merge + internal refs).

**产出**: `confluence/decisions/EPIC-200-doc-audit-2-*.md` + retrospective + test

## Phase 5: 极致扩展 (EPIC-201)

**目标**: Phase 1-4 的工具扩展 + 索引补全。

**A. 工具 scope 扩** (`check-internal-refs.cjs`):
- 仅 .md → 加 .html / .json / .sh / .cjs / .js
- 3 pattern: markdown link / html href / json key
- 收紧 regex (避免中文/空格误报)
- web/ HTML scope 默认开
- root .json/.html 纳入

**B. DEPRECATED index** (`docs/_deprecated-index.md`):
- 列出全 DEPRECATED 文件 (跨目录)
- 1 页入口, 给 reader 全貌
- 分组统计 + 现代替代

**C. scripts/ scope (loose)**)**):
- `--scripts` flag 启 loose 模式
- 跳注释行 (避免 var assignment 误报)
- 仅作 governance-debt audit, 不参与 CI fail-fast

**产出**: `confluence/decisions/EPIC-201-audit-extension-*.md`

## 总计

- **5 个 EPIC** 闭环 (196/197/199/200/201)
- **15 PR** 全 merge (测试→main→miao 模式)
- **20+ files changed** 累计
- **22 DEPRECATED header** (跟 _deprecated-index.md)
- **0 stale ref** (含 web/ scope, 98 refs)

## 工具链 (跟 5 Phase 1:1)

| Phase | 工具 |
|------|------|
| 1, 4 | `find ... -exec sha256sum {} \;` |
| 1, 5 | `node scripts/check-internal-refs.cjs` |
| 3, 4 | `git mv` + `git rm` + `rmdir` |
| 3, 5 | `node scripts/fix-stale-links.cjs` (auto strip) |

## 真实案例

| EPIC | Phase | 工具落地 |
| | | |
|  EPIC-196 | Phase 1 audit 启动 | 264 文件审计 |
| EPIC-197 | Phase 2 删除冗余 | sha256sum 二次验证 |
| EPIC-199 | Phase 3 refresh/merge | check-internal-refs.cjs 起步 |
| EPIC-200 | Phase 4 补扫 | fix-stale-links.cjs, _deprecated-index.md |
| EPIC-201 | Phase 5 scope 扩展 | scope扩 web/, _deprecated-index.md |

## 调度

**推荐频率**: 每 10-15 EPIC 或每次重大目录结构调整后
**触发条件**: `docs/` 子目录 ≥ 8 个, 或 `_archived/` 无 DEPRECATED header 文件 ≥ 3 个
**前置条件**: EPIC-198 docs-only CI exempt (PR size + CHANGELOG 不阻塞纯 docs 变更)

## 跟 EPIC-202-A/B/C 联合

EPIC-202-A (工具代码修) + EPIC-202-B (流程治理修) + EPIC-202-C (数据/文档修) 是 EPIC-197/199/200/201 后的修 Phase。三 EPIC 都用对抗式 review (Tooling/Process/Architect+Auditor) 验证 0 CRITICAL。

---

Co-Authored-By: Claude <noreply@anthropic.com>