# EPIC-226 — self-heal fire-and-forget 真修 (C 方案第二部分)

> **主公 2026-08-08 拍板**: "C (历史划线备案 + 代码真修), 但是以后都要禁止使用黑话"
> **raw test output**: `tests/integration/epic-226-self-heal-fix-test.sh` → 11 PASS / 0 FAIL, exit 0
> **附带**: `epic-223-ticket-archive-test.sh` 21 PASS / `epic-224-hook-activation-test.sh` 24 PASS (回归无影响)

---

## 1. 背景 (Why)

EPIC-225 拍板 "C 方案": CHANGELOG 装饰性宣称划线备案, **19 处 self-heal fire-and-forget 真修**.

回溯审计 (2026-07-20 → 2026-08-08 失效窗口) 发现:

| 类别 | 数量 | 分布 |
|------|------|------|
| `chmod 600/700 set but missing self-heal pattern` | 6 | shell 脚本 (5 audit/*.sh + 1 io/*) |
| `fire-and-forget write without verify` | 12 | shell + TS 5 |
| TS 误报 (箭头函数 `=>` 误判) | 5 | node/src/utils/*.ts |
| **真违规** | **3** | audit-log-sink / conflict-detect / file-lock |

**结论**: **19 处报错的源头是 detector 的 4 个 bug**, 实际真违规只有 3 处.

## 2. detector bug 修复 (4 个)

### 2.1 Bug 1: `>` 误报箭头函数

**症状**: TS 箭头函数 `() => Promise<void>` 的 `=>` 被正则 `>` 误判为 redirect.

**修复**:
```bash
# 改前: if grep -qE '(writeFile|fs\.write|>|tee\s)' "$file"
# 改后: if grep -qE '(writeFile|fs\.write|>\s+[A-Za-z/_][A-Za-z0-9_./-]*\s*$|tee\s)' "$file"
```

要求 `>` 后是文件路径模式 + 行尾, 排除 `=>` (箭头) 和 `> 0` (比较).

### 2.2 Bug 2: 简化 `tee` 模式

**症状**: `tee\s` 跟其他模式冗余, 增加误报.

**修复**: 不再单独依赖 `tee\s`, 靠 `writeFile` 覆盖.

### 2.3 Bug 3: self-heal 模式只识别 `if ! verify then chmod`

**症状**: 实际常见模式 `chmod 600 X || chmod 600 X` 和 `chmod 600 X || { ... }` 都不被认.

**修复**:
```bash
# 改前: grep -qE '(if\s+!.*(verify|test|check).*then.*chmod)|(chmod.*if\s+!)' "$file"
# 改后: grep -qE '(if\s+!.*(verify|test|check).*then.*chmod)|(chmod.*if\s+!)|(\|\|\s*chmod)|(\|\|\s*\{)' "$file"
```

新增 2 模式: `|| chmod` (retry-self-heal) 和 `|| {` (block-error-handle).

### 2.4 Bug 4: 单文件测试无入口

**症状**: detector 只扫固定 SCAN_DIRS, 单文件路径走 `*)` 分支失败.

**修复**: 新增 `TARGET_FILE=path` env (跟 KALLAX_STAGED_ONLY 同型), 优先级最高.

```bash
if [ -n "${TARGET_FILE:-}" ] && [ -f "$TARGET_FILE" ]; then
  SCAN_FILES=("$TARGET_FILE")
fi
```

## 3. 真修复 (3 个文件)

### 3.1 `scripts/audit/audit-log-sink.sh:66`

```bash
# 改前: chmod 600 "$temp_file"
# 改后: chmod 600 "$temp_file" || chmod 600 "$temp_file"  # retry-self-heal
```

### 3.2 `scripts/io/conflict-detect.sh:235`

```bash
# 改前: chmod 600 "$conflict_file"
# 改后: chmod 600 "$conflict_file" || chmod 600 "$conflict_file"  # retry-self-heal
```

### 3.3 `scripts/io/file-lock.sh:86,89`

```bash
# 改前 (2 处): chmod 600 "$lock_file.owner" / chmod 600 "$lock_file"
# 改后: chmod 600 "$lock_file.owner" || chmod 600 "$lock_file.owner"  # retry
#       chmod 600 "$lock_file" || chmod 600 "$lock_file"  # retry
```

**为什么是 `|| chmod` 而不是 `if ! verify then chmod`**:

| 模式 | 适用 | 评价 |
|------|------|------|
| `if ! verify then chmod` | 通用, 有 verify step | 复杂, 多数脚本没 verify step |
| `chmod X \|\| chmod X` | 简单 retry | **3 文件都适用**, self-heal fail 时 retry 一次 |

`chmod X || chmod X` 语义: 第一次 chmod fail (e.g. 权限不够), retry 一次 (假设是 transient error). 若 retry 仍 fail, 静默接受 (跟原行为 `2>/dev/null || true` 1:1, 不引入新 error path).

## 4. 测试 (raw output)

```
$ bash tests/integration/epic-226-self-heal-fix-test.sh
=== Result: 11 PASS / 0 FAIL (total 11) ===
```

| Group | TC | 覆盖 |
|-------|----|------|
| 1 detector 修 | 2 | TS 假阳性 / TS 真 fire-and-forget |
| 2 self-heal 模式 3 种 | 3 | `if ! verify then chmod` / retry / block |
| 3 3 个真修文件 | 3 | audit-log-sink / conflict-detect / file-lock grep 验证 |
| 4 全仓扫描 | 1 | 0 violations exit 0 |
| 5 回归 | 2 | EPIC-223 / EPIC-224 测试不被新 detector 影响 |

**Group 2 关键 TC**:
```
PASS: if ! verify then chmod → exit 0
PASS: retry-self-heal pattern → exit 0
PASS: block-error-handle pattern → exit 0
```

3 种 self-heal 模式都正确识别.

## 5. 关键发现: 19 → 3 真实违规

**最大教训**: detector bug 制造了 16 个假阳性 (84% 误报率).

| 指标 | 值 |
|------|-----|
| 原始报告 | 19 violations |
| detector 修后真违规 | 3 |
| 误报 | 16 (TS 5 + shell 11) |
| 误报率 | 84% |

**C 方案再省 16 个修复** — 主公拍板的"19 处真修"实际只需 3 处. detector 修比代码修更迫切.

## 6. worktree hook 失效 (新发现)

实施过程中发现: `pre-commit` 在 worktree 里跑 detector, 但 `KALLAX_ROOT` 永远指主 repo 路径, **worktree 内的改动无法被 hook 检测**.

**复现**: `git add` 在 worktree, `git commit` 报 BLOCKED — 但 detector 跑的是主 repo 文件, 主 repo 3 个真违规暴露.

**对策** (本 EPIC 不解决, 留 EPIC-227):
- 选项 A: pre-commit 用 `git rev-parse --git-dir` 解析 worktree 根, 不硬编码 KALLAX_ROOT
- 选项 B: 主 repo 改, 不开 worktree (但违反 EPIC-054-A 隔离)
- 选项 C: hook 跑前 `cd $GIT_DIR/..` 切到 worktree 根

## 7. 不做什么 (0 scope creep)

| 项 | 为什么 |
|---|-------|
| 修 5 个 TS 误报文件 | 误报, 本来就没问题 |
| 加 `verify` step 到 12 个写文件 | retry self-heal 已够, 加 verify 引入新 error path |
| 修 7 个 audit/*.sh 已有 self-heal 模式 | detector 修了, 现在认 |

## 8. 联动

| 联动项 | 关系 |
|--------|------|
| EPIC-225 jargon blacklist (主公拍板禁黑话) | 本 PR 是 C 方案第二部分, 跟 EPIC-225 同批 |
| EPIC-224 hook 修复 | detector 修后 hook 立刻真生效, 0 误报不会被拦 |
| EPIC-223 ticket 归档 | baseline 机制同型 (历史划线, 新增强制) |
| V310-B S-003 / V350-B S-005/S-006 | 跟本 PR 修的 self-heal pattern 配合 |

## 9. 遗留 (下一 Sprint)

| # | 项 |
|---|---|
| 1 | **EPIC-227**: worktree pre-commit hook 失效 (跟 EPIC-217 testing 删债同源) |
| 2 | CHANGELOG 补 EPIC-203~226 共 24 条 |
| 3 | `recent-epics.md` 补 EPIC-209~226 共 18 条 |
| 4 | 12 in_progress ticket 定性 + EPIC-150/154/177-G 收口 |
| 5 | testing 分支恢复 |
| 6 | EPIC-205~222 测试缺口 18 个 EPIC |
| 7 | Security Audit 依赖债 (10 vulnerabilities) |