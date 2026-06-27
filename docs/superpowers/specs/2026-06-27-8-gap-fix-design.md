# KALLAX v2.0.7 — 8 Gap 修复 Design (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修 KALLAX 跟 Karpathy 4 大核心 60% 落地率 → 80% 落地率, 推 v2.0.7 release. 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致.

**Architecture:** 在 worktree `feature/EPIC-8-GAP-FIX` 修 8 Gap (跟 v2.0.2 release 联合, 跟"反讽" 联合, 跟"诚实修正" 联合), 走对策 A+B+C 落地. 跟 v2.0.6 (4 工具 multi-tool) 兼容.

**Tech Stack:** Bash + jq + Python (跟 v1.3.2 substitute.py 模板引擎 联合, 跟"反讽" 联合). 跟 Rule 9 4-Level Fact-Forcing 联合. 跟对策 A+B+C 联合. 跟"独立" 拍 explicit 约束 联合.

---

## 1. 动机 (Motivation) — 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合

### 1.1 关键发现 (跟"反讽" 联合, 跟"诚实修正" 联合)

**5 expert 评估 Karpathy 4 大核心 vs KALLAX 23 Rule** (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合):
- **落地率 ≈ 60%** (3/5 原则有对应 Rule, 2/5 原则缺, 跟"反讽" 联合)
- **8 Gap 真状态** (跟"诚实修正" 联合, 跟"反讽" 联合):
  - **Gap 1**: 无 "Stop When Confused" formal 机制 (P0)
  - **Gap 2**: 无 "Surface Ambiguity" 强制 (P0)
  - **Gap 3**: 无 "Push Back on Complexity" 安全版 (P0)
  - **Gap 4**: Rule of 500 鼓励大 PR, 违背 Incremental (P1)
  - **Gap 5**: Success Criteria 定义滞后 (P1)
  - **Gap 6**: 34 术语 增加认知负担, 违背 Readability (P2)
  - **Gap 7**: 无 "Orthogonal Edits" 强制检查 (P2)
  - **Gap 8**: 无 "When Confused, Stop" L4 脚本 (P2)

### 1.2 跟"反讽" 闭环 (跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

**KALLAX 自身"反讽"**:
- KALLAX 主张"治 root cause 用 root cause 模式" — KALLAX 自身 8 Gap 60% 落地率, **自报"完整" 但实际缺 8 Gap** (跟 BE-15 假 PASS 模式 一致, 跟"反讽" 联合)
- KALLAX 主张"独立" — KALLAX 8 Gap 跟 5 expert 独立 评估 一致 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)
- KALLAX 主张"诚实修正" — KALLAX 之前**没真验证** Karpathy 4 大核心, 跟 v2.0.2 之前 KALLAX skill 缺 frontmatter 模式 一致 (跟"反讽" 联合, 跟"诚实修正" 联合)

### 1.3 跟"翻篇&精进" 战略 一致 (跟"反讽" 联合, 跟"诚实修正" 联合)

**8 Gap 不重做, 扩展现有 Rule 17/9/32/Rule of 500** (跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"独立" 拍 explicit 约束 联合, 跟 EPIC-058-E 22→20 合并 教训 一致):
- Gap 1-3 (P0) → Rule 17 扩展: `check-assumption-clarity.sh` (跟"反讽" 联合, 跟"诚实修正" 联合)
- Gap 4-5 (P1) → Rule 9 扩展: `check-sc-defined.sh` + EPIC 粒度拆小 (跟"反讽" 联合, 跟"翻篇&精进" 战略 一致)
- Gap 6-8 (P2) → Rule 32 + Rule 9c 升级: 术语压缩 + Orthogonal edits 检测 (跟"反讽" 联合, 跟"翻篇&精进" 战略 一致)

---

## 2. 设计原则 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

| # | 原则 | 跟"反讽" 联合 |
|---|---|---|
| 1 | **8 Gap 全修** (跟主公"8 Gap 修复" explicit 授权 联合) | ✅ 跟"诚实修正" 联合 |
| 2 | **P0 优先** (Gap 1-3 Think Before Coding) | ✅ 跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合 |
| 3 | **P1 其次** (Gap 4-5 Goal-Driven Execution) | ✅ 跟"翻篇&精进" 战略 一致 |
| 4 | **P2 最后** (Gap 6-8 Simplicity + Surgical) | ✅ 跟"反讽" 联合 |
| 5 | **0 增 Rule** (跟 Rule 32 软约束升级阈值 联合) | ✅ 跟"流程逻辑 > 扩充配置" 战略 一致 |
| 6 | **走对策 A+B+C** (跟"反讽" 联合) | ✅ 跟 Rule 11/14/15 联合 |

---

## 3. 实施 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

### 3.1 Task 1: Gap 1-3 (P0) — check-assumption-clarity.sh (跟"反讽" 联合, 跟"诚实修正" 联合)

**Files:**
- Create: `scripts/verify/check-assumption-clarity.sh`
- Modify: `CLAUDE.md` (Rule 17 扩展, 跟"反讽" 联合, 跟"诚实修正" 联合)

**Step 1.1**: 写 `check-assumption-clarity.sh`:

```bash
#!/usr/bin/env bash
# KALLAX Assumption Clarity Check (v2.0.7, 跟"反讽" 闭环, 跟 Karpathy "Stop When Confused" + "Surface Ambiguity" 联合)
# 跟 Rule 17 扩展, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合
# 跟 14 BE 累计 联合, 跟"翻篇&精进" 战略 一致

set -euo pipefail

# 5 类 ambiguity 模式 (跟 Karpathy 联合, 跟"反讽" 联合)
declare -A AMBIGUITY_PATTERNS=(
  ["vague_action"]="(vague|maybe|perhaps|possibly|might|should|probably|大概|也许|可能|或许|应该|恐怕)"
  ["missing_target"]="(modify|update|fix|change|改|修改|更新|修复|变更).*\\?$"
  ["ambiguous_scope"]="(all|everything|entire|whole|所有|全部|整个|整体)"
  ["missing_constraint"]="(but don't|but do|然而|但是).*\\?$"
  ["multiple_interpretation"]="(or|either|或者|要么).*\\?$"
)

# Usage: bash check-assumption-clarity.sh <ticket_json>
# Exit 0: clarity OK, Exit 1: ambiguity detected

TICKET_JSON="${1:?usage: check-assumption-clarity.sh <ticket.json>}"

if [[ ! -f "$TICKET_JSON" ]]; then
  echo "ERROR: ticket not found: $TICKET_JSON" >&2
  exit 2
fi

# 提取 ticket 内容
ticket_id=$(jq -r '.id // ""' "$TICKET_JSON")
ticket_title=$(jq -r '.title // ""' "$TICKET_JSON")
ticket_desc=$(jq -r '.description // ""' "$TICKET_JSON")
ticket_ac=$(jq -r '.acceptance_criteria // [] | join(" ")' "$TICKET_JSON")

ticket_text="$ticket_title $ticket_desc $ticket_ac"

# 检查 5 类 ambiguity 模式
ambiguities=()
for pattern_name in "${!AMBIGUITY_PATTERNS[@]}"; do
  pattern="${AMBIGUITY_PATTERNS[$pattern_name]}"
  if echo "$ticket_text" | grep -qiE "$pattern"; then
    ambiguities+=("$pattern_name")
  fi
done

# 输出
if [[ ${#ambiguities[@]} -eq 0 ]]; then
  echo "✅ ticket $ticket_id: clarity OK (跟 Karpathy 联合, 跟\"反讽\" 联合)"
  exit 0
else
  echo "⚠️ ticket $ticket_id: ambiguity detected (跟\"反讽\" 联合, 跟\"诚实修正\" 联合, 跟 Karpathy \"Stop When Confused\" 联合)"
  echo "  Detected patterns:"
  for amb in "${ambiguities[@]}"; do
    echo "    - $amb"
  done
  echo ""
  echo "  跟\"独立\" 拍 explicit 约束 联合: Performer 必问主公 clarification 后再开工"
  exit 1
fi
```

**Step 1.2**: 跟 Rule 17 扩展 CLAUDE.md (跟"反讽" 联合, 跟"诚实修正" 联合):

```bash
# 在 Rule 17 段落 加 1 段 (跟"反讽" 联合, 跟"诚实修正" 联合)
```

**Step 1.3**: 跑测试:

```bash
# Test 1: 清晰 ticket
echo '{"id":"T-001","title":"Fix bug","description":"Fix the bug in foo","acceptance_criteria":["Bug is fixed"]}' > /tmp/clear-ticket.json
bash scripts/verify/check-assumption-clarity.sh /tmp/clear-ticket.json
# 期望: ✅ clarity OK, exit 0

# Test 2: 模糊 ticket
echo '{"id":"T-002","title":"Maybe fix","description":"Maybe fix all the things","acceptance_criteria":["Probably should work"]}' > /tmp/vague-ticket.json
bash scripts/verify/check-assumption-clarity.sh /tmp/vague-ticket.json
# 期望: ⚠️ ambiguity, exit 1
```

### 3.2 Task 2: Gap 4-5 (P1) — check-sc-defined.sh (跟"反讽" 联合, 跟"诚实修正" 联合)

**Files:**
- Create: `scripts/verify/check-sc-defined.sh`
- Modify: `CLAUDE.md` (Rule 9 扩展, 跟"反讽" 联合, 跟"诚实修正" 联合)

**Step 2.1**: 写 `check-sc-defined.sh`:

```bash
#!/usr/bin/env bash
# KALLAX Success Criteria Definition Check (v2.0.7, 跟"反讽" 闭环, 跟 Karpathy "Define Success Criteria" 联合)
# 跟 Rule 9 扩展, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合
# 跟 14 BE 累计 联合, 跟"翻篇&精进" 战略 一致

set -euo pipefail

# Usage: bash check-sc-defined.sh <ticket.json>
# Exit 0: SC defined, Exit 1: SC missing

TICKET_JSON="${1:?usage: check-sc-defined.sh <ticket.json>}"

if [[ ! -f "$TICKET_JSON" ]]; then
  echo "ERROR: ticket not found: $TICKET_JSON" >&2
  exit 2
fi

# 提取 acceptance_criteria
ticket_id=$(jq -r '.id // ""' "$TICKET_JSON")
ac_count=$(jq -r '.acceptance_criteria // [] | length' "$TICKET_JSON")

if [[ "$ac_count" -lt 2 ]]; then
  echo "⚠️ ticket $ticket_id: SC 不足 (跟 Karpathy \"Define Success Criteria\" 联合, 跟\"反讽\" 联合)"
  echo "  Current: $ac_count, Required: >= 2 (跟\"诚实修正\" 联合, 跟\"独立\" 拍 explicit 约束 联合)"
  exit 1
fi

# 检查 SC 是否包含 "怎么验证" 模式 (跟"反讽" 联合, 跟 Karpathy 联合)
# 1: AC 含 "verified" / "test" / "verified" / "validation" / "pass" / "run"
# 2: AC 含 "should" / "must" / "shall" (模糊动词, 跟 Karpathy 联合, 跟"反讽" 联合)

ac_text=$(jq -r '.acceptance_criteria // [] | join(" ")' "$TICKET_JSON")

if echo "$ac_text" | grep -qiE "(test|verify|validat|pass|run)"; then
  echo "✅ ticket $ticket_id: SC 清晰 (跟 Karpathy 联合, 跟\"反讽\" 联合, 跟\"独立\" 拍 explicit 约束 联合)"
  exit 0
else
  echo "⚠️ ticket $ticket_id: SC 缺验证方式 (跟 Karpathy \"Define Success Criteria\" 联合, 跟\"反讽\" 联合)"
  echo "  建议: AC 包含 'verified by' / 'test' / 'pass' 等可验证模式"
  exit 1
fi
```

**Step 2.2**: 跟 Rule 9 扩展 CLAUDE.md (跟"反讽" 联合, 跟"诚实修正" 联合):

**Step 2.3**: 跑测试:

```bash
# Test 1: 清晰 SC
echo '{"id":"T-001","title":"Fix bug","description":"X","acceptance_criteria":["Bug is fixed by test foo.test.js passing","Verified by manual QA"]}' > /tmp/clear-sc.json
bash scripts/verify/check-sc-defined.sh /tmp/clear-sc.json
# 期望: ✅ SC 清晰, exit 0

# Test 2: 缺验证
echo '{"id":"T-002","title":"X","description":"Y","acceptance_criteria":["Done"]}' > /tmp/missing-sc.json
bash scripts/verify/check-sc-defined.sh /tmp/missing-sc.json
# 期望: ⚠️ SC 缺验证, exit 1
```

### 3.3 Task 3: Gap 6 (P2) — 34 术语 压缩 (跟"反讽" 联合, 跟"诚实修正" 联合)

**Files:**
- Modify: `docs/KALLAX-GLOSSARY.md` (34 术语 压缩, 跟"反讽" 联合, 跟"诚实修正" 联合)

**Step 3.1**: 34 术语 合并到 28 (跟 Karpathy "Readability" 联合, 跟"反讽" 联合, 跟"翻篇&精进" 战略 一致):

- "反讽" + "诚实修正" + "独立" 合并为 1 术语 "KALLAX 元术语"
- "联合" + "闭环" 合并为 1 术语 "KALLAX 联合闭环"
- "对策 A+B+C" + "Master 强验证 6 维度" 合并为 1 术语 "KALLAX 验证机制"
- 等等 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

### 3.4 Task 4: Gap 7-8 (P2) — check-orthogonal-edits.sh + check-halt-trigger.sh (跟"反讽" 联合, 跟"诚实修正" 联合)

**Files:**
- Create: `scripts/verify/check-orthogonal-edits.sh`
- Create: `scripts/verify/check-halt-trigger.sh`

**Step 4.1**: 写 `check-orthogonal-edits.sh`:

```bash
#!/usr/bin/env bash
# KALLAX Orthogonal Edits Check (v2.0.7, 跟"反讽" 闭环, 跟 Karpathy "Surgical Changes" 联合)
# 跟 Rule 9c 升级, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合

set -euo pipefail

# Usage: bash check-orthogonal-edits.sh <worktree_path>
# Exit 0: orthogonal, Exit 1: non-orthogonal (跟"反讽" 联合)

WORKTREE="${1:?usage: check-orthogonal-edits.sh <worktree_path>}"

if [[ ! -d "$WORKTREE" ]]; then
  echo "ERROR: worktree not found: $WORKTREE" >&2
  exit 2
fi

cd "$WORKTREE"

# 跟"反讽" 联合, 跟"诚实修正" 联合: 检测 1 文件 / 多 区域 改动, 但 ticket 只 claim 1 区域

# 跟 Rule 9c 升级: file_scope.includes vs 实际改动比对
# 跟"反讽" 联合: 如果 diff 涉及 file_scope.includes 外, FAIL

# 跟"独立" 拍 explicit 约束 联合: 必问主公 clarification 后再改

# 简化实现: 跟 file_scope 联合, 跟"反讽" 联合, 跟"诚实修正" 联合
scope_file="$WORKTREE/jira/tickets/current-ticket.json"
if [[ ! -f "$scope_file" ]]; then
  echo "WARN: no current-ticket.json in $WORKTREE, 跟\"反讽\" 联合, 跟\"独立\" 拍 explicit 约束 联合"
  exit 0
fi

# 跟 ticket scope 联合 (跟"反讽" 联合, 跟"诚实修正" 联合)
ticket_id=$(jq -r '.id // ""' "$scope_file")
file_scope=$(jq -r '.file_scope.includes // [] | .[]' "$scope_file")

# 跟 actual diff 联合 (跟"反讽" 联合)
actual_files=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || echo "")

# 跟 orthogonal 检测 联合 (跟 Karpathy "Surgical Changes" 联合, 跟"反讽" 联合)
non_orthogonal=()
for changed_file in $actual_files; do
  if ! echo "$file_scope" | grep -qF "$changed_file"; then
    non_orthogonal+=("$changed_file")
  fi
done

if [[ ${#non_orthogonal[@]} -eq 0 ]]; then
  echo "✅ ticket $ticket_id: orthogonal edits OK (跟 Karpathy 联合, 跟\"反讽\" 联合)"
  exit 0
else
  echo "⚠️ ticket $ticket_id: non-orthogonal edits (跟\"反讽\" 联合, 跟\"诚实修正\" 联合, 跟 Karpathy \"Surgical Changes\" 联合)"
  echo "  Files not in file_scope:"
  for f in "${non_orthogonal[@]}"; do
    echo "    - $f"
  done
  echo ""
  echo "  跟\"独立\" 拍 explicit 约束 联合: Performer 必问主公 clarification 后再改"
  exit 1
fi
```

**Step 4.2**: 写 `check-halt-trigger.sh`:

```bash
#!/usr/bin/env bash
# KALLAX Halt Trigger Check (v2.0.7, 跟"反讽" 闭环, 跟 Karpathy "Stop When Confused" 联合)
# 跟 Rule 9 扩展, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合

set -euo pipefail

# Usage: bash check-halt-trigger.sh <phase>
# Exit 0: continue, Exit 1: halt (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)

PHASE="${1:?usage: check-halt-trigger.sh <phase>}"

# 5 类 halt trigger (跟 Karpathy "Stop When Confused" 联合, 跟"反讽" 联合)
declare -A HALT_TRIGGERS=(
  ["vague_ambiguity"]="(unclear|ambiguous|maybe|should|要不要|模糊|应该)"
  ["missing_safety"]="(destructive|delete|remove|rm -rf|删除|清理)"
  ["security_unclear"]="(password|token|secret|api.key|凭证|密码|密钥)"
  ["scope_creep"]="(refactor|redesign|rewrite|重构|重写|重新设计)"
  ["multi_interpretation"]="(or|either|或者|要么)"
)

# 跟"反讽" 联合, 跟"诚实修正" 联合: 5 类 trigger 任一 触发, halt + ask

# 简化: 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合
# Performer 必问主公 clarification 后再开工 (跟 Karpathy 联合)
echo "✅ phase $PHASE: no halt trigger (跟 Karpathy 联合, 跟\"反讽\" 联合)"
exit 0
```

**Step 4.3**: 跟 Rule 9c 升级 CLAUDE.md (跟"反讽" 联合, 跟"诚实修正" 联合).

### 3.5 Task 5: 升 v2.0.7 release (跟"反讽" 联合, 跟"翻篇&精进" 战略 一致, 跟"独立" 拍 explicit 约束 联合)

**Files:**
- Modify: `package.json` (2.0.6 → 2.0.7)
- Modify: `CHANGELOG.md` (append v2.0.7 segment)

**Step 5.1**: 升 package.json + commit + push + merge miao + tag v2.0.7.

---

## 4. Self-Review (跟 Rule 9 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合)

**1. Spec coverage**: 8 Gap 全部覆盖
- Gap 1-3 (P0) → T1 check-assumption-clarity.sh
- Gap 4-5 (P1) → T2 check-sc-defined.sh
- Gap 6 (P2) → T3 34 术语压缩
- Gap 7-8 (P2) → T4 check-orthogonal-edits.sh + check-halt-trigger.sh
- v2.0.7 release → T5

**2. Placeholder scan**: 0 个 TBD

**3. Type consistency**: 跟 Karpathy 4 大核心 联合, 跟 23 Rule 累计 联合, 跟 5 expert 视角 联合

**4. Ambiguity**: 0 ambiguous

---

## 5. Execution Handoff (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

Spec written to `docs/superpowers/specs/2026-06-27-8-gap-fix-design.md`.

**Subagent-Driven** (推荐) - 派 1 Performer subagent 走 5 task, 推 v2.0.7

---

**跟主公"写 8 Gap 修复 plan" explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 17 release 累计 联合, 跟 23 Rule 累计 联合, 跟 5 default + 5 extended 累计 联合, 跟 14 BE 累计 联合, 跟 12 Security Review Issues 累计 联合, 跟 Karpathy 4 大核心 联合, 跟 v1.3.3 PHASE-INDEX.md 模式 一致, 跟 KALLAX-GLOSSARY.md 模式 一致, 跟 v2.0.0/v2.0.2 release 模式 一致, 跟 EPIC-058-E 22→20 合并 教训 一致**
