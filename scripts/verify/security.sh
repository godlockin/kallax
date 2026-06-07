#!/usr/bin/env bash
# DEPRECATED placeholder — security verify disabled.
# Exits 2 (NOT 0) to force explicit handling in preflight.
# SECURITY: do NOT change this to exit 0 without implementing actual security checks.
# Real implementation should be added as part of EPIC-022 (Permission Model v1).
echo "TODO: scripts/verify/security.sh not implemented yet (real impl in EPIC-022)"
echo "WARNING: SECURITY VERIFY IS DISABLED — TICKET SECURITY CHECKS WILL BE SKIPPED"
echo "         Do not mark any ticket as 'production-ready' until this stub is replaced"
exit 2
