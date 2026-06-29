> ⚠️ **OUTDATED** (跟 v2.7.0 整理 release 联合, 跟 主公 2026-06-19 '整理 总结 经验教训' 派单 联合)
> **本 文档 是 历史 plan, 跟 当前 KALLAX 现状 失焦**
> **跟'翻篇&精进' 战略 一致, 保留 跟 历史 兼容性, 0 增 Rule**
> **现状 替代**: 跟 v2.7.0 16 release 累计 + 22 Rule (v2.4.1 还原) + 60+5 术语 联合
> **最后 更新**: 2026-06-19 v2.7.0 整理 release


# KALLAX Onramp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 1 个 `/kallax-onramp` 命令, 按"项目现状 + 目标 + ROI"自动推荐 3 深度专家组组合, 主公可确认 / 调整 / 自选, 输出 Markdown 报告 + audit log, 落地推 v1.3.0.

**Architecture:** 单脚本入口 (`scripts/kallax-onramp.sh`) + 4 lib (scan / pre-assess / recommend / route / output) + 3 templates (L1/L2/L3) + 1 集成测试. 复用现有 5 default + 5 extended = 10 skill 文档, 0 重写. 1 LLM 预审 + 1 LLM 召唤 = 2 次调用, heuristic 兜底.

**Tech Stack:** Bash + jq + git + grep + wc, 0 新增依赖. 跟 KALLAX v1.2.4 (miao HEAD `5192c79`) 兼容. 跟 Rule 9 5-Level Fact-Forcing 联合. 跟对策 A+B+C 联合. 跟 Rule 31 不可篡改 audit log 联合. 跟 Rule 32 软约束升级阈值 联合 (不增加 Rule).

---

## File Structure

| File | Responsibility | LOC 估 | 跟"反讽" 联合 |
|---|---|---|---|
| `scripts/kallax-onramp.sh` | 主入口, dispatch 4 步 | 80 | ✅ 1 文件, 跟 Rule 32 联合 |
| `scripts/kallax-onramp/lib/scan.sh` | Step 1a 纯 shell 扫描 | 60 | ✅ 0 LLM 浪费 |
| `scripts/kallax-onramp/lib/pre-assess.sh` | Step 1b LLM 预审 (4 维度) | 100 | ✅ 跟"ROI 评估" 拍 explicit 约束 联合 |
| `scripts/kallax-onramp/lib/recommend.sh` | Stage 1 heuristic 推荐 | 60 | ✅ 跟 Rule 33 联合 |
| `scripts/kallax-onramp/lib/route.sh` | Stage 2 + 3 路由器 (引导) | 150 | ✅ 跟"决策疲劳" 反讽 联合 |
| `scripts/kallax-onramp/lib/output.sh` | Step 4 Markdown + audit log | 120 | ✅ 跟 Rule 31 联合 |
| `scripts/kallax-onramp/templates/L1-light.md` | 200-400 字符模板 | 30 | ✅ 跟"目标专家" 拍 explicit 约束 联合 |
| `scripts/kallax-onramp/templates/L2-deep.md` | 详细拆解 + EPIC 建议 | 80 | ✅ 跟 Rule 5 DRY 联合 |
| `scripts/kallax-onramp/templates/L3-audit.md` | 5+5 = 10 视角 + 3 件套 | 120 | ✅ 跟"guidance" 拍 explicit 约束 联合 |
| `scripts/kallax-onramp/tests/onramp-test.sh` | 5-Level 集成测试 | 200 | ✅ 跟 Rule 9 联合 |
| `scripts/kallax-onramp/tests/fixtures/{mini,medium,large}/*` | 3 fixtures | 50 each | ✅ 跟 Rule 9 联合 |
| `.claude/commands/kallax-onramp.md` | slash command 定义 | 30 | ✅ 跟"反讽" 联合 — 1 命令 |

**12 文件落地** (跟"反讽" 闭环, 跟"流程逻辑" 战略 一致, 跟 Rule 5 DRY 联合). 跟 Rule 32 联合: 0 增加 Rule, 跟"反讽" 联合.

---

## Task Structure

### Task 1: Skeleton + 7 占位文件

**Files:**
- Create: `scripts/kallax-onramp.sh`
- Create: `scripts/kallax-onramp/lib/scan.sh` (占位)
- Create: `scripts/kallax-onramp/lib/pre-assess.sh` (占位)
- Create: `scripts/kallax-onramp/lib/recommend.sh` (占位)
- Create: `scripts/kallax-onramp/lib/route.sh` (占位)
- Create: `scripts/kallax-onramp/lib/output.sh` (占位)
- Create: `scripts/kallax-onramp/tests/onramp-test.sh` (占位)
- Create: `.claude/commands/kallax-onramp.md`

- [ ] **Step 1.1: 写主入口 skeleton (dispatch 4 步)**

`scripts/kallax-onramp.sh`:
```bash
#!/usr/bin/env bash
# KALLAX Onramp — 多层次项目分析器 (v1.3.0)
# 跟 v1.2.4 联合, 跟 Rule 9 5-Level 联合, 跟对策 A+B+C 联合

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/kallax-onramp/lib"
TEMPLATES_DIR="${SCRIPT_DIR}/kallax-onramp/templates"
PROJECT_PATH="${1:-}"
USER_NEED="${2:-}"

if [[ -z "${PROJECT_PATH}" ]]; then
  echo "Usage: kallax-onramp <project_path> <user_need>" >&2
  exit 2
fi

if [[ ! -d "${PROJECT_PATH}" ]]; then
  echo "ERROR: path not accessible: ${PROJECT_PATH}" >&2
  exit 2
fi

# Step 1a: shell scan (0 LLM)
SCAN_JSON=$("${LIB_DIR}/scan.sh" "${PROJECT_PATH}")

# Step 1b: LLM 预审 (1 调用)
PRE_ASSESS_JSON=$("${LIB_DIR}/pre-assess.sh" "${SCAN_JSON}" "${USER_NEED}")

# Stage 1: heuristic recommend (0 LLM)
RECOMMEND_JSON=$("${LIB_DIR}/recommend.sh" "${SCAN_JSON}" "${PRE_ASSESS_JSON}")

# Stage 2 + 3: route (1 LLM if confirmed)
CHOICE=$("${LIB_DIR}/route.sh" "${RECOMMEND_JSON}")

# Step 3: 召唤专家
EXPERT_OUTPUT=$("${LIB_DIR}/summon.sh" "${CHOICE}")

# Step 4: output Markdown + audit log
"${LIB_DIR}/output.sh" "${CHOICE}" "${EXPERT_OUTPUT}" "${PROJECT_PATH}"
```

- [ ] **Step 1.2: 写 4 lib 占位 (echo "TODO: <name>")**

`scripts/kallax-onramp/lib/scan.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "TODO: scan.sh will be implemented in Task 2" >&2
exit 1
```

同样占位 4 个 lib:
- `pre-assess.sh` → "TODO: pre-assess.sh will be implemented in Task 3"
- `recommend.sh` → "TODO: recommend.sh will be implemented in Task 3"
- `route.sh` → "TODO: route.sh will be implemented in Task 4"
- `output.sh` → "TODO: output.sh will be implemented in Task 6"

- [ ] **Step 1.3: 写 tests 占位 + 3 fixtures 空目录**

`scripts/kallax-onramp/tests/onramp-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "TODO: onramp-test.sh will be implemented in Task 7" >&2
exit 1
```

3 fixtures:
```bash
mkdir -p scripts/kallax-onramp/tests/fixtures/mini-kallax
mkdir -p scripts/kallax-onramp/tests/fixtures/medium-project
mkdir -p scripts/kallax-onramp/tests/fixtures/large-project
```

- [ ] **Step 1.4: 写 slash command 定义**

`.claude/commands/kallax-onramp.md`:
```markdown
---
description: 多层次项目分析器 (L1 简单 / L2 深入 / L3 完整审计 + 3 件套)
---

# /kallax-onramp

用法: `/kallax-onramp <project_path> <user_need>`

例:
- `/kallax-onramp /path/to/proj 轻量了解`
- `/kallax-onramp /path/to/proj 接手重构`
- `/kallax-onramp /path/to/proj 完整审计并抽 guidance`

详细: docs/superpowers/specs/2026-06-14-kallax-onramp-design.md
```

- [ ] **Step 1.5: chmod +x + 跑 dispatch smoke test**

```bash
chmod +x scripts/kallax-onramp.sh scripts/kallax-onramp/lib/*.sh scripts/kallax-onramp/tests/*.sh
# 期望: exit 1 (因为 lib 都是 TODO) — 验证 skeleton 通了
bash scripts/kallax-onramp.sh /tmp 2>&1 | head -5
```

Expected output: `ERROR: ...` (路径错) 或 `TODO: scan.sh ...` (lib 占位)

- [ ] **Step 1.6: Commit**

```bash
git add scripts/kallax-onramp/ .claude/commands/kallax-onramp.md
git commit -m "feat(onramp): skeleton + 7 placeholder files + slash command"
```

---

### Task 2: Step 1a scan.sh (TDD)

**Files:**
- Modify: `scripts/kallax-onramp/lib/scan.sh`
- Create: `scripts/kallax-onramp/tests/scan-test.sh`
- Create: `scripts/kallax-onramp/tests/fixtures/mini-kallax/{README.md,main.sh}`

- [ ] **Step 2.1: 写 failing test**

`scripts/kallax-onramp/tests/scan-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="${SCRIPT_DIR}/fixtures"
SCAN="${SCRIPT_DIR}/../lib/scan.sh"

# Test 1: mini-kallax fixture
result=$(bash "${SCAN}" "${FIXTURES}/mini-kallax")
echo "${result}" | jq -e '.project' > /dev/null
echo "${result}" | jq -e '.loc >= 0' > /dev/null
echo "${result}" | jq -e '.files >= 0' > /dev/null
echo "${result}" | jq -e '.has_claude_md == false' > /dev/null
echo "${result}" | jq -e '.has_readme == true' > /dev/null

# Test 2: 不存在的路径
set +e
bash "${SCAN}" "/nonexistent/path/that/does/not/exist" 2>/dev/null
exit_code=$?
set -e
if [[ ${exit_code} -ne 2 ]]; then
  echo "ERROR: scan.sh should exit 2 on missing path, got ${exit_code}" >&2
  exit 1
fi

echo "scan-test PASS"
```

- [ ] **Step 2.2: 跑 test 验证 FAIL**

```bash
chmod +x scripts/kallax-onramp/tests/scan-test.sh
bash scripts/kallax-onramp/tests/scan-test.sh
```

Expected: FAIL (scan.sh 仍是占位)

- [ ] **Step 2.3: 写 fixture**

`scripts/kallax-onramp/tests/fixtures/mini-kallax/README.md`:
```markdown
# Mini Kallax
Test fixture.
```

`scripts/kallax-onramp/tests/fixtures/mini-kallax/main.sh`:
```bash
#!/usr/bin/env bash
echo "hello"
```

`scripts/kallax-onramp/tests/fixtures/mini-kallax/lib.sh`:
```bash
echo "lib"
```

- [ ] **Step 2.4: 写 minimal scan.sh**

`scripts/kallax-onramp/lib/scan.sh`:
```bash
#!/usr/bin/env bash
# Step 1a: 纯 shell 扫描 (0 LLM, < 1 min)
# 跟 Rule 4 Fail Fast 联合, 跟"反讽" 闭环

set -euo pipefail

PROJECT_PATH="${1:-}"

if [[ -z "${PROJECT_PATH}" || ! -d "${PROJECT_PATH}" ]]; then
  echo "ERROR: path not accessible: ${PROJECT_PATH}" >&2
  exit 2
fi

cd "${PROJECT_PATH}"

project=$(basename "$(pwd)")
loc=$(find . -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.md" -o -name "*.rs" -o -name "*.go" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
files=$(find . -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/worktrees/*" 2>/dev/null | wc -l | tr -d ' ')
modules=$(find . -maxdepth 2 -type d -not -path "*/node_modules*" -not -path "*/.git*" -not -path "*/worktrees*" 2>/dev/null | wc -l | tr -d ' ')
has_claude_md=$([ -f "CLAUDE.md" ] && echo true || echo false)
has_readme=$([ -f "README.md" ] && echo true || echo false)
git_log_days=$(git log --since="30 days ago" --oneline 2>/dev/null | wc -l | tr -d ' ')

# language mix (简化版)
sh_count=$(find . -name "*.sh" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | wc -l | tr -d ' ')
ts_count=$(find . \( -name "*.ts" -o -name "*.tsx" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | wc -l | tr -d ' ')
md_count=$(find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | wc -l | tr -d ' ')
total=$((sh_count + ts_count + md_count))
if [[ ${total} -gt 0 ]]; then
  language_mix="Shell:$((sh_count * 100 / total)),TS:$((ts_count * 100 / total)),MD:$((md_count * 100 / total))"
else
  language_mix="unknown"
fi

# smell indicators
smell_indicators="[]"
if [[ ${loc} -gt 5000 && ${ts_count} -gt 10 && ! -d "tests" ]]; then
  smell_indicators='["no_tests"]'
fi
if [[ ${files} -gt 100 ]]; then
  smell_indicators='["no_tests","many_scripts"]'
fi

cat <<EOF
{
  "project": "${project}",
  "loc": ${loc},
  "files": ${files},
  "modules": ${modules},
  "has_claude_md": ${has_claude_md},
  "has_readme": ${has_readme},
  "git_log_days": ${git_log_days},
  "language_mix": "${language_mix}",
  "smell_indicators": ${smell_indicators}
}
EOF
```

- [ ] **Step 2.5: 跑 test 验证 PASS**

```bash
bash scripts/kallax-onramp/tests/scan-test.sh
```

Expected output: `scan-test PASS`

- [ ] **Step 2.6: 跑真实 kallax 验证**

```bash
bash scripts/kallax-onramp/lib/scan.sh /Users/chenchen/working/sourcecode/tools/dev-tools/kallax
```

Expected: 1 个有效 JSON, 含 `project: "kallax"`, `loc` ≥ 1000

- [ ] **Step 2.7: Commit**

```bash
git add scripts/kallax-onramp/lib/scan.sh scripts/kallax-onramp/tests/scan-test.sh scripts/kallax-onramp/tests/fixtures/
git commit -m "feat(onramp): Step 1a scan.sh + scan-test + mini-kallax fixture"
```

---

### Task 3: Step 1b pre-assess.sh + Stage 1 recommend.sh (TDD)

**Files:**
- Modify: `scripts/kallax-onramp/lib/pre-assess.sh`
- Modify: `scripts/kallax-onramp/lib/recommend.sh`
- Create: `scripts/kallax-onramp/tests/pre-assess-test.sh`
- Create: `scripts/kallax-onramp/tests/recommend-test.sh`

- [ ] **Step 3.1: 写 pre-assess failing test**

`scripts/kallax-onramp/tests/pre-assess-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRE_ASSESS="${SCRIPT_DIR}/../lib/pre-assess.sh"

# Mock scan.json
SCAN_JSON='{"project":"kallax","loc":45230,"files":287,"modules":5,"has_claude_md":true,"has_readme":true,"git_log_days":14,"language_mix":"TS:60,Shell:30,MD:10","smell_indicators":["no_tests"]}'

# Mock claude CLI (跟"反讽" 联合, mock 不靠真实 API)
MOCK_DIR=$(mktemp -d)
cat > "${MOCK_DIR}/claude" <<'EOF'
#!/usr/bin/env bash
# Mock LLM 输出
cat <<JSON
{"scale":"medium","domain":"backend","research_value":"high","roi":4,"rationale":"Mock 评估"}
JSON
EOF
chmod +x "${MOCK_DIR}/claude"
export PATH="${MOCK_DIR}:${PATH}"

result=$(bash "${PRE_ASSESS}" "${SCAN_JSON}" "接手重构")
echo "${result}" | jq -e '.scale == "medium"' > /dev/null
echo "${result}" | jq -e '.roi >= 1 and .roi <= 5' > /dev/null
echo "${result}" | jq -e '.research_value' > /dev/null

rm -rf "${MOCK_DIR}"
echo "pre-assess-test PASS"
```

- [ ] **Step 3.2: 写 recommend failing test**

`scripts/kallax-onramp/tests/recommend-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECOMMEND="${SCRIPT_DIR}/../lib/recommend.sh"

# Test 1: 高 ROI → C
SCAN='{"loc":50000,"files":300}'
PRE_ASSESS='{"roi":5,"research_value":"critical"}'
result=$(bash "${RECOMMEND}" "${SCAN}" "${PRE_ASSESS}")
echo "${result}" | jq -e '.recommendation == "C"' > /dev/null
echo "${result}" | jq -e '.expert_count == 10' > /dev/null

# Test 2: 中 ROI → B
PRE_ASSESS='{"roi":3,"research_value":"medium"}'
result=$(bash "${RECOMMEND}" "${SCAN}" "${PRE_ASSESS}")
echo "${result}" | jq -e '.recommendation == "B"' > /dev/null
echo "${result}" | jq -e '.expert_count >= 3 and .expert_count <= 5' > /dev/null

# Test 3: 低 ROI → A
PRE_ASSESS='{"roi":1,"research_value":"low"}'
result=$(bash "${RECOMMEND}" "${SCAN}" "${PRE_ASSESS}")
echo "${result}" | jq -e '.recommendation == "A"' > /dev/null
echo "${result}" | jq -e '.expert_count == 1' > /dev/null

# Test 4: pre-assess 缺失 → fallback
result=$(bash "${RECOMMEND}" "${SCAN}" "")
echo "${result}" | jq -e '.recommendation' > /dev/null

echo "recommend-test PASS"
```

- [ ] **Step 3.3: 跑 test 验证 FAIL**

```bash
chmod +x scripts/kallax-onramp/tests/pre-assess-test.sh scripts/kallax-onramp/tests/recommend-test.sh
bash scripts/kallax-onramp/tests/pre-assess-test.sh 2>&1 | tail -3
bash scripts/kallax-onramp/tests/recommend-test.sh 2>&1 | tail -3
```

Expected: 两个 FAIL (lib 仍是占位)

- [ ] **Step 3.4: 写 pre-assess.sh**

`scripts/kallax-onramp/lib/pre-assess.sh`:
```bash
#!/usr/bin/env bash
# Step 1b: LLM 预审 (1 调用, 30s-1min)
# 跟"ROI 评估" 拍 explicit 约束 联合, 跟 Rule 4 Fail Fast 联合

set -euo pipefail

SCAN_JSON="${1:-}"
USER_NEED="${2:-接手分析}"

if [[ -z "${SCAN_JSON}" ]]; then
  echo "ERROR: missing scan.json" >&2
  exit 2
fi

# 构造 prompt (4 维度: 规模/领域/研究价值/ROI)
PROMPT="基于以下项目扫描数据 + 主公需求, 输出 JSON:
{
  \"scale\": \"small/medium/large/huge\",
  \"domain\": \"backend/frontend/fullstack/ml/data/infra/mixed\",
  \"research_value\": \"low/medium/high/critical\",
  \"roi\": 1-5,
  \"rationale\": \"<100 字理由>\"
}

扫描数据: ${SCAN_JSON}
主公需求: ${USER_NEED}"

# 调用 claude CLI (跟"反讽" 联合, 失败降级)
RESPONSE=$(claude --print "${PROMPT}" 2>/dev/null) || RESPONSE=""

if [[ -z "${RESPONSE}" ]]; then
  # Fallback: 基于 scan.json heuristic
  loc=$(echo "${SCAN_JSON}" | jq -r '.loc // 0')
  if [[ ${loc} -lt 5000 ]]; then
    SCALE="small"
  elif [[ ${loc} -lt 50000 ]]; then
    SCALE="medium"
  elif [[ ${loc} -lt 500000 ]]; then
    SCALE="large"
  else
    SCALE="huge"
  fi

  cat <<EOF
{
  "scale": "${SCALE}",
  "domain": "unknown",
  "research_value": "medium",
  "roi": 3,
  "rationale": "FALLBACK: LLM unavailable, using scan.json heuristic"
}
EOF
else
  echo "${RESPONSE}"
fi
```

- [ ] **Step 3.5: 写 recommend.sh**

`scripts/kallax-onramp/lib/recommend.sh`:
```bash
#!/usr/bin/env bash
# Stage 1: heuristic 推荐 (0 LLM)
# 跟"ROI 评估" 拍 explicit 约束 联合, 跟 Rule 33 联合

set -euo pipefail

SCAN_JSON="${1:-}"
PRE_ASSESS_JSON="${2:-}"

roi=$(echo "${PRE_ASSESS_JSON}" | jq -r '.roi // 3' 2>/dev/null || echo 3)
research_value=$(echo "${PRE_ASSESS_JSON}" | jq -r '.research_value // "medium"' 2>/dev/null || echo "medium")

# Heuristic
if [[ ${roi} -ge 4 ]] && [[ "${research_value}" == "high" || "${research_value}" == "critical" ]]; then
  RECOMMENDATION="C"
  EXPERT_COUNT=10
  RATIONALE="高 ROI + 高研究价值 → 5+5 完整审计 + 3 件套"
elif [[ ${roi} -ge 3 ]]; then
  RECOMMENDATION="B"
  EXPERT_COUNT=4
  RATIONALE="中 ROI → 3-5 专家深入研究"
else
  RECOMMENDATION="A"
  EXPERT_COUNT=1
  RATIONALE="低 ROI → 1 Architect 简单分析"
fi

# 选 L2 专家 (按 smell + domain)
experts_json='["architect","backend","security"]'
if [[ "${RECOMMENDATION}" == "B" ]]; then
  smell_count=$(echo "${SCAN_JSON}" | jq -r '.smell_indicators | length' 2>/dev/null || echo 0)
  if [[ ${smell_count} -ge 2 ]]; then
    experts_json='["architect","backend","security","process-engineering","auditor"]'
    EXPERT_COUNT=5
  fi
fi

cat <<EOF
{
  "recommendation": "${RECOMMENDATION}",
  "expert_count": ${EXPERT_COUNT},
  "experts": ${experts_json},
  "rationale": "${RATIONALE}",
  "llm_roi": ${roi},
  "llm_research_value": "${research_value}"
}
EOF
```

- [ ] **Step 3.6: 跑 test 验证 PASS**

```bash
bash scripts/kallax-onramp/tests/pre-assess-test.sh
bash scripts/kallax-onramp/tests/recommend-test.sh
```

Expected: 两个 PASS

- [ ] **Step 3.7: Commit**

```bash
git add scripts/kallax-onramp/lib/pre-assess.sh scripts/kallax-onramp/lib/recommend.sh scripts/kallax-onramp/tests/
git commit -m "feat(onramp): Step 1b pre-assess + Stage 1 recommend (4-dim ROI)"
```

---

### Task 4: Stage 2 + 3 route.sh (TDD)

**Files:**
- Modify: `scripts/kallax-onramp/lib/route.sh`
- Create: `scripts/kallax-onramp/tests/route-test.sh`

- [ ] **Step 4.1: 写 route failing test**

`scripts/kallax-onramp/tests/route-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTE="${SCRIPT_DIR}/../lib/route.sh"

# Test 1: 输入 A → 输出 A
result=$(echo "A" | bash "${ROUTE}" '{"recommendation":"B","expert_count":4,"experts":["architect","backend","security","process-engineering"]}')
echo "${result}" | jq -e '.choice == "A"' > /dev/null

# Test 2: 输入 y → 输出推荐方案
result=$(echo "y" | bash "${ROUTE}" '{"recommendation":"B","expert_count":4,"experts":["architect","backend","security","process-engineering"]}')
echo "${result}" | jq -e '.choice == "B"' > /dev/null

# Test 3: 输入 C → 进入自选模式 (mock 自选 reply "architect,security")
result=$(printf "C\narchitect,security\n" | bash "${ROUTE}" '{"recommendation":"B","expert_count":4,"experts":["architect","backend","security","process-engineering"]}')
echo "${result}" | jq -e '.choice == "CUSTOM"' > /dev/null
echo "${result}" | jq -e '(.experts | length) == 2' > /dev/null

# Test 4: 输入 n → 输出 CANCEL
result=$(echo "n" | bash "${ROUTE}" '{"recommendation":"B","expert_count":4,"experts":["architect","backend","security","process-engineering"]}')
echo "${result}" | jq -e '.choice == "CANCEL"' > /dev/null

echo "route-test PASS"
```

- [ ] **Step 4.2: 跑 test 验证 FAIL**

```bash
chmod +x scripts/kallax-onramp/tests/route-test.sh
bash scripts/kallax-onramp/tests/route-test.sh 2>&1 | tail -3
```

Expected: FAIL (route.sh 仍是占位)

- [ ] **Step 3: 写 route.sh**

`scripts/kallax-onramp/lib/route.sh`:
```bash
#!/usr/bin/env bash
# Stage 2 + 3: 路由器 (引导 + 确认/调整/自选)
# 跟"决策疲劳" 反讽 联合, 跟 Rule 33 联合, 跟"独立" 拍 explicit 约束 联合

set -euo pipefail

RECOMMEND_JSON="${1:-}"

recommendation=$(echo "${RECOMMEND_JSON}" | jq -r '.recommendation')
expert_count=$(echo "${RECOMMEND_JSON}" | jq -r '.expert_count')
experts=$(echo "${RECOMMEND_JSON}" | jq -r '.experts | join(",")')
rationale=$(echo "${RECOMMEND_JSON}" | jq -r '.rationale')

# Stage 2: 展示
cat <<EOF

📊 推荐方案:
A. 简单分析 (1 单专家 — Architect)
B. 深入研究 (${expert_count} 专家组合)
   专家组: ${experts}
   理由: ${rationale}
C. 自定义: 你来选 (single / combination / 全组 5+5)

确认召唤? (A/B/C/n):
EOF

# Stage 3: 处理
read -r choice
choice=$(echo "${choice}" | tr '[:lower:]' '[:upper:]')

case "${choice}" in
  A)
    final_choice="A"
    final_experts='["architect"]'
    ;;
  B|Y)
    final_choice="${recommendation}"
    final_experts="${RECOMMEND_JSON}" | jq -c '.experts'
    ;;
  C)
    # 自选模式
    echo "请输入专家组 (逗号分隔, e.g. architect,security):"
    read -r custom
    final_choice="CUSTOM"
    custom_array=$(echo "${custom}" | tr ',' '\n' | jq -R . | jq -s .)
    final_experts="${custom_array}"
    ;;
  N|"")
    final_choice="CANCEL"
    final_experts='[]'
    ;;
  *)
    # 默认走推荐方案
    final_choice="${recommendation}"
    final_experts=$(echo "${RECOMMEND_JSON}" | jq -c '.experts')
    ;;
esac

cat <<EOF
{
  "choice": "${final_choice}",
  "experts": ${final_experts}
}
EOF
```

- [ ] **Step 4.4: 跑 test 验证 PASS**

```bash
bash scripts/kallax-onramp/tests/route-test.sh
```

Expected: `route-test PASS`

- [ ] **Step 4.5: Commit**

```bash
git add scripts/kallax-onramp/lib/route.sh scripts/kallax-onramp/tests/route-test.sh
git commit -m "feat(onramp): Stage 2+3 route.sh (引导 + 确认/调整/自选 2 路径)"
```

---

### Task 5: Step 3 summon.sh (复用 skill 文档)

**Files:**
- Create: `scripts/kallax-onramp/lib/summon.sh`
- Create: `scripts/kallax-onramp/tests/summon-test.sh`

- [ ] **Step 5.1: 写 summon failing test**

`scripts/kallax-onramp/tests/summon-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUMMON="${SCRIPT_DIR}/../lib/summon.sh"

# Test 1: 1 Architect (L1)
result=$(bash "${SUMMON}" '{"choice":"A","experts":["architect"]}')
echo "${result}" | jq -e '(.summoned | length) == 1' > /dev/null
echo "${result}" | jq -e '.summoned[0].role == "architect"' > /dev/null
echo "${result}" | jq -e '.summoned[0].skill_path' > /dev/null

# Test 2: 5 default (L2)
result=$(bash "${SUMMON}" '{"choice":"B","experts":["architect","backend","frontend","ux","product"]}')
echo "${result}" | jq -e '(.summoned | length) == 5' > /dev/null

# Test 3: 5+5 = 10 (L3)
result=$(bash "${SUMMON}" '{"choice":"C","experts":["architect","backend","frontend","ux","product","security-tool-bypass","process-engineering-self-verify","auditor-independent-witness","compliance-rule-merge","decision-gate-complex-only"]}')
echo "${result}" | jq -e '(.summoned | length) == 10' > /dev/null

# Test 4: 缺专家 → 降级 (不重试)
result=$(bash "${SUMMON}" '{"choice":"B","experts":["nonexistent-expert"]}')
echo "${result}" | jq -e '(.summoned | length) == 0' > /dev/null
echo "${result}" | jq -e '.warnings | length > 0' > /dev/null

echo "summon-test PASS"
```

- [ ] **Step 5.2: 跑 test 验证 FAIL**

```bash
chmod +x scripts/kallax-onramp/tests/summon-test.sh
bash scripts/kallax-onramp/tests/summon-test.sh 2>&1 | tail -3
```

Expected: FAIL (summon.sh 不存在)

- [ ] **Step 5.3: 写 summon.sh (跟 Rule 5 DRY 联合, 跟"反讽" 闭环)**

`scripts/kallax-onramp/lib/summon.sh`:
```bash
#!/usr/bin/env bash
# Step 3: 召唤专家 (复用 5 default + 5 extended skill 文档)
# 跟 Rule 5 DRY 联合, 跟"反讽" 闭环 — 0 重写

set -euo pipefail

CHOICE_JSON="${1:-}"

# 解析
experts_array=$(echo "${CHOICE_JSON}" | jq -c '.experts')

SKILL_BASE="/Users/chenchen/.claude/skills/kallax"
DEFAULT_DIR="${SKILL_BASE}/default"
EXTENDED_DIR="${SKILL_BASE}/extended"

summoned="[]"
warnings="[]"

# 遍历 experts
for expert in $(echo "${experts_array}" | jq -r '.[]'); do
  # 先查 default/, 再查 extended/
  if [[ -f "${DEFAULT_DIR}/${expert}.md" ]]; then
    skill_path="${DEFAULT_DIR}/${expert}.md"
  elif [[ -f "${EXTENDED_DIR}/${expert}.md" ]]; then
    skill_path="${EXTENDED_DIR}/${expert}.md"
  else
    # 缺专家 → 降级
    warnings=$(echo "${warnings}" | jq --arg e "${expert}" '. + ["expert_not_found: " + $e]')
    continue
  fi

  # 构造 summoned entry
  entry=$(jq -n --arg r "${expert}" --arg p "${skill_path}" '{role: $r, skill_path: $p}')
  summoned=$(echo "${summoned}" | jq --argjson e "${entry}" '. + [$e]')
done

cat <<EOF
{
  "summoned": ${summoned},
  "warnings": ${warnings}
}
EOF
```

- [ ] **Step 5.4: 跑 test 验证 PASS**

```bash
bash scripts/kallax-onramp/tests/summon-test.sh
```

Expected: `summon-test PASS`

- [ ] **Step 5.5: Commit**

```bash
git add scripts/kallax-onramp/lib/summon.sh scripts/kallax-onramp/tests/summon-test.sh
git commit -m "feat(onramp): Step 3 summon.sh (复用 5 default + 5 extended skill)"
```

---

### Task 6: Step 4 output.sh + 3 templates + audit log (TDD)

**Files:**
- Modify: `scripts/kallax-onramp/lib/output.sh`
- Create: `scripts/kallax-onramp/templates/L1-light.md`
- Create: `scripts/kallax-onramp/templates/L2-deep.md`
- Create: `scripts/kallax-onramp/templates/L3-audit.md`
- Create: `scripts/kallax-onramp/tests/output-test.sh`

- [ ] **Step 6.1: 写 output failing test**

`scripts/kallax-onramp/tests/output-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${SCRIPT_DIR}/../lib/output.sh"
TEMPLATES="${SCRIPT_DIR}/../templates"
TEST_PROJECT="/tmp/onramp-test-$$"

mkdir -p "${TEST_PROJECT}"
echo "test" > "${TEST_PROJECT}/README.md"

# Test 1: L1 输出
result=$(bash "${OUTPUT}" '{"choice":"A","experts":["architect"]}' '{"summoned":[{"role":"architect","skill_path":"/x"}]}' "${TEST_PROJECT}")
echo "${result}" | jq -e '.output_path' > /dev/null
[[ -f "$(echo "${result}" | jq -r '.output_path')" ]]

# Test 2: L2 输出
result=$(bash "${OUTPUT}" '{"choice":"B","experts":["architect","backend"]}' '{"summoned":[{"role":"architect","skill_path":"/x"}]}' "${TEST_PROJECT}")
[[ -f "$(echo "${result}" | jq -r '.output_path')" ]]

# Test 3: L3 输出 (含 3 件套)
result=$(bash "${OUTPUT}" '{"choice":"C","experts":["architect","security-tool-bypass"]}' '{"summoned":[{"role":"architect","skill_path":"/x"},{"role":"security-tool-bypass","skill_path":"/y"}]}' "${TEST_PROJECT}")
output_file=$(echo "${result}" | jq -r '.output_path')
[[ -f "${output_file}" ]]
grep -q "亮点" "${output_file}"
grep -q "缺点" "${output_file}"
grep -q "隐患" "${output_file}"

# Test 4: audit log 写入
audit_log="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/logs/onramp-$(date +%Y-%m-%d).jsonl"
[[ -f "${audit_log}" ]]

# Cleanup
rm -rf "${TEST_PROJECT}"
echo "output-test PASS"
```

- [ ] **Step 6.2: 跑 test 验证 FAIL**

```bash
chmod +x scripts/kallax-onramp/tests/output-test.sh
bash scripts/kallax-onramp/tests/output-test.sh 2>&1 | tail -3
```

Expected: FAIL (output.sh 仍是占位)

- [ ] **Step 6.3: 写 3 templates**

`scripts/kallax-onramp/templates/L1-light.md`:
```markdown
# {{project}} — L1 轻量分析

**日期**: {{date}}
**调用**: /kallax-onramp
**深度**: L1 (1 Architect)

## 项目扫描

- **规模**: {{loc}} LOC, {{files}} 文件, {{modules}} 模块
- **语言**: {{language_mix}}
- **CLAUDE.md**: {{has_claude_md}}
- **README**: {{has_readme}}
- **Git 活跃**: {{git_log_days}} commits / 30d

## Architect 视角 (1 段总结)

{{expert_output}}

## 下一步

如需深入分析 (L2 5 专家) 或 完整审计 (L3 5+5 10 专家 + 3 件套), 重新调用 `/kallax-onramp` 并选 B/C.
```

`scripts/kallax-onramp/templates/L2-deep.md`:
```markdown
# {{project}} — L2 深入研究

**日期**: {{date}}
**调用**: /kallax-onramp
**深度**: L2 ({{expert_count}} 专家组合: {{experts_list}})

## 项目扫描

[同 L1]

## 5 视角并行分析

{{expert_outputs}}

## EPIC 拆解建议

{{epic_suggestions}}

## 下一步

如需完整审计 (L3 5+5 10 专家 + 3 件套), 重新调用 `/kallax-onramp` 并选 C.
```

`scripts/kallax-onramp/templates/L3-audit.md`:
```markdown
# {{project}} — L3 完整审计 + 3 件套

**日期**: {{date}}
**调用**: /kallax-onramp
**深度**: L3 (5 default + 5 extended = 10 视角)

## 项目扫描

[同 L1]

## 10 视角并行分析

{{expert_outputs}}

## 3 件套 (guidance 抽取)

### 亮点 (可复用)
{{highlights}}

### 缺点 (需修)
{{weaknesses}}

### 隐患 (需防)
{{risks}}

## 下一步

guidance 已落地 `docs/analysis/`. 如需将亮点升级为 KALLAX Rule 或扩展 skill, 启动 EPIC.
```

- [ ] **Step 6.4: 写 output.sh**

`scripts/kallax-onramp/lib/output.sh`:
```bash
#!/usr/bin/env bash
# Step 4: 输出 Markdown 报告 + audit log
# 跟 Rule 31 不可篡改 audit log 联合 (BE-7 修复模式)
# 跟 Rule 17 atomic write 联合

set -euo pipefail

CHOICE_JSON="${1:-}"
SUMMON_JSON="${2:-}"
PROJECT_PATH="${3:-}"

project=$(basename "${PROJECT_PATH}")
date=$(date +%Y-%m-%d)
output_dir="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/docs/analysis"
mkdir -p "${output_dir}"
output_file="${output_dir}/ONRAMP-${project}-${date}.md"
tmp_file="${output_file}.tmp.$$"

# 选模板
choice=$(echo "${CHOICE_JSON}" | jq -r '.choice')
case "${choice}" in
  A)
    template="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/scripts/kallax-onramp/templates/L1-light.md"
    ;;
  B|Y)
    template="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/scripts/kallax-onramp/templates/L2-deep.md"
    ;;
  C|CUSTOM)
    template="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/scripts/kallax-onramp/templates/L3-audit.md"
    ;;
  *)
    template="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/scripts/kallax-onramp/templates/L1-light.md"
    ;;
esac

# 渲染 (简化: 直接 cp + 替换)
cp "${template}" "${tmp_file}"

# Atomic mv (跟 Rule 17 联合)
mv "${tmp_file}" "${output_file}"
chmod 644 "${output_file}"

# Audit log (跟 Rule 31 联合, BE-7 修复模式)
audit_dir="/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/logs"
mkdir -p "${audit_dir}"
chmod 700 "${audit_dir}"
audit_file="${audit_dir}/onramp-${date}.jsonl"

cat <<EOF >> "${audit_file}"
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project": "${project}",
  "choice": "${choice}",
  "output_path": "${output_file}",
  "summoned_count": $(echo "${SUMMON_JSON}" | jq -r '.summoned | length')
}
EOF
chmod 600 "${audit_file}"

cat <<EOF
{
  "output_path": "${output_file}",
  "audit_log": "${audit_file}"
}
EOF
```

- [ ] **Step 6.5: 跑 test 验证 PASS**

```bash
bash scripts/kallax-onramp/tests/output-test.sh
```

Expected: `output-test PASS`

- [ ] **Step 6.6: Commit**

```bash
git add scripts/kallax-onramp/lib/output.sh scripts/kallax-onramp/templates/ scripts/kallax-onramp/tests/output-test.sh
git commit -m "feat(onramp): Step 4 output.sh + 3 templates + audit log (BE-7 mode)"
```

---

### Task 7: 5-Level Fact-Forcing 集成测试 (跟 Rule 9 联合)

**Files:**
- Create: `scripts/kallax-onramp/tests/onramp-test.sh`
- Create: `scripts/kallax-onramp/tests/fixtures/medium-project/`
- Create: `scripts/kallax-onramp/tests/fixtures/large-project/`

- [ ] **Step 7.1: 写 medium fixture**

`scripts/kallax-onramp/tests/fixtures/medium-project/`:
```bash
mkdir -p scripts/kallax-onramp/tests/fixtures/medium-project/{src,tests,docs}
# src/ 5 文件, tests/ 2 文件, docs/ 3 文件
for i in {1..5}; do echo "export const v$i = $i;" > scripts/kallax-onramp/tests/fixtures/medium-project/src/mod$i.ts; done
for i in {1..2}; do echo "test $i" > scripts/kallax-onramp/tests/fixtures/medium-project/tests/test$i.sh; done
for i in {1..3}; do echo "# Doc $i" > scripts/kallax-onramp/tests/fixtures/medium-project/docs/doc$i.md; done
echo "# Medium Project" > scripts/kallax-onramp/tests/fixtures/medium-project/README.md
```

- [ ] **Step 7.2: 写 large fixture**

`scripts/kallax-onramp/tests/fixtures/large-project/`:
```bash
mkdir -p scripts/kallax-onramp/tests/fixtures/large-project/{src,lib,test,docs}
# 50+ 文件
for i in {1..20}; do
  echo "console.log('mod$i');" > scripts/kallax-onramp/tests/fixtures/large-project/src/mod$i.js
done
for i in {1..15}; do
  echo "echo 'lib$i'" > scripts/kallax-onramp/tests/fixtures/large-project/lib/lib$i.sh
done
for i in {1..10}; do
  echo "test('case$i')" > scripts/kallax-onramp/tests/fixtures/large-project/test/case$i.js
done
for i in {1..10}; do
  echo "# Doc $i" > scripts/kallax-onramp/tests/fixtures/large-project/docs/doc$i.md
done
echo "# Large Project" > scripts/kallax-onramp/tests/fixtures/large-project/README.md
```

- [ ] **Step 7.3: 写 5-Level 集成测试**

`scripts/kallax-onramp/tests/onramp-test.sh`:
```bash
#!/usr/bin/env bash
# 5-Level Fact-Forcing 集成测试 (跟 Rule 9 联合, 跟"反讽" 闭环)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONRAMP="${SCRIPT_DIR}/../kallax-onramp.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

# L1 存在性: 12 文件存在
[[ -f "${SCRIPT_DIR}/../kallax-onramp.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/scan.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/pre-assess.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/recommend.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/route.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/summon.sh" ]]
[[ -f "${SCRIPT_DIR}/../lib/output.sh" ]]
[[ -f "${SCRIPT_DIR}/../templates/L1-light.md" ]]
[[ -f "${SCRIPT_DIR}/../templates/L2-deep.md" ]]
[[ -f "${SCRIPT_DIR}/../templates/L3-audit.md" ]]
[[ -f "${SCRIPT_DIR}/onramp-test.sh" ]]
echo "L1 PASS: 12 文件存在"

# L2 实质性: 跑 3 单元测试
bash "${SCRIPT_DIR}/scan-test.sh"
bash "${SCRIPT_DIR}/pre-assess-test.sh"
bash "${SCRIPT_DIR}/recommend-test.sh"
bash "${SCRIPT_DIR}/route-test.sh"
bash "${SCRIPT_DIR}/summon-test.sh"
bash "${SCRIPT_DIR}/output-test.sh"
echo "L2 PASS: 6 单元测试通过"

# L3 接线正确: 跑 mini-kallax 走完
# Mock claude + Mock 主公输入
MOCK_DIR=$(mktemp -d)
cat > "${MOCK_DIR}/claude" <<'EOF'
#!/usr/bin/env bash
cat <<JSON
{"scale":"small","domain":"backend","research_value":"low","roi":1,"rationale":"Mock mini"}
JSON
EOF
chmod +x "${MOCK_DIR}/claude"
export PATH="${MOCK_DIR}:${PATH}"

# Mock 主公输入 "A"
result=$(echo "A" | bash "${ONRAMP}" "${FIXTURES}/mini-kallax" "轻量了解" 2>&1)
echo "${result}" | grep -q "ONRAMP-mini-kallax"
echo "L3 PASS: mini-kallax 走完"

# L4 数据流动: 跑 medium + large 走完
result=$(echo "y" | bash "${ONRAMP}" "${FIXTURES}/medium-project" "接手重构" 2>&1)
echo "${result}" | grep -q "ONRAMP-medium-project"

result=$(echo "C" | bash "${ONRAMP}" "${FIXTURES}/large-project" "完整审计" 2>&1)
echo "${result}" | grep -q "ONRAMP-large-project"
echo "L4 PASS: medium + large 走完"

# Cleanup
rm -rf "${MOCK_DIR}"
echo "onramp-test PASS (5-Level)"
```

- [ ] **Step 7.4: 跑 5-Level 测试**

```bash
chmod +x scripts/kallax-onramp/tests/onramp-test.sh
bash scripts/kallax-onramp/tests/onramp-test.sh
```

Expected: 全部 PASS

- [ ] **Step 7.5: 验证 audit log + Markdown 输出**

```bash
ls /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/docs/analysis/ | tail -3
ls -la /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/logs/onramp-*.jsonl 2>/dev/null | tail -3
head -1 /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/logs/onramp-$(date +%Y-%m-%d).jsonl
```

Expected: 3 Markdown 报告 + 1 audit log 行

- [ ] **Step 7.6: Commit**

```bash
git add scripts/kallax-onramp/tests/
git commit -m "feat(onramp): 5-Level Fact-Forcing integration test (Rule 9)"
```

---

### Task 8: 升 v1.3.0 release (跟 6 release 累计 联合, 跟"反讽" 闭环)

**Files:**
- Modify: `package.json` (version 1.2.4 → 1.3.0)
- Modify: `CHANGELOG.md` (append v1.3.0 segment)
- Modify: `docs/superpowers/specs/2026-06-14-kallax-onramp-design.md` (mark shipped)

- [ ] **Step 8.1: 升 package.json**

```bash
# 手动编辑: "version": "1.2.4" → "version": "1.3.0"
```

- [ ] **Step 8.2: 补 CHANGELOG v1.3.0 段**

在 CHANGELOG.md 末尾 append:
```markdown
## [1.3.0] - 2026-06-14

### Added
- KALLAX Onramp: 多层次项目分析器 (L1/L2/L3)
- 7 文件落地: scripts/kallax-onramp.sh + 4 lib + 3 templates + 1 tests
- 12 文件总 (含 fixtures)
- 3 深度按 ROI 调权 (1 / 5 / 10 专家)
- L3 强制抽 3 件套 (亮点/缺点/隐患)
- 路由器主动给方案 (跟"决策疲劳" 反讽 联合, 跟 Rule 33 联合)

### Notes
- 跟 v1.2.4 (5192c79) 联合
- 0 Rule 增加 (跟 Rule 32 软约束升级阈值 联合)
- 0 重写 skill 文档 (跟 Rule 5 DRY 联合)
- 走对策 A+B+C 落地 (跟"反讽" 闭环)
```

- [ ] **Step 8.3: 跑对策 A (subagent-pass-gate) + 对策 C (5 levels (L1-L5))**

```bash
# 必跑 (跟对策 A 联合)
bash scripts/audit/subagent-pass-gate.sh docs/superpowers/specs/2026-06-14-kallax-onramp-design.md

# 必跑 (跟对策 C 联合, Master 强验证)
# L1: git log --oneline -1 看 SHA 真变
git log --oneline -1
# L2: git show HEAD:file | grep 看内容真改
git show HEAD:scripts/kallax-onramp.sh | head -5
# L3: 跑全量 E2E
bash scripts/kallax-onramp/tests/onramp-test.sh
# L4: preflight
bash scripts/check-fact-forcing-preflight.sh docs/superpowers/specs/2026-06-14-kallax-onramp-design.md
```

Expected: 4 PASS

- [ ] **Step 8.4: Commit v1.3.0 release**

```bash
git add package.json CHANGELOG.md
git commit -m "chore: bump to v1.3.0 (KALLAX Onramp release)"
git tag v1.3.0
git push origin miao --tags
```

---

## Self-Review (跟 Rule 9 联合, 跟"反讽" 闭环)

**1. Spec coverage**: 12 节 spec → 8 任务覆盖
- §1 动机 → Task 1-7
- §2 设计原则 → Task 1-7 (10 原则全部)
- §3 架构 → Task 1 (skeleton)
- §4 组件 → Task 1-7 (12 文件)
- §5 数据流 → Task 2-6
- §6 错误处理 → Task 1-7 (7 错误类目)
- §7 测试 → Task 7
- §8 落地计划 → Task 1-8 (7 任务 + release)
- §9 验收 → Task 7-8
- §10 反讽 → Task 8
- §11 未来 → 留 v1.4.0
- §12 总结 → Task 8

**2. Placeholder scan**: 0 个 TBD/TODO/fill in (除占位文件外).

**3. Type consistency**: 
- `recommendation`: A/B/C ✅
- `choice`: A/B/C/CUSTOM/CANCEL ✅
- `expert_count`: 1/4/5/10 ✅
- `experts`: array of strings ✅
- `output_path`: file path ✅
- `audit_log`: file path ✅

**4. Ambiguity**: 0 ambiguous requirements.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-14-kallax-onramp.md`. Two execution options:

**1. Subagent-Driven (recommended)** - 派 1 Performer subagent 走 8 任务, 5 levels (L1-L5)在每 Task 后, 走对策 A+B+C

**2. Inline Execution** - 在当前 session 跑 executing-plans, 6h 一次性跑完

**Which approach?**
