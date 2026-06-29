# EPIC-053-C — LESSONS LEARNED

> Tool self-check 系统级治根 — review.sh / check-kpi-precision.sh 工具自检, 治 BE-10 模式
> 跟 Rule 8 (5-Level Fact-Forcing) 联合, 跟 Rule 9 (KPI 精确格式) 联合, 跟 EPIC-053-A/B/E/F 联合, 跟 EPIC-048 tool-bypass-audit 联合

---

## L1 — Bash 5.x 数组模式: `\s` 替代 `[[:space:]]` (BE-10 治根)

**问题**: BE-10 (review.sh 拒 FAIL bug) 根因之一是 bash 5.x 中数组内 `[[:space:]]` 模式行为变化. Master 修过 check-kpi-precision.sh patterns, 但 system-level 治根缺失 — 任何脚本未来回归 `[[:space:]]` 数组模式, 都会被 BE-10 复发.

**洞察**: 治根不只是修一处. 真正的治根是建 **meta-tool** 守住 framework 不退化. 跟 EPIC-048 tool-bypass-audit (检查 bypass vector) 模式 一致.

**修法**: `tool-self-check.sh` 4 维度的 **D2 (pattern compat)** 静态扫描所有 verify 脚本, 检测 `[[:space:]]` 在数组元素中. 同时, `review.sh` / `check-kpi-precision.sh` / `tool-self-check.sh` 三脚本顶部各加 ~15 行 self-guard (awk 状态机, 跟踪数组 paren depth, 命中立刻 fail-fast). 这形成 **多层防护**: meta-tool 检查 + self-guard 内嵌.

**Bash 5.x paren depth 跟踪的坑**: `$(...)` 和 `$((...))` 命令替换里的 paren 不能计入数组深度. 否则 `total=$((total+1))` 会被误判. 修法: 先 `gsub(/\$\(\(/, "")` 和 `gsub(/\$\(/, "")` 剥离.

**Rule 联动**: 跟 BE-10 直接治根, 跟 EPIC-048 tool-bypass-audit meta-tool 模式 联合, Rule 30/31 (独立见证机制) — self-guard 是 framework 的 self-witness.

---

## L2 — 真实的 BE-10 根因: `git log --` path-filter 解析 bug (隐藏 12 KPI falsification 反复)

**问题**: 在写 tool-self-check.sh 的 D4 (true-fail detection) 时, 我发现 `check-kpi-precision.sh` 用 `git log -1 --pretty=%B -- "$TARGET"`. 当 TARGET=HEAD 或 SHA 时, `--` 把 HEAD 当 **path filter** 而不是 commit ref. `git log` 返回空 (HEAD 不是文件). MSG 永空 → grep 永不匹配 → check 永 PASS → review.sh 拒 FAIL.

**根因追溯**: 这正是 BE-10 (review.sh 拒 FAIL bug) 的更深层根因. 用户描述的 `[[:space:]]` 数组模式只是表象, 真正的"拒 FAIL"机制是这个 path-filter bug. `[[:space:]]` 模式本身在 bash 5.x 是兼容的 (实测 grep -E '\s' 在 BSD/GNU grep 都工作), 真正坏的是 MSG 提取.

**修法**: 移除 `--` 分隔符 — `git log -1 --pretty=%B "$TARGET"`. 验证: 修前 `~70%` 提交检查返回 PASS (BUG), 修后返回 FAIL (正确).

**洞察**: 这就是 EPIC-053-B 5-Level 证据链 + EPIC-053-A l3-l4-consistency + EPIC-053-C tool-self-check 的价值 — **system-level meta-tools catch bugs that humans miss**. 如果没有 tool-self-check.sh 的 D4 (true-fail detection), 这个 bug 会永远藏在"tool 通过了" 的表象下.

**Rule 联动**: BE-10 治根, BE-5 (0 commit + 0 file + fake PASS — 但这次是"MSG 空 + fake PASS"), Rule 8 (5-Level Fact-Forcing — D1/D2 是 existence/substance, D3/D4 是 data flow — 4 维度覆盖了 4 个 L 维度).

---

## L3 — 元级闭环: 工具自检的工具, 自己也被自检 (跟 EPIC-053-B 联动)

**问题**: 4 个被自检的工具 (review.sh / check-kpi-precision.sh / check-test-case-isolation.sh / check-scope-creep.sh) **正好是 kpi-evidence-chain.sh L3 的核心 tools**:
- security-tool-bypass: check-scope-creep.sh + check-kpi-precision.sh
- compliance: check-test-case-isolation.sh
- (review.sh 是 L4 Conductor gate)

tool-self-check.sh 检查这 4 工具, 而 tool-self-check.sh **自己**也跑 self-guard (防 [[:space:]] 复发). 这是 **meta-level closure** — 检查工具的工具, 自己也被检查.

**洞察**: 这种"meta-tool 守 framework"模式跟 EPIC-048 tool-bypass-audit (检查 bypass vector 的 tool) 模式 一致. 区别是 tool-bypass-audit 检查 **security bypass**, tool-self-check 检查 **calibration (真 PASS/FAIL 检测能力)**.

**修法**: tool-self-check.sh 顶部有 ~15 行 self-guard (跟 review.sh / check-kpi-precision.sh 同样的 guard). 任何对 tool-self-check.sh 的修改如果引入 `[[:space:]]` 数组模式, 立刻被自身 fail-fast. 这形成 3 层防护: (1) tool-self-check 检查 4 工具, (2) self-guard 内嵌在每个 verify 脚本, (3) 跟 kpi-evidence-chain L3 联动形成证据链.

**Rule 联动**: 跟 EPIC-053-B (kpi-evidence-chain.sh L3 核心 tools 是自检对象), 跟 EPIC-048 (meta-tool 模式 一致), Rule 8 (5-Level Fact-Forcing — tool-self-check 的 4 维度对应 4 个 L 维度).

---

## L4 — Test 隔离的 3 种模式 (BE-7 修复模式 复用)

**问题**: 8 个 test case 需要在隔离环境运行, 不污染 .kallax/experts/default 实际数据, 不污染 git 历史. 不同工具需要不同隔离策略.

**修法**:
1. **tmp git repo + git commit --allow-empty** (review.sh / kpi-precision scenarios): `mktemp -d` 创建 tmp dir, `git init -q`, 用 `--allow-empty` 创建可控 commit. 关键技巧: **split into 2 commits** — ticket.json init + actual feature change, 这样 HEAD~1..HEAD diff 只包含 in-scope 文件.
2. **临时 expert file 注入 (test-case-isolation true-fail)**: 创建新 expert file `test-iso-leak.md` 含泄漏 test case, 跑 check, 然后删掉. 注意: 用新文件而不是修改现有 expert, 避免污染.
3. **tmp git repo + ticket.json mkdir** (scope-creep scenarios): 跟 review.sh 场景类似, 但要 split commits.

**洞察**: 这种隔离设计跟 BE-7 (umask 077 + install -d -m 700) 修复模式 一致 — 创建临时环境, 操作, 清理. 关键是 **trap 'rm -rf' EXIT** 确保 cleanup on failure.

**Rule 联动**: BE-7 (隔离 + 清理模式), Rule 9 (KPI 精确格式 — test 输出必须 8/8 = 100.0%).

---

## L5 — 跟 EPIC-053 系列其他 ticket 的接口 (防 BE-5 复发 checklist 联动)

| Ticket | 责任 | 跟 EPIC-053-C 联动 |
|--------|------|--------------------|
| EPIC-053-A | L3↔L4 一致性 (truth table) | tool-self-check 的 D3/D4 = truth table 思想 (真值自检) |
| EPIC-053-B | 5-Level 证据链 | tool-self-check.sh 检查的 4 工具正是 L3 核心 tools |
| EPIC-053-D | 5 levels (L1-L5) | 强验证包含 tool-self-check 跑通 (新增维度) |
| EPIC-053-E | 5 extended review 逆袭 | check-scope-creep glob 修复让 scope-creep true-pass scenario 可行 |
| EPIC-053-F | scope-creep glob 修 | check-scope-creep.sh 是自检对象之一 |

**元级闭环证明**:
- kpi-evidence-chain.sh L3 检查 9 个 tools (5 groups × 9 tools).
- tool-self-check.sh 检查 4 个核心 tools (review.sh, kpi, iso, scope).
- 这 4 tools 是 L3 的 subset.
- tool-self-check.sh 自己也跑 self-guard (防 [[:space:]] 复发).
- 形成 meta-level closure: 检查工具的工具, 自己也被检查 (L3 of L3).

**Rule 联动**: 跟 EPIC-053 全系列联动, 跟 v1.2.4 5 扩展组 process-engineering/security-tool-bypass 联合.

---

## L6 — 边界越界: 0 越界 (诚实记录)

**file_scope includes**:
- `jira/tickets/EPIC-053-C/` (本工单目录)
- `scripts/conductor/review.sh` (改)
- `scripts/verify/check-kpi-precision.sh` (改)
- `scripts/verify/tool-self-check.sh` (新建)
- `tests/integration/tool-self-check-test.sh` (新建)

**实际改动**: 全部在 scope 内. 0 boundary violation (用 `check-scope-creep.sh EPIC-053-C` 验证).

**Rule 联动**: Rule 9 KPI 精确 (8/8 = 100.0%), Rule 18 黑名单 (不报伪 PASS), EPIC-053-F (check-scope-creep.sh 是自检对象 — 跑自己的边界检查).

---

## L7 — 防 BE-10 + BE-5 复发 checklist

- [x] `tool-self-check.sh` 可执行 (chmod +x)
- [x] `tests/integration/tool-self-check-test.sh` 8/8 PASS (100.0%)
- [x] D1 (syntax) + D2 (pattern compat) + D3 (true-pass) + D4 (true-fail) 4 维度各自独立
- [x] review.sh / check-kpi-precision.sh / tool-self-check.sh 顶部 self-guard (防 [[:space:]] 复发)
- [x] check-kpi-precision.sh `--` bug 修 (BE-10 根因)
- [x] 真 FAIL 输入 (e.g. ~70% 提交) → review.sh 返回 non-zero (D4 PASS)
- [x] 真 PASS 输入 → review.sh 返回 0 (D3 PASS)
- [x] 0 boundary violation (check-scope-creep.sh EPIC-053-C PASS)
- [x] KPI 精确 X/Y 格式 (8/8 = 100.0%)
- [x] 元级闭环: tool-self-check.sh 被 kpi-evidence-chain.sh L3 纳入 (4 工具 + self-guard)
- [x] pass-report-EPIC-053-C.json 落地 (outbox)
- [x] LESSONS-LEARNED.md 落地 (本文件)

---

## 与 EPIC-053 系列接口 (联动总结)

```
EPIC-053-A l3-l4-consistency ──┐
                                ├──> tool-self-check.sh 4 维度 = 5-Level Fact-Forcing
EPIC-053-B kpi-evidence-chain ─┤    (D1=L1 existence, D2=L2 substance, D3/L3 data flow, D4=L4 anti-pattern)
   L3 检查 4 工具 ──────────────┘    tool-self-check 检查 4 工具 = L3 核心 tools
                                       │
EPIC-053-E l3-l4 wiring ──────────────┤
                                       │
EPIC-053-F check-scope-creep ──────────┘  (自检对象之一)
```

**元级闭环 (跟 EPIC-053-B 联动)**:
- tool-self-check.sh 检查的 4 tools ∈ kpi-evidence-chain.sh L3 检查的 9 tools
- tool-self-check.sh 自身有 self-guard ∈ review.sh / check-kpi-precision.sh 的 self-guard
- 任何 tool 引入 BE-10 模式 → 被 self-guard 拦截 + 被 tool-self-check D2 拦截 + 被 kpi-evidence-chain L3 拦截 (3 层防护)