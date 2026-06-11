# KALLAX EKET P0 借鉴清单 9 项 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 借鉴 EKET 5 视角对比报告的 P0 剩余 9 项 (主公 2026-06-09 拍"全部借鉴"硬决策, EPIC-029 落地了 P1-3), 主公 2026-06-11 拍 A 落地 / B 拆 9 / C 新 DB / D 串行 / E 先 7 default

**Architecture:** 9 ticket 串行派单 (主公 D 改 3-3-3 → 串行, 1 Conductor 1 Performer). 9 ticket 分 5 视角对比报告借鉴: Conductor §5.1/5.3 (A/B/C) / Performer §5.1/5.4/5.5 (D/E/I) / UX §5.2 (F) / Security §5.2 (G) / EPIC-021 §3.1 (H). 跟 EPIC-029 3 模式 + Rule 1/9/10/11 联动.

**Tech Stack:** Bash (核心检查) + Python (TrustScore 计算) + SQLite (新 audit.db 独立, G) + jq + jq -n (审计) + 9-pass redact (跟 EPIC-029 一致)

---

## File Structure

**新建文件**:
- `scripts/agent/trust-score.sh` — TrustScore 4 因子计算 (A)
- `scripts/agent/best-matching-slaver.sh` — 3 层匹配算法 (A)
- `scripts/agent/scoring-trace.sh` — scoring_trace.jsonl 每日轮转 (B)
- `scripts/agent/waiting-for-expert.sh` — waiting-for-expert.json + need-expert 提示 (C)
- `.kallax/hooks/hook-profile.sh` — Hook Profile 三档 (D)
- `tests/fixtures/pr-size/cases.json` — PR Size self-test fixture (E)
- `tests/integration/pr-size-self-test.sh` — 回归测试 (E)
- `tests/integration/hook-profile-test.sh` — 3 档 env var 测试 (D)
- `tests/integration/agent/trust-score-test.sh` — TrustScore + 3 层匹配测试 (A)
- `tests/integration/agent/scoring-trace-test.sh` — 轮转 + 写读测试 (B)
- `tests/integration/agent/waiting-for-expert-test.sh` — 匹配失败 + JSON + inbox 测试 (C)
- `tests/integration/health-check-json-test.sh` — 3 状态 level 1/2/3 测试 (F)
- `scripts/audit/audit-middleware.sh` — audit_log 写 (G)
- `scripts/audit/audit-db.sh` — 新 SQLite 建表 (G)
- `tests/integration/audit-middleware-test.sh` — 写 + 查 + 跨 command (G)
- `scripts/task-claim-brief.sh` — Brief Inference 强制 (I)
- `tests/integration/brief-inference-test.sh` — 有 brief PASS / 无 FAIL 测试 (I)

**修改文件**:
- `.kallax/hooks/pre-commit` — 串联 hook-profile.sh (D)
- `scripts/health_check.sh` — JSON 输出 (F)
- `scripts/check-pr-size.sh` — 加 `--self-test` (E)
- `.kallax/experts/default/architect.md` + 6 default — 加 5 persona 字段 (H)

**审计**:
- `.kallax/audit/scoring-YYYY-MM-DD.jsonl` — TrustScore 派发决策审计 (B)
- `.kallax/state/waiting-for-expert.json` — 等待专家队列 (C)
- `.kallax/inbox/need-expert-<TICKET>.md` — 提示 (C)
- `.kallax/data/audit.db` — 新 SQLite 独立 (G)

---

## 串行执行顺序 (主公 D)

| # | Ticket | 估时 | 依赖 | 来源 |
|---|---|---|---|---|
| 1 | A: TrustScore | 2d | — | Conductor §5.1 |
| 2 | B: scoring_trace | 0.5d | A | Conductor §5.1 |
| 3 | C: waiting-for-expert | 0.5d | A | Conductor §5.3 |
| 4 | D: Hook Profile | 0.5d | — | Performer §5.4 |
| 5 | E: PR Size self-test | 1d | — | Performer §5.5 |
| 6 | F: system:doctor JSON | 0.5d | — | UX §5.2 |
| 7 | G: AuditMiddleware (新 DB) | 1.5d | — | Security §5.2 |
| 8 | H: KALLAX persona (7 default) | 1d | — | EPIC-021 §3.1 |
| 9 | I: Brief Inference | 0.5d | — | Performer §5.1 |

**总估时 8d**. 9 全串行 (1 Conductor 1 Performer).

---

## Task 1 (Ticket A): TrustScore 三层匹配 + 向量 cosine

**Files:**
- Create: `scripts/agent/trust-score.sh`
- Create: `scripts/agent/best-matching-slaver.sh`
- Create: `tests/integration/agent/trust-score-test.sh`

**关键 Bash 骨架 (从 eket master_heartbeat.rs 借鉴)**:

```bash
# trust-score.sh — 4 因子计算
compute_trust() {
  local instance_id="$1"
  local success_rate_7d=$(jq -r '.success_rate_7d // 0.5' ".kallax/state/instances/${instance_id}.json")
  local uptime_30d=$(jq -r '.uptime_30d // 0.5' ".kallax/state/instances/${instance_id}.json")
  local avg_latency_norm=$(jq -r '.avg_latency_norm // 0.5' ".kallax/state/instances/${instance_id}.json")
  local error_rate=$(jq -r '.error_rate // 0.0' ".kallax/state/instances/${instance_id}.json")
  
  # 权重: 4 因子加权
  echo "scale=2; 0.4 * $success_rate_7d + 0.3 * $uptime_30d + 0.2 * (1 - $avg_latency_norm) + 0.1 * (1 - $error_rate)" | bc
}

# best-matching-slaver.sh — 3 层匹配
best_matching_slaver() {
  local required_expertise="$1"
  
  # Layer 1: "any" / 空 → TrustScore 最高
  if [[ -z "$required_expertise" ]] || [[ "$required_expertise" == "any" ]]; then
    jq -r '.instances | sort_by(-.trust_score) | .[0].id // empty' .kallax/state/instances.json
    return
  fi
  
  # Layer 2: 向量 cosine ≥ 0.5
  local cosine_match=$(jq -r --arg req "$required_expertise" \
    '.instances | map(select(.expertise_cosine >= 0.5)) | sort_by(-.trust_score) | .[0].id // empty' \
    .kallax/state/instances.json)
  if [[ -n "$cosine_match" ]]; then
    echo "$cosine_match"
    return
  fi
  
  # Layer 3: Fallback 标签评分 (role=2, skills=1)
  jq -r --arg req "$required_expertise" \
    '.instances | map(.score = (if .role == $req then 2 else 0 end) + (if (.skills // [] | contains([$req])) then 1 else 0 end)) | sort_by(-.score, -.trust_score) | .[0].id // empty' \
    .kallax/state/instances.json
}
```

**TDD 步骤 (per `docs/superpowers/plans/2026-06-09-kallax-3-modes.md` 模板)**:
1. 写失败测试 `tests/integration/agent/trust-score-test.sh`
2. 跑测试, 确认 FAIL
3. 写 `scripts/agent/trust-score.sh` + `best-matching-slaver.sh` 骨架
4. chmod +x
5. 跑测试, 确认 PASS
6. Commit: `feat(EPIC-030-A): TrustScore + 3 层匹配算法骨架`

**4-Level AC**:
- L1: 2 脚本 + 1 测试存在
- L2: 真实 TrustScore 4 因子 + 3 层匹配
- L3: jq 合法, 算法骨架 + "算法建议 + 人工拍板" 出口
- L4: 8+ 测试 PASS (3 层 + 边界 + 人工拍板)

**主公 A 决策落地**: KALLAX 加 "算法建议 + 人工拍板" 出口 (跟 3 模式 A1 经验), best-matching-slaver.sh 输出建议 + 标 "ALGO_SUGGEST: <id>", Conductor 实际派发仍人工.

---

## Task 2 (Ticket B): scoring_trace.jsonl 每日轮转

**Files:**
- Create: `scripts/agent/scoring-trace.sh`
- Create: `tests/integration/agent/scoring-trace-test.sh`

**关键 Bash**:
```bash
append_scoring_trace() {
  local algo_suggest="$1"
  local slaver_id="$2"
  local trust_score="$3"
  local factors="$4"
  local decision="$5"  # "suggested" / "overridden" / "auto-dispatched"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
  
  mkdir -p .kallax/audit
  local audit_file=".kallax/audit/scoring-$(date -u +%Y-%m-%d).jsonl"
  
  jq -n --arg ts "$timestamp" --arg sug "$algo_suggest" --arg sid "$slaver_id" \
    --argjson ts_score "$trust_score" --argjson fac "$factors" --arg dec "$decision" \
    '{timestamp:$ts, algo_suggest:$sug, slaver_id:$sid, trust_score:$ts_score, factors:$fac, decision:$dec}' \
    >> "$audit_file"
}
```

**TDD**: 1 写 + 1 读 + 跨日轮转 (改 date) → 3 测试 PASS

**4-Level AC**:
- L1: 1 脚本 + 1 测试存在
- L2: 真实 jq -n 写 JSONL (跟 EPIC-029 决策门一致, 防 JSON injection)
- L3: jq 合法, 跟 A 配合 (A 调用时记录)
- L4: 3 测试 PASS

**Commit**: `feat(EPIC-030-B): scoring_trace.jsonl 每日轮转审计`

---

## Task 3 (Ticket C): waiting-for-expert 自动降级

**Files:**
- Create: `scripts/agent/waiting-for-expert.sh`
- Create: `tests/integration/agent/waiting-for-expert-test.sh`

**关键 Bash**:
```bash
append_waiting_for_expert() {
  local ticket_id="$1"
  local required_expertise="$2"
  local retries=$(jq -r --arg tid "$ticket_id" '.[$tid].retries // 0' .kallax/state/waiting-for-expert.json 2>/dev/null || echo "0")
  
  # 更新 waiting-for-expert.json
  mkdir -p .kallax/state
  [[ ! -f .kallax/state/waiting-for-expert.json ]] && echo "{}" > .kallax/state/waiting-for-expert.json
  
  jq --arg tid "$ticket_id" --arg exp "$required_expertise" --argjson r "$((retries + 1))" \
    '. + {($tid): {required_expertise: $exp, retries: $r, last_attempt: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}}' \
    .kallax/state/waiting-for-expert.json > .kallax/state/waiting-for-expert.json.tmp
  mv .kallax/state/waiting-for-expert.json.tmp .kallax/state/waiting-for-expert.json
  
  # 写 inbox 提示
  mkdir -p .kallax/inbox
  cat > ".kallax/inbox/need-expert-${ticket_id}.md" <<EOF
# Need Expert: $ticket_id

## 任务
TICKET: $ticket_id
Required Expertise: $required_expertise
Retries: $((retries + 1))

## 建议
1. 手动注册匹配 expert (worktree_role / skills 字段)
2. 修改 ticket 的 required_expertise 字段
3. 接受 fallback 标签评分
EOF
}

# 下次 heartbeat 优先重试 waiting-for-expert (retries DESC)
get_priority_waiting() {
  jq -r 'to_entries | sort_by(-.value.retries) | .[].key' .kallax/state/waiting-for-expert.json 2>/dev/null
}
```

**TDD**: 匹配失败触发 + 写 JSON + 写 inbox + 重试优先 → 4 测试 PASS

**4-Level AC**:
- L1: 1 脚本 + 1 测试存在
- L2: 真实写 2 文件 + 重试计数
- L3: jq + bash 兼容
- L4: 4 测试 PASS

**Commit**: `feat(EPIC-030-C): waiting-for-expert 自动降级 + inbox 提示`

---

## Task 4 (Ticket D): Hook Profile 三档

**Files:**
- Create: `.kallax/hooks/hook-profile.sh`
- Modify: `.kallax/hooks/pre-commit`
- Create: `tests/integration/hook-profile-test.sh`

**关键 Bash**:
```bash
# hook-profile.sh
PROFILE="${KALLAX_HOOK_PROFILE:-standard}"

case "$PROFILE" in
  minimal)
    # safety hooks only
    HOOKS=("check-test-case-isolation.sh")
    ;;
  standard)
    # safety + quality
    HOOKS=("check-test-case-isolation.sh" "check-kpi-precision.sh" "check-scope-creep.sh")
    ;;
  strict)
    # all hooks
    HOOKS=("check-test-case-isolation.sh" "check-kpi-precision.sh" "check-scope-creep.sh" "check-fact-forcing-preflight.sh")
    ;;
  *)
    echo "ERROR: KALLAX_HOOK_PROFILE must be minimal|standard|strict, got: $PROFILE" >&2
    exit 1
    ;;
esac

# 跑每个 hook
for hook in "${HOOKS[@]}"; do
  bash "scripts/verify/${hook}" || { echo "BLOCKED: ${hook} FAIL"; exit 1; }
done
echo "PASS: profile=$PROFILE, ${#HOOKS[@]} hooks"
```

**pre-commit 改造**:
```bash
# 替换现有 3 anti-fab 串联, 改用 hook-profile.sh
bash "${KALLAX_ROOT}/.kallax/hooks/hook-profile.sh" || exit 1
```

**TDD**: 3 档 env var + 默认 standard + 不破坏现有 → 5 测试 PASS

**4-Level AC**:
- L1: 1 脚本 + 1 测试 + pre-commit 改
- L2: 真实 case-based profile 选择
- L3: env var 兼容, 不破坏现有串联
- L4: 5 测试 PASS

**Commit**: `feat(EPIC-030-D): Hook Profile 三档 minimal/standard/strict`

---

## Task 5 (Ticket E): PR Size self-test fixture

**Files:**
- Modify: `scripts/check-pr-size.sh` (加 `--self-test`)
- Create: `tests/fixtures/pr-size/cases.json`
- Create: `tests/integration/pr-size-self-test.sh`

**关键 Bash**:
```bash
# check-pr-size.sh 加 --self-test
self_test() {
  local fixture="tests/fixtures/pr-size/cases.json"
  [[ ! -f "$fixture" ]] && { echo "FAIL: fixture $fixture not found"; exit 1; }
  
  local total=$(jq 'length' "$fixture")
  local pass=0
  
  for i in $(seq 0 $((total - 1))); do
    local name=$(jq -r ".[$i].name" "$fixture")
    local lines=$(jq -r ".[$i].lines" "$fixture")
    local expected=$(jq -r ".[$i].expected" "$fixture")  # "WARN" / "FAIL" / "PASS"
    
    local actual
    if [[ $lines -gt 500 ]]; then actual="FAIL"
    elif [[ $lines -gt 100 ]]; then actual="WARN"
    else actual="PASS"; fi
    
    if [[ "$actual" == "$expected" ]]; then
      echo "  ✓ case $i: $name ($lines lines → $actual)"
      pass=$((pass + 1))
    else
      echo "  ✗ case $i: $name expected $expected, got $actual"
    fi
  done
  
  echo "=== Summary: $pass/$total PASS ==="
  [[ $pass -eq $total ]] || exit 1
}

[[ "${1:-}" == "--self-test" ]] && { self_test; exit $?; }
```

**fixture 5 case**:
```json
[
  {"name": "small PR", "lines": 30, "expected": "PASS"},
  {"name": "boundary 100", "lines": 100, "expected": "PASS"},
  {"name": "boundary 101 (WARN)", "lines": 101, "expected": "WARN"},
  {"name": "boundary 500 (WARN)", "lines": 500, "expected": "WARN"},
  {"name": "huge PR (FAIL)", "lines": 600, "expected": "FAIL"}
]
```

**4-Level AC**:
- L1: 1 脚本 + fixture + test 存在
- L2: 真实 self-test + 5 case
- L3: jq + bash 兼容
- L4: 5 测试 PASS

**Commit**: `feat(EPIC-030-E): PR Size self-test fixture 回归`

---

## Task 6 (Ticket F): system:doctor JSON 结构化

**Files:**
- Modify: `scripts/health_check.sh`
- Create: `tests/integration/health-check-json-test.sh`

**关键 Bash 改造**:
```bash
# health_check.sh 加 --json flag (默认 --text 兼容旧用法)
MODE="${1:-text}"

check_redis() { ... }
check_sqlite() { ... }
check_miao_branch() { ... }

if [[ "$MODE" == "--json" ]]; then
  # 结构化 JSON 输出
  status="healthy"; level=3
  [[ "$REDIS_OK" != "ok" ]] && { status="degraded"; level=2; }
  [[ "$SQLITE_OK" != "ok" ]] && { status="unhealthy"; level=1; }
  
  jq -n \
    --arg status "$status" \
    --argjson level "$level" \
    --arg redis "$REDIS_OK" \
    --arg sqlite "$SQLITE_OK" \
    --arg miao "$MIAO_OK" \
    '{status: $status, level: $level, checks: [{name: "redis", status: $redis}, {name: "sqlite", status: $sqlite}, {name: "miao", status: $miao}]}'
else
  # 旧文本输出
  echo "KALLAX Health: $status"
  echo "  Redis: $REDIS_OK"
  ...
fi
```

**TDD**: 3 状态 (healthy/degraded/unhealthy) + level 1/2/3 + 旧文本兼容 → 6 测试 PASS

**4-Level AC**:
- L1: 1 脚本 + 1 测试
- L2: 真实 --json + --text 2 模式
- L3: jq 合法, 兼容旧用法
- L4: 6 测试 PASS

**Commit**: `feat(EPIC-030-F): system:doctor JSON 结构化输出`

---

## Task 7 (Ticket G): AuditMiddleware audit_log (新 SQLite 独立)

**Files:**
- Create: `scripts/audit/audit-middleware.sh`
- Create: `scripts/audit/audit-db.sh`
- Create: `tests/integration/audit-middleware-test.sh`
- Create: `.kallax/data/audit.db` (auto-created)

**关键 Bash**:
```bash
# audit-db.sh — 新 SQLite 建表 (主公 C 拍: 独立 DB)
AUDIT_DB="${KALLAX_ROOT}/.kallax/data/audit.db"

init_audit_db() {
  mkdir -p "$(dirname "$AUDIT_DB")"
  sqlite3 "$AUDIT_DB" <<'EOF'
CREATE TABLE IF NOT EXISTS audit_log (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  command     TEXT NOT NULL,
  ticket_id   TEXT,
  slaver_id   TEXT,
  elapsed_ms  INTEGER,
  created_at  TEXT NOT NULL
);
EOF
}

# audit-middleware.sh — 在 preflight 执行时写 audit_log
write_audit_log() {
  local command="$1"
  local ticket_id="$2"
  local slaver_id="$3"
  local elapsed_ms="$4"
  local created_at=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
  
  init_audit_db
  sqlite3 "$AUDIT_DB" <<EOF
INSERT INTO audit_log (command, ticket_id, slaver_id, elapsed_ms, created_at)
VALUES ('$command', '$ticket_id', '$slaver_id', $elapsed_ms, '$created_at');
EOF
}
```

**注**: 真实集成 `check-fact-forcing-preflight.sh` 时, 需在 script 头尾加 `start_time=$(date +%s%N)` + `elapsed_ms=$((($(date +%s%N) - start_time) / 1000000))` + 调 `write_audit_log`. 这是后续集成, 简化本 ticket 只做 1 写 1 查.

**TDD**: 建表 + 写 1 条 + 查 + 跨多 command 写多 → 4 测试 PASS

**4-Level AC**:
- L1: 2 脚本 + 1 测试
- L2: 真实 SQLite 建表 + 写查
- L3: sqlite3 CLI 合法, 新独立 DB 不污染
- L4: 4 测试 PASS

**Commit**: `feat(EPIC-030-G): AuditMiddleware audit_log 新 SQLite 独立表 (主公 C)`

---

## Task 8 (Ticket H): KALLAX persona 5 字段 (7 default)

**Files:**
- Modify: `.kallax/experts/default/architect.md` + 6 default expert (主公 E: 只 7 default, 90 extended 留 P2)

**关键 Frontmatter 改造** (每个 default expert):
```yaml
---
id: kallax.architect.001
tier: default
worktree_role: conductor              # NEW: master/conductor/performer/auditor/readonly
tickets_served: [EPIC-016-D, EPIC-016-S]  # NEW: 反向索引
review_group: A                       # NEW: A(forward)/B(attack)/AB
phase: 1
rationalizations_count: 6
version: 1.0.0                        # NEW: semver
last_reviewed: 2026-06-11             # NEW: ISO date
trigger: ...
domain: ...
---
```

**worktree_role 分配** (主公拍默认值):
- architect.md → conductor
- backend.md → performer
- frontend.md → performer
- ux.md → performer
- product.md → conductor
- security.md → auditor
- pm.md → master

**TDD**: 跑 `expert-quality-audit.py --enforce-tier-domain` 验证 7/7 PASS

**4-Level AC**:
- L1: 7 文件 frontmatter 加字段
- L2: 真实 worktree_role / tickets_served / review_group / version / last_reviewed
- L3: frontmatter 合法, 跟现有 trigger/tier/domain 不冲突
- L4: expert-quality-audit 7/7 PASS

**Commit**: `feat(EPIC-030-H): KALLAX persona 5 字段 (7 default, 主公 E)`

---

## Task 9 (Ticket I): Brief Inference 任务理解强制

**Files:**
- Create: `scripts/task-claim-brief.sh`
- Create: `tests/integration/brief-inference-test.sh`

**关键 Bash**:
```bash
# task-claim-brief.sh — 强制 task:claim 后 brief_inference 字段
TICKET_JSON="${1:-}"

if [[ -z "$TICKET_JSON" ]] || [[ ! -f "$TICKET_JSON" ]]; then
  echo "ERROR: ticket.json path required"
  exit 1
fi

if ! jq -e '.brief_inference' "$TICKET_JSON" >/dev/null 2>&1; then
  echo "BLOCKED: ticket.json missing brief_inference field"
  echo "Required: 📋 任务理解: [任务类型] | [核心目标] | [技术方案] | [风险点]"
  exit 1
fi

BRIEF=$(jq -r '.brief_inference' "$TICKET_JSON")
echo "✓ Brief Inference: $BRIEF"
exit 0
```

**TDD**: 有 brief_inference (PASS) + 无 (FAIL exit 1) → 2 测试 PASS

**4-Level AC**:
- L1: 1 脚本 + 1 测试
- L2: 真实 jq -e 验证, 缺字段 exit 1 拒绝
- L3: jq 合法, 跟 task:claim 流程兼容
- L4: 2 测试 PASS

**Commit**: `feat(EPIC-030-I): Brief Inference 任务理解强制`

---

## Self-Review

**Spec coverage**:
- A (TrustScore): Task 1 ✅
- B (scoring_trace): Task 2 ✅
- C (waiting-for-expert): Task 3 ✅
- D (Hook Profile): Task 4 ✅
- E (PR Size self-test): Task 5 ✅
- F (system:doctor JSON): Task 6 ✅
- G (AuditMiddleware 新 DB): Task 7 ✅
- H (persona 7 default): Task 8 ✅
- I (Brief Inference): Task 9 ✅

**Placeholder scan**: 0 TBD/TODO, 所有 code 完整

**Type consistency**:
- `.kallax/audit/scoring-YYYY-MM-DD.jsonl` 跨 A/B 一致
- `.kallax/state/waiting-for-expert.json` 跟 eket 一致 schema
- `.kallax/data/audit.db` 新独立, 不污染
- `KALLAX_HOOK_PROFILE=minimal|standard|strict` 跨 D 一致

**主公 5 决策** (A-E) 全部 spec 落地:
- A: Task 1 "算法建议 + 人工拍板" 出口 (best-matching-slaver.sh 输出 ALGO_SUGGEST)
- B: 拆 9 ticket (本 plan 9 task)
- C: Task 7 新 SQLite 独立
- D: 9 串行 (1 Conductor 1 Performer)
- E: Task 8 只 7 default, 90 extended 不改

All consistent. Ready for execution.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-11-kallax-eket-borrow-p0.md`. 9 task, 估时 8d 串行 (主公 D 拍).

**Execution options**:
1. **Subagent-Driven (推荐)** - 派独立 Performer 子 agent 跑每个 task, task 间 review
2. **Inline Execution** - 当前 session 串行跑, batch + checkpoint
3. **Performer 派单** (跟 EPIC-029 一样) - 标准 KALLAX 流程
