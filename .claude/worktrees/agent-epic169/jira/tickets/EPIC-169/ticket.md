# EPIC-169 — 公开化路径

> **借鉴 loopx 1:1 (hosted frontstage + showcase + Lark/WeChat 群 + GitHub Pages)**

## 起源

主公 2026-08-05 拍板 Phase 5 E. 详细分析: `confluence/decisions/epic-169-public-path-2026-08-05.md`.

## loopx 公开化路径 (借鉴)

| 项 | loopx | KALLAX (改进后) |
|----|-------|-----------------|
| GitHub Pages | huangruiteng.github.io/loopx | github.com/godlockin/kallax hosted frontstage |
| README 双语 | 24KB EN + 24KB CN | README + README.en.md 7-section |
| Showcase catalog | 7 case + json | docs/showcases/ + showcase-catalog.json (EPIC-165) |
| Lark 群 | Lark QR code | docs/community/README.md (含 QR 占位) |
| WeChat 群 | huangrt00 | docs/community/README.md |
| CONTRIBUTING | CONTRIBUTING.md + tasks | CONTRIBUTING.md 100+ 行 |
| Issue template | 标准 | bug_report.md + feature_request.md |
| Sponsor | loopx 1:1 | .github/FUNDING.yml |

## Acceptance (13 项)

AC1~AC13 见 `jira/tickets/EPIC-169/ticket.json` `acceptance` 字段

## 约束

- 0 改 source code
- 0 增 Rule
- 0 增 immutable script
- BE-14: 1 ticket 1 subagent 串行
- EPIC-165 showcase 1:1 verify

## 估时

~10 h (1 EPIC 周期), 含 5-Level Verify + 4-branch flow.

## Phase

PHASE-020 — Public Path (2026-08-05 主公拍板)