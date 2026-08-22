# KALLAX Dashboard Phase 1 — 静态站 MVP

> **EPIC-281 Phase 1**: 自研静态站 dashboard, 0 借, 0 schema change, 0 DB.
> 数据源: `jira/tickets/**/*.json` (跟 EPIC-277-F PR #467 数据源 1:1).

## 用法

```bash
# 1. 生成静态站
bash scripts/dashboard-p1/emit.sh

# 2. (可选) 本地预览 — 127.0.0.1:8765 (拒绝 0.0.0.0)
bash scripts/dashboard-p1/serve.sh

# 3. 跑 fail-closed gate (EPIC-223 + EPIC-069-D)
bash scripts/dashboard-p1/verify.sh
```

输出:
- `dist/dashboard/data.json` — 静态数据
- `dist/dashboard/index.html` — 单页 table, 4-branch swimlane, 零 JS 依赖

## 架构

| 组件 | 路径 | 职责 |
|------|------|------|
| emit | `scripts/dashboard-p1/emit.sh` | 扫 ticket.json → 生成 data.json + index.html (~150 LOC) |
| serve | `scripts/dashboard-p1/serve.sh` | python3 http.server 锁 127.0.0.1:8765 (~30 LOC) |
| verify | `scripts/dashboard-p1/verify.sh` | check-ticket-schema + check-claim-evidence + emit 自检 (~70 LOC) |
| command | `.claude/commands/kallax-dashboard.md` | 新 slash command `/kallax-dashboard` |

## 设计原则

- **0 schema change**: 不改 `jira/tickets/*.json` 字段, 跟 `check-ticket-schema.sh` 1:1
- **0 DB**: 单一真相源 = 文件系统 (跟 EPIC-223 / EPIC-277-F 1:1)
- **0 借**: 纯 bash + python3 stdlib + jq, 无新依赖
- **NO_DATA 灰态**: 跟 `sprint-metrics.sh` exit=2 (NO_DATA) / exit=3 (DOCS_ONLY_SKIP) 对齐
- **Rule 34 gate badge**: bugfix ticket 缺 reproduction 字段 → 红牌列表
- **9-immutable 子集 fail-closed**: render 前必跑 check-ticket-schema + check-claim-evidence

## 4-Branch Swimlane 映射

| Status | Branch (swimlane) | Color |
|--------|-------------------|-------|
| `done` / `merged` / `closed` / `passed` | miao | GREEN |
| `in_progress` / `in-progress` | feature | YELLOW |
| `review` | testing | MAGENTA |
| `blocked` | main | RED |
| `backlog` / `todo` | backlog | BLUE |
| `archived` (EPIC ≤ 222) | archived | GRAY |

## NO_DATA 灰态 vs 真 0 区分

| 数据源 | 真 0 | NO_DATA (灰态) |
|--------|------|----------------|
| sprint-metrics exit | 0 (PASS) / 1 (FAIL) | 2 (NO_DATA) / 3 (DOCS_ONLY_SKIP) |
| Counts.no_data | 0 | 显示 ⚠ + "sprint-metrics exit=2" 引用 |
| Bugfix Rule 34 缺字段 | 0 = PASS | N/A (不适用) |

## R5 风险: 公网 host 暴露

`serve.sh` hard-code `HOST=127.0.0.1`, 拒绝 `DASHBOARD_HOST` env override (除显式 `127.0.0.1`).
python http.server 默认 bind 0.0.0.0, 用 `--bind 127.0.0.1` 强锁.
防 jira/ 父级目录被列 (R5 mitigation, 跟 prime-agent security 报告 §2 一致).

## 不做什么 (Phase 1 边界)

- ❌ 0 DB / 0 schema change
- ❌ 0 借用第三方 dashboard (AGPL/Fair-code 风险)
- ❌ 0 JS 依赖 (单页 table + CSS, 浏览器原生渲染)
- ❌ 0 实时更新 (Phase 2 才考虑 SSE/heartbeat)
- ❌ 0 auth (本地预览用, 生产部署走 4-PR flow 后另议)

## 后续 (Phase 2)

- SSE 实时推送 (跟 heartbeat-daemon.sh 1:1)
- expert panel 调度视图
- rule 改动 timeline (snapshot-claude-md.sh 集成)

## Reference

- EPIC-277-F: 数据源 (PR #467)
- EPIC-223: check-ticket-schema.sh (9-immutable)
- EPIC-069-D: check-claim-evidence.sh (9-immutable)
- EPIC-281 ticket: `jira/tickets/EPIC-281/`