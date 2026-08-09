#!/usr/bin/env bash
# scripts/verify/check-self-heal.sh — self-heal pattern 检测
# 强制 self-heal pattern (跟 V310-B S-003 + V350-B S-005/S-006 1:1 联合)
#
# 检测类别:
#   1. 应有 self-heal 模式 但 没有: chmod 600/700 缺失
#   2. `if ! verify then chmod` 缺失
#   3. fire-and-forget 模式 (写文件但 0 验证)
#
# Exit: 0 = pass, 1 = fail (found missing self-heal)
#
# v3.6.0 immutable law

set -euo pipefail

# KALLAX_DESIGN_MODE: master token 显式 拍板 mode
# 用法: KALLAX_DESIGN_MODE=1 bash scripts/verify/check-self-heal.sh
# 跟 check-scope-creep.sh design mode 1:1 联合
# 跟 V350-B P-002 evidence byte-different 1:1 联合 (master token 显式 接受)
if [ -n "${KALLAX_DESIGN_MODE:-}" ] && [ "$KALLAX_DESIGN_MODE" = "1" ]; then
  echo "KALLAX_DESIGN_MODE=1 detected: 4 immutable scripts run as guards, master token 显式 接受 violations"
  echo "WARNING: scripts FAIL 是 设计意图 (0 假装 100% PASS)"
  echo "跟 V350-B P-002 evidence byte-different 1:1 联合"
  echo "Run normal mode: unset KALLAX_DESIGN_MODE && bash $0"
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

SCAN_DIRS=(
  "scripts/audit/"
  "scripts/io/"
  "node/src/utils/"
)

SCAN_FILES=()
for dir in "${SCAN_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  while IFS= read -r f; do
    SCAN_FILES+=("$f")
  done < <(find "$dir" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.sh" \) 2>/dev/null)
done

# EPIC-110-C: KALLAX_STAGED_ONLY=1 → filter to staged files under SCAN_DIRS
if [ -n "${KALLAX_STAGED_ONLY:-}" ] && [ "$KALLAX_STAGED_ONLY" = "1" ]; then
  STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || echo "")
  if [ -z "$STAGED" ]; then
    echo "KALLAX_STAGED_ONLY=1: no staged files, skip"
    exit 0
  fi
  FILTERED=()
  for f in $STAGED; do
    for dir in "${SCAN_DIRS[@]}"; do
      case "$f" in
        "${dir}"*)
          case "$f" in
            *.ts|*.js|*.sh)
              [ -f "$f" ] && FILTERED+=("$f") ;;
          esac
          break ;;
      esac
    done
  done
  if [ ${#FILTERED[@]} -eq 0 ]; then
    echo "KALLAX_STAGED_ONLY=1: no staged files match scan scope, skip"
    exit 0
  fi
  SCAN_FILES=("${FILTERED[@]}")
fi

# 单文件测试支持: TARGET_FILE=path 只测该文件
if [ -n "${TARGET_FILE:-}" ] && [ -f "$TARGET_FILE" ]; then
  SCAN_FILES=("$TARGET_FILE")
fi

if [ ${#SCAN_FILES[@]} -eq 0 ]; then
  echo "=========================================="
  echo "Self-Heal Pattern Check"
  echo "=========================================="
  echo "No scan files found in: ${SCAN_DIRS[*]}"
  echo "PASS: 0 missing self-heal (vacuously true)"
  exit 0
fi

echo "=========================================="
echo "Self-Heal Pattern Check"
echo "=========================================="
echo "Scan files: ${#SCAN_FILES[@]} (from ${SCAN_DIRS[*]})"
echo ""

# Self-heal pattern: chmod 600/700 + if ! verify then chmod
# 检测缺失: 文件 写权限 设置 但 没有 self-heal 验证
SELF_HEAL_MISSING=()

for file in "${SCAN_FILES[@]}"; do
  # Skip this check script itself
  case "$file" in
    *check-self-heal.sh) continue ;;
  esac

  # Check if file sets restrictive permissions (chmod 600/700/0xxx)
  has_chmod=false
  has_self_heal=false

  if grep -qE 'chmod\s+[0-7]00' "$file" 2>/dev/null; then
    has_chmod=true
  fi

  # Self-heal: if ! verify then chmod
  if grep -qE '(if\s+!.*(verify|test|check).*then.*chmod)|(chmod.*if\s+!)|(\|\|\s*chmod)|(\|\|\s*\{)' "$file" 2>/dev/null; then
    has_self_heal=true
  fi

  # Fire-and-forget: write file but no verify
  has_write=false
  has_verify=false
  # 严格匹配: 排除箭头函数/类型/比较
  # - writeFile (TS / Node)
  # - fs.writeFileSync (Node)
  # - > filename (shell redirect, 不是箭头函数或比较)
  # - tee filename (shell)
  # 排除:
  #   - => (箭头函数)
  #   - > type/variable (TS 类型 + 比较)
  #   - .> (chain)
  if grep -qE '(writeFile|fs\.write|>\s+[A-Za-z/_][A-Za-z0-9_./-]*\s*$|tee\s)' "$file" 2>/dev/null; then
    has_write=true
  fi
  # 同步匹配 writeFileSync (TS fs 模块, 跟 writeFile 同义)
  if grep -qE 'writeFileSync|appendFileSync' "$file" 2>/dev/null; then
    has_write=true
  fi
  if grep -qE '(verify|stat|exists|test\s+-f)' "$file" 2>/dev/null; then
    has_verify=true
  fi

  # Report: has_chmod but no self_heal = missing pattern
  if [ "$has_chmod" = true ] && [ "$has_self_heal" = false ]; then
    SELF_HEAL_MISSING+=("$file: chmod 600/700 set but missing self-heal pattern (if ! verify then chmod)")
  fi

  # Fire-and-forget: write but no verify
  if [ "$has_write" = true ] && [ "$has_verify" = false ]; then
    SELF_HEAL_MISSING+=("$file: fire-and-forget write without verify (write but no stat/exists/test)")
  fi
done

if [ ${#SELF_HEAL_MISSING[@]} -gt 0 ]; then
  echo "FAIL: ${#SELF_HEAL_MISSING[@]} missing self-heal patterns:"
  printf '  %s\n' "${SELF_HEAL_MISSING[@]}"
  echo ""
  echo "REQUIREMENT: chmod 600/700 后必须 self-heal (if ! verify then chmod)."
  echo "Reference: V310-B S-003 + V350-B S-005/S-006 1:1 联合"
  echo "[ERR] FAIL-detected → exit 1 (fail-closed, P0-7 治理: 禁止 print FAIL + exit 0)"
  exit 1
fi

# Defense-in-depth (P0-7): if any pattern marker leaked to end of script, fail-closed.
if grep -qE '^FAIL: [0-9]+ missing self-heal patterns' /tmp/.check-self-heal.fail-marker 2>/dev/null; then
  echo "[ERR] Defensive: FAIL marker seen, forcing exit 1"
  exit 1
fi

echo "PASS: 0 missing self-heal patterns in scanned files"
