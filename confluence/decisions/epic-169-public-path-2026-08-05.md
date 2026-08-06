# EPIC-169 公开化路径 — 拍板记录

**日期**: 2026-08-05
**主公**: Phase 5 E
**EPIC**: EPIC-169

---

## 起源

主公 2026-08-05 拍板 Phase 5 E — 公开化路径。

## loopx 公开化路径 (借鉴)

| 项 | loopx | KALLAX (改进后) |
|----|-------|-----------------|
| GitHub Pages | huangruiteng.github.io/loopx | github.com/godlockin/kallax hosted frontstage |
| README 双语 | 24KB EN + 24KB CN | README + README.en.md 7-section |
| Showcase catalog | 7 case + json | docs/showcases/ + showcase-catalog.json |
| Lark 群 | Lark QR code | docs/community/README.md (含 QR 占位) |
| WeChat 群 | huangrt00 | docs/community/README.md |
| CONTRIBUTING | CONTRIBUTING.md + tasks | CONTRIBUTING.md 100+ 行 |
| Issue template | 标准 | bug_report.md + feature_request.md |
| Sponsor | loopx 1:1 | .github/FUNDING.yml |

---

## 决策

1. **README.en.md 完善**: 扩到 ≥250 行 7-section
2. **hosted frontstage scaffold**: web/index.html + web/showcase/index.html
3. **CONTRIBUTING.md 完善**: 含 Lark/WeChat 群入口
4. **docs/i18n/README.md 扩展**: sync rule 详化
5. **docs/community/README.md**: 社区入口
6. **docs/sponsor/README.md + .github/FUNDING.yml**: 赞助入口
7. **Issue templates**: bug_report.md + feature_request.md

---

## 约束

- 0 改 source code
- 0 增 Rule
- 0 增 immutable script
- 跟 EPIC-165 showcase + i18n 1:1 兼容

---

## 验收标准 (AC1~AC13)

见 `jira/tickets/EPIC-169/ticket.json` `acceptance` 字段.

---

## 实施

Performer: agent-epic169 (docs)

---

## Version

v3.32.15
