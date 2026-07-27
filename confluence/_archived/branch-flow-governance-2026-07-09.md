# KALLAX Branch Flow Governance (EPIC-074)

> **起源**: 项目负责人 2026-07-09 提问 "有没有严格遵守 feature/xx-xx → testing → main (UAT) → miao (stable/prod) 的 PR 流程?"
> **Master 自查 (配合 v3.8.0 reviewer 同样诚实)**: ❌ v3.8.1-3.9.2 5 release 跳过 testing + main (直推 miao)
> **项目负责人拍板**: "以后用 + 上个 release 之后补 (推荐)"

## 当前状态 (2026-07-09 自查)

### 4-branch 流程 (项目负责人期望)

```
feature/xx-xx  →  testing  →  main (UAT)  →  miao (stable/prod)
   工作         UAT 验证      集成测试        稳定发布
```

### 实证 (4 branch remote state)

| Branch | 之前 | 现在 (EPIC-074 修复后) |
|--------|------|----------------------|
| `feature/*` | ❌ 5 个未推 (只本地) | ✅ 5 个推到 remote (PR 追溯 record) |
| `testing` | ⚠️ diverged (60797f4, 旧 history) | ✅ force-update 到 miao tip (0595fea) |
| `main` | ❌ 不存在 | ✅ 创建并推到 remote (0595fea) |
| `miao` | ✅ 活跃 | ✅ 维持现状 |

### v3.8.1-3.9.2 5 release PR 追溯 record

| Release | Feature branch | PR 记录 | Testing 验证 | Main 集成 | Miao 合并 |
|---------|---------------|--------|--------------|-----------|-----------|
| v3.8.1 | `feature/v3.8.1-EPIC-069` | ✅ 推到 remote | ❌ 跳过 (历史) | ❌ 跳过 (历史) | ✅ direct merge |
| v3.8.2 | `feature/v3.8.2-EPIC-070` | ✅ 推到 remote | ❌ 跳过 (历史) | ❌ 跳过 (历史) | ✅ direct merge |
| v3.9.0 | `feature/v3.9.0-EPIC-071` | ✅ 推到 remote | ❌ 跳过 (历史) | ❌ 跳过 (历史) | ✅ direct merge |
| v3.9.1 | `feature/v3.9.1-EPIC-072` | ✅ 推到 remote | ❌ 跳过 (历史) | ❌ 跳过 (历史) | ✅ direct merge |
| v3.9.2 | `feature/v3.9.2-EPIC-073` | ✅ 推到 remote | ❌ 跳过 (历史) | ❌ 跳过 (历史) | ✅ direct merge |

## 未来 release 流程 (v3.10.0+)

### 4-step 强制流程

1. **`feature/v3.X.Y-EPIC-ZZZ` 创建 worktree** (跟现状一致)
   - raw output: `git worktree add -b feature/v3.X.Y-EPIC-ZZZ .worktrees/...`

2. **`feature/*` → `testing` PR** (UAT 验证)
   - raw output: `gh pr create --base testing --head feature/v3.X.Y-EPIC-ZZZ`
   - 验证站: integration test + 5-Level Verify (新规: cargo test + vitest env)
   - 通过 → merge testing

3. **`testing` → `main` PR** (集成测试)
   - raw output: `gh pr create --base main --head testing`
   - 验证站: full e2e + decision matrix 25 cells
   - 通过 → merge main

4. **`main` → `miao` PR** (stable release)
   - raw output: `gh pr create --base miao --head main`
   - 验证站: master review + 4 sub-roles (coder/reviewer/tester/docs)
   - 通过 → merge miao + tag v3.X.Y

### 配套 hook

- 5-Level Verify L1 (git) 升级: 4-PR 全程 raw test output 引用
- check-claim-evidence.sh 拦截 "X/Y PASS" 但无 PR link 引用
- 禁止跳过 testing/main (v3.8.0 reviewer 阻塞点)

### 紧急 bypass 路径

项目负责人明确批准时:
- `git commit --no-verify` (跳过 pre-commit hook)
- `--admin` flag 跳 testing/main (1 release 0 PR 追溯)
- 禁止长期绕过或静默跳过 (由 check-claim-evidence.sh 拦截)

## Honest (未完全完整完成, 待续)

- v3.8.1-3.9.2 5 release 的 testing/main PR 记录**已追溯**(branch 推到 remote), 但实际 PR review 流程**仍跳过**
- 未来 v3.10.0+ 必须 4-PR 强制流程 (此 doc 升级为 CLAUDE.md Rule)
- TierRouter 0/1/3 tier 执行 (v3.9.0 仅 stub) — 后续 EPIC

raw output: git ls-remote origin main testing feature/v3.*-EPIC-*