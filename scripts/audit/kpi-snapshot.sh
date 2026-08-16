#!/usr/bin/env bash
# scripts/audit/kpi-snapshot.sh — Q2 决策: 单一 source of truth for KALLAX KPI
# Iter 3 / EPIC-GAP6: stop the 3-document KPI drift (CLAUDE.md / KALLAX-GLOSSARY.md / approval-tiering.md).
#
# 输出 JSON 到 stdout 含:
#   - timestamp (ISO8601 UTC)
#   - rule_count (实测: CLAUDE.md + confluence/decisions/ PHASE rules 合计)
#   - glossary_term_count (实测: docs/CHEATSHEET.md + 5-levels.md + 4-roles.md sections)
#   - workspace_file_count (git ls-files | wc -l)
#   - rust_crate_count (从 Cargo.toml [workspace] members 段)
#   - rust_workspace_version (rust/Cargo.toml [workspace.package] version)
#   - node_package_version (package.json version)
#   - net_value: deprecated (Q7 决策: 砍 35 術语后 0 KPI 数字, 不再跟踪)
#   - upgrade_rate: deprecated (同上)
#   - fatigue_index: deprecated (同上)
#
# 跟 Rule 19 (5 类标签 SOP) + Rule 5 (DRY) 联合: 1 snapshot, 1 timestamp, 1 source.
#
# 退出码: 0 总是 (snapshot 是 read-only, 不 fail; CI 可 parse + compare)。

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT" || exit 1

BUILD_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --build-only) BUILD_ONLY=1 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Rule count: CLAUDE.md 现有 0 numeric rules (Iter 2 trim to 3.3KB);
# 改数 confluence/decisions/ 下的 PHASE-* / EPIC-* 决策文件 (实际 rule 落地).
rule_count() {
  local n=0
  if [[ -d confluence/decisions ]]; then
    n=$(find confluence/decisions -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "$n"
}

# Glossary term count: docs/CHEATSHEET.md + 5-levels.md + 4-roles.md
# (Q16 决策: 砍 35 術语后 3 single-source docs 替代 glossary).
glossary_term_count() {
  local total=0
  for f in docs/CHEATSHEET.md docs/5-levels.md docs/4-roles.md; do
    if [[ -f "$f" ]]; then
      local c
      c=$(grep -cE "^## " "$f" 2>/dev/null || true)
      c=${c:-0}
      total=$((total + c))
    fi
  done
  echo "$total"
}

# Workspace file count
workspace_file_count() {
  git ls-files 2>/dev/null | wc -l | tr -d ' '
}

# Rust crate count: parse Cargo.toml workspace members
rust_crate_count() {
  if [[ -f rust/Cargo.toml ]]; then
    sed -n '/^\[workspace\]/,/^]/p' rust/Cargo.toml \
      | grep -cE '^[[:space:]]+"crates/' 2>/dev/null || true
  else
    echo 0
  fi
}

# Rust workspace version
rust_workspace_version() {
  if [[ -f rust/Cargo.toml ]]; then
    awk -F'"' '/^version[[:space:]]*=/ {print $2; exit}' rust/Cargo.toml
  else
    echo "unknown"
  fi
}

# Node package version (top-level package.json)
node_package_version() {
  if [[ -f package.json ]]; then
    grep -E '"version"' package.json | head -1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
  else
    echo "unknown"
  fi
}

# Build artifact count: node/dist + rust/target (Q2 决策: build-relevant KPI)
build_artifact_count() {
  local total=0
  if [[ -d node/dist ]]; then
    total=$((total + $(find node/dist -type f 2>/dev/null | wc -l | tr -d ' ')))
  fi
  if [[ -d rust/target/release ]]; then
    total=$((total + $(find rust/target/release -maxdepth 1 -type f -executable 2>/dev/null | wc -l | tr -d ' ')))
  fi
  if [[ -d rust/target/debug ]]; then
    total=$((total + $(find rust/target/debug -maxdepth 1 -type f -executable 2>/dev/null | wc -l | tr -d ' ')))
  fi
  echo "$total"
}

main() {
  local ts rc gc wfc rcc rwv npv bac
  ts=$(timestamp)
  rc=$(rule_count)
  gc=$(glossary_term_count)
  wfc=$(workspace_file_count)
  rcc=$(rust_crate_count)
  rwv=$(rust_workspace_version)
  npv=$(node_package_version)
  bac=$(build_artifact_count)

  if [[ "$BUILD_ONLY" == "1" ]]; then
    cat <<EOF
{
  "mode": "build-only",
  "rule_count": ${rc},
  "rust_crate_count": ${rcc},
  "build_artifact_count": ${bac},
  "rust_workspace_version": "${rwv}",
  "node_package_version": "${npv}"
}
EOF
    return 0
  fi

  cat <<EOF
{
  "timestamp": "${ts}",
  "rule_count": ${rc},
  "glossary_term_count": ${gc},
  "workspace_file_count": ${wfc},
  "rust_crate_count": ${rcc},
  "rust_workspace_version": "${rwv}",
  "node_package_version": "${npv}",
  "build_artifact_count": ${bac},
  "net_value": "deprecated (Q7 决策: 砍 35 術语后 0 KPI 数字)",
  "upgrade_rate": "deprecated (Q7 决策)",
  "fatigue_index": "deprecated (Q7 决策)"
}
EOF
}

main