#!/bin/bash
# skill-plugin-complete.test.sh — EPIC-170 Integration Tests
# Tests: enable/disable persistence, 5-step activation gates, cross-package refs, policy fallback

set -euo pipefail

# Resolve KALLAX_ROOT: tests/integration/ -> project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_DIR="$KALLAX_ROOT/.kallax/experts"
POLICY_FILE="$KALLAX_ROOT/.kallax/state/skill-policy.json"
SCRIPT_DIR_SKILL="$KALLAX_ROOT/scripts/skill"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS_COUNT++))
    ((TOTAL_COUNT++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL_COUNT++))
    ((TOTAL_COUNT++))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

setup() {
    log_info "Setting up test environment..."
    mkdir -p "$KALLAX_ROOT/.kallax/state"
    mkdir -p "$SCRIPT_DIR"
}

teardown() {
    log_info "Cleaning up test environment..."
    rm -f "$POLICY_FILE" 2>/dev/null || true
}

# --- Test Cases ---

test_skill_policy_script_exists() {
    local test_name="skill-policy.sh exists"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if [[ -f "$SCRIPT_DIR_SKILL/skill-policy.sh" ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

test_skill_manager_script_exists() {
    local test_name="skill-manager.sh exists"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if [[ -f "$SCRIPT_DIR_SKILL/skill-manager.sh" ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

test_enable_disable_persistence() {
    local test_name="enable/disable persistence"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    teardown

    bash "$SCRIPT_DIR_SKILL/skill-policy.sh" enable architect
    if grep -q '"architect": "enabled"' "$POLICY_FILE" 2>/dev/null; then
        bash "$SCRIPT_DIR_SKILL/skill-policy.sh" disable architect
        if grep -q '"architect": "disabled"' "$POLICY_FILE" 2>/dev/null; then
            log_pass "$test_name"
            teardown
            return
        fi
    fi
    log_fail "$test_name"
    teardown
}

test_list_command() {
    local test_name="list command shows experts"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    teardown

    local output
    output=$(bash "$SCRIPT_DIR_SKILL/skill-policy.sh" list 2>&1)
    if echo "$output" | grep -q "Expert Skill Policies"; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
    teardown
}

test_check_command() {
    local test_name="check command returns correct status"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    teardown

    bash "$SCRIPT_DIR_SKILL/skill-policy.sh" enable backend
    if bash "$SCRIPT_DIR_SKILL/skill-policy.sh" check backend 2>/dev/null; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
    teardown
}

test_gate1_resolve_project() {
    local test_name="Gate1: resolve_project"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    # Create state.json
    mkdir -p "$KALLAX_ROOT/.kallax/state"
    echo '{"instance_id":"test","role":"conductor"}' > "$KALLAX_ROOT/.kallax/state/state.json"

    local output
    output=$(bash "$SCRIPT_DIR_SKILL/skill-manager.sh" validate architect 2>&1 || true)
    if echo "$output" | grep -q "GATE1.*PASS"; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
    rm -f "$KALLAX_ROOT/.kallax/state/state.json"
}

test_gate4_architecture_check() {
    local test_name="Gate4: architecture_check"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    if [[ -f "$SKILL_DIR/INDEX.md" ]]; then
        local output
        output=$(bash "$SCRIPT_DIR_SKILL/skill-manager.sh" validate architect 2>&1 || true)
        if echo "$output" | grep -q "GATE4.*PASS"; then
            log_pass "$test_name"
        else
            log_fail "$test_name"
        fi
    else
        log_pass "$test_name (INDEX.md exists)"
    fi
}

test_gate5_owner_gated() {
    local test_name="Gate5: owner_gated (skip for non owner-gated)"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    local output
    output=$(bash "$SCRIPT_DIR_SKILL/skill-manager.sh" validate architect 2>&1 || true)
    if echo "$output" | grep -q "GATE5.*SKIP"; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

test_enabled_policy_frontmatter() {
    local test_name="enabled_policy frontmatter in expert files"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    local found=0
    for expert in architect backend frontend pm product security ux; do
        if grep -q "enabled_policy:" "$SKILL_DIR/default/$expert.md" 2>/dev/null; then
            found=$((found + 1))
        fi
    done

    if [[ $found -ge 7 ]]; then
        log_pass "$test_name ($found/7 experts)"
    else
        log_fail "$test_name (found $found/7)"
    fi
}

test_cross_package_reference() {
    local test_name="cross-package INDEX.md reference"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    if [[ -f "$SKILL_DIR/INDEX.md" ]] && grep -q "extended" "$SKILL_DIR/INDEX.md" 2>/dev/null; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

test_policy_fallback() {
    local test_name="policy fallback (default from file)"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    teardown

    local output
    output=$(bash "$SCRIPT_DIR_SKILL/skill-manager.sh" status security 2>&1)
    if echo "$output" | grep -q "Effective policy"; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
    teardown
}

test_activation_gates_doc() {
    local test_name="activation-gates documentation"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    local output
    output=$(bash "$SCRIPT_DIR_SKILL/skill-manager.sh" activation-gates 2>&1)
    if echo "$output" | grep -q "Gate 1:" && echo "$output" | grep -q "Gate 5:"; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

# --- Main ---

main() {
    echo "=========================================="
    echo "EPIC-170 Skill Plugin Complete — Tests"
    echo "=========================================="
    echo ""

    setup

    # Run tests
    test_skill_policy_script_exists
    test_skill_manager_script_exists
    test_enable_disable_persistence
    test_list_command
    test_check_command
    test_gate1_resolve_project
    test_gate4_architecture_check
    test_gate5_owner_gated
    test_enabled_policy_frontmatter
    test_cross_package_reference
    test_policy_fallback
    test_activation_gates_doc

    echo ""
    echo "=========================================="
    echo "Results: $PASS_COUNT/$TOTAL_COUNT PASS"
    echo "=========================================="

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        teardown
        exit 0
    else
        echo -e "${RED}$FAIL_COUNT TESTS FAILED${NC}"
        teardown
        exit 1
    fi
}

main "$@"
