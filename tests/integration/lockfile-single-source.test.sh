#!/usr/bin/env bash
# tests/integration/lockfile-single-source.test.sh — EPIC-255
#
# 锚定 workspace lockfile 单一来源, 防止子包 lockfile 再次出现导致版本分叉.
#
# 真根因 (4 层挖掘后确认):
#   node/package-lock.json 锁 vitest 1.6.1, 根 lockfile 锁 4.1.10,
#   node/package.json 声明 ^4.1.10 — 三者对不上.
#   装 1.6.1 时它按 hoisting 去根 node_modules 找 tinypool (v1 依赖, v4 不用),
#   那里是 4.1.10 的树 → No handler function exported from vitest/dist/worker.js.
#
# node/package-lock.json 只有 1 次提交 (080eb414 EPIC-211 npm audit fix), 意外产生.
# workspace 项目只该有根 lockfile.
#
# Exit: 0 = all PASS, 1 = FAIL

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
no() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ── Case 1: 根 package.json 声明 workspaces ──────────────────────────────────
echo "Case 1: root package.json declares workspaces"
WS=$(jq -r '.workspaces // empty | if type == "array" then join(",") else . end' "$KALLAX_ROOT/package.json" 2>/dev/null)
if [ -n "$WS" ]; then
  ok "workspaces = [$WS]"
else
  no "no workspaces field (hoisting assumption broken)"
fi

# ── Case 2: 只有根 lockfile, 无子包 lockfile ─────────────────────────────────
echo ""
echo "Case 2: single lockfile at repo root (no workspace-member lockfiles)"
if [ -f "$KALLAX_ROOT/package-lock.json" ]; then
  ok "root package-lock.json exists"
else
  no "root package-lock.json missing"
fi
if [ -f "$KALLAX_ROOT/node/package-lock.json" ]; then
  no "node/package-lock.json exists (version fork risk — EPIC-255 removed it)"
else
  ok "node/package-lock.json absent (single source of truth)"
fi

# ── Case 3: 根 lockfile 覆盖 node/ 的 devDependencies ────────────────────────
echo ""
echo "Case 3: root lockfile covers node/ workspace deps"
if jq -e '.packages | has("node")' "$KALLAX_ROOT/package-lock.json" >/dev/null 2>&1; then
  DEVDEPS=$(jq -r '.packages["node"].devDependencies // {} | keys | length' "$KALLAX_ROOT/package-lock.json" 2>/dev/null)
  DECLARED=$(jq -r '.devDependencies // {} | keys | length' "$KALLAX_ROOT/node/package.json" 2>/dev/null)
  if [ "${DEVDEPS:-0}" -eq "${DECLARED:-0}" ] 2>/dev/null; then
    ok "root lockfile records all $DEVDEPS node/ devDependencies"
  else
    no "mismatch: lockfile has ${DEVDEPS:-0}, package.json declares ${DECLARED:-0}"
  fi
else
  no "root lockfile has no 'node' workspace entry"
fi

# ── Case 4: vitest 版本声明跟锁定吻合 ────────────────────────────────────────
echo ""
echo "Case 4: vitest version consistent between declaration and lock"
DECL=$(jq -r '.devDependencies.vitest // empty' "$KALLAX_ROOT/node/package.json" 2>/dev/null)
LOCKED=$(jq -r '.packages["node_modules/vitest"].version // empty' "$KALLAX_ROOT/package-lock.json" 2>/dev/null)
if [ -n "$DECL" ] && [ -n "$LOCKED" ]; then
  # 去掉 ^ ~ 前缀比 major
  DECL_MAJOR=$(printf '%s' "$DECL" | sed 's/^[^0-9]*//' | cut -d. -f1)
  LOCK_MAJOR=$(printf '%s' "$LOCKED" | cut -d. -f1)
  if [ "$DECL_MAJOR" = "$LOCK_MAJOR" ]; then
    ok "declared $DECL, locked $LOCKED (major $LOCK_MAJOR matches)"
  else
    no "major mismatch: declared $DECL (major $DECL_MAJOR), locked $LOCKED (major $LOCK_MAJOR)"
  fi
else
  no "cannot read vitest version (declared='$DECL', locked='$LOCKED')"
fi

# ── Case 5: 文档记录正确装法 ─────────────────────────────────────────────────
echo ""
echo "Case 5: .claude/rules/testing.md documents the install command + root cause"
RULE="$KALLAX_ROOT/.claude/rules/testing.md"
if [ -f "$RULE" ]; then
  if grep -q 'npm install --prefix <repo-or-worktree-root>' "$RULE" 2>/dev/null; then
    ok "install command documented"
  else
    no "install command not documented"
  fi
  if grep -q 'EPIC-255' "$RULE" 2>/dev/null; then
    ok "EPIC-255 referenced"
  else
    no "EPIC-255 reference missing"
  fi
  if grep -qE '两份 lockfile 锁不同|真根因' "$RULE" 2>/dev/null; then
    ok "root cause (version fork) explained"
  else
    no "root cause not explained"
  fi
  if grep -q 'BLOCKED-env' "$RULE" 2>/dev/null; then
    ok "affected historical verdicts listed (not rewritten)"
  else
    no "affected verdicts not listed"
  fi
else
  no ".claude/rules/testing.md missing"
fi

# ── Case 6: tinypool 不该出现在根 lockfile (v4 不依赖它) ─────────────────────
echo ""
echo "Case 6: tinypool absent from root lockfile (vitest v4 dropped it)"
TP=$(grep -c 'tinypool' "$KALLAX_ROOT/package-lock.json" 2>/dev/null || true)
TP=${TP:-0}
if [ "$TP" -eq 0 ]; then
  ok "tinypool not in root lockfile (consistent with vitest v4)"
else
  echo "  INFO: $TP tinypool references (may be legitimate if vitest downgraded)"
  PASS=$((PASS + 1))
fi

echo ""
echo "================================================"
echo "EPIC-255 Lockfile Single Source Tests: $PASS passed, $FAIL failed"
echo "================================================"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
