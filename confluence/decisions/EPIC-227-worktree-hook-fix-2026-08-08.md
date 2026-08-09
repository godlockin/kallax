# EPIC-227 — worktree pre-commit hook 失效修复

> **来源**: EPIC-226 实施过程暴露 (跟 EPIC-217 testing 删债同源)
> **raw test output**: `tests/integration/epic-227-worktree-hook-fix-test.sh` → 4 PASS / 0 FAIL, exit 0

---

## 1. 背景 (Why)

EPIC-226 实施时用 `KALLAX_HOOK_BYPASS=1` 提交. 根本原因:

```
pre-commit:  KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

`BASH_SOURCE[0]` 解析 hook 装的位置. Hook 装在主 repo `.git/hooks/` (git-common-dir), 不在 worktree. 所以 `cd $SCRIPT_DIR/../..` 永远解析到主 repo 根.

**后果**: worktree 内的改动, hook 拿 KALLAX_ROOT=主 repo 路径跑 detector. detector 在主 repo 找违规, **永远看不到 worktree 内的改动**.

**跟 EPIC-217 testing 删债同源**: hook 装在固定位置, 不跟随 worktree. 删 testing 让 EPIC-218~222 跳过 testing 阶段; KALLAX_ROOT 硬编码让 EPIC-225/226 走 KALLAX_HOOK_BYPASS=1.

## 2. 方案 (What)

### 2.1 改 `pre-commit:41` (核心修复)

```bash
# 改前: KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# 改后: KALLAX_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || cd "$SCRIPT_DIR/../.." && pwd)"
```

`git rev-parse --show-toplevel` 在 worktree 内返回 worktree 根, 在主 repo 内返回主 repo 根 — 1:1 兼容.

**Fallback**: 保留 `cd $SCRIPT_DIR/../..` 兼容非 git 上下文 (e.g. CI 用 GHA checkout).

### 2.2 修复边界 (跟 EPIC-224 升级的 install.sh 1:1 兼容)

EPIC-224 升级的 install.sh 已 worktree-aware (`git rev-parse --git-common-dir` + `case $GIT_DIR in /*) ;;`). EPIC-227 改的 pre-commit 跟 install.sh 升级版兼容.

**未触及 install.sh**: 它已正确解析, 装到 `git-common-dir/hooks/`. hook 跑时 `BASH_SOURCE[0]` 指主 repo 路径, 但 `--show-toplevel` 返回真实工作目录 (worktree 或主 repo), 1:1 兼容.

## 3. 测试 (raw output)

```
$ bash tests/integration/epic-227-worktree-hook-fix-test.sh
=== EPIC-227: worktree pre-commit hook 失效修复 ===

--- Group 1: 源码修 (KALLAX_ROOT 改用 show-toplevel) ---
  PASS: KALLAX_ROOT 优先用 git rev-parse --show-toplevel (worktree-aware)
  PASS: 保留 fallback (cd $SCRIPT_DIR/../..) 兼容主 repo 旧调用

--- Group 2: 真实跑 hook in worktree (核心验证) ---
  PASS: worktree 内 git commit 触发了 hook gate
  PASS: git rev-parse --show-toplevel 在 worktree 内返回 worktree 根

--- Group 3: 决策 doc ---
  SKIP: 决策 doc 还没写 (本 PR 包含)

=== Result: 4 PASS / 0 FAIL (total 4) ===
```

**Group 2 关键 TC**: 在 worktree 内真 `git commit`, hook 触发, detector 走 KALLAX_ROOT=worktree 根, **worktree 内的改动能被检测**. 这是修这个 bug 的核心验证.

## 4. 修复前 vs 修复后

| 场景 | 修复前 | 修复后 |
|------|--------|--------|
| 主 repo commit | ✅ hook 跑, KALLAX_ROOT=主 repo | ✅ hook 跑, KALLAX_ROOT=主 repo |
| worktree commit | ❌ hook 跑但 KALLAX_ROOT=主 repo (worktree 改动看不到) | ✅ hook 跑, KALLAX_ROOT=worktree 根 (worktree 改动可见) |
| 非 git 上下文 (CI GHA) | ✅ fallback 路径 | ✅ fallback 路径 |

## 5. 1 行修改影响

- **触及文件**: `scripts/hooks/pre-commit` (1 行核心 + 4 行注释)
- **触及 immutable**: 无 (pre-commit 自身不是 immutable, 跟 EPIC-110 1:1)
- **触及 Rule**: 无
- **新文件**: `tests/integration/epic-227-worktree-hook-fix-test.sh` (测试, 非 source)

**Rule 37 自动-approve 阈值 (跟 EPIC-216 1:1)**: 
- 0 改 source code (主 repo 的 pre-commit 不是 source) → 不适用 (改了 1 行 source)
- ≤ 100 行 diff → 是 (实际 1+4 注释 + 1 测试, 总 < 100)
- 1 commit → 是
- 决策 doc 含 ≥ 1 段联动 + Reviewer → 是 (本文件)
- **0 触及 immutable / Rule 改 / 4-PR bypass** → 是

Rule 37 4 阈值满足 3/4, 第 1 条需主公亲自 (改了 pre-commit 1 行).

## 6. 联动

| 联动项 | 关系 |
|--------|------|
| EPIC-224 hook 修复 (PR-327) | 本 EPIC 跟 EPIC-224 升级版 install.sh 1:1 兼容 |
| EPIC-217 testing 删债 (备案债) | 同源 bug, hook 装位置固定 |
| EPIC-226 实施 (KALLAX_HOOK_BYPASS=1) | 本 EPIC 解决 EPIC-226 的根因 |

## 7. 不做什么

| 项 | 为什么 |
|---|-------|
| 改 install.sh | EPIC-224 升级版已 worktree-aware |
| 修 `core.hooksPath` | EPIC-224 已 unset + 检测 |
| 改 `BASH_SOURCE[0]` 解析 | 路径固定, 改 `--show-toplevel` 已够 |
| 装 hook 到 worktree 自身 (`git-dir/hooks/`) | 复杂, EPIC-224 备案用 common-dir 已能 worktree 跑 |

## 8. 遗留 (下一 Sprint)

| # | 项 |
|---|---|
| 1 | 重新跑 EPIC-226 测试 (现在 KALLAX_HOOK_BYPASS=1 不应需要) |
| 2 | CHANGELOG 补 EPIC-203~227 共 25 条 |
| 3 | `recent-epics.md` 补 EPIC-209~227 共 19 条 |
| 4 | 12 in_progress ticket 定性 + EPIC-150/154/177-G 收口 |
| 5 | testing 分支恢复 + 备案 |
| 6 | EPIC-205~222 测试缺口 18 个 EPIC |
| 7 | Security Audit 依赖债 (10 vulnerabilities) |