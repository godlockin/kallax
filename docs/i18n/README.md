# KALLAX i18n — EN/CN Synchronization

> **EPIC-165**: Bilingual index for KALLAX external narrative layer.

## Background

KALLAX v3.32.4+ ships with bilingual documentation:
- **EN**: `README.en.md` (4-section: Why / Try / Capabilities / Docs Index)
- **CN**: `README.md` (17.8KB, Chinese-only before EPIC-165)

## Synchronization Rules

### Files requiring 1:1 sync

| EN | CN | Status |
|----|----|--------|
| `README.en.md` | `README.md` | Must stay in sync |

### Sync triggers (any of)

1. New section added to `README.md` → add corresponding EN section to `README.en.md`
2. Version bump → update both `README.en.md` and `README.md` version line
3. New showcase case → add to both `docs/showcases/README.md` (CN) and `README.en.md` Showcase section
4. CHANGELOG entry → add with same `raw_output` references in both EN and CN

### Sync rules (strict)

- **Version line**: Must match exactly (e.g., `**v3.32.4**`)
- **Evidence links**: Both EN and CN must reference same `raw_output` file paths
- **Showcase catalog**: `docs/showcases/showcase-catalog.json` is source of truth (language-neutral)
- **CLI output**: Keep English (commands are English regardless of UI language)
- **Rule references**: CLAUDE.md stays Chinese-only (internal governance, not external-facing)

### EN/CN split principle

| Content | Language | Reason |
|---------|----------|--------|
| README / showcase docs | EN + CN | external-facing, user-facing |
| CLAUDE.md / rules | CN only | internal governance |
| CLI commands / code | EN | universal |
| Error messages | EN | universal |
| CHANGELOG | CN + raw_output | both for traceability |

## Showcase Catalog (Language-Neutral)

`docs/showcases/showcase-catalog.json` drives the showcase index. Each case links to:
- ticket.json chain (CN context)
- 5-Level Verify raw output (EN, universal)
- 4-branch flow trajectory (EN, universal)
- Master decision record (CN context)

Case files (`.md`) are bilingual by design: title + pattern tags in EN, body in CN.

## Reference Pattern (loopx 1:1)

loopx 24KB EN + 24KB CN README pattern:
1. EN README = structural copy of CN README (same sections, translated)
2. CN README = source of truth for governance content
3. EN README = source of truth for user-facing copy

## Verify Sync

```bash
# Check EN/CN version match
diff <(grep -E '\*\*v[0-9]+\.[0-9]+\.[0-9]+\*\*' README.md) \
     <(grep -E '\*\*v[0-9]+\.[0-9]+\.[0-9]+\*\*' README.en.md)

# Check showcase catalog consistency
bash tests/integration/showcase-catalog.test.sh
```

## Changelog sync (per EPIC-069-D)

CHANGELOG entries must include `raw_output` references:
```
## [3.32.4] - 2026-08-03
raw: `bash scripts/verify/check-cargo-test-workspace.sh` → exit 0
raw: `cd node && npm run build` → exit 0
```

Both EN README (external) and CN README (internal) should link to same raw output paths.
