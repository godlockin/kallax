# EPIC-057-A Implementation Plan

> Ticket: EPIC-057-A — `install.sh --target=auto + 4 工具 skills/commands 路径`
> Performer: backend (bash + shell scripting)
> Worktree: `.kallax/worktrees/performer-EPIC-057-A` (`feature/EPIC-057-A-install-multi-tool`, base `b2722e4`)
> AC target: 8/8 ✅ (Rule 9 KPI 6/6 = 100.0%)
> Created: 2026-06-17

## 1. Scope Recap

v2.0.2 commit `01786f7` named "跨平台 fix release" but `scripts/install.sh` hard-codes
Claude Code paths only. v2.0.5 still ships single-tool installer. Master 2026-06-17
explicit 派 D: refactor `install.sh` to support 4 tools (Claude Code / opencode / Codex /
Gemini) via `--target=auto|all|<tool>|a,b` + `--interactive` flag.

Closed-loop target: rebrand `v2.0.6` install.sh as "actually multi-tool", 与 EPIC-057 联环.

## 2. Environment Audit (实测 baseline @ 2026-06-17)

| Tool | Binary | `$HOME/.<tool>/` | `skills/kallax/` | `commands/` | `settings` |
|---|---|---|---|---|---|
| Claude Code | ✅ `~/.local/bin/claude` | ✅ | ✅ 9 files | ✅ 30 files | ✅ `settings.json` |
| opencode 1.17.7 | ✅ `~/.opencode/bin/opencode` | ✅ | ❌ | ✅ 1 file (`command/` singular) | ❌ `config.json` |
| Codex | ❌ (no binary) | ✅ | ❌ | ✅ 1 file (`prompts/`) | ✅ `config.toml` |
| Gemini 0.22.2 | ✅ `/usr/local/bin/gemini` | ✅ | ❌ | ✅ 1 file (`commands/`) | ❌ `config/settings.json` |

Source dirs in worktree:
- `.claude/commands/` — `_kallax_common.sh` + `kallax-*.sh` (10 files)
- `.claude/skills/kallax/` — full skill tree (9 entries)
- `.opencode/command/` — `_kallax_common.sh` + `kallax-*.md` (10 files, .md format)
- `.opencode/skills/` — MISSING (no skill source)
- `.codex/`, `.gemini/` — MISSING (fallback to `.claude/commands/`)

**Detection signal rule**: `($HOME/.<tool>/) OR (which <tool>)` ⇒ tool considered installed.

## 3. Design — TOOL_PATHS + flag-controlled dispatch

### 3.1 Tool registry (associative arrays)

```bash
# Tool order matters for predictable output
TOOLS=(claude opencode codex gemini)

# Per-tool metadata
declare -A TOOL_BINARY=( \
  [claude]=claude [opencode]=opencode [codex]=codex [gemini]=gemini )
declare -A TOOL_BASE_DIR=( \
  [claude]="$HOME/.claude" [opencode]="$HOME/.opencode" \
  [codex]="$HOME/.codex"   [gemini]="$HOME/.gemini" )
declare -A TOOL_SKILLS_DIR=( \
  [claude]="$HOME/.claude/skills/kallax" [opencode]="$HOME/.opencode/skills/kallax" \
  [codex]="$HOME/.codex/skills/kallax"   [gemini]="$HOME/.gemini/skills/kallax" )
declare -A TOOL_COMMANDS_DIR=( \
  [claude]="$HOME/.claude/commands" [opencode]="$HOME/.opencode/command" \
  [codex]="$HOME/.codex/prompts"   [gemini]="$HOME/.gemini/commands" )
declare -A TOOL_COMMANDS_EXT=( \
  [claude]=sh [opencode]=md [codex]=md [gemini]=sh )
declare -A TOOL_SETTINGS_FILE=( \
  [claude]="$HOME/.claude/settings.json"        [opencode]="$HOME/.opencode/config.json" \
  [codex]="$HOME/.codex/config.toml"            [gemini]="$HOME/.gemini/config/settings.json" )
```

### 3.2 Detection algorithm

```bash
detect_tools() {
  local tool
  for tool in "${TOOLS[@]}"; do
    if [ -d "${TOOL_BASE_DIR[$tool]}" ] || command -v "${TOOL_BINARY[$tool]}" &>/dev/null; then
      DETECTED_TOOLS+=("$tool")
    fi
  done
}
```

### 3.3 Flag parser

`--target=auto`     → use `DETECTED_TOOLS`
`--target=all`      → force all 4 tools (override detection)
`--target=claude`   → single-tool explicit
`--target=a,b,c`    → multi-tool comma-separated (lowercase normalization)
`--target=foo`      → `exit 1` (unknown tool)
`--interactive`     → prompt user with detected-tools list

**Strict mode**: when user explicitly `--target=<tool>` and detection fails, **exit 1**
(test 3). When `--target=auto` and detection yields 0, default behavior is
**exit 1 + suggestion** (test 6). User can override with `--target=all`.

### 3.4 Per-tool install (DRY)

```bash
install_for_tool() {
  local tool="$1"
  install_skills_for_tool "$tool"
  install_commands_for_tool "$tool"
}

install_skills_for_tool() {
  local tool="$1"
  local dst="${TOOL_SKILLS_DIR[$tool]}"
  local src="$PROJECT_ROOT/.claude/skills/kallax"
  [ ! -d "$src" ] && src="$PROJECT_ROOT/template/.claude/skills/kallax"
  [ ! -d "$src" ] && { warn "[$tool] no skill source"; return 0; }
  rm -rf "$dst"; mkdir -p "$(dirname "$dst")"
  cp -r "$src" "$dst"
  ok "[$tool] skills → $dst ($(find "$dst" -type f | wc -l) files)"
}

install_commands_for_tool() {
  local tool="$1"
  local dst="${TOOL_COMMANDS_DIR[$tool]}"
  local ext="${TOOL_COMMANDS_EXT[$tool]}"
  # Source priority: tool-native dir > .claude fallback
  local src="$PROJECT_ROOT/.claude/commands"
  case "$tool" in
    opencode) src="$PROJECT_ROOT/.opencode/command" ;;
    codex)    src="$PROJECT_ROOT/.codex/prompts" ;;
    gemini)   src="$PROJECT_ROOT/.gemini/commands" ;;
  esac
  [ ! -d "$src" ] && src="$PROJECT_ROOT/.claude/commands"
  [ ! -d "$src" ] && src="$PROJECT_ROOT/template/.claude/commands"
  [ ! -d "$src" ] && { warn "[$tool] no commands source"; return 0; }
  mkdir -p "$dst"
  local count=0
  for f in "$src"/kallax-*; do
    [ -f "$f" ] || continue
    cp "$f" "$dst/"; count=$((count + 1))
  done
  # Shared lib + heartbeat prompts
  [ -f "$src/_kallax_common.sh" ] && cp "$src/_kallax_common.sh" "$dst/"
  for f in "$src"/heartbeat-*; do [ -f "$f" ] && cp "$f" "$dst/"; done
  ok "[$tool] commands → $dst ($count files)"
}
```

### 3.5 Per-tool verify + configure

```bash
verify_install() {
  echo "=== Verification ==="
  local tool status
  for tool in "${TARGET_TOOLS[@]}"; do
    local skills="${TOOL_SKILLS_DIR[$tool]}"
    local cmds="${TOOL_COMMANDS_DIR[$tool]}"
    if [ -d "$skills" ] && [ -f "$skills/SKILL.md" ]; then
      ok "[$tool] skills: $(find "$skills" -type f | wc -l) files"
    else
      warn "[$tool] skills: not installed"
    fi
    local count=$(ls "$cmds"/kallax-* 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
      ok "[$tool] commands: $count slash cmds"
    else
      warn "[$tool] commands: not installed"
    fi
  done
}

configure_permissions_for_tool() {
  local tool="$1"
  local settings="${TOOL_SETTINGS_FILE[$tool]}"
  case "$tool" in
    claude)  configure_claude_perms "$settings" ;;
    opencode) log "[opencode] permissions: edit config.json manually (TODO future EPIC)" ;;
    codex)    log "[codex] permissions: edit config.toml manually (TODO future EPIC)" ;;
    gemini)   log "[gemini] permissions: edit config/settings.json manually (TODO future EPIC)" ;;
  esac
}
```

### 3.6 Backward compatibility (v2.0.5 等价)

Default behavior is `--target=auto`. If `DETECTED_TOOLS` is empty AND user did not pass
explicit `--target`, we **warn and exit 1** with install hint (test 6). Legacy flags
`--skip-cli --skip-skills --skip-commands --upgrade --version -h|--help`保留.

## 4. Test Plan (TDD, 6/6)

`tests/integration/install-multi-tool-test.sh` — 6 case, exit 0 iff all 6 PASS:

| # | Case | Setup | Expect |
|---|---|---|---|
| 1 | `--target=auto` + 4 mock | HOME=tmp with 4 base dirs | All 4 skills dirs created |
| 2 | `--target=all` + 0 mock | HOME=empty, no PATH | 4 skills dirs force-created |
| 3 | `--target=claude` + no mock | HOME=empty | exit 1, "not detected" |
| 4 | `--target=opencode,codex` | HOME=tmp with 4 base dirs | 2 skills dirs (opencode+codex) |
| 5 | `--target=nonexistent` | any | exit 1, "unknown tool" |
| 6 | 0 detected + 0 binary | HOME=empty, PATH=empty | exit 1, suggestion to use `--target=all` |

Each test uses isolated `mktemp -d` HOME + stubs project root in a fixture sub-dir.
Helper: `assert_dir_exists`, `assert_exit_code`, `assert_contains_output`.

## 5. File-level Changes

| File | Action | Lines | Note |
|---|---|---|---|
| `scripts/install.sh` | rewrite | 325 → ~420 | TOOL_PATHS + parse_target + install_for_tool |
| `tests/integration/install-multi-tool-test.sh` | create | ~200 (new) | 6 test cases + helpers |
| `jira/tickets/EPIC-057-A/IMPLEMENTATION-PLAN.md` | create | this | self |
| `jira/tickets/EPIC-057-A/LESSONS-LEARNED.md` | create | ~80 (after tests) | post-mortem |
| `.kallax/queue/outbox/performer-EPIC-057-A/pass-report-EPIC-057-A.json` | create | JSON | PASS report with raw output |

Out-of-scope (NEVER touch):
- `scripts/kallax-onramp.sh` (EPIC-057-B)
- `scripts/lib/*` (EPIC-057-B)
- `docs/guides/*`, `README.md` (EPIC-057-C)
- `tests/integration/onramp-*`, `tests/integration/multi-tool-e2e-test.sh` (EPIC-057-D)

## 6. Execution Order

1. **TDD-first**: write 6-case test, run, see 0/6 FAIL ✓
2. Refactor `install.sh` to add TOOL_PATHS + parse_target + install_for_tool
3. Run tests, iterate until 6/6 PASS
4. Write LESSONS-LEARNED.md
5. Commit (no merge — Conductor only)
6. Write PASS report JSON with raw test output + commit SHA + 4 tools path mapping verification

## 7. Risk + Mitigation

| Risk | Mitigation |
|---|---|
| Backward compat break (v2.0.5 users) | default `--target=auto`, 4 tools must opt-in via explicit |
| `.opencode/command/` singular vs `.claude/commands/` plural | per-tool path registry, not glob |
| codex binary missing but base dir present | detection accepts base-dir-only as signal |
| Test fixture polluted by real `$HOME` | `HOME=$(mktemp -d)` override per test |
| Bash associative array on macOS bash 3.2 | bash 3.2 不支持 declare -A → use eval indirection OR check bash version, fallback to parallel arrays |

**Bash 3.2 check**: macOS default `bash` is 3.2.57 (no assoc arrays). Options:
- Use 4 parallel arrays: `TOOL_NAME=("claude" "opencode" "codex" "gemini")`, `TOOL_BASE_DIR_ARR=("$HOME/.claude" ...)`, lookup via `for i in "${!TOOL_NAME[@]}"; do tool="${TOOL_NAME[$i]}"`.
- Use `bash 4+` if available (`/opt/homebrew/bin/bash`, `brew install bash`).
- **Decision**: use 4 parallel arrays + index lookup, works on bash 3.2 (10.14兼容性 + 10.15+).

## 8. Verification Checklist (4-Level)

- Level 1 (Existence): `scripts/install.sh` exists, tests file exists in worktree
- Level 2 (Substance): no TODO/stubs in critical paths, real logic
- Level 3 (Wiring): bash syntax check `bash -n install.sh`, no missing fns
- Level 4 (Data Flow): 6/6 PASS, all 4 tools skill/command paths touched by tests

## 9. 5-Tag SOP

- `#verify`: each commit + push + tag verification
- `#milestone`: TDD → impl → test → docs → report
- `#risk`: bash 3.2 compat + bash 4+ fallback
- `#decision`: bash 3.2 compat (parallel arrays)
- `#kpi`: Rule 9 6/6 = 100.0% enforced

## 10. Anti-patterns to avoid

- ❌ Background mode (Rule 2) — done in foreground with raw output
- ❌ Scope violation (out-of-file_scope)
- ❌ Modify `.opencode/command/` source (v2.0.2 commit, untouched)
- ❌ Assume bash 4+ (use parallel arrays)
- ❌ Silent output (main公拍 D explicit: raw git log + test output every commit)
- ❌ Mock integration (real `bash install.sh`, real `mktemp -d` HOME)
- ❌ Self-approve / merge
- ❌ Fabricated KPI without raw test output