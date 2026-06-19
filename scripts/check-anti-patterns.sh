#!/usr/bin/env bash
# scripts/check-anti-patterns.sh — Detect 7 anti-patterns that create long-term debt
# v2.7.4 cleanup, 跟 主公 2026-06-19 '不埋坑 / 长期提升优先' 5 原则 联合
# 跟 v2.7.1 9 hard rules 模式 一致 (硬性 脚本 校验, 跟 Master 6 维 L6 诚实 联合)
# 跟 EPIC-059-D Fact-Forcing 联合 (治根 跟 反讽 联合 反复)
# Usage: ./scripts/check-anti-patterns.sh [directory] (default: .)
set -uo pipefail

TARGET="${1:-.}"
ISSUES=0
WARNINGS=0

# Colors (跟 scripts/install.sh 模式 一致)
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
err()   { echo -e "${RED}[ERR]${NC} $1" >&2; ISSUES=$((ISSUES + 1)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1" >&2; WARNINGS=$((WARNINGS + 1)); }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }

echo "════════════════════════════════════════════"
echo " KALLAX Anti-Pattern Check (7 categories)"
echo " Target: $TARGET"
echo "════════════════════════════════════════════"
echo ""

# ── Anti-Pattern 1: 4+ level up imports (跟 v2.7.4 B5.1 治根 联合) ──
# Fragile path that breaks when test or source dir is reorganized.
# Example: import { x } from '../../../../node/src/foo';
echo "─── Anti-Pattern 1: 4+ level up imports ───"
grep -rEn "from\s+['\"]\.\.\/\.\.\/\.\.\/\.\.\/" "$TARGET" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.mjs" 2>/dev/null \
  | grep -v node_modules | grep -v "node/src/permissions" || true
FOUND_4LEVEL=$(grep -rE "from\s+['\"]\.\.\/\.\.\/\.\.\/\.\.\/" "$TARGET" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.mjs" 2>/dev/null \
  | grep -v node_modules | awk 'END{print NR+0; exit 0}' 2>/dev/null)
FOUND_4LEVEL=${FOUND_4LEVEL:-0}
if [ "$FOUND_4LEVEL" -gt 0 ]; then
  err "Found $FOUND_4LEVEL 4-level-up import(s) — fragile, breaks on dir rename. Refactor to 0-2 levels."
else
  ok "0 4-level-up imports (跟 v2.7.4 B5.1 治根 联合, 跟 Rule 5 DRY 联合)"
fi
echo ""

# ── Anti-Pattern 2: legacy/ or deprecated/ directories (跟 v2.7.4 B5.1 治根 联合) ──
# Permanent legacy paths accumulate debt; either delete or rename to clear status.
echo "─── Anti-Pattern 2: legacy/ or deprecated/ dirs ───"
LEGACY_DIRS=$(find "$TARGET" -type d \( -name "legacy" -o -name "deprecated" -o -name "old" -o -name "archive" \) 2>/dev/null \
  | grep -v node_modules | grep -v ".git" | grep -v "/_archive/" | grep -v "archive/" || true)
if [ -n "$LEGACY_DIRS" ]; then
  err "Found 'legacy'/'deprecated' dirs (not in _archive/):"
  echo "$LEGACY_DIRS" | head -5
else
  ok "0 legacy/deprecated dirs (跟 v2.7.4 B5.1 治根 联合)"
fi
echo ""

# ── Anti-Pattern 3: TODO with `exit 0` stubs (跟 v2.7.4 B1 治根 联合) ──
# Stub scripts that pretend to pass preflight gates (Rule 18 anti-fab).
# Detection: file has "TODO" comment + `exit 0` at line 6+ (after some code) + no preceding test code.
echo "─── Anti-Pattern 3: TODO with `exit 0` stubs ───"
STUB_FILES=$(find "$TARGET/scripts" -name "*.sh" 2>/dev/null \
  | grep -v "check-anti-patterns.sh" \
  | while read -r f; do
      # Check for pattern: TODO comment + exit 0 in same file, AND file is <30 lines (stub size)
      if grep -q "TODO" "$f" 2>/dev/null && grep -q "^exit 0" "$f" 2>/dev/null; then
        LINES=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
        if [ "$LINES" -lt 30 ]; then
          echo "$f"
        fi
      fi
    done 2>/dev/null | head -10 || true)
STUB_COUNT=$(printf '%s' "$STUB_FILES" | awk 'END{print NR+0; exit 0}' 2>/dev/null)
STUB_COUNT=${STUB_COUNT:-0}
if [ "$STUB_COUNT" -gt 0 ]; then
  err "Found $STUB_COUNT TODO + exit 0 stub script(s) — silently pass preflight (Rule 18 anti-fab violation):"
  echo "$STUB_FILES" | head -5
else
  ok "0 TODO + exit 0 stubs (跟 v2.7.4 B1 治根 联合, 跟 Rule 18 联合)"
fi
echo ""

# ── Anti-Pattern 4: Hardcoded /Users/ paths in markdown (跟 v2.7.4 B3 治根 联合) ──
# Privacy leak + non-portable. Use $HOME or relative paths.
echo "─── Anti-Pattern 4: Hardcoded /Users/ paths in docs ───"
HARDCODED=$(grep -rEl "/Users/[a-zA-Z0-9_-]+/" "$TARGET" \
  --include="*.md" --include="*.txt" 2>/dev/null \
  | grep -v node_modules | grep -v ".git" | grep -v "_archive/" | head -10 || true)
HARDCODED_COUNT=$(printf '%s' "$HARDCODED" | awk 'END{print NR+0; exit 0}' 2>/dev/null)
HARDCODED_COUNT=${HARDCODED_COUNT:-0}
if [ "$HARDCODED_COUNT" -gt 0 ]; then
  warn "Found $HARDCODED_COUNT hardcoded /Users/ in docs (consider \$HOME or relative):"
  echo "$HARDCODED" | head -5
else
  ok "0 hardcoded /Users/ paths in docs (跟 v2.7.4 B3 治根 联合)"
fi
echo ""

# ── Anti-Pattern 5: console.log in src/ (跟 Rule 7 联合) ──
# Production source should use structured logger, not console.log.
echo "─── Anti-Pattern 5: console.log in src/ (Rule 7) ───"
CONSOLE_LOGS=$(grep -rEn "^\s*console\.(log|error|warn)\(" "$TARGET/node/src" --include="*.ts" 2>/dev/null \
  | grep -v "tests/" | grep -v ".test.ts" || true)
CONSOLE_COUNT=$(printf '%s' "$CONSOLE_LOGS" | awk 'END{print NR+0; exit 0}' 2>/dev/null)
CONSOLE_COUNT=${CONSOLE_COUNT:-0}
if [ "$CONSOLE_COUNT" -gt 0 ]; then
  warn "Found $CONSOLE_COUNT console.log/error/warn in node/src/ (Rule 7 violation, use logger):"
  echo "$CONSOLE_LOGS" | head -3
else
  ok "0 console.log in node/src/ (跟 Rule 7 联合, 跟 v2.7.4 整理 release 联合)"
fi
echo ""

# ── Anti-Pattern 6: Files over 500 lines (跟 Rule 8 联合) ──
# Too-large files reduce reviewability and increase risk.
echo "─── Anti-Pattern 6: Files over 500 lines (Rule 8) ───"
LARGE_FILES=$(find "$TARGET" \( -path "*/src/*" -o -path "*/node/src/*" -o -path "*/rust/*" \) \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.rs" \) 2>/dev/null \
  | grep -v node_modules | grep -v "/target/" | grep -v ".test." \
  | xargs wc -l 2>/dev/null | awk '$1 > 500 {print $0}' | head -5 || true)
LARGE_COUNT=$(printf '%s' "$LARGE_FILES" | awk 'END{print NR+0; exit 0}' 2>/dev/null)
LARGE_COUNT=${LARGE_COUNT:-0}
if [ "$LARGE_COUNT" -gt 0 ]; then
  warn "Found $LARGE_COUNT file(s) > 500 lines (Rule 8 violation, consider splitting):"
  echo "$LARGE_FILES" | head -3
else
  ok "0 files > 500 lines (跟 Rule 8 联合, 跟 v2.7.4 整理 release 联合)"
fi
echo ""

# ── Anti-Pattern 7: OUTDATED marker in non-archive (跟 v2.7.4 B3 治根 联合) ──
# Files marked OUTDATED should be in _archive/, not main tree.
echo "─── Anti-Pattern 7: OUTDATED marker in non-archive ───"
OUTDATED_FILES=$(grep -rEl "^>\s*⚠️\s*\*\*OUTDATED\*\*|^>\s*\*\*OUTDATED\*\*" "$TARGET" \
  --include="*.md" 2>/dev/null \
  | grep -v node_modules | grep -v "_archive/" 2>/dev/null || true)
OUTDATED_COUNT=$(printf '%s' "$OUTDATED_FILES" | awk 'END{print NR+0; exit 0}' 2>/dev/null)
OUTDATED_COUNT=${OUTDATED_COUNT:-0}
if [ "$OUTDATED_COUNT" -gt 0 ]; then
  warn "Found $OUTDATED_COUNT OUTDATED file(s) outside _archive/ (consider archiving):"
  echo "$OUTDATED_FILES" | head -5
else
  ok "0 OUTDATED files in non-archive (跟 v2.7.4 B3 治根 联合)"
fi
echo ""

# ── Summary ──
echo "════════════════════════════════════════════"
if [ "$ISSUES" -gt 0 ]; then
  err "Anti-Pattern Check: $ISSUES ERRORS, $WARNINGS WARNINGS"
  echo "════════════════════════════════════════════"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  warn "Anti-Pattern Check: 0 ERRORS, $WARNINGS WARNINGS"
  echo "════════════════════════════════════════════"
  exit 0
else
  ok "Anti-Pattern Check: 0 ERRORS, 0 WARNINGS — 7/7 categories clean ✅"
  echo "════════════════════════════════════════════"
  exit 0
fi
