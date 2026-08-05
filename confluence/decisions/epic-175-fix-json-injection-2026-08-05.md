# EPIC-175-fix JSON Injection Fix — 2026-08-05

## Context

Security review (security-guidance plugin) caught 2 MEDIUM JSON injection vulnerabilities in `scripts/automation-monitor-todos.sh`.

## Vulnerabilities

### MEDIUM #1: emit_event JSON Injection

```bash
# Vulnerable (printf)
entry=$(printf '{"ts":"%s","type":"%s","ticket_id":"%s","payload":%s}' \
  "$ts" "$event_type" "$ticket_id" "$payload")
```

**Risk**: `$payload` can contain `"` or special characters that break JSON structure or inject malicious content.

### MEDIUM #2: cmd_emit Status Injection

```bash
# Vulnerable (hardcoded JSON string)
emit_event "automation-monitor" "$ticket_id" "{\"status\":\"$status\"}"
```

**Risk**: `$status` can contain `"` or escape sequences that break JSON.

## Fix (jq -n Pattern)

### Fix #1: emit_event

```bash
# Safe (jq -n)
entry=$(jq -n \
  --arg ts "$ts" \
  --arg type "$event_type" \
  --arg ticket_id "$ticket_id" \
  --argjson payload "$payload" \
  '{ts: $ts, type: $type, ticket_id: $ticket_id, payload: $payload}')
```

### Fix #2: cmd_emit

```bash
# Safe (jq -n)
local payload
payload=$(jq -n --arg status "$status" '{status: $status}')
emit_event "automation-monitor" "$ticket_id" "$payload"
```

## Why jq -n

- `--arg`: Treats input as string (escapes special chars automatically)
- `--argjson`: Treats input as JSON (validates it IS valid JSON)
- No printf/sprintf format string vulnerabilities
- Consistent with EPIC-168-BG pattern

## Test Coverage

`tests/integration/automation-monitor-json-injection.test.sh`:

| Case | Payload | Expected |
|------|---------|----------|
| Normal | `in_progress` | Valid JSON |
| Single quote | `' OR '1'='1` | Escaped |
| Double quote | `"; DROP TABLE` | Escaped |
| Newline | `test\n{"evil":"x"}` | Escaped |

## References

- EPIC-175 (Security Rules 强化)
- EPIC-168-BG (jq -n pattern 1:1)
- security-guidance plugin review
