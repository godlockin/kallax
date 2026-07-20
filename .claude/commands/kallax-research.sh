#!/usr/bin/env bash
# /kallax-research — Guided research on an existing project (EPIC-135-A).
#
# Subcommands:
#   detect [path]            — detect tech stack + git stats (deterministic, 0 LLM)
#   dispatch [path] [opts]   — generate RESEARCH-DISPATCH.md + role prompt templates
#   help                     — show usage
#
# Borrowed pattern from eket/scripts/analyze-existing.sh (借方法论 不借代码).
# Output dir: confluence/decisions/research-<date>/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_kallax_common.sh"

DATE=$(date +%Y-%m-%d)

# ── Tech stack detection (Step 1, deterministic, 0 LLM) ────────────────────

detect_tech_stack() {
  local root="$1"
  local stack_parts=()

  [ -f "$root/package.json" ]      && stack_parts+=("Node.js/TypeScript")
  { [ -f "$root/requirements.txt" ] || [ -f "$root/pyproject.toml" ] || [ -f "$root/setup.py" ]; } \
                                    && stack_parts+=("Python")
  [ -f "$root/go.mod" ]            && stack_parts+=("Go")
  [ -f "$root/Cargo.toml" ]        && stack_parts+=("Rust")
  [ -f "$root/pom.xml" ]           && stack_parts+=("Java/Maven")
  [ -f "$root/build.gradle" ]      || [ -f "$root/build.gradle.kts" ] \
                                    && stack_parts+=("Java/Gradle")
  [ -f "$root/Gemfile" ]           && stack_parts+=("Ruby")
  [ -f "$root/composer.json" ]     && stack_parts+=("PHP")
  [ -f "$root/Package.swift" ]     && stack_parts+=("Swift")
  [ -f "$root/pubspec.yaml" ]      && stack_parts+=("Dart/Flutter")

  if [ ${#stack_parts[@]} -eq 0 ]; then
    echo "Unknown"
  else
    IFS=', '
    echo "${stack_parts[*]}"
  fi
}

detect_git_stats() {
  local root="$1"
  if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    echo "no git"
    return
  fi

  local commits branches contributors last_commit
  commits=$(git -C "$root" log --oneline 2>/dev/null | wc -l | tr -d ' ')
  branches=$(git -C "$root" branch -a 2>/dev/null | wc -l | tr -d ' ')
  contributors=$(git -C "$root" shortlog -sn 2>/dev/null | wc -l | tr -d ' ')
  last_commit=$(git -C "$root" log -1 --format="%ar" 2>/dev/null || echo "n/a")

  echo "commits=$commits branches=$branches contributors=$contributors last=$last_commit"
}

detect_package_count() {
  local root="$1"
  local count=0
  if [ -f "$root/package.json" ]; then
    count=$(grep -cE '"[a-zA-Z@][^"]+":' "$root/package.json" 2>/dev/null || echo "0")
  fi
  echo "$count"
}

cmd_detect() {
  local target="${1:-.}"

  if [ ! -d "$target" ] && [ ! -f "$target" ]; then
    log_error "路径不存在: $target"
    exit 1
  fi

  log_title "Tech Stack Detection"

  local stack git_stats pkg_count
  stack=$(detect_tech_stack "$target")
  git_stats=$(detect_git_stats "$target")
  pkg_count=$(detect_package_count "$target")

  printf "  ${BOLD}Path${NC}:        %s\n" "$target"
  printf "  ${BOLD}Tech Stack${NC}:  %s\n" "$stack"
  printf "  ${BOLD}Git${NC}:         %s\n" "$git_stats"
  [ "$pkg_count" -gt 0 ] 2>/dev/null && printf "  ${BOLD}Node packages${NC}: %s\n" "$pkg_count" || true

  # File breakdown (top 5 extensions)
  echo ""
  printf "  ${BOLD}File breakdown (top 5 ext)${NC}:\n"
  if [ -d "$target" ]; then
    set +o pipefail
    find "$target" -type f \
      ! -path '*/node_modules/*' ! -path '*/.git/*' \
      ! -path '*/target/*' ! -path '*/dist/*' \
      ! -path '*/__pycache__/*' ! -path '*/venv/*' \
      2>/dev/null \
      | sed 's/.*\.//' \
      | sort | uniq -c | sort -rn | head -5 \
      | awk '{printf "    %-10s %s\n", $2, $1}'
    set -o pipefail
  fi

  echo ""
  printf "  ${BOLD}下一步${NC}: /kallax-research (进入 Step 2 引导 4 问)\n"
}

# ── Dispatch (Step 3, deterministic, 0 LLM) ────────────────────────────────

# Default role recommendations per purpose (mirrors /kallax-research.md Q1 → Q4)
default_roles_for_purpose() {
  case "$1" in
    architecture) echo "architect,developer,researcher" ;;
    code-quality) echo "developer,auditor,researcher" ;;
    security)     echo "developer,auditor,security" ;;
    performance)  echo "developer,architect,performance" ;;
    product)      echo "product,researcher,architect" ;;
    overview)     echo "architect,developer,product" ;;
    deep-audit)   echo "architect,developer,auditor,product,researcher,security,performance" ;;
    *)            echo "architect,developer,product" ;;
  esac
}

# Build a role-specific prompt by injecting context into a template
# Falls back to inline default if .claude/skills/kallax/experts/<role>.md absent
build_role_prompt() {
  local role="$1"
  local purpose="$2"
  local depth="$3"
  local focus="$4"
  local project_path="$5"
  local tech_stack="$6"
  local git_stats="$7"
  local dir_tree="$8"
  local output_path="$9"

  # Precompute depth limit (bash heredoc can't call functions inline)
  local dlimit
  dlimit=$(depth_limit_for_depth "$depth")

  # Default prompt template (in lieu of expert skill file)
  cat <<EOF
# Slaver: ${role} — ${purpose} (depth=${depth})

## Project
- **Path**: ${project_path}
- **Tech Stack**: ${tech_stack}
- **Git**: ${git_stats}

## Task
研究此项目,从 ${role} 视角输出报告 (focus: ${focus:-none})。

## Constraints
- 限 Read 单文件 < 500 行
- 限 Grep 输出 < 100 行
- 报告 < ${dlimit} 行
- 0 build / 0 install / 0 test
- 0 修改任何文件

## Directory tree (前 150 行, 已过滤 node_modules / .git / dist / target)
\`\`\`
${dir_tree}
\`\`\`

## Output
写到: ${output_path}

格式:
\`\`\`markdown
# ${role} 视角分析

## 🎯 关注点
(架构 / 代码 / 风险 / 性能 / 产品 / 安全)

## 📋 关键发现
(按 P0/P1/P2 排序)

## 🔍 详尽分析
(代码示例 + file:line + 引用)

## 💡 可借鉴点
(对 KALLAX 框架的建议,具体可落地)
\`\`\`

## 完成后
回 echo "✓ ${role}-REPORT.md done"
EOF
}

depth_limit_for_depth() {
  case "$1" in
    quick)       echo "100" ;;
    detailed)    echo "300" ;;
    deep-audit)  echo "500" ;;
    *)           echo "300" ;;
  esac
}

cmd_dispatch() {
  local target=""
  local purpose=""
  local depth="detailed"
  local focus=""
  local roles=""

  # Parse args: positional = target, --key=value for options
  while [ $# -gt 0 ]; do
    case "$1" in
      --purpose=*) purpose="${1#--purpose=}" ;;
      --depth=*)   depth="${1#--depth=}" ;;
      --focus=*)   focus="${1#--focus=}" ;;
      --roles=*)   roles="${1#--roles=}" ;;
      -h|--help)
        echo "Usage: dispatch [path] [--purpose=X] [--depth=X] [--focus=a,b] [--roles=a,b,c]"
        exit 0
        ;;
      *)
        if [ -z "$target" ]; then
          target="$1"
        else
          log_error "Unknown arg: $1"
          exit 1
        fi
        ;;
    esac
    shift
  done

  target="${target:-.}"

  if [ ! -d "$target" ] && [ ! -f "$target" ]; then
    log_error "路径不存在: $target"
    exit 1
  fi

  if [ -z "$purpose" ]; then
    log_error "--purpose= 必填 (architecture/code-quality/security/performance/product/overview/deep-audit)"
    exit 1
  fi

  # Default roles if not provided
  if [ -z "$roles" ]; then
    roles=$(default_roles_for_purpose "$purpose")
    log_info "按 purpose=$purpose 自动推荐角色: $roles"
  fi

  # Compute context (temporarily disable pipefail for find|head SIGPIPE tolerance)
  local tech_stack git_stats dir_tree
  tech_stack=$(detect_tech_stack "$target")
  git_stats=$(detect_git_stats "$target")
  set +o pipefail
  dir_tree=$(find "$target" \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/dist/*' -not -path '*/target/*' \
    -not -path '*/__pycache__/*' -not -path '*/venv/*' \
    2>/dev/null | head -150 | sort)
  set -o pipefail

  # Output dir
  local output_root="${KALLAX_ROOT}/confluence/decisions/research-${DATE}"
  mkdir -p "$output_root"

  log_title "Research Dispatch"
  echo "  Target:   $target"
  echo "  Purpose:  $purpose"
  echo "  Depth:    $depth"
  echo "  Focus:    ${focus:-none}"
  echo "  Roles:    $roles"
  echo "  Output:   $output_root"
  echo ""

  # Generate per-role prompt files + report placeholders
  IFS=',' read -ra ROLE_ARRAY <<< "$roles"
  for role in "${ROLE_ARRAY[@]}"; do
    role=$(echo "$role" | xargs)  # trim whitespace
    local prompt_file="$output_root/.prompt-${role}.md"
    local report_file="$output_root/${role}-REPORT.md"

    build_role_prompt \
      "$role" "$purpose" "$depth" "$focus" \
      "$target" "$tech_stack" "$git_stats" "$dir_tree" \
      "$report_file" > "$prompt_file"

    # Empty report placeholder
    [ -f "$report_file" ] || cat > "$report_file" <<EOF
# ${role} 视角分析报告 (待填充)

> 由 /kallax-research 生成于 $(date -u +%Y-%m-%dT%H:%M:%SZ)
> 参考 prompt: ${prompt_file}

<!--
  LLM Step 4: 读取 ${prompt_file},按指示输出报告,然后回写此文件。
-->
EOF

    log_info "  ${role}: prompt + report 占位 OK"
  done

  # DISPATCH.md (main entry) — use quoted heredoc + envsubst-lite via sed to avoid backtick/${arr} pitfalls
  local dispatch_file="$output_root/DISPATCH.md"
  # Build role checklist as a pre-computed string
  local role_checklist=""
  for role in "${ROLE_ARRAY[@]}"; do
    role=$(echo "$role" | xargs)
    role_checklist+="- [ ] ${role}  (.prompt-${role}.md → ${role}-REPORT.md)"$'\n'
  done

  # Write with plain-text quoted heredoc, then substitute placeholders
  cat > "$dispatch_file" <<'DISPATCH_EOF'
# 📊 Research Dispatch — __DATE__

> **Target**:  __TARGET__
> **Purpose**: __PURPOSE__
> **Depth**:   __DEPTH__
> **Focus**:   __FOCUS__
> **Roles**:   __ROLES__
> **Tech**:    __TECH__
> **Git**:     __GIT__

## Next Steps (LLM-driven, Step 4-5)

对每个角色 `<role>`:

1. 读取 `.prompt-<role>.md` 获取任务
2. 模拟 `<role>` 视角,Read 目标项目 5-10 个关键文件
3. 按 prompt 指示输出报告,写入 `<role>-REPORT.md`
4. echo "✓ <role>-REPORT.md done"

完成后:

5. 读所有 `<role>-REPORT.md`
6. 生成 `alignment.md`:跨角色共识 / 冲突 / Top 10 行动项 / 可借鉴点

## Role Checklist

__CHECKLIST__

## Output Files

| 文件 | 用途 |
|------|------|
| `DISPATCH.md` | 本文件 |
| `.prompt-<role>.md` | 每个角色的 prompt 模板 |
| `<role>-REPORT.md` | 每个角色的报告(LLM Step 4 填) |
| `alignment.md` | 综合报告(LLM Step 5 填) |
DISPATCH_EOF

  # Substitute placeholders (using | as sed delimiter to survive paths with /)
  local focus_display="${focus:-none}"
  # Escape sed special chars in values
  local esc_target=$(printf '%s\n' "$target" | sed 's|[\|&]|\\&|g')
  local esc_tech=$(printf '%s\n' "$tech_stack" | sed 's|[\|&]|\\&|g')
  local esc_git=$(printf '%s\n' "$git_stats" | sed 's|[\|&]|\\&|g')
  local esc_checklist=$(printf '%s' "$role_checklist" | sed 's|[\|&]|\\&|g' | awk '{printf "%s\\n", $0}')

  sed -i.bak \
    -e "s|__DATE__|${DATE}|g" \
    -e "s|__TARGET__|${esc_target}|g" \
    -e "s|__PURPOSE__|${purpose}|g" \
    -e "s|__DEPTH__|${depth}|g" \
    -e "s|__FOCUS__|${focus_display}|g" \
    -e "s|__ROLES__|${roles}|g" \
    -e "s|__TECH__|${esc_tech}|g" \
    -e "s|__GIT__|${esc_git}|g" \
    "$dispatch_file"
  rm -f "${dispatch_file}.bak"

  # Substitute the multi-line checklist separately via python (sed multi-line is a pain)
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$dispatch_file" "$role_checklist" <<'PYEOF'
import sys
path = sys.argv[1]
checklist = sys.argv[2]
with open(path, 'r') as f:
    content = f.read()
content = content.replace('__CHECKLIST__', checklist.rstrip())
with open(path, 'w') as f:
    f.write(content)
PYEOF
  else
    # Fallback: just replace with a note
    sed -i.bak "s|__CHECKLIST__|(see .prompt-*.md files)|g" "$dispatch_file"
    rm -f "${dispatch_file}.bak"
  fi

  echo ""
  log_info "Dispatch 包已生成:"
  printf "  ${BOLD}%s${NC}\n" "$dispatch_file"
  echo ""
  echo "  下一步:LLM 读 DISPATCH.md → Step 4 模拟角色视角 → Step 5 alignment.md"
}

cmd_help() {
  cat <<EOF
/kallax-research — Guided research on an existing project (EPIC-135-A)

USAGE:
  /kallax-research [path]
  /kallax-research [path] --purpose=<X> [--depth=<X>] [--focus=<a,b>] [--roles=<a,b,c>]

SUBCOMMANDS (via .sh):
  bash .claude/commands/kallax-research.sh detect [path]
  bash .claude/commands/kallax-research.sh dispatch [path] --purpose=<X> [opts]

PURPOSES:
  architecture  code-quality  security  performance
  product       overview      deep-audit

DEPTHS:
  quick (100 行/角色)  detailed (300 行/角色,默认)
  deep-audit (500 行/角色)

EXAMPLES:
  # 引导式(LLM 调 AskUserQuestion 4 问)
  /kallax-research ~/work/grok-build

  # 直接 dispatch (跳过引导)
  bash .claude/commands/kallax-research.sh dispatch ~/work/grok-build \\
    --purpose=architecture --depth=detailed --focus=ci-cd --roles=architect,developer

RELATED:
  /kallax-onramp   — L0 入门(项目扫描)
  /kallax-takeover — L2 接手存量项目

BORROWED FROM:
  eket/scripts/analyze-existing.sh (借方法论 不借代码, EPIC-135-A)
EOF
}

# ── Main ────────────────────────────────────────────────────────────────────

main() {
  local subcmd="${1:-help}"
  shift || true

  case "$subcmd" in
    detect)   cmd_detect "$@" ;;
    dispatch) cmd_dispatch "$@" ;;
    help|--help|-h) cmd_help ;;
    *)
      # Bare path arg → run detect
      cmd_detect "$subcmd"
      ;;
  esac
}

main "$@"