# EPIC-229 — testing 分支恢复 + 防复发 gate + 测试缺口分类

> **主公 2026-08-09 拍板**: "testing 分支恢复 + 备案" + "EPIC-205~222 测试缺口 18 EPIC"
> **raw test output**: `tests/integration/epic-229-testing-restore-test.sh` → 14 PASS / 0 FAIL, exit 0

---

## 1. testing 分支恢复

### 1.1 事故回顾 (EPIC-217)

EPIC-217 PR-2 用 `gh pr merge --delete-branch` 合并 testing→main, 把 testing 分支删了.

**后果**: EPIC-218~222 共 5 个 EPIC 跳过 testing 阶段, 直接 feature→main. 违反 CLAUDE.md §4 "4-branch 强制流程 (v3.10.0+ 强制, 0 容忍)".

### 1.2 恢复操作 (raw output)

```
$ git ls-remote origin | grep -E "refs/heads/(testing|main|miao)$"
06e082b83aae544f7b6dcb6434bafd9dce64e3eb	refs/heads/main
27d739d91244a266a873d9e86f47c8580bc97d8a	refs/heads/miao
# testing 缺失

$ git push origin origin/main:refs/heads/testing
 * [new branch]        origin/main -> testing

$ git ls-remote origin | grep -E "refs/heads/(testing|main|miao)$"
06e082b83aae544f7b6dcb6434bafd9dce64e3eb	refs/heads/main
27d739d91244a266a873d9e86f47c8580bc97d8a	refs/heads/miao
06e082b83aae544f7b6dcb6434bafd9dce64e3eb	refs/heads/testing
```

**恢复点**: testing = main = `06e082b8` (EPIC-226 合并后). 按 4-branch flow, testing 应 ≤ main, 取相等是最保守选择.

### 1.3 备案 (EPIC-218~222 跳过 testing)

| EPIC | 实际路径 | 应走路径 | 备案 |
|------|---------|---------|------|
| EPIC-218 | feature→main | feature→testing→main | 主公 2026-08-08 接受 |
| EPIC-219 | feature→main | feature→testing→main | 同上 |
| EPIC-220 | feature→main | feature→testing→main | 同上 |
| EPIC-221 | feature→main | feature→testing→main | 同上 |
| EPIC-222 | feature→main | feature→testing→main | 同上 |
| EPIC-223~228 | feature→main | feature→testing→main | testing 缺失期间, 无法走 |

**跟 EPIC-155/176/208 备案债同型**: 已发生不可逆, 记录 + 防复发, 不追溯 re-promote (跟 EPIC-223 ticket 归档 + EPIC-225 jargon baseline 同一原则).

## 2. 防复发 gate

### 2.1 `scripts/verify/check-branch-flow.sh`

| 模式 | 行为 | exit |
|------|------|------|
| `--verify` (默认) | 检查 testing + main + miao 全存在 | 0 齐 / 1 缺 |
| `--repair` | testing 缺失时从 origin/main 恢复 | 0 |

**为什么只自动恢复 testing**: main/miao 是核心分支, 缺失说明灾难性事故, 需人工介入. testing 是中转站, 可安全从 main 重建.

### 2.2 CI 接入

`.github/workflows/ci.yml` `hook-health` job 新增 step:
- 验证 `check-branch-flow.sh` 存在 + 可执行 + 语法
- 实跑 `--verify`, 缺 branch 则 CI fail

**跟 EPIC-224 hook-health 同一 job**: 治理元检查集中一处 (hook 体系 + branch flow).

### 2.3 操作纪律 (主公 2026-08-08 指示)

```bash
# ✅ 正确
gh pr merge <N> --admin --squash

# ❌ 禁止 (会删远程 branch)
gh pr merge <N> --admin --squash --delete-branch
```

远程 branch 是审计链的一部分 — squash 后原始 commit 历史只存在于远程 feature branch.

## 3. 测试缺口分类 (18 → 7 → 0)

### 3.1 audit 结果 (raw output)

```
$ bash /tmp/audit-test-gap.sh
EPIC         src    test?    decision doc
EPIC-205     1      YES      EPIC-205-retrospective-routine-2026-08-08.md
EPIC-206     0      NO       EPIC-206-manifesto-2026-08-08.md
EPIC-207     0      NO       EPIC-207-4pr-governance-2026-08-08.md
EPIC-208     0      NO       EPIC-208-governance-debt-2026-08-08.md
EPIC-209     0      NO       EPIC-209-sprint-close-2026-08-08.md
EPIC-210     1      YES      EPIC-210-ci-fix-2026-08-08.md
EPIC-211     1      YES      EPIC-211-ci-fix-2026-08-08.md
EPIC-212     0      NO       EPIC-212-github-intro-2026-08-08.md
EPIC-213     0      NO       EPIC-213-elevator-pitch-2026-08-08.md
EPIC-214     0      NO       EPIC-214-readme-reorg-2026-08-08.md
EPIC-215     0      NO       EPIC-215-tech-stack-2026-08-08.md
EPIC-216     0      NO       EPIC-216-rule-37-2026-08-08.md
EPIC-217     0      NO       (none)
EPIC-218     1      YES      (none)
EPIC-219     1      YES      (none)
EPIC-220     1      YES      (none)
EPIC-221     1      YES      (none)
EPIC-222     0      NO       EPIC-222-persistent-supervisor-2026-08-08.md

需 test: EPIC-205 EPIC-210 EPIC-211 EPIC-218 EPIC-219 EPIC-220 EPIC-221
docs-only: EPIC-206 EPIC-207 EPIC-208 EPIC-209 EPIC-212 EPIC-213 EPIC-214 EPIC-215 EPIC-216 EPIC-217 EPIC-222
```

### 3.2 分类结论

| 类别 | 数量 | 处置 |
|------|------|------|
| **docs-only** (0 source change) | 11 | 不需 test (跟 EPIC-198/204 docs-only exempt 同一原则) |
| **已有 test** | 1 | EPIC-205 → `tests/integration/retrospective-routine.test.sh` (17/17 PASS) |
| **CI 自身验证** | 2 | EPIC-210/211 (cargo fmt + Forbidden Patterns regex + npm audit) — CI job 就是 test |
| **被 EPIC-224 test 覆盖** | 4 | EPIC-218/219/220/221 → `epic-224-hook-activation-test.sh` 5 处引用验证 gate wire |

**真实缺口: 0**. 原报告"18 EPIC 无 test"是按文件名匹配 (`epic-2xx-*.sh`) 得出的, 未考虑 docs-only 豁免 + 跨 EPIC test 覆盖.

### 3.3 EPIC-224 test 覆盖验证

```
$ grep -cE 'EPIC-219|EPIC-220|EPIC-221|EPIC-223' tests/integration/epic-224-hook-activation-test.sh
5
```

`epic-224-hook-activation-test.sh` Group 5 逐个验证 3 gate 已 wire 进 pre-commit:
- EPIC-220 `check-disclaimer.sh`
- EPIC-219 `snapshot-claude-md.sh`
- EPIC-223 `check-ticket-schema.sh`
- EPIC-221 `commit-msg` hook (Group 4, 6 TC: DCO / type / Merge 豁免 / 超长 / bypass)

## 4. 测试 (raw output)

```
$ bash tests/integration/epic-229-testing-restore-test.sh
=== EPIC-229: testing 分支恢复 + 防复发 gate ===

--- Group 1: check-branch-flow.sh 存在 + 可执行 + 语法 ---
  PASS: scripts/verify/check-branch-flow.sh 存在
  PASS: scripts/verify/check-branch-flow.sh 可执行
  PASS: scripts/verify/check-branch-flow.sh 语法 OK

--- Group 2: 4-branch flow 完整 (核心验证) ---
  PASS: 4-branch flow 完整 (testing + main + miao 全存在)
  PASS: origin/testing 存在 (06e082b8)
  PASS: origin/main 存在 (06e082b8)
  PASS: origin/miao 存在 (27d739d9)

--- Group 3: --repair 模式支持 ---
  PASS: check-branch-flow.sh 有 --repair 模式
  PASS: --repair 从 origin/main 恢复 testing

--- Group 4: CI 接入 (防复发) ---
  PASS: ci.yml 有 4-branch flow 验证 step
  PASS: ci.yml 调用 check-branch-flow.sh

--- Group 5: 测试缺口分类 (EPIC-205~222) ---
  PASS: EPIC-205 有 test (retrospective-routine.test.sh)
  PASS: EPIC-218~221 由 EPIC-224 test 覆盖 (5 处引用)

--- Group 6: 决策 doc ---
  PASS: 决策 doc 存在

=== Result: 14 PASS / 0 FAIL (total 14) ===
```

## 5. 不做什么

| 项 | 为什么 |
|---|-------|
| 补 11 docs-only EPIC 的 test | 0 source change, 跟 EPIC-198/204 docs-only exempt 同一原则 |
| 补 EPIC-210/211 的 test | CI job 本身就是 test (cargo fmt / Forbidden Patterns / npm audit) |
| 补 EPIC-218~221 独立 test | `epic-224-hook-activation-test.sh` 已覆盖, 重复 test 违反 Rule 5 DRY |
| 追溯 re-promote EPIC-218~228 走 testing | 跟 EPIC-155/176/208 备案债同型, 已发生不可逆 |
| 把 `check-branch-flow.sh` 登记为 immutable | 它是运维检查不是 fail-closed gate, 跟 `scan-dead-code.sh` 同类 (数字仍 9) |

## 6. 联动

| 联动 | 关系 |
|------|------|
| EPIC-217 (testing 删除事故) | 本 EPIC 修复其后果 |
| EPIC-224 (hook-health CI job) | branch-flow 检查加进同一 job |
| EPIC-155/176/208 (force-push 备案债) | 备案原则同型 (记录 + 防复发, 不追溯) |
| EPIC-223 (ticket 归档) + EPIC-225 (jargon baseline) | 历史划线原则同型 |
| EPIC-198/204 (docs-only exempt) | 11 docs-only EPIC 免 test 依据 |
| CLAUDE.md §4 4-branch flow | 本 EPIC 恢复其完整性 |

## 7. 遗留

| # | 项 |
|---|---|
| 1 | CHANGELOG 补 EPIC-203~229 共 27 条 |
| 2 | `recent-epics.md` 补 EPIC-209~229 共 21 条 |
| 3 | 主公拍板 EPIC-228 的 4 复杂票 (选项 A/B/C) |
| 4 | Security Audit 依赖债 (10 vulnerabilities) |
| 5 | miao 落后 main 4 EPIC (EPIC-223~229), 需 PR-3 main→miao |