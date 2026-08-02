#!/usr/bin/env bash
# scripts/binding/lib/expert-pool.sh — EPIC-157 expert pool library
#
# Sourceable; provides ALLOWED_EXPERTS (跟 node/src/core/schema-validator.ts
# ExpertPool 字段保持 1:1) + is_allowed_expert() helper.
#
# 4 default + 5 extended + 15 local
ALLOWED_EXPERTS=(
  backend frontend ux product
  security-tool-bypass process-engineering-self-verify
  auditor-independent-witness compliance-rule-merge
  decision-gate-complex-only
  architect sre devops security performance
  database aiml mlops data-analyst tester
  reviewer docs-writer tech-lead conductor master
)

# Returns 0 if name is in ALLOWED_EXPERTS or matches custom:<name> namespace.
is_allowed_expert() {
  local name="$1"
  for e in "${ALLOWED_EXPERTS[@]}"; do
    if [ "$e" = "$name" ]; then
      return 0
    fi
  done
  case "$name" in
    custom:*) return 0 ;;
  esac
  return 1
}