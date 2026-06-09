# Hallucination Deviation Log

> **Purpose**: Record instances where agent output hash != script output hash.
> This is an anti-hallucination deviation record for EPIC-016-K.

## Schema

Each entry:
```yaml
timestamp: ISO8601
agent_output_hash: <sha256>
script_output_hash: <sha256>
deviation: true|false
ticket: EPIC-XXX
notes: <optional>
```

## Entries

<!-- Add entries below -->