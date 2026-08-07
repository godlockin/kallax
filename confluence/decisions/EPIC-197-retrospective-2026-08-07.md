# EPIC-197: confluence/ + docs/ 全量审计 — Retrospective (2026-08-07)

> **补 EPIC-202-B**: EPIC-197 当初忘了写 retrospective, EPIC-202-B (Process 对抗式 review 触发) 补上。

## Metrics

| 指标 | 数值 |
|------|------|
| 文件审计 | 264 个 .md (声称 100% Read, 实际 40%, EPIC-200 §11 自补) |
| 删冗余 | 10 个文件 (sha256sum 二次验证) |
| 4-PR | testing + main + miao (PR #277-279) |
| 工作量 | 1 session (跟 4-PR wrapper 反复) |

## 4 Lessons (跟 EPIC-197 拍板记录 1:1 补充)

### 1. 100% Read 必字面 — 列出全子目录
**教训**: "100% Read 264 文件" 实际只扫 40% 子目录。`find docs/ confluence/ -name '*.md' | wc -l` 给出的数字不能代表实际覆盖率。
**应用**: future audit-first EPIC 必先 `find <dirs> -type d | sort` 列出全子目录、孙目录、根级 .md, 逐目录进扫描清单。
**后续**: EPIC-200 闭环补扫剩余 60%, 100+ 文件加 15 DEPRECATED header + 10 git mv + 1 git rm。

### 2. cross-dir 100% duplicate 检测用 sha256sum
**教训**: 10 文件删除全部 sha256sum 二次验证。`diff -q` + `sha256sum | sort` 是标配。
**应用**: future docs cleanup EPIC 用 `bash scripts/audit/check-duplicate-refs.sh` (待建) 或在脚本里加 sha256sum 校验。

### 3. Step 7 retrospective 必须有
**教训**: EPIC-197 拍板记录有, retrospective 没写。导致 EPIC-200 §11 自补时拿不到 EPIC-197 原始 metric, 需要重新跑测量。
**应用**: future EPIC 必跟 8-step flow (Step 7 retrospective), 不能跳。
**本 retro 是 EPIC-202-B 触发补写的 (Process 对抗式 review 抓到 Step 7 缺)。

### 4. CI 失败 = 阻塞
**教训**: EPIC-197 4 个 PR (#277-280 段) merge 时 check-body / check-dco / Forbidden Patterns / Security Audit 等多项 CI 失败。v3.8.0 假 PASS 复发警告 (跟 EPIC-069-D 起源同根)。
**应用**: future EPIC: PR 创建后必看 CI 全绿再触发 merge。CI 红 = 阻塞, 不能 force-push 跳过。
**修**: EPIC-198 docs-only exempt 帮EPIC-199/200/201 绕过 PR size check, 但 check-body 跟 check-dco 仍需手动 ensure。

## 跟后续 EPIC 联合

- EPIC-199: 7 DEPRECATED header + 10 git mv + internal merge
- EPIC-200: 补扫剩余目录 (60% 覆盖)
- EPIC-201: check-internal-refs 扩 scope
- EPIC-202-A: 工具代码修 (4 CRITICAL 3轮对抗 review)
- **EPIC-202-B (本)**: 补 retrospective + 流程治理修

## Rule 联合

- Rule 4 (4-branch flow): 0 跳 — 4-PR 全跑
- Rule 8 (Rule-of-500): 2 commit 超 500 行 (EPIC-197 e9a4cf39 + 6ce4abeb), Process 专家挑刺, 后续 EPIC 拆细
- Rule 9 (KPI): 数字带 raw output
- Rule 35 (Sprint 时间盒): 5 EPIC × 4 PR = 20 PR, 0 破
- Rule 36 (Sprint 北极星): NO_DATA, EPIC-202-B 触发补跑 (待修)

---

Co-Authored-By: Claude <noreply@anthropic.com>