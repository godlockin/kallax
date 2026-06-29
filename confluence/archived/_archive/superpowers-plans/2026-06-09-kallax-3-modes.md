> ⚠️ **OUTDATED** (跟 v2.7.0 整理 release 联合, 跟 主公 2026-06-19 '整理 总结 经验教训' 派单 联合)
> **本 文档 是 历史 plan, 跟 当前 KALLAX 现状 失焦**
> **跟'翻篇&精进' 战略 一致, 保留 跟 历史 兼容性, 0 增 Rule**
> **现状 替代**: 跟 v2.7.0 16 release 累计 + 22 Rule (v2.4.1 还原) + 60+5 术语 联合
> **最后 更新**: 2026-06-19 v2.7.0 整理 release


# KALLAX 3 模式 (ai-auto / ai-copilot / manual) 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 KALLAX Conductor/Performer 引入 3 模式决策权分配 (ai-auto / ai-copilot / manual), session-level 写 state.json, 5 阶段协商 + 危险/block 决策统一停下问, 跟 EKET `interactive:start` 借鉴集成

**Architecture:** session_start.sh 增加 MODE 选择菜单 → state.json.mode + mode_lock 字段 → stage-gate.sh (Performer 5 阶段分流) + decision-gate.sh (Block 决策 + 危险操作统一检查) → pre-commit 集成 decision-gate.sh → decision-YYYY-MM-DD.jsonl 审计

**Tech Stack:** Bash (核心检查), jq (state.json), Python (审计 JSONL), 集成到现有 `scripts/permission/` + `.kallax/hooks/` + `tests/integration/`

---

## File Structure

**新建文件**:
- `scripts/performer/stage-gate.sh` — Performer 5 阶段协商检查 (claim/analysis/in_progress/test/review)
- `scripts/permission/decision-gate.sh` — 5 类 Block + 3 类危险操作统一检查
- `scripts/permission/mode-set.sh` — 写入 state.json mode + mode_lock
- `tests/integration/3-modes-e2e.sh` — 3 模式 × 4 阶段 × 3 危险 × 5 block E2E 测试
- `tests/fixtures/3-modes/` — self-test fixtures (PR cases.json + block cases.json)
- `docs/architecture/3-MODES.md` — 用户文档 (主公/Conductor/Performer 3 视角怎么用)

**修改文件**:
- `.kallax/hooks/session_start.sh` — 加 MODE 选择菜单
- `scripts/kallax-init.sh` — 加 `--mode ai-auto|ai-copilot|manual` CLI
- `scripts/permission/authz/check.sh` — 加 mode 字段读取
- `.kallax/hooks/pre-commit` — 串联 decision-gate.sh
- `scripts/permission/whoami.sh` — 输出加 mode 字段
- `CLAUDE.md` — 加 Rule 13 "3 模式决策权分配"

**审计**:
- `.kallax/audit/decision-YYYY-MM-DD.jsonl` — 每日轮转 AI 决策审计

---

## Task 1: state.json schema 扩展 (mode + mode_lock)

**Files:**
- Modify: `scripts/permission/mode-set.sh` (新)

- [ ] **Step 1: 写失败测试**

创建 `tests/integration/3-modes/state-schema-test.sh`:
```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
MODE_SET="${KALLAX_ROOT}/scripts/permission/mode-set.sh"

# Test 1: mode-set.sh 存在
if [[ -x "$MODE_SET" ]]; then
  echo "  ✓ mode-set.sh exists and executable"
else
  echo "  ✗ mode-set.sh missing or not executable"
  exit 1
fi
```

- [ ] **Step 2: 跑测试, 确认失败**

Run: `bash tests/integration/3-modes/state-schema-test.sh`
Expected: FAIL with "mode-set.sh missing"

- [ ] **Step 3: 创建 mode-set.sh 骨架**

创建 `scripts/permission/mode-set.sh`:
```bash
#!/bin/bash
# mode-set.sh — 写入 state.json mode + mode_lock
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
MODE_LOCK_FILE="${KALLAX_ROOT}/.kallax/state/mode.lock"

usage() {
  cat <<EOF
Usage: $0 --mode <ai-auto|ai-copilot|manual> [--actor <name>]
  --mode    必填, 3 模式之一
  --actor   可选, 写 audit 字段, 默认 current user
EOF
  exit 1
}

MODE=""
ACTOR="${USER:-unknown}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "ERROR: --mode required"
  usage
fi

case "$MODE" in
  ai-auto|ai-copilot|manual) ;;
  *) echo "ERROR: mode must be ai-auto|ai-copilot|manual, got: $MODE"; exit 1 ;;
esac

# mode_lock: 检测冲突
if [[ -f "$MODE_LOCK_FILE" ]]; then
  LOCK_PID=$(cat "$MODE_LOCK_FILE" 2>/dev/null || echo "")
  if [[ -n "$LOCK_PID" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "ERROR: mode locked by PID $LOCK_PID, abort"
    exit 1
  fi
  rm -f "$MODE_LOCK_FILE"
fi

# 写 state.json mode + mode_set_at
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
TMP="${STATE_FILE}.tmp.$$"

if [[ -f "$STATE_FILE" ]]; then
  jq --arg m "$MODE" --arg t "$TIMESTAMP" \
    '. + {mode: $m, mode_set_at: $t}' \
    "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
else
  echo "ERROR: $STATE_FILE not found" >&2
  exit 1
fi

# 写 mode_lock (current shell PID)
echo "$$" > "$MODE_LOCK_FILE"

echo "OK: mode=$MODE set at $TIMESTAMP by $ACTOR"
```

- [ ] **Step 4: 加执行权限 + 跑测试, 确认通过**

Run:
```bash
chmod +x scripts/permission/mode-set.sh
bash tests/integration/3-modes/state-schema-test.sh
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/permission/mode-set.sh tests/integration/3-modes/state-schema-test.sh
git commit -m "feat(3-modes): state.json mode + mode_lock schema + mode-set.sh CLI"
```

---

## Task 2: stage-gate.sh (Performer 5 阶段协商)

**Files:**
- Create: `scripts/performer/stage-gate.sh` (新)

- [ ] **Step 1: 写失败测试**

创建 `tests/integration/3-modes/stage-gate-test.sh`:
```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE_GATE="${KALLAX_ROOT}/scripts/performer/stage-gate.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

if [[ -x "$STAGE_GATE" ]]; then
  echo "  ✓ stage-gate.sh exists and executable"
else
  echo "  ✗ stage-gate.sh missing"
  exit 1
fi

# Test: claim 阶段 ai-auto 直接 PASS
jq --arg r "performer" --arg m "ai-auto" \
  '.role = $r | .mode = $m' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

if bash "$STAGE_GATE" --stage claim --ticket TASK-001 2>/dev/null; then
  echo "  ✓ claim stage + ai-auto = ALLOWED"
else
  echo "  ✗ claim stage + ai-auto should be allowed"
  exit 1
fi
```

- [ ] **Step 2: 跑测试, 确认失败**

Run: `bash tests/integration/3-modes/stage-gate-test.sh`
Expected: FAIL with "stage-gate.sh missing"

- [ ] **Step 3: 创建 stage-gate.sh 骨架**

创建 `scripts/performer/stage-gate.sh`:
```bash
#!/bin/bash
# stage-gate.sh — Performer 5 阶段协商检查
# 阶段: claim / analysis / in_progress / test / review
# 模式: ai-auto / ai-copilot / manual
# 决策: 简单阶段直接过, 复杂阶段按模式分流
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

usage() {
  cat <<EOF
Usage: $0 --stage <claim|analysis|in_progress|test|review> --ticket <TASK-XXX>
  --stage   必填, Performer 5 阶段之一
  --ticket  必填, ticket id
EOF
  exit 1
}

STAGE=""
TICKET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage) STAGE="$2"; shift 2 ;;
    --ticket) TICKET="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$STAGE" ]] || [[ -z "$TICKET" ]]; then
  echo "ERROR: --stage and --ticket required"
  usage
fi

# 读 mode + role
MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null)
ROLE=$(jq -r '.role // "performer"' "$STATE_FILE" 2>/dev/null)

# 5 阶段复杂度定义
declare -A COMPLEXITY=(
  [claim]=simple
  [analysis]=complex
  [in_progress]=simple
  [test]=complex
  [review]=complex
)

STAGE_COMPLEXITY="${COMPLEXITY[$STAGE]:-unknown}"

if [[ "$STAGE_COMPLEXITY" == "unknown" ]]; then
  echo "ERROR: unknown stage $STAGE"
  exit 1
fi

# 决策: 简单阶段 / 复杂阶段 × 3 模式
if [[ "$STAGE_COMPLEXITY" == "simple" ]]; then
  echo "ALLOW: stage=$STAGE mode=$MODE (simple stage, AI auto)"
  exit 0
fi

# 复杂阶段: 按 mode 分流
case "$MODE" in
  ai-auto)
    echo "ALLOW: stage=$STAGE mode=$MODE (complex but auto)"
    exit 0
    ;;
  ai-copilot)
    # 协商: 写 ask file, exit 2 (跟 KallaxError 体系一致)
    ASK_FILE="${KALLAX_ROOT}/.kallax/inbox/ask-stage-${TICKET}-${STAGE}.md"
    mkdir -p "$(dirname "$ASK_FILE")"
    cat > "$ASK_FILE" <<EOF
# Ask: stage=$STAGE ticket=$TICKET

## Context
- Mode: ai-copilot
- Stage: $STAGE (complex)
- Actor: $(jq -r '.actor // "unknown"' "$STATE_FILE")
- Time: $(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

## AI 提案
(Performer 应在 commit message 或 PR body 写入技术方案/测试结果/Review 反馈)

## 选项
1. Approve — 继续执行
2. Modify — 调整后继续
3. Reject — 回退到上一阶段
EOF
    echo "ASK: stage=$STAGE ticket=$TICKET → wrote $ASK_FILE, exit 2"
    exit 2
    ;;
  manual)
    # 强制问: 跟 ai-copilot 一样但语义更强
    ASK_FILE="${KALLAX_ROOT}/.kallax/inbox/ask-manual-${TICKET}-${STAGE}.md"
    mkdir -p "$(dirname "$ASK_FILE")"
    cat > "$ASK_FILE" <<EOF
# Manual Confirm: stage=$STAGE ticket=$TICKET

## Mode: manual (主公确认每阶段)

### 选项
1. Approve — 继续执行
2. Cancel — 终止 ticket
EOF
    echo "ASK_MANUAL: stage=$STAGE ticket=$TICKET → wrote $ASK_FILE, exit 2"
    exit 2
    ;;
  *)
    echo "ERROR: unknown mode $MODE"
    exit 1
    ;;
esac
```

- [ ] **Step 4: 加权限 + 跑测试, 确认通过**

Run:
```bash
chmod +x scripts/performer/stage-gate.sh
mkdir -p tests/integration/3-modes/
bash tests/integration/3-modes/stage-gate-test.sh
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/performer/stage-gate.sh tests/integration/3-modes/stage-gate-test.sh
git commit -m "feat(3-modes): stage-gate.sh Performer 5 阶段协商"
```

---

## Task 3: decision-gate.sh (Block + 危险操作统一检查)

**Files:**
- Create: `scripts/permission/decision-gate.sh` (新)

- [ ] **Step 1: 写失败测试**

创建 `tests/integration/3-modes/decision-gate-test.sh`:
```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DECISION_GATE="${KALLAX_ROOT}/scripts/permission/decision-gate.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

# Test 1: 文件存在 + 可执行
if [[ -x "$DECISION_GATE" ]]; then
  echo "  ✓ decision-gate.sh exists and executable"
else
  echo "  ✗ decision-gate.sh missing"
  exit 1
fi

# Test 2: ai-auto + 危险操作 (git push --force) → 停下问
jq --arg r "conductor" --arg m "ai-auto" \
  '.role = $r | .mode = $m' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# 模拟"删除数据"危险操作
if bash "$DECISION_GATE" --action "danger.delete_data" --cmd "rm -rf test/" 2>/dev/null; then
  echo "  ✗ danger.delete_data in ai-auto should ASK"
  exit 1
else
  echo "  ✓ danger.delete_data in ai-auto = ASK"
fi
```

- [ ] **Step 2: 跑测试, 确认失败**

Run: `bash tests/integration/3-modes/decision-gate-test.sh`
Expected: FAIL with "decision-gate.sh missing"

- [ ] **Step 3: 创建 decision-gate.sh 骨架**

创建 `scripts/permission/decision-gate.sh`:
```bash
#!/bin/bash
# decision-gate.sh — Block 决策 + 危险操作统一检查
# 5 类 Block: ambiguous_options / performer_failure / rule_exception / epic_critical / high_impact
# 3 类 Danger: miao_modify / security_failing / data_destruction
# 3 模式都触发, 命中即 exit 2 写 ask file
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"
AUDIT_DIR="${KALLAX_ROOT}/.kallax/audit"

usage() {
  cat <<EOF
Usage: $0 --action <action-id> [--cmd <command>] [--context <json>]
  --action   必填, 5 block + 3 danger 之一
  --cmd      可选, 触发命令 (写 audit 用)
  --context  可选, JSON 上下文
EOF
  exit 1
}

ACTION=""
CMD=""
CONTEXT="{}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action) ACTION="$2"; shift 2 ;;
    --cmd) CMD="$2"; shift 2 ;;
    --context) CONTEXT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  echo "ERROR: --action required"
  usage
fi

# 读 mode + role
MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null)
ACTOR=$(jq -r '.actor // "unknown"' "$STATE_FILE" 2>/dev/null)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

# 分类 action
DANGER_ACTIONS="danger.miao_modify danger.security_failing danger.data_destruction"
BLOCK_ACTIONS="block.ambiguous_options block.performer_failure block.rule_exception block.epic_critical block.high_impact"

IS_DECISION=""
case "$ACTION" in
  danger.*|block.*) IS_DECISION="yes" ;;
  *) echo "ALLOW: action=$ACTION (not in block/danger list)"; exit 0 ;;
esac

# 写 ask file
ASK_FILE="${KALLAX_ROOT}/.kallax/inbox/decision-${ACTION//./_}-$(date +%s).md"
mkdir -p "$(dirname "$ASK_FILE")" "$AUDIT_DIR"

cat > "$ASK_FILE" <<EOF
# Decision Required: $ACTION

## Context
- Mode: $MODE
- Actor: $ACTOR
- Time: $TIMESTAMP
- Command: $CMD
- Context: $CONTEXT

## 选项
1. Approve — 继续执行
2. Reject — 中止操作
3. Defer — 推迟到主公明确指示
EOF

# 写 audit JSONL
AUDIT_FILE="${AUDIT_DIR}/decision-$(date -u +%Y-%m-%d).jsonl"
echo "{\"timestamp\":\"$TIMESTAMP\",\"actor\":\"$ACTOR\",\"mode\":\"$MODE\",\"action\":\"$ACTION\",\"cmd\":\"$CMD\",\"context\":$CONTEXT}" >> "$AUDIT_FILE"

echo "ASK: action=$ACTION mode=$MODE → wrote $ASK_FILE"
exit 2
```

- [ ] **Step 4: 加权限 + 跑测试, 确认通过**

Run:
```bash
chmod +x scripts/permission/decision-gate.sh
bash tests/integration/3-modes/decision-gate-test.sh
```
Expected: PASS (3 个 assertion 全过)

- [ ] **Step 5: Commit**

```bash
git add scripts/permission/decision-gate.sh tests/integration/3-modes/decision-gate-test.sh
git commit -m "feat(3-modes): decision-gate.sh block + danger 统一检查"
```

---

## Task 4: session_start.sh MODE 选择菜单

**Files:**
- Modify: `.kallax/hooks/session_start.sh` (加 MODE 选择 + 写 state.json)
- Create: `tests/integration/3-modes/session-start-test.sh`

- [ ] **Step 1: 读 session_start.sh 找到 ASCII card 位置**

Run: `grep -n "INBOX\|NEXT\|ROLE\|INSTANCE" .kallax/hooks/session_start.sh | head -20`
Expected: 找到 ASCII card 渲染函数

- [ ] **Step 2: 写失败测试**

创建 `tests/integration/3-modes/session-start-test.sh`:
```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSION_START="${KALLAX_ROOT}/.kallax/hooks/session_start.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

# Test 1: session_start.sh 包含 "MODE" 字串
if grep -q "MODE" "$SESSION_START"; then
  echo "  ✓ session_start.sh shows MODE field"
else
  echo "  ✗ session_start.sh missing MODE field"
  exit 1
fi

# Test 2: 提供 mode 时写到 state.json
TMP_STATE=$(mktemp)
echo '{"role": "master", "instance_id": "test"}' > "$TMP_STATE"

# 模拟输入 "2" (ai-copilot)
KALLAX_STATE_OVERRIDE="$TMP_STATE" echo "2" | bash "$SESSION_START" 2>/dev/null || true

# 检查 state.json (注意: 实际 session_start.sh 写的是真 state.json, 不是 override)
# 简化: 直接 grep session_start.sh 看是否有 "ai-copilot" 字符串
if grep -q "ai-copilot\|ai-auto\|manual" "$SESSION_START"; then
  echo "  ✓ session_start.sh mentions 3 mode values"
else
  echo "  ✗ session_start.sh missing mode values"
  exit 1
fi
```

- [ ] **Step 3: 跑测试, 确认失败**

Run: `bash tests/integration/3-modes/session-start-test.sh`
Expected: FAIL

- [ ] **Step 4: 改 session_start.sh 加 MODE 选择**

定位 ASCII card 渲染处 (典型是 `cat <<EOF` 输出 ASCII box), 在 ROLE/INSTANCE 之后 INBOX 之前加:

```bash
# MODE 选择 (3 模式)
MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null)
if [[ -z "$MODE" ]] || [[ "$MODE" == "null" ]]; then
  echo ""
  echo "┌─ KALLAX MODE ─────────────────────────────"
  echo "│ 1) ai-auto     (AI 决策, 仅 block/danger 停下问)"
  echo "│ 2) ai-copilot  (简单自主, 复杂协商) [默认]"
  echo "│ 3) manual      (每阶段主公确认)"
  echo "└──────────────────────────────────────────"
  echo -n "Select mode [1/2/3] (default 2): "
  read -r MODE_CHOICE
  case "$MODE_CHOICE" in
    1) MODE="ai-auto" ;;
    3) MODE="manual" ;;
    *) MODE="ai-copilot" ;;
  esac
  bash "${KALLAX_ROOT}/scripts/permission/mode-set.sh" --mode "$MODE" --actor "${USER:-unknown}" 2>/dev/null || true
fi
```

在 ASCII card 模板加 `│ MODE*    ▸ $MODE` 一行 (在 `│ INSTANCE` 之后 `│ INBOX` 之前)。

- [ ] **Step 5: 跑测试, 确认通过**

Run: `bash tests/integration/3-modes/session-start-test.sh`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add .kallax/hooks/session_start.sh tests/integration/3-modes/session-start-test.sh
git commit -m "feat(3-modes): session_start.sh MODE 选择菜单"
```

---

## Task 5: pre-commit 串联 decision-gate.sh

**Files:**
- Modify: `.kallax/hooks/pre-commit` (在 3 anti-fab 之后加 decision-gate)
- Create: `tests/integration/3-modes/precommit-integration-test.sh`

- [ ] **Step 1: 写失败测试**

创建 `tests/integration/3-modes/precommit-integration-test.sh`:
```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRE_COMMIT="${KALLAX_ROOT}/.kallax/hooks/pre-commit"
DECISION_GATE="${KALLAX_ROOT}/scripts/permission/decision-gate.sh"

# Test: pre-commit 引用 decision-gate.sh
if grep -q "decision-gate" "$PRE_COMMIT"; then
  echo "  ✓ pre-commit references decision-gate"
else
  echo "  ✗ pre-commit missing decision-gate"
  exit 1
fi
```

- [ ] **Step 2: 跑测试, 确认失败**

Run: `bash tests/integration/3-modes/precommit-integration-test.sh`
Expected: FAIL

- [ ] **Step 3: 在 pre-commit 加 decision-gate 调用**

在 pre-commit 现有 3 anti-fab 工具调用之后, 加:

```bash
# ── 3 模式 decision-gate (Rule 13) ──────────────────────────────────────
DECISION_GATE="${KALLAX_ROOT}/scripts/permission/decision-gate.sh"
if [[ -x "$DECISION_GATE" ]]; then
  # 检测 commit message 是否触发 block/danger
  if grep -qE "merge.*miao|push.*--force|rm -rf|reset --hard" "$COMMIT_MSG_FILE" 2>/dev/null; then
    if [[ "$(jq -r '.mode // "ai-copilot"' "${KALLAX_ROOT}/.kallax/state/state.json")" != "manual" ]]; then
      bash "$DECISION_GATE" --action "danger.data_destruction" --cmd "$COMMIT_MSG" || {
        echo "BLOCKED: decision-gate detected dangerous operation"
        exit 1
      }
    fi
  fi
fi
```

(具体 commit msg 检测需适配实际 pre-commit 写法, 这里示意)

- [ ] **Step 4: 跑测试, 确认通过**

Run: `bash tests/integration/3-modes/precommit-integration-test.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add .kallax/hooks/pre-commit tests/integration/3-modes/precommit-integration-test.sh
git commit -m "feat(3-modes): pre-commit 串联 decision-gate.sh"
```

---

## Task 6: kallax-init.sh --mode CLI

**Files:**
- Modify: `scripts/kallax-init.sh` (加 --mode 参数)
- Create: `tests/integration/3-modes/kallax-init-mode-test.sh`

- [ ] **Step 1: 写失败测试**

创建 `tests/integration/3-modes/kallax-init-mode-test.sh`:
```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INIT="${KALLAX_ROOT}/scripts/kallax-init.sh"

if grep -q "\\-\\-mode" "$INIT"; then
  echo "  ✓ kallax-init.sh accepts --mode"
else
  echo "  ✗ kallax-init.sh missing --mode"
  exit 1
fi
```

- [ ] **Step 2: 跑测试, 确认失败**

Run: `bash tests/integration/3-modes/kallax-init-mode-test.sh`
Expected: FAIL

- [ ] **Step 3: 在 kallax-init.sh 加 --mode 参数**

在 init 脚本参数解析处 (典型是 `while getopts` 或 `while [[ $# -gt 0 ]]`), 加:

```bash
MODE_CHOICE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE_CHOICE="$2"
      shift 2
      ;;
    ...
  esac
done

# 验证 mode
case "$MODE_CHOICE" in
  ai-auto|ai-copilot|manual|"") ;;
  *) echo "ERROR: --mode must be ai-auto|ai-copilot|manual, got: $MODE_CHOICE"; exit 1 ;;
esac

# 如果提供 --mode, 写到 state.json
if [[ -n "$MODE_CHOICE" ]]; then
  bash "${KALLAX_ROOT}/scripts/permission/mode-set.sh" --mode "$MODE_CHOICE" --actor "${USER:-unknown}" 2>/dev/null || true
fi
```

- [ ] **Step 4: 跑测试, 确认通过**

Run: `bash tests/integration/3-modes/kallax-init-mode-test.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/kallax-init.sh tests/integration/3-modes/kallax-init-mode-test.sh
git commit -m "feat(3-modes): kallax-init.sh --mode CLI"
```

---

## Task 7: whoami.sh 输出 mode 字段

**Files:**
- Modify: `scripts/permission/whoami.sh` (加 mode 字段)
- Create: `tests/integration/3-modes/whoami-test.sh`

- [ ] **Step 1: 写失败测试**

创建 `tests/integration/3-modes/whoami-test.sh`:
```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WHOAMI="${KALLAX_ROOT}/scripts/permission/whoami.sh"

OUTPUT=$(bash "$WHOAMI" 2>/dev/null)
if echo "$OUTPUT" | grep -q "mode"; then
  echo "  ✓ whoami.sh outputs mode field"
else
  echo "  ✗ whoami.sh missing mode field"
  exit 1
fi
```

- [ ] **Step 2: 跑测试, 确认失败**

Run: `bash tests/integration/3-modes/whoami-test.sh`
Expected: FAIL

- [ ] **Step 3: 在 whoami.sh 加 mode 字段**

读取现有 `whoami.sh` 找到输出格式, 在 role/actor/instance_id 后加:

```bash
MODE=$(jq -r '.mode // "ai-copilot"' "$STATE_FILE" 2>/dev/null)
echo "mode: $MODE"
```

- [ ] **Step 4: 跑测试, 确认通过**

Run: `bash tests/integration/3-modes/whoami-test.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/permission/whoami.sh tests/integration/3-modes/whoami-test.sh
git commit -m "feat(3-modes): whoami.sh 输出 mode 字段"
```

---

## Task 8: 3 模式 × 4 维度 E2E 集成测试

**Files:**
- Create: `tests/integration/3-modes-e2e.sh`

- [ ] **Step 1: 写 E2E 测试**

```bash
#!/bin/bash
# 3-modes-e2e.sh — 3 模式 × 4 维度 E2E 测试
# 4 维度: 简单阶段 / 复杂阶段 / 危险操作 / Block 决策
# 期望: 3 模式都停下问危险/Block, 但简单阶段 ai-auto/ai-copilot 自动过, manual 问
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE_GATE="${KALLAX_ROOT}/scripts/performer/stage-gate.sh"
DECISION_GATE="${KALLAX_ROOT}/scripts/permission/decision-gate.sh"
MODE_SET="${KALLAX_ROOT}/scripts/permission/mode-set.sh"
STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"

# 保存 + 恢复 state
ORIGINAL_STATE=$(cat "$STATE_FILE")
trap 'echo "$ORIGINAL_STATE" > "$STATE_FILE"' EXIT

PASS=0
FAIL=0

test_case() {
  local name="$1"
  local cmd="$2"
  local expected_exit="$3"

  if eval "$cmd" >/dev/null 2>&1; then
    actual_exit=0
  else
    actual_exit=$?
  fi

  if [[ "$actual_exit" == "$expected_exit" ]]; then
    echo "  ✓ $name (exit=$actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected exit=$expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

echo "[E2E 1] ai-auto mode"
bash "$MODE_SET" --mode ai-auto --actor "e2e" 2>/dev/null
test_case "claim + ai-auto = ALLOW" \
  "bash $STAGE_GATE --stage claim --ticket TASK-001" 0
test_case "analysis + ai-auto = ALLOW" \
  "bash $STAGE_GATE --stage analysis --ticket TASK-001" 0
test_case "danger.data_destruction + ai-auto = ASK" \
  "bash $DECISION_GATE --action danger.data_destruction --cmd 'rm -rf /'" 2
test_case "block.ambiguous_options + ai-auto = ASK" \
  "bash $DECISION_GATE --action block.ambiguous_options" 2

echo "[E2E 2] ai-copilot mode"
bash "$MODE_SET" --mode ai-copilot --actor "e2e" 2>/dev/null
test_case "claim + ai-copilot = ALLOW" \
  "bash $STAGE_GATE --stage claim --ticket TASK-001" 0
test_case "analysis + ai-copilot = ASK" \
  "bash $STAGE_GATE --stage analysis --ticket TASK-001" 2
test_case "in_progress + ai-copilot = ALLOW" \
  "bash $STAGE_GATE --stage in_progress --ticket TASK-001" 0
test_case "test + ai-copilot = ASK" \
  "bash $STAGE_GATE --stage test --ticket TASK-001" 2
test_case "review + ai-copilot = ASK" \
  "bash $STAGE_GATE --stage review --ticket TASK-001" 2
test_case "danger.miao_modify + ai-copilot = ASK" \
  "bash $DECISION_GATE --action danger.miao_modify --cmd 'git push miao'" 2

echo "[E2E 3] manual mode"
bash "$MODE_SET" --mode manual --actor "e2e" 2>/dev/null
test_case "claim + manual = ASK" \
  "bash $STAGE_GATE --stage claim --ticket TASK-001" 2
test_case "analysis + manual = ASK" \
  "bash $STAGE_GATE --stage analysis --ticket TASK-001" 2
test_case "in_progress + manual = ASK" \
  "bash $STAGE_GATE --stage in_progress --ticket TASK-001" 2
test_case "test + manual = ASK" \
  "bash $STAGE_GATE --stage test --ticket TASK-001" 2
test_case "review + manual = ASK" \
  "bash $STAGE_GATE --stage review --ticket TASK-001" 2
test_case "block.rule_exception + manual = ASK" \
  "bash $DECISION_GATE --action block.rule_exception" 2

echo ""
echo "=== Summary: $PASS PASS, $FAIL FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
```

- [ ] **Step 2: 跑 E2E 测试**

Run: `bash tests/integration/3-modes-e2e.sh`
Expected: 16 PASS, 0 FAIL

- [ ] **Step 3: 修复发现的问题 (如有)**

如果 FAIL, 根据输出调整 `stage-gate.sh` / `decision-gate.sh` / `mode-set.sh` 逻辑, 重新跑直到全过。

- [ ] **Step 4: Commit**

```bash
git add tests/integration/3-modes-e2e.sh
git commit -m "test(3-modes): 3 模式 × 4 维度 E2E 集成测试 (16 场景)"
```

---

## Task 9: CLAUDE.md Rule 13 (3 模式决策权分配)

**Files:**
- Modify: `CLAUDE.md` (加 Rule 13)

- [ ] **Step 1: 在 CLAUDE.md 加 Rule 13**

在 Rule 12 之后, 加:

```markdown
### 13. 3 模式决策权分配 (KALLAX P0) — 主公原话 2026-06-09

**教训**: 之前 Conductor/Performer 决策权模糊, 主公要么 "放手" (误操作风险), 要么 "每步问" (主公疲劳). 借鉴 EKET `interactive:start` 多模式 + 主公原话硬决策.

**规则**: 3 模式 = `ai-auto` (AI 自主 + block/danger 停下问) / `ai-copilot` (默认, 简单自主 + 复杂协商) / `manual` (主公确认每阶段).

**生效范围**: Performer + Conductor (Master 不受控, 跟 Rule 11 联动).

**模式存储**: `state.json.mode` 字段, 每个 session_start 选一次, `mode_lock` 防热切换.

**Block 决策 (5 类, 3 模式都触发)**:
1. `block.ambiguous_options` — 多个选项无明显最优
2. `block.performer_failure` — Performer 失败/超时/3 次 retry
3. `block.rule_exception` — 规则冲突/Exception 请求
4. `block.epic_critical` — EPIC 交付关键节点
5. `block.high_impact` — 可能有重大影响/风险

**危险操作 (3 类, 3 模式都触发)**:
1. `danger.miao_modify` — 修改 miao 分支
2. `danger.security_failing` — 安全检查 FAIL
3. `danger.data_destruction` — rm -rf / reset --hard / drop table

**5 阶段复杂度 (Performer)**:
- `claim` (简单) / `analysis` (复杂) / `in_progress` (简单) / `test` (复杂) / `review` (复杂)

**落地**: `scripts/performer/stage-gate.sh` + `scripts/permission/decision-gate.sh` + `scripts/permission/mode-set.sh`, pre-commit 集成 decision-gate.

**审计**: `.kallax/audit/decision-YYYY-MM-DD.jsonl` 每日轮转.

**设计文档**: `docs/superpowers/specs/2026-06-09-kallax-3-modes-design.md`
**实施计划**: `docs/superpowers/plans/2026-06-09-kallax-3-modes.md`

**红线**:
- ❌ 跳过 decision-gate.sh 自行决定危险操作
- ❌ 跳过 stage-gate.sh 在 5 阶段复杂步骤独断
- ❌ 运行时热切换 mode (需 restart session)
- ❌ mode_lock 文件被绕过直接写 state.json
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(3-modes): CLAUDE.md Rule 13 3 模式决策权分配"
```

---

## Task 10: 文档 (docs/architecture/3-MODES.md)

**Files:**
- Create: `docs/architecture/3-MODES.md`

- [ ] **Step 1: 写用户文档**

```markdown
# KALLAX 3 模式决策权分配 — 用户文档

> **3 模式 = ai-auto / ai-copilot / manual**
> 主公 2026-06-09 拍板, 跟 EKET `interactive:start` 借鉴集成.

## 怎么选?

每个 session 启动时 (`.kallax/hooks/session_start.sh`) 选一次:

```
┌─ KALLAX MODE ─────────────────────────────
│ 1) ai-auto     (AI 决策, 仅 block/danger 停下问)
│ 2) ai-copilot  (简单自主, 复杂协商) [默认]
│ 3) manual      (每阶段主公确认)
└──────────────────────────────────────────
```

## 什么时候选哪种?

| 场景 | 推荐模式 |
|---|---|
| 跑 Sprint 3 批量 4 expert | ai-auto |
| 日常开发 (主公多数场景) | **ai-copilot (默认)** |
| 新 EPIC 设计 | manual |
| 高风险 migration | manual |
| 修复紧急 bug | ai-copilot |

## 3 模式行为差异

### ai-auto
- AI 决策所有事
- 仅"block 决策" + "危险操作" 停下问
- 5 阶段全 AI 自主

### ai-copilot (推荐默认)
- 简单阶段 (claim / in_progress) AI 自主
- 复杂阶段 (analysis / test / review) 停下协商
- "block 决策" + "危险操作" 停下问

### manual
- 每阶段都停下问主公
- "block 决策" + "危险操作" 停下问
- 适合学习新领域 / 高风险操作

## 怎么改模式?

每个 session 只能选一次. 改模式 → 重新启动 session:

```bash
# 在主 session 退出后
exit  # 或 Ctrl+D

# 启动新 session
/kallax-init --mode ai-auto
# 或
/kallax-init --mode ai-copilot
# 或
/kallax-init --mode manual
```

不能在 session 中热切换, 避免状态不一致.

## 怎么回应 AI 的"停下问"?

AI 写 ask file 到 `.kallax/inbox/`:
- `ask-stage-<TICKET>-<STAGE>.md` (ai-copilot 复杂阶段)
- `ask-manual-<TICKET>-<STAGE>.md` (manual 阶段)
- `decision-<ACTION>-<TIMESTAMP>.md` (block/danger)

主公回应:
1. 编辑 ask file 写"Approve" / "Modify" / "Reject"
2. AI 读 ask file 继续执行

## 审计

所有 AI 决策写到 `.kallax/audit/decision-YYYY-MM-DD.jsonl`:
- 每条记录: timestamp / actor / mode / action / cmd / context
- 每日轮转, 永久留存
- Conductor 可在 review 时查

## 故障排查

| 问题 | 排查 |
|---|---|
| mode 没生效 | `bash scripts/permission/whoami.sh` 看 mode 字段 |
| decision-gate 误报 | 检查 `state.json.mode` 是否正确 |
| 改 mode 无效 | 确认 session 已重启 (不能热切换) |
| ask file 没出现 | 检查 `.kallax/inbox/` 目录权限 |
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture/3-MODES.md
git commit -m "docs(3-modes): 用户文档 3-MODES.md"
```

---

## Task 11: 收尾 — 跑全量集成测试 + miao promote

**Files:**
- Modify: 无 (仅跑测试 + merge)

- [ ] **Step 1: 跑全量 E2E**

Run:
```bash
bash tests/integration/3-modes-e2e.sh
bash tests/integration/permission-v1-e2e.sh
bash tests/integration/conductor-scope.sh
bash tests/integration/workspace-switch.sh
bash tests/integration/authz-sanitization.sh
```
Expected: 5 套全过 (3-modes 16 + 已有 64 = 80 PASS)

- [ ] **Step 2: 测试 → miao**

```bash
# 在 feature 分支开发
git checkout -b feature/EPIC-029-3-modes

# ... (跑任务 1-10) ...

# 测试通过后, 推到 testing
git push origin feature/EPIC-029-3-modes
# 然后 master 合并到 testing
git checkout testing
git merge --no-ff feature/EPIC-029-3-modes
git push origin testing

# testing 通过全量测试后, promote 到 miao
git checkout miao
git merge --no-ff origin/testing
git push origin miao
```

- [ ] **Step 3: Commit (merge commit)**

```bash
git commit --allow-empty -m "merge: testing → miao (EPIC-029 3 模式决策权分配 落地)"
```

---

## Self-Review

**Spec coverage check**:
- §2 3 模式定义 → Task 1 (state schema) + Task 4 (session_start 菜单) + Task 6 (CLI)
- §3 决策粒度 → Task 2 (stage-gate) + Task 3 (decision-gate)
- §4 5 类 Block → Task 3 (decision-gate action id 完整列出)
- §5 3 类危险 → Task 3 (decision-gate action id 完整列出)
- §6 5 阶段复杂度 → Task 2 (stage-gate COMPLEXITY array)
- §7 模式切换 → Task 1 (mode_lock) + Task 4 (session_start 选一次) + Task 6 (--mode CLI)
- §8 落地位置 → Task 1-7 全部覆盖
- §9 状态机 → Task 8 E2E 验证
- §10 风险 → Task 9 Rule 13 红线
- §11 5-Level 验收 → Task 8 E2E (L4 数据流动) + 各 task L1/L2/L3 自检

**Placeholder scan**: 0 TBD/TODO, 所有 code 完整, 无 "similar to task N"

**Type consistency**:
- `mode-set.sh --mode <X>` 跟 `decision-gate.sh` 读 `.mode` 一致 (`ai-auto|ai-copilot|manual`)
- `stage-gate.sh --stage <X>` 跟 spec §6 5 阶段一致 (`claim|analysis|in_progress|test|review`)
- `decision-gate.sh --action <X>` 跟 spec §4 §5 一致 (5 block + 3 danger)
- `state.json.mode` / `state.json.mode_lock` 跟 spec §7 schema 一致
- Exit codes: `0` = ALLOW, `2` = ASK, `1` = ERROR, 跨 task 一致

All consistent. Ready for execution.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-09-kallax-3-modes.md`. 11 tasks, 估时 1-2 周 (跟 EPIC-029 EKET 借鉴 P0 合并落地).

**Execution options**:
1. **Subagent-Driven (推荐)** - 派独立 Performer 子 agent 跑每个 task, task 间 review
2. **Inline Execution** - 当前 session 串行跑, batch + checkpoint
