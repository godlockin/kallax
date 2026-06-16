#!/usr/bin/env bash
# scripts/verify/kpi-evidence-chain.sh — 4-Level KPI Evidence Chain (EPIC-053-B)
#
# 12 KPI falsification 反复治根 (EPIC-024/028/031/036/037/039-B)
# BE-5 治根 (Performer-EPIC-036/037 假 PASS 第 9/10 次)
#
# 4-Level evidence chain:
#   L1: git-anchor — real commit SHA (not cached, not fake)
#   L2: test stdout — raw output with "PASS" + "X/Y PASS" format (Rule 9)
#   L3: 5 extended groups — security / process-engineering / auditor / compliance / decision-gate
#   L4: 独立见证签名 — audit-log-sink.sh writes immutable witness (Rule 30/31)
#
# Usage:
#   kpi-evidence-chain.sh verify <ticket_id> <commit_sha> <test_stdout_file>
#   kpi-evidence-chain.sh check-l1 <commit_sha>
#   kpi-evidence-chain.sh check-l2 <test_stdout_file>
#   kpi-evidence-chain.sh check-l3
#   kpi-evidence-chain.sh check-l4 <ticket_id>
#
# Exit codes:
#   0 = all 4 levels PASS
#   1 = at least one level FAIL
#   2 = invalid arguments
#
# Env overrides (test/extension):
#   KALLAX_EXTENDED_GROUPS_DIR — override path to extended-group tool scripts
#   KALLAX_AUDIT_SINK_DIR — override audit sink directory
#
# Rule alignment:
#   - Rule 8: 4-Level Fact-Forcing (extended from EPIC-053-A L3↔L4 to 4 dimensions)
#   - Rule 9: KPI X/Y format precision (no estimate, exact)
#   - Rule 18: KPI falsification blacklist
#   - Rule 30/31: Independent witness mechanism (BE-5 + BE-7 修复模式)
#   - BE-5: 0 commit + 0 file + fake PASS detection
#   - BE-9: defense system self-check (跟 l3-l4-consistency 联合)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Allow override for tests and extensions
EXTENDED_GROUPS_DIR="${KALLAX_EXTENDED_GROUPS_DIR:-$KALLAX_ROOT/scripts/verify}"
AUDIT_SINK_SCRIPT="$KALLAX_ROOT/scripts/audit/audit-log-sink.sh"

# -------------------------------------------------------
# Extended-group tool registry (5 groups, 9 tools)
# Each tool must PASS for its group to PASS
# -------------------------------------------------------
EXTENDED_GROUP_TOOLS=(
    "security-tool-bypass:check-scope-creep.sh:check-kpi-precision.sh"
    "process-engineering:check-fact-forcing-preflight.sh:l3-l4-consistency.sh"
    "auditor:auditor-checkpoint.sh:subagent-pass-gate.sh"
    "compliance:check-test-case-isolation.sh:"
    "decision-gate:review-checkpoint.sh:rule-19-checkpoint.sh"
)

# -------------------------------------------------------
# L1: git-anchor verification
# Args: $1 = commit SHA
# Returns: 0 if real, 1 if fake/missing
# -------------------------------------------------------
check_l1_git_anchor() {
    local sha="$1"

    if [ -z "$sha" ]; then
        echo "[L1 FAIL] empty SHA"
        return 1
    fi

    # Reject obvious fakes (not 40-char hex)
    if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        echo "[L1 FAIL] SHA not 40-char hex: $sha"
        return 1
    fi

    # Verify SHA exists in git object store
    if ! git rev-parse --verify "${sha}^{commit}" >/dev/null 2>&1; then
        echo "[L1 FAIL] SHA not a real commit: $sha"
        return 1
    fi

    # Verify SHA matches HEAD~X ancestry — must be reachable from current HEAD
    if ! git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
        echo "[L1 FAIL] SHA not in current branch ancestry: $sha"
        return 1
    fi

    echo "[L1 PASS] git-anchor verified: $sha"
    return 0
}

# -------------------------------------------------------
# L2: test stdout verification
# Args: $1 = test_stdout_file
# Returns: 0 if valid, 1 if fake/missing
# -------------------------------------------------------
check_l2_test_stdout() {
    local stdout_file="$1"

    if [ -z "$stdout_file" ]; then
        echo "[L2 FAIL] empty stdout file path"
        return 1
    fi

    if [ ! -f "$stdout_file" ]; then
        echo "[L2 FAIL] stdout file not found: $stdout_file"
        return 1
    fi

    if [ ! -s "$stdout_file" ]; then
        echo "[L2 FAIL] stdout file empty: $stdout_file"
        return 1
    fi

    # Must contain "PASS" keyword (case-insensitive)
    if ! grep -qiE '(PASS|passed|✓)' "$stdout_file"; then
        echo "[L2 FAIL] no PASS marker in stdout"
        return 1
    fi

    # Must contain X/Y format (Rule 9 KPI precision)
    if ! grep -qE '[0-9]+/[0-9]+\s*(\(\s*[0-9]+\.[0-9]+\s*%\s*\))?\s*(PASS|pass)' "$stdout_file"; then
        echo "[L2 FAIL] no X/Y PASS format in stdout (Rule 9 KPI precision)"
        return 1
    fi

    echo "[L2 PASS] test stdout verified: $stdout_file"
    return 0
}

# -------------------------------------------------------
# L3: 5 extended groups verification
# Returns: 0 if all 5 groups PASS, 1 if any FAIL
# -------------------------------------------------------
check_l3_extended_groups() {
    local group_pass=0
    local group_fail=0
    local fail_groups=()

    for entry in "${EXTENDED_GROUP_TOOLS[@]}"; do
        IFS=':' read -r group_name tool1 tool2 <<< "$entry"

        local tools_pass=0
        local tools_total=0
        local tool_failed=""

        for tool in "$tool1" "$tool2"; do
            [ -z "$tool" ] && continue
            tools_total=$((tools_total+1))

            local tool_path="$EXTENDED_GROUPS_DIR/$tool"
            if [ ! -x "$tool_path" ]; then
                tool_failed="$tool (not executable)"
                continue
            fi

            # Run the tool, capture exit code only (don't fail on tool non-zero — we collect)
            set +e
            bash "$tool_path" >/dev/null 2>&1
            local rc=$?
            set -e

            if [ "$rc" -eq 0 ]; then
                tools_pass=$((tools_pass+1))
            else
                tool_failed="$tool (exit=$rc)"
            fi
        done

        if [ "$tools_total" -gt 0 ] && [ "$tools_pass" -eq "$tools_total" ]; then
            echo "[L3 PASS] $group_name group: $tools_pass/$tools_total tools"
            group_pass=$((group_pass+1))
        else
            echo "[L3 FAIL] $group_name group: $tools_pass/$tools_total tools (failed: $tool_failed)"
            fail_groups+=("$group_name")
            group_fail=$((group_fail+1))
        fi
    done

    if [ "$group_fail" -gt 0 ]; then
        echo "[L3 FAIL] $group_fail/5 groups incomplete: ${fail_groups[*]}"
        return 1
    fi

    echo "[L3 PASS] 5/5 extended groups complete"
    return 0
}

# -------------------------------------------------------
# L4: 独立见证签名 verification
# Args: $1 = ticket_id
# Returns: 0 if witness written, 1 if missing
#
# Strategy:
#   1. Prefer audit-log-sink.sh (production, flock + atomic mv)
#   2. Fallback: direct atomic temp+mv (when flock unavailable, e.g. macOS)
#   3. Both modes enforce umask 077 + chmod 600 (BE-7 修复模式)
# -------------------------------------------------------
check_l4_witness() {
    local ticket_id="$1"

    if [ -z "$ticket_id" ]; then
        echo "[L4 FAIL] empty ticket_id"
        return 1
    fi

    # Get current SHA + subagent_id for witness content
    local current_sha
    current_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local subagent_id="${KALLAX_SUBAGENT_ID:-performer_unknown}"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Resolve audit dir
    local audit_dir="${KALLAX_AUDIT_SINK_DIR:-$KALLAX_ROOT/.kallax/audit/sink}"

    # Ensure dir exists with BE-7 修复模式 permissions
    if [ ! -d "$audit_dir" ]; then
        (umask 077 && install -d -m 700 "$audit_dir" 2>/dev/null) || {
            echo "[L4 FAIL] cannot create audit dir: $audit_dir"
            return 1
        }
    fi

    local log_entry
    log_entry="{\"ts\":\"$timestamp\",\"type\":\"evidence_chain_witness\",\"ticket\":\"$ticket_id\",\"content\":\"subagent=$subagent_id sha=$current_sha level=4/4\",\"instance\":\"kpi-evidence-chain\"}"

    local write_ok=0

    # Try audit-log-sink first (production path, flock-based)
    if [ -x "$AUDIT_SINK_SCRIPT" ]; then
        set +e
        bash "$AUDIT_SINK_SCRIPT" write "evidence_chain_witness" "$ticket_id" \
            "subagent=$subagent_id sha=$current_sha level=4/4 ts=$timestamp" \
            >/dev/null 2>&1
        local rc=$?
        set -e
        if [ "$rc" -eq 0 ]; then
            write_ok=1
        fi
    fi

    # Fallback: direct atomic write (when flock unavailable, e.g. macOS)
    if [ "$write_ok" -eq 0 ]; then
        local temp_file="$audit_dir/.kpi-witness-$$.tmp"
        (umask 077 && echo "$log_entry" > "$temp_file" 2>/dev/null) || {
            echo "[L4 FAIL] cannot write witness temp file: $temp_file"
            return 1
        }
        chmod 600 "$temp_file" 2>/dev/null || true
        if mv "$temp_file" "$audit_dir/${ticket_id}-${timestamp}.log" 2>/dev/null; then
            write_ok=1
        else
            rm -f "$temp_file" 2>/dev/null
            echo "[L4 FAIL] cannot move witness file into place"
            return 1
        fi
    fi

    # Verify witness file exists
    local witness_files
    witness_files=$(ls "$audit_dir"/${ticket_id}-*.log 2>/dev/null | wc -l | tr -d ' ')

    if [ "$witness_files" -eq 0 ]; then
        echo "[L4 FAIL] no witness file found in audit sink for $ticket_id"
        return 1
    fi

    echo "[L4 PASS] independent witness recorded ($witness_files file(s))"
    return 0
}

# -------------------------------------------------------
# verify: full 4-Level verification
# Args: $1 = ticket_id, $2 = commit_sha, $3 = test_stdout_file
# -------------------------------------------------------
cmd_verify() {
    local ticket_id="$1"
    local commit_sha="$2"
    local stdout_file="$3"

    echo "=========================================="
    echo "4-Level KPI Evidence Chain Verification"
    echo "=========================================="
    echo "Ticket: $ticket_id"
    echo "Commit: $commit_sha"
    echo "Stdout: $stdout_file"
    echo ""

    local all_pass=1

    # L1
    echo "--- L1: git-anchor ---"
    if ! check_l1_git_anchor "$commit_sha"; then
        all_pass=0
    fi
    echo ""

    # L2
    echo "--- L2: test stdout ---"
    if ! check_l2_test_stdout "$stdout_file"; then
        all_pass=0
    fi
    echo ""

    # L3
    echo "--- L3: 5 extended groups ---"
    if ! check_l3_extended_groups; then
        all_pass=0
    fi
    echo ""

    # L4
    echo "--- L4: 独立见证签名 ---"
    if ! check_l4_witness "$ticket_id"; then
        all_pass=0
    fi
    echo ""

    echo "=========================================="
    if [ "$all_pass" -eq 1 ]; then
        echo "RESULT: PASS — 4-Level evidence chain complete"
        echo "跟 EPIC-053-A l3-l4-consistency 联合, 治 BE-5 + 12 KPI falsification 反复"
        return 0
    fi
    echo "RESULT: FAIL — at least one level missing or invalid"
    return 1
}

# -------------------------------------------------------
# CLI entry
# -------------------------------------------------------
usage() {
    cat <<'USAGE'
Usage: kpi-evidence-chain.sh <command> [args]

Commands:
  verify <ticket_id> <commit_sha> <test_stdout_file>  — Full 4-Level verification
  check-l1 <commit_sha>                                — Verify L1 git-anchor
  check-l2 <test_stdout_file>                          — Verify L2 test stdout
  check-l3                                             — Verify L3 5 extended groups
  check-l4 <ticket_id>                                — Verify L4 独立见证签名

Exit codes:
  0 = all 4 levels PASS
  1 = at least one level FAIL
  2 = invalid arguments

Env overrides:
  KALLAX_EXTENDED_GROUPS_DIR  — path to extended-group tool scripts
  KALLAX_AUDIT_SINK_DIR       — audit sink directory
  KALLAX_SUBAGENT_ID          — subagent identifier for witness

Rule alignment:
  Rule 8  — 4-Level Fact-Forcing (L1/L2/L3/L4)
  Rule 9  — KPI X/Y format precision
  Rule 18 — KPI falsification blacklist
  Rule 30/31 — Independent witness mechanism (BE-5 + BE-7 修复模式)
  BE-5    — 0 commit + 0 file + fake PASS detection
  BE-9    — defense system self-check (跟 l3-l4-consistency 联合)
USAGE
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        verify)
            local ticket_id="${1:-}"
            local commit_sha="${2:-}"
            local stdout_file="${3:-}"
            if [ -z "$ticket_id" ] || [ -z "$commit_sha" ] || [ -z "$stdout_file" ]; then
                echo "ERROR: verify requires <ticket_id> <commit_sha> <test_stdout_file>" >&2
                usage >&2
                exit 2
            fi
            if cmd_verify "$ticket_id" "$commit_sha" "$stdout_file"; then
                exit 0
            fi
            exit 1
            ;;
        check-l1)
            local sha="${1:-}"
            if [ -z "$sha" ]; then
                echo "ERROR: check-l1 requires <commit_sha>" >&2
                exit 2
            fi
            if check_l1_git_anchor "$sha"; then
                exit 0
            fi
            exit 1
            ;;
        check-l2)
            local stdout_file="${1:-}"
            if [ -z "$stdout_file" ]; then
                echo "ERROR: check-l2 requires <test_stdout_file>" >&2
                exit 2
            fi
            if check_l2_test_stdout "$stdout_file"; then
                exit 0
            fi
            exit 1
            ;;
        check-l3)
            if check_l3_extended_groups; then
                exit 0
            fi
            exit 1
            ;;
        check-l4)
            local ticket_id="${1:-}"
            if [ -z "$ticket_id" ]; then
                echo "ERROR: check-l4 requires <ticket_id>" >&2
                exit 2
            fi
            if check_l4_witness "$ticket_id"; then
                exit 0
            fi
            exit 1
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown command: $action" >&2
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"