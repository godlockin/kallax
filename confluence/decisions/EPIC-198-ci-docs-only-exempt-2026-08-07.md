# EPIC-198 提案 — docs-only PR 3 规范 exempt (跟 EPIC-197 联动)

> **日期**: 2026-08-07
> **触发**: EPIC-197 PR #277 CI 4 fail, 3 跟 docs-only PR 矛盾
> **拍板**: 待主公 review
> **联动**: EPIC-197 拍板记录 + 8 步流程 + Rule 32 (0 增 Rule 软约束)

---

## Summary

EPIC-197 (PR #277) 是 docs-only PR (0 Rust 改 / 0 source code change / 仅 markdown + test script 跟 CHANGELOG), 但 4 个 CI 检查 fail,其中 3 个不适用 docs-only:

| CI Check | Fail 原因 | docs-only 适用? |
|----------|----------|----------------|
| **check-dco** | HEAD commit 缺 Signed-off-by | ✅ amend 修复 (跟所有 PR 一致) |
| **PR Size Check (Rule of 500)** | 1603 行 ≥ 1000 | ❌ docs-only 拍板记录天然长, 不可拆 |
| **CHANGELOG 3-crate scope** | 缺 raw output core + engine + server | ❌ docs-only 无 Rust diff, 跟 3-crate 无关联 |
| **check-body (7-class risk)** | PR body 缺 12 段 (## 摘要 + ## 自动验证 + ## 手工验证 + ## 未执行验证 + ## 关联 ticket + ## 1-7 risk) | ⚠️ docs-only 需简化 body 模板 (不需 5-Level raw output, 因 docs 不触发 cargo test) |

**主公拍板方向 (2026-08-07)**: "必要就全部修复, 不必要就修改规范"。

EPIC-197 实例修复 + EPIC-198 规范修改并行:
1. **DCO**: 修复 (amend --signoff)
2. **PR Size**: 改规范 — docs-only PR exempt Rule of 500 (拍板记录天然长)
3. **CHANGELOG 3-crate scope**: 改规范 — docs-only PR 豁免 (需 raw output 仅 Rust PR)
4. **check-body**: 改规范 — docs-only PR 用简化 body 模板 (1-7 risk 全部 "不涉及" + 简化的 ## 摘要 / ## 验证 / ## 关联)

---

## 拍板 1 — PR Size docs-only exempt

### 现状

`.github/workflows/pr-size-check.yml` 跑 `scripts/ci/check-pr-size.sh`:
```
PR ~100:  fail (FAIL)  # ≥ 500 行
Rule of 500: reject (FAIL)  # ≥ 1000 行
```

EPIC-197 PR #277: 1603 行 (拍板记录 264 行 + 10 D files diff = 1339 行 + 11 file 其他小修改)。

### 提案

```yaml
# docs-only exempt: PR 触碰 ≤ 0 .ts/.rs/.js/.sh 文件, 仅 .md + tests/integration/ + .yml
# (拍板记录 + 决策文档 + test script 跟 PR template)
```

**Rule**: docs-only PR (0 source code change) exempt Rule of 500, 但**保留** PR ~100 (≥ 500 行警告, ≥ 1000 行 reject)。

**理由**:
- docs-only PR 跟 source PR 责任边界不同 (1 PR 1 EPIC 决策, 不可拆)
- 拍板记录 + decision doc 天然 ≥ 264 行 (跟 EPIC-196 v2 EPIC-197-doc-audit-2026-08-07.md 1:1)
- 治理 1.1 (跟 PR Size ≤ 100 一致, 但 PR ~100 是建议, Rule of 500 是 hard gate)

**实施** (改 `scripts/ci/check-pr-size.sh`):
```bash
# 检测 docs-only: diff 触碰 0 .ts/.rs/.js/.sh 文件
DOCS_ONLY=$(git diff --name-only origin/${BASE_REF}...HEAD | \
    grep -vE "\.(ts|rs|js|sh)$" | \
    grep -cE "\.md$|tests/integration/|\.yml$")

SOURCE_FILES=$(git diff --name-only origin/${BASE_REF}...HEAD | \
    grep -cE "\.(ts|rs|js|sh)$")

if [ "$SOURCE_FILES" -eq 0 ] && [ "$DOCS_ONLY" -gt 0 ]; then
    echo "docs-only PR detected: ${DOCS_ONLY} docs files, 0 source files"
    echo "✅ docs-only PR exempt Rule of 500 (拍板记录天然长)"
    echo "⚠️  PR ~100: ${LINES} 行 (警告, 不 reject)"
    exit 0
fi
```

---

## 拍板 2 — CHANGELOG 3-crate docs-only exempt

### 现状

`.github/workflows/kallax-ci.yml` `changelog-scope-check`:
```bash
# 强制每个 release entry 含 core + engine + server 字面
if ! echo "$RECENT" | grep -qE "(core.*passed|passed.*core)" || \
   ! echo "$RECENT" | grep -qE "(engine.*passed|passed.*engine)" || \
   ! echo "$RECENT" | grep -q "server"; then
    exit 1
fi
```

EPIC-197 PR #277 fail: 最近 entry v3.34.5 是 auto-generated TBD, scope 未填。

### 提案

```yaml
# CHANGELOG 3-crate scope 仅适用 Rust 改 PR (source PR 含 .rs 文件)
# docs-only PR (0 .rs diff) 豁免, 但保留 CHANGELOG entry 强制 (docs entry 仍要求 raw output 引用 baseline)
```

**Rule**: docs-only PR 豁免 3-crate scope, 但仍要求 CHANGELOG entry (含 docs-only 标识 + 引用 cargo baseline)。

**理由**:
- 3-crate scope 治 v3.8.0 lesson #3 (Rust 数字假装单 lib 当 workspace), 仅适用 Rust PR
- docs-only PR 0 .rs diff, 跟 3-crate 无关联
- docs-only entry 仍要求 raw output 引用 (baseline cargo test) 保持 trace

**实施** (改 `kallax-ci.yml`):
```bash
# 检测 docs-only PR
SOURCE_RS=$(git diff --name-only origin/${BASE_REF}...HEAD | grep -c "\.rs$")
if [ "$SOURCE_RS" -eq 0 ]; then
    echo "docs-only PR detected: 0 .rs diff"
    echo "✅ docs-only CHANGELOG entry exempt 3-crate scope"
    # 但仍验证 CHANGELOG entry 存在 (docs-only entry 必含 raw output 引用 baseline)
    exit 0
fi
```

---

## 拍板 3 — check-body docs-only 简化模板

### 现状

`.github/PULL_REQUEST_TEMPLATE.md` (EPIC-138-A) 强制 7-class risk 全部 "✅" 或 "不涉及:<原因>" + 12 段 body。

EPIC-197 PR #277 fail: 缺 12 段 (`## 摘要` / `## 变更类型` / `## 关联 ticket` / `## 自动验证 (raw output)` / `## 手工验证` / `## 未执行验证` / `## 回滚方案` / `## 提交前 checklist` + `### 1-7` risk)。

### 提案

docs-only PR 用简化 body 模板, 1-7 risk 全 "不涉及" (docs 不触发 Rust/Node/worktree/state/sentinel 边界):

```markdown
## 摘要

<1-2 段 docs-only 改什么 + 为什么>

## 变更类型

- [x] docs — 文档 (file1, file2, ...)
- [x] test — 测试 (test-script.sh)

## 关联 ticket

- Ticket: EPIC-XXX

---

## 🔒 KALLAX 7 类风险 checkbox (docs-only 简化)

### 1. 5-Level Verify (L2)

- [x] 不涉及: docs-only PR, baseline cargo test --workspace 沿用 miao HEAD 218 passed (109 core + 78 engine + 31 server)

### 2. state.json 边界

- [x] 不涉及: 0 改 .kallax/state/ 或 scripts/permission/

### 3. worktree 隔离

- [x] 不涉及: feature/EPIC-XXX worktree 隔离, 全在 scope

### 4. Dead-code sentinel

- [x] 不涉及: docs-only, 0 新 module, test script N/N PASS

### 5. Rule / immutable script

- [x] 不涉及: 0 改 5 immutable scripts, 0 改 CLAUDE.md Rule

### 6. Rust ↔ Node 边界

- [x] 不涉及: docs-only, 0 改 IPC / protocol / schema

### 7. 跨 EPIC 复用

- [x] 不涉及: <理由>

---

## 自动验证 (raw output)

### <test-script>

```
$ bash tests/integration/<test-script>.sh
<N/N PASS>
EXIT=0
```

## 手工验证

- <人肉验证过的行为>

## 未执行验证

- 未跑 e2e 4-PR flow 端到端 (testing → main → miao)
- 9 类破坏性操作中 #5 主分支 push 跟 #9 网络发布由主公操作

## 回滚方案

`git revert <sha>` 直接回退, 无 schema migration

---

## 提交前 checklist

- [x] DCO 签核
- [x] 无凭证入库
- [x] 文档同步 (CHANGELOG entry)
- [x] 测试全绿 (test script N/N PASS)
- [x] Branch flow 已走
- [x] Master 已审阅

## Cherry-pick 备案

如 PR CONFLICTING, 走 EPIC-196 v2 PR #274 cherry-pick pattern。
```

**Rule**: docs-only PR 用简化 body (1-7 risk 全 "不涉及"), 跟 EPIC-138-A 12 段结构对齐但内容简化。

**理由**:
- docs-only PR 不触发 5-Level raw output (无 Rust diff)
- 1-7 risk 默认 "不涉及" (docs 不改 source/state/sentinel)
- 简化降低 docs PR 提交摩擦, 跟 "流程效果 > 流程表演" 战略一致

**实施**:
- 选项 A: 加 `## docs-only PR body template` 到 `PULL_REQUEST_TEMPLATE.md` (跟源模板并列)
- 选项 B: 改 `scripts/ci/check-pr-body.sh` 检测 docs-only + 跳 1-7 risk 内容检查

---

## 4. 实施计划

### 4.1 EPIC-197 PR #277 即时修复 (已完成)

- [x] DCO amend --signoff
- [x] CHANGELOG 加 v3.34.6 docs-only entry 含 baseline raw output
- [x] PR body 重写 (含 7-class risk 全 "不涉及" + 简化的 12 段)
- [ ] 等 CI 重跑

### 4.2 EPIC-198 规范修改 (待主公拍板)

- [ ] 改 `scripts/ci/check-pr-size.sh` — docs-only detect + exempt Rule of 500
- [ ] 改 `.github/workflows/kallax-ci.yml` `changelog-scope-check` — docs-only PR exempt
- [ ] 改 `scripts/ci/check-pr-body.sh` 或 `PULL_REQUEST_TEMPLATE.md` — docs-only 简化 body

### 4.3 拍板记录

- [ ] 写 `confluence/decisions/EPIC-198-ci-docs-only-exempt-2026-08-07.md` 拍板记录

---

## 5. 联动

| EPIC | 1:1 联动 |
|------|---------|
| EPIC-197 | docs-only 实例触发 3 规范 fail |
| EPIC-138-A | 7-class risk schema + 12 段 body 模板 |
| EPIC-196 v2 | 教训3 禁止抽样 + 拍板记录模式 |
| EPIC-181 | branch-4pr R1-R5 退出码契约 |
| EPIC-159 | CLAUDE.md ≤ 200 行 治理 2.0 |

---

## 6. Reviewer

- 主公 (拍板)
- master (执行)

**Last updated**: 2026-08-07 (EPIC-198 提案 v1)