# KALLAX i18n (Internationalization)

KALLAX documentation supports multiple languages.

---

## Supported Languages

| Code | Language | Status | Primary |
|------|----------|--------|---------|
| zh-CN | Chinese (Simplified) | Primary | Yes |
| en-US | English | Secondary | No |

---

## Sync Rule

### File Naming Convention

| File | Description |
|------|-------------|
| `README.md` | Chinese version (primary) |
| `README.en.md` | English version |

### Sync Requirements

1. **Primary doc updates first**: `README.md` is the source of truth
2. **English translation follows**: Within 7 days of Chinese update
3. **Version alignment**: English version should match Chinese version
4. **Sync check**: Before major releases, verify all translated files

### Sync Checklist

When updating `README.md`:
- [ ] Translate new sections to English
- [ ] Update `README.en.md`
- [ ] Update `docs/i18n/README.md`
- [ ] Verify line counts are reasonable (EN should be ~same length)
- [ ] Update CHANGELOG if documentation change warrants

---

## Current Translation Status

### Primary Files

| File | Status | Last Sync |
|------|--------|-----------|
| README.md | Current | 2026-08-05 |
| README.en.md | Current | 2026-08-05 |
| CONTRIBUTING.md | Current | 2026-08-05 |
| CONTRIBUTING.en.md | TODO | - |

### Showcase Cases (7 cases)

| Case | Chinese | English |
|------|---------|---------|
| Case 1: Epic-Driven Development | docs/showcases/ | TODO |
| Case 2: 5-Level Verify | docs/showcases/ | TODO |
| Case 3: Multi-Agent | docs/showcases/ | TODO |
| Case 4: Hash-Chain Audit | docs/showcases/ | TODO |
| Case 5: Worktree Isolation | docs/showcases/ | TODO |
| Case 6: Decision Matrix | docs/showcases/ | TODO |
| Case 7: Skill Plugin | docs/showcases/ | TODO |

---

## Translation Tooling

### Recommended Tools

- [DeepL](https://www.deepl.com/) - High quality translation
- [Google Translate](https://translate.google.com/) - Quick drafts
- [GitLocalize](https://gitlocalize.com/) - Git-based sync

### Manual Review

After machine translation, verify:
- Technical terms are accurate
- Code examples compile
- Links work correctly
- Terminology is consistent

---

## Terminology

| Chinese | English | Notes |
|---------|---------|-------|
| 主公 | Master | Decision authority |
| Conductor | Conductor | Coordinator role |
| Performer | Performer | Executor role |
| 武器 | Weapon | Core feature |
| 验证 | Verify | Quality check |
| EPIC | EPIC | Large feature |
| Ticket | Ticket | Work item |

---

## Links

- [README.md (Chinese)](../README.md)
- [README.en.md (English)](README.en.md)
- [Community (Chinese)](../community/)
