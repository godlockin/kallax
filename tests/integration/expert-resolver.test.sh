#!/usr/bin/env bash
# expert-resolver.test.sh — EPIC-272 索引式专家 resolver 守卫 test
#
# 设计原则 (同 next-epic-id.test.sh): **行为断言, 不 grep 源码**.
# 每个 case 构造 fixture 目录 (default + 外挂两种布局), 断言 resolver 的实际输出.
#
# 这批 case 的来历: EPIC-272 首版 merge 后实跑发现 3 个 bug —
#   1. scan_dir 用 "$dir"/*.md 扁平扫, 远程 experts/ 是 <division>/[<domain>/]*.md 嵌套 → 外挂 0 个
#   2. PLUGIN_EXPERTS_DIR 指仓库根, md 实际在 experts/ 子目录下
#   3. `path <role_id>` 参数进了 QUERY, ROLE_ID 空 → 报 "需要 role_id 参数"
# 每个 case 都能杀掉对应修复的回退.
#
# 变异测试结果 (6 个变异体, 逐个还原已修 bug 验证本 test 能杀掉):
#   MUTANT 1 (嵌套扫描 → 扁平 glob)      KILLED — 11 case fail
#   MUTANT 2 (去掉 experts/ 下探)         KILLED — 2 case fail
#   MUTANT 3 (path 参数归属还原)          KILLED — 3 case fail
#   MUTANT 4 (find 不搜 triggers)         KILLED — 1 case fail
#   MUTANT 5 (去重失效)                   KILLED — 1 case fail
#   MUTANT 6 (删 scan_dir 的 [ -d ] 检查) SURVIVED — **不是 test 缺陷**:
#     find 的 stderr 已被 2>/dev/null 吞, 该检查是纯冗余早退优化, 无可观察行为差异.
#     实测两个目录都不存在时, 有/无该行都输出 "总: 0" exit 0.
#
# 不加 set -e — 本 test 检查非 0 退出码
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
TARGET="$REPO_ROOT/scripts/expert-resolver.sh"

PASS=0
FAIL=0
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/e272-test.XXXXXX")"
trap 'rm -rf "$TMPROOT"' EXIT

ok()  { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
bad() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

# 造一个专家定义文件 (frontmatter 按远程 kallax-experts schema)
make_expert() {
  local path="$1" role_id="$2" name="$3" triggers="${4:-}" use_when="${5:-}"
  mkdir -p "$(dirname "$path")"
  {
    echo "---"
    echo "name: $name"
    echo "role_id: $role_id"
    echo "vibe: test fixture"
    if [ -n "$triggers" ]; then
      echo "triggers:"
      echo "  zh: [$triggers]"
      echo "  en: [$triggers]"
    fi
    if [ -n "$use_when" ]; then
      echo "use_when_zh:"
      echo "  - $use_when"
    fi
    echo "tools: [Read]"
    echo "priority: high"
    echo "---"
    echo ""
    echo "# $name"
  } > "$path"
}

run_resolver() {
  local root="$1" plugin="$2"; shift 2
  KALLAX_ROOT="$root" KALLAX_EXPERTS_DIR="$plugin" bash "$TARGET" "$@" 2>&1
}

# ─────────────────────────────────────────────────────────
# Case 1: 外挂嵌套目录被扫到 (杀 bug 1 — 扁平 glob 回退)
# ─────────────────────────────────────────────────────────
echo "Case 1: 外挂嵌套目录 (<division>/<domain>/*.md)"
FX1="$TMPROOT/c1"
mkdir -p "$FX1/root/.claude/agents"
make_expert "$FX1/root/.claude/agents/backend.md" "backend-architect" "backend"
make_expert "$FX1/plugin/experts/ai/llm/llm-engineer.md" "llm-engineer-senior" "LLM 工程师"
make_expert "$FX1/plugin/experts/tech/qa/qa-engineer.md" "qa-engineer" "QA 工程师"
OUT1="$(run_resolver "$FX1/root" "$FX1/plugin" list)"
if echo "$OUT1" | grep -q "llm-engineer-senior"; then
  ok "3 层嵌套 (experts/ai/llm/) 的专家被扫到"
else
  bad "3 层嵌套的专家没被扫到 — scan_dir 可能退回扁平 glob"
fi
if echo "$OUT1" | grep -q "qa-engineer"; then
  ok "另一个 3 层嵌套专家也被扫到"
else
  bad "qa-engineer 没被扫到"
fi
if echo "$OUT1" | grep -qE "总: 3$"; then
  ok "总数 3 (default 1 + 外挂 2)"
else
  bad "总数不对 — 实际: $(echo "$OUT1" | tail -1)"
fi

# ─────────────────────────────────────────────────────────
# Case 2: experts/ 子目录自动识别 (杀 bug 2 — 指错根目录)
#
# 这个 case 的关键是仓库根有 **带 frontmatter 的文档**: 真实 kallax-experts 的
# docs/CONTRIBUTING.md 在讲 schema 时含 role_id 字样, 不下探 experts/ 就会被
# 当成专家解析 (实测总数 21 → 22, 混进 docs/CONTRIBUTING.md).
# 光放个无 frontmatter 的 README 杀不掉这个变异体 — 它本来就会因无 role_id 被跳过.
# ─────────────────────────────────────────────────────────
echo "Case 2: KALLAX_EXPERTS_DIR 指仓库根, 自动下探 experts/"
FX2="$TMPROOT/c2"
mkdir -p "$FX2/root/.claude/agents"
make_expert "$FX2/root/.claude/agents/ux.md" "ux-researcher" "ux"
# 仓库根的噪声: 无 frontmatter 的 README + 讲 schema 因而含 role_id 的贡献指南
mkdir -p "$FX2/plugin/docs"
printf '# kallax-experts\n\nplugin pool.\n' > "$FX2/plugin/README.md"
make_expert "$FX2/plugin/docs/CONTRIBUTING.md" "role-id-example" "贡献指南里的 schema 示例"
make_expert "$FX2/plugin/experts/business/legal-advisor.md" "legal-advisor" "法律顾问"
OUT2="$(run_resolver "$FX2/root" "$FX2/plugin" list)"
if echo "$OUT2" | grep -q "legal-advisor"; then
  ok "传仓库根时自动下探 experts/ 找到定义"
else
  bad "没下探 experts/ — 外挂专家丢失"
fi
if echo "$OUT2" | grep -q "role-id-example"; then
  bad "把 docs/CONTRIBUTING.md 当专家解析了 — 未下探 experts/ 隔离噪声"
else
  ok "experts/ 之外带 frontmatter 的文档未被误当专家"
fi
if echo "$OUT2" | grep -qE "总: 2$"; then
  ok "总数 2 (default 1 + 外挂 1), 噪声未混入"
else
  bad "总数不对 — 实际: $(echo "$OUT2" | tail -1)"
fi

# ─────────────────────────────────────────────────────────
# Case 3: 扁平布局回退 (兼容不带 experts/ 的目录)
# ─────────────────────────────────────────────────────────
echo "Case 3: 无 experts/ 子目录时回退扫根"
FX3="$TMPROOT/c3"
mkdir -p "$FX3/root/.claude/agents"
make_expert "$FX3/root/.claude/agents/security.md" "security-engineer" "security"
make_expert "$FX3/plugin/data-analyst.md" "data-analyst" "数据分析师"
OUT3="$(run_resolver "$FX3/root" "$FX3/plugin" list)"
if echo "$OUT3" | grep -q "data-analyst"; then
  ok "无 experts/ 子目录时扫根仍工作 (向后兼容)"
else
  bad "扁平布局回退失效"
fi

# ─────────────────────────────────────────────────────────
# Case 4: path <role_id> 参数解析 (杀 bug 3 — 参数进错变量)
# ─────────────────────────────────────────────────────────
echo "Case 4: path 子命令参数解析"
FX4="$TMPROOT/c4"
mkdir -p "$FX4/root/.claude/agents"
make_expert "$FX4/root/.claude/agents/architect.md" "system-architect" "architect"
make_expert "$FX4/plugin/experts/ai/data/data-analyst.md" "data-analyst" "数据分析师"
OUT4="$(run_resolver "$FX4/root" "$FX4/plugin" path data-analyst)"
RC4=$?
if [ "$RC4" -eq 0 ]; then
  ok "path <role_id> exit 0"
else
  bad "path <role_id> exit $RC4 — 参数可能进了 QUERY 而非 ROLE_ID"
fi
if echo "$OUT4" | grep -q "data-analyst.md"; then
  ok "path 返回外挂专家的定义文件路径"
else
  bad "path 没返回路径 — 实际: $OUT4"
fi
OUT4B="$(run_resolver "$FX4/root" "$FX4/plugin" path system-architect)"
if echo "$OUT4B" | grep -q "architect.md"; then
  ok "path 也能查 default 专家"
else
  bad "path 查 default 失败 — 实际: $OUT4B"
fi

# ─────────────────────────────────────────────────────────
# Case 5: find 搜 triggers 字段
# ─────────────────────────────────────────────────────────
echo "Case 5: find 覆盖 triggers 关键词"
FX5="$TMPROOT/c5"
mkdir -p "$FX5/root/.claude/agents"
make_expert "$FX5/root/.claude/agents/product.md" "product-manager" "product"
# 关键词只在 triggers 里, use_when 里没有
make_expert "$FX5/plugin/experts/ai/llm/llm.md" "llm-engineer-senior" "LLM 工程师" "RAG, 向量库" "大模型选哪个"
OUT5="$(run_resolver "$FX5/root" "$FX5/plugin" find RAG)"
if echo "$OUT5" | grep -q "llm-engineer-senior"; then
  ok "find 命中只存在于 triggers 的关键词"
else
  bad "find 没搜 triggers 字段 — 实际: $OUT5"
fi
OUT5B="$(run_resolver "$FX5/root" "$FX5/plugin" find 大模型选哪个)"
if echo "$OUT5B" | grep -q "llm-engineer-senior"; then
  ok "find 也命中 use_when_zh"
else
  bad "find 漏了 use_when_zh"
fi

# ─────────────────────────────────────────────────────────
# Case 6: 同名 role_id 去重, default 优先
# ─────────────────────────────────────────────────────────
echo "Case 6: 同名 role_id 去重 (default 优先, 不物理合并)"
FX6="$TMPROOT/c6"
mkdir -p "$FX6/root/.claude/agents"
make_expert "$FX6/root/.claude/agents/backend.md" "backend-architect" "backend-DEFAULT"
make_expert "$FX6/plugin/experts/tech/backend/backend-architect.md" "backend-architect" "backend-PLUGIN"
make_expert "$FX6/plugin/experts/ai/data/data-analyst.md" "data-analyst" "数据分析师"
OUT6="$(run_resolver "$FX6/root" "$FX6/plugin" list)"
if echo "$OUT6" | grep -qE "总: 2$"; then
  ok "同名 role_id 去重 (1 default + 2 plugin - 1 同名 = 2)"
else
  bad "去重不对 — 实际: $(echo "$OUT6" | tail -1)"
fi
if echo "$OUT6" | grep -q "backend-DEFAULT"; then
  ok "同名冲突时 default 胜出"
else
  bad "同名冲突时 default 没胜出 — 外挂覆盖了 default"
fi
# AC5: 不物理合并 — 跑完后 default 目录文件数不变
AGENT_COUNT="$(find "$FX6/root/.claude/agents" -name '*.md' | wc -l | tr -d ' ')"
if [ "$AGENT_COUNT" -eq 1 ]; then
  ok "不物理合并 — .claude/agents/ 仍 1 个文件, 无外挂写入"
else
  bad "resolver 往 .claude/agents/ 写了文件 (现 $AGENT_COUNT 个)"
fi

# ─────────────────────────────────────────────────────────
# Case 7: 外挂目录不存在时 fail-soft
# ─────────────────────────────────────────────────────────
echo "Case 7: 外挂目录不存在时 fail-soft"
FX7="$TMPROOT/c7"
mkdir -p "$FX7/root/.claude/agents"
make_expert "$FX7/root/.claude/agents/auditor.md" "auditor-independent-witness" "auditor"
OUT7="$(run_resolver "$FX7/root" "$FX7/does-not-exist" list)"
RC7=$?
if [ "$RC7" -eq 0 ]; then
  ok "外挂目录不存在时 exit 0 (fail-soft)"
else
  bad "外挂目录不存在时 exit $RC7 — 应 fail-soft"
fi
if echo "$OUT7" | grep -qE "总: 1$"; then
  ok "只返回 default, 不报错"
else
  bad "fail-soft 输出不对 — 实际: $(echo "$OUT7" | tail -1)"
fi

# ─────────────────────────────────────────────────────────
# Case 8: --source 过滤
# ─────────────────────────────────────────────────────────
echo "Case 8: --source 过滤"
FX8="$TMPROOT/c8"
mkdir -p "$FX8/root/.claude/agents"
make_expert "$FX8/root/.claude/agents/ux.md" "ux-researcher" "ux"
make_expert "$FX8/root/.claude/agents/frontend.md" "frontend-engineer" "frontend"
make_expert "$FX8/plugin/experts/tech/qa/qa.md" "qa-engineer" "QA 工程师"
OUT8D="$(run_resolver "$FX8/root" "$FX8/plugin" list --source=default)"
if echo "$OUT8D" | grep -qE "总: 2$"; then
  ok "--source=default 只返回 2 个"
else
  bad "--source=default 数量不对 — 实际: $(echo "$OUT8D" | tail -1)"
fi
OUT8P="$(run_resolver "$FX8/root" "$FX8/plugin" list --source=plugin)"
if echo "$OUT8P" | grep -qE "总: 1$"; then
  ok "--source=plugin 只返回 1 个"
else
  bad "--source=plugin 数量不对 — 实际: $(echo "$OUT8P" | tail -1)"
fi

# ─────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════"
echo "PASS: $PASS | FAIL: $FAIL"
echo "═══════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1
