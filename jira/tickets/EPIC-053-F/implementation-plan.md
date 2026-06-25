# EPIC-053-F Implementation Plan

> check-scope-creep.sh glob bug fix + tests/integration/l3-l4-consistency-test.sh 命名误导
> P1 | 4h | branch: feature/EPIC-053-F-scope-creep-bug
> Performer: performer-EPIC-053-F | base SHA: 48e76f1
> 跟 EPIC-053-A L6 lesson 闭环, 跟 EPIC-053-C BE-10 模式联动, 跟 B 组 5 extended review 逆袭 #2 + #3 联合

---

## 1. 目标 (跟 AC 1:1 对齐)

| AC | 描述 | 验证方法 |
|----|------|----------|
| AC1 | `check-scope-creep.sh` glob 修 — support `jira/tickets/EPIC-XXX/` 目录 | 跑 `bash scripts/verify/check-scope-creep.sh EPIC-053-A` → exit=0 |
| AC2 | `tests/integration/l3-l4-consistency-test.sh` git mv → `l3-l4-consistency-truth-table-test.sh` | `git log --diff-filter=R --name-status` |
| AC3 | Bash 5.x 兼容 patterns (BE-10 模式治根, 跟 EPIC-053-C 联动) | `bash -n` + 跑测试 OK |
| AC4 | `l3-l4-consistency-truth-table-test.sh` 跑通 4/4 PASS | raw test output |
| AC5 | `check-scope-creep.sh` 跑 jira/tickets/EPIC-053-A/ 不再 exit=1 | exit=0 + 0 false positive |
| AC6 | `tests/integration/scope-creep-glob-test.sh` 4/4 PASS (file, dir, glob, no-match) | raw test output |
| AC7 | Rule 9 KPI 精确 X/Y — 4/4 + 4/4 = 8/8 = 100.0% | pass-report |

---

## 2. 设计 (跟 EPIC-053-A L6 + EPIC-053-C 联动)

### 2.1 Bug 1: check-scope-creep.sh glob 不支持目录

**现状** (line 96-101):
```bash
for allowed in "${ALLOWED_ARRAY[@]}"; do
    if [ "$file" = "$allowed" ]; then   # ← exact string match
        MATCHED=1
        break
    fi
done
```

**问题**: 当 `allowed` 是 `jira/tickets/EPIC-053-A/` (目录), 实际 `file` 是 `jira/tickets/EPIC-053-A/IMPLEMENTATION-PLAN.md`, exact match 永远 fail ⇒ false positive exit=1.

**修法** (`match_glob` helper):
- 当 `allowed` 以 `/` 结尾 → prefix match (`file starts with allowed`)
- 否则 → exact match (现有行为)
- 未来 `*` glob 可扩展, 但本 ticket 只补目录支持 (最小变更原则)

### 2.2 Bug 2: l3-l4-consistency-test.sh 命名误导

**现状**: 文件在 `tests/integration/` 但实际是**硬编码 truth table** — 喂 `PASS/FAIL` 字符串给 `l3-l4-consistency.sh`, 验证 4 case 的 exit code. 没真跑集成测试.

**B 组 (process-engineering 3/5) 逆袭发现**: 命名误导 — 读者期望 "integration test" 但实际是 unit-style truth table.

**修法**: `git mv` → `l3-l4-consistency-truth-table-test.sh`. 路径从 `tests/integration/` → 保留在 `tests/integration/` (跟 file_scope 一致, EPIC-053-A 已建此路径), 仅文件名加 `-truth-table-` 标识真相.

**注意**: 保留 `tests/integration/` 目录位置 (不改目录), 跟 ticket file_scope `tests/integration/l3-l4-consistency-truth-table-test.sh` 一致. 内部内容不动 (4/4 行为保持).

### 2.3 Bash 5.x 兼容 (AC3)

**BE-10 模式**: `[[:space:]]` 字符类在 Bash 5.x 数组元素内可能行为变化. 跟 EPIC-053-C 联动 (8/8 PASS BE-10 治根).

**本 ticket 适用范围**:
- `check-scope-creep.sh` 修改时**不引入** `[[:space:]]` 字符类
- 改用 `case "$file" in` + `$allowed` prefix match
- 避免 `[[ "$x" =~ [[:space:]] ]]` 模式
- 注释明确引用 EPIC-053-C 联动

---

## 3. 步骤 (15 步子集)

| Step | 动作 | 状态 |
|------|------|------|
| 1 | 验证 worktree | ✓ (48e76f1) |
| 2 | 读 ticket.json | ✓ |
| 3 | 加载 backend expert | ✓ |
| 4 | 深度分析 (复现 exit=1 false positive, 读 EPIC-053-A L6 lesson) | ✓ |
| 5 | 写本 plan | 写入中 |
| 6 | TDD 写 `scope-creep-glob-test.sh` 4 case | 待执行 |
| 7a | 修 `check-scope-creep.sh` (glob 改) | 待执行 |
| 7b | `git mv` test 改名 | 待执行 |
| 8 | 跑 4/4 + 4/4 = 8/8 PASS | 待执行 |
| 11 | 写 LESSONS-LEARNED.md | 待执行 |
| 12 | 报 PASS (outbox/pass-report-EPIC-053-F.json) | 待执行 |

---

## 4. 文件清单 (跟 file_scope 1:1)

**修改**:
- `scripts/verify/check-scope-creep.sh` — glob pattern 改 (line 96-101 区域)

**git mv**:
- `tests/integration/l3-l4-consistency-test.sh` → `tests/integration/l3-l4-consistency-truth-table-test.sh` (内容不动, 路径调整)

**新建**:
- `tests/integration/scope-creep-glob-test.sh` — TDD 4 case
- `jira/tickets/EPIC-053-F/IMPLEMENTATION-PLAN.md` — 本文件
- `jira/tickets/EPIC-053-F/LESSONS-LEARNED.md` — 教训沉淀

**不动 (边界)**:
- `scripts/verify/l3-l4-consistency.sh` (EPIC-053-A 边界)
- `tests/integration/l3-l4-wiring-test.sh` (EPIC-053-E 边界, 跟 E 联动)
- `scripts/verify/check-fact-forcing-preflight.sh` (EPIC-053-A 边界)

---

## 5. 测试设计

### 5.1 `scope-creep-glob-test.sh` 4 case

| Case | Input file | Allowed pattern | 期望 |
|------|-----------|----------------|------|
| 1 | `scripts/foo.sh` | `scripts/foo.sh` (exact) | MATCH |
| 2 | `jira/tickets/EPIC-A/PLAN.md` | `jira/tickets/EPIC-A/` (dir) | MATCH (prefix) |
| 3 | `tests/integration/x-test.sh` | `tests/integration/x-*.sh` (glob) | MATCH (未来) — 本 ticket skip (out of scope) |
| 4 | `docs/random.md` | `scripts/` (no match) | NO MATCH (exit 0 if test mode) |

注: Case 3 (glob `*`) 是**未来扩展** — 留 hook 注释, 本 ticket 不实现 (避免 scope creep 到 wildcards).

Case 4: 用 `set +e` + capture exit, 而不是 fail (测试 mode 不需要让 check-scope-creep 真的 exit=1, 只测 match 函数).

### 5.2 `l3-l4-consistency-truth-table-test.sh` (git mv 后)

保持原 `l3-l4-consistency-test.sh` 4 case 全 PASS, 仅 git mv 改名, 验证 4/4 一致.

---

## 6. 风险 + 反模式 (跟 Rule 18 联合)

| 风险 | 缓解 |
|------|------|
| Glob 修复引入新 bug | TDD 先写 4 case 红 → 改 check-scope-creep → 绿 |
| 越界 file_scope (改 l3-l4-consistency.sh) | 修后跑 `check-scope-creep.sh EPIC-053-F` 验证 0 越界 |
| git mv 失败 (target not exist) | `git mv` 一次完成 (git handles dir creation) |
| Bash 5.x `[[:space:]]` 字符类 bug | 用 `case "$file" in "$allowed"*)` pattern, 不引字符类 |
| KPI falsification 反复 (报 PASS 没真修) | raw test_output 含 PASS/FAIL line, commit SHA + diff 在 report |
| 自审 | 跳 A/B review, 由 Conductor/Master review |
| 跟 EPIC-053-C 联动不齐 | 注释引用 BE-10, pattern 一致 |

---

## 7. 联动

| Ticket | 联动点 |
|--------|--------|
| EPIC-053-A L6 | L6 lesson "check-scope-creep 工具局限性" 闭环 |
| EPIC-053-C | BE-10 Bash 5.x `[[:space:]]` 数组模式, 本 ticket 不用字符类 |
| EPIC-053-E | `l3-l4-wiring-test.sh` 边界不动, 跟 E 互不干扰 |

---

## 8. 跟 Rule 9 KPI X/Y 联合

最终 KPI: `4/4 (scope-creep-glob) + 4/4 (l3-l4-consistency-truth-table) = 8/8 PASS = 100.0%`
精确数字, no estimate (跟 EPIC-053-A 6 次 KPI 反复 闭环).
