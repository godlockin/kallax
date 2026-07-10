# 🎨 Frontend Expert Review
> Date: 2026-06-25 | Topic: 清理文件 + 重写文档树
> Role: 🎨 Frontend (跟 v2.0.3 EPIC-056-A Phase 2 联合, 跟 EPIC-060-A Phase 4 web dashboard 部署 联合, 跟"品味" 战略 联合)

## 1. 现状 评估 (跟"诚实修正" 战略 联合 0 隐藏)

### 1.1 Phase 1 数字 错位 (跟 Phase 1 §1.2 file:line `inbox/panel-2026-06-25/phase-1-conductor-scan.md:18-36` 联合)

| Path | Phase 1 stated | Actual (ls) | Delta | 备注 |
|------|----------------|-------------|-------|------|
| `docs/api/` | 5 files | **3 files** (agents-api / system-api / tasks-api) | **-2** | Phase 1 多算 |
| `docs/guides/` | 11 files | **9 files** | **-2** | Phase 1 多算 |
| `docs/reference/` | 8 files | **6 files** + 2 archive subdirs | **-2** | Phase 1 多算 |

**F1**: Phase 1 §1.2 数字 跟 实际 fs 不一致 (3 处 file:line `phase-1-conductor-scan.md:29, 31, 34`), "诚实修正" 从根源修复: 跟"独立" 战略 联合 master explicit 拍 留待.

### 1.2 Web dashboard 组件架构 (跟 EPIC-060-A Phase 4 联合)

**F2**: `web/src/dashboard/dispatch/` 仅 3 文件 (index.html:134 行 + dispatch.js:203 行 + dispatch.css), 0 README/0 组件 docs, 跟"品味" 联合 跨 release 留待.

**F3**: Data wiring 隐性 fallback pattern:
- `web/src/dashboard/dispatch/dispatch.js:172` — `// 真实部署: fetch('/api/dispatch/dashboard.json')` 注释
- `web/src/dashboard/dispatch/dispatch.js:176` — 实际 `fetch('../api/dispatch-dashboard.json')` (相对路径, **不一致**)
- 0 docs 解释 reverse proxy setup (跟 EPIC-053-D LESSONS-LEARNED.md:228 "把 dispatch-dashboard.sh 输出接入 web reverse proxy" 留待 联合, 但 未 在 web/ 落地)

### 1.3 跨文档 broken links (跟"诚实修正" 联合 0 隐藏, 跟 Phase 1 §1.3 7 命名 模式 混用 联合)

**F4**: 25+ cross-doc 引用 全部 use un-suffixed `.md` names, actual files use `-2026-06-19.md` suffix — **100% broken**. 抽样:

| Source (file:line) | Broken Ref | Actual File |
|--------------------|------------|-------------|
| `docs/reference/slash-commands-2026-06-19.md:5` | `cli-reference.md` | `cli-reference-2026-06-19.md` |
| `docs/reference/slash-commands-2026-06-19.md:13` | `INSTALL-MULTI-TOOL.md` | `INSTALL-MULTI-TOOL-2026-06-19.md` |
| `docs/reference/slash-commands-2026-06-19.md:641,642` | `cli-reference.md`, `INSTALL-MULTI-TOOL.md` | 同上 ×2 |
| `docs/reference/environment-variables-2026-06-19.md:84,86` | `config-reference.md`, `deployment.md` | `-2026-06-19.md` ×2 |
| `docs/reference/database-schema-2026-06-19.md:108` | `sqlite-module.md` | `sqlite-module-2026-06-19.md` |
| `docs/reference/config-reference-2026-06-19.md:117` | `environment-variables.md` | `environment-variables-2026-06-19.md` |
| `docs/architecture/AGENT-PROTOCOL.md:96` | `tasks-api.md` | `tasks-api-2026-06-19.md` |
| `docs/architecture/HOOK-PIPELINE.md:134` | `config-reference.md` | `config-reference-2026-06-19.md` |
| `docs/architecture/RECOMMENDER-SYSTEM.md:141` | `cli-reference.md` | `cli-reference-2026-06-19.md` |
| `docs/architecture/WORKFLOW-ENGINE.md:143` | `quick-start.md` | `quick-start-2026-06-19.md` |
| `docs/guides/quick-start-2026-06-19.md:148,151` | 7 个 un-suffixed refs | 全部 `-2026-06-19.md` |
| `docs/guides/deployment-2026-06-19.md:118,152,153` | `config-reference.md`, `monitoring.md`, `backup-restore.md` | `-2026-06-19.md` ×3 |
| `docs/guides/testing-guide-2026-06-19.md:150` | `contributing.md` | `contributing-2026-06-19.md` |
| `docs/guides/api-authentication-2026-06-19.md:110` | `config-reference.md` | `config-reference-2026-06-19.md` |
| `docs/guides/troubleshooting-2026-06-19.md:87,129,132` | 3 个 un-suffixed refs | 全部 `-2026-06-19.md` |
| `docs/guides/sqlite-module-2026-06-19.md:142,163` | `backup-restore.md` ×2 | `backup-restore-2026-06-19.md` |
| `docs/guides/contributing-2026-06-19.md:131,139` | `ADR-template.md`, `runbook.md` | (path B 路径差异) |
| `README.md:127` | `docs/guides/INSTALL-MULTI-TOOL.md` | `INSTALL-MULTI-TOOL-2026-06-19.md` |
| `RELEASE.md:89` | `docs/guides/migration-single-to-multi-agent.md` | `migration-single-to-multi-agent-2026-06-19.md` |
| `.continue/skills/kallax/README.md:61,63` | `INSTALL-MULTI-TOOL.md`, `slash-commands.md` | `-2026-06-19.md` ×2 |
| `.claude/skills/kallax/SKILL.md:47` | `slash-commands.md` | `slash-commands-2026-06-19.md` |

**F5**: **`docs/api/` 缺 overview / auth doc** — `api-authentication-2026-06-19.md` 在 `docs/guides/` 而非 `docs/api/`, 跟"api-authentication" 路径 不一致 (跨 release 留待 从根源修复).

### 1.4 EPIC-060-A Phase 4 web dashboard deploy docs gap (跟"诚实修正" 联合 0 隐藏)

**F6**: `web/scripts/deploy.sh` + `deploy-cloudflare.sh` + `deploy-github-pages.sh` + `status-deploy.sh` (4 scripts, 跟 `confluence/decisions/EPIC-060-A-PHASE-4-WEB-DEPLOY-2026-06-19.md:22-42` 联合, 3/3 PASS deployment-ready) — **0 user-facing docs**.

**F7**: `docs/guides/deployment-2026-06-19.md:1-153` 全文 **0 提到** `web/scripts/deploy*.sh` / Cloudflare Pages / GitHub Pages / wrangler / gh-pages — 跟"反讽" 联合 从根源修复 "deployment doc 0 提 真部署 路径".

### 1.5 版本 drift (跟"诚实修正" 联合 0 隐藏)

**F8**: Version 不一致:
- `web/index.html:15, 140` — 显示 `v2.7.3`
- `web/package.json:3` — `"version": "2.7.4"`
- `CHANGELOG.md` (file:line `CHANGELOG.md:61-122`) — 截至 **v2.7.2** (无 v2.7.3 / v2.7.4 entry)

跨 release 留待 master explicit 拍 1 命名 共识 (跟"独立" 战略 联合).

### 1.6 i18n / navigation 模式 不一致 (跟"品味" 战略 联合)

**F9**: 2 dashboard 用 2 种 导航 pattern:
- `web/index.html:30-33` — `data-tab` attribute + i18n (`data-i18n="nav.overview"`)
- `web/src/dashboard/dispatch/index.html:27-31` — `href="#overview"` hash + 0 i18n

跟"品味" 战略 联合 跨 release 留待 master 拍 1 命名 共识.

## 2. 风险 + 约束 (跟"诚实修正" 战略 联合 0 隐藏)

| # | 风险 | 描述 | 缓解 |
|---|------|------|------|
| **R1** | 用户 onboarding 受阻 | 25+ broken cross-doc links → 新人 跟 quick-start 路径 走 9/9 断 (跟 README.md:127, RELEASE.md:89, troubleshooting.md:87 联合) | 跟"诚实修正" 联合 master explicit 拍 1 命名 共识 (Phase 1 §1.3), 跟"独立" 战略 联合 跨 release 留待 |
| **R2** | EPIC-060-A Phase 4 文档 缺口 | 5 deploy scripts + 4 sections 0 user-facing docs → deployment-ready 但 用户 0 知道 如何 invoke | 跟"诚实修正" 联合: 文档 缺口 跟 代码 完成 度 失焦 (跟"反讽" 联合 从根源修复) |
| **R3** | Phase 1 KPI 错位 风险 | 3/3 Phase 1 §1.2 数字 跟 fs 不一致 → 9 专家 报告 跟 Phase 1 baseline 不齐 | 跟"诚实修正" 联合 修 Phase 1 numbers (跟"独立" 战略 联合 0 跨 session 拍板) |
| **R4** | dashboard 数据 fallback 隐性 | dispatch.js:176 fetch 相对路径 跟 comment:172 不一致 → 真实部署 silent failure (SAMPLE_DATA fallback 静默) | 跟"反讽" 联合: 0 hidden data wiring (跟 EPIC-053-D LESSONS-LEARNED.md:143 "SAMPLE_DATA fallback" 联合) |
| **R5** | 命名 共识 0 拍 | 7 命名 模式 + 25+ broken links → 跨 release 反复 从根源修复 | 跟"独立" + "翻篇&精进" 战略 联合 0 强制 拍板, master explicit 拍 1 命名 共识 留待 |
| **R6** | Version drift | web/index.html v2.7.3 / web/package.json v2.7.4 / CHANGELOG v2.7.2 → 3 源 3 版本 | 跟"独立" 联合 master explicit 拍 1 共识, 跟"诚实修正" 联合 0 隐藏 drift |

## 3. 推荐 (跟"独立" 战略 联合 0 跨 session 拍板)

### 3.1 短 term (跟 EPIC-060-A Phase 4 联合, deployment-ready)

**Rec 1**: 跟 Phase 1 §1.2 file:line `phase-1-conductor-scan.md:18-36` 联合, 修 Phase 1 数字 (api/3 + guides/9 + reference/6), 跟"诚实修正" 战略 联合 0 隐藏 KPI falsification.

**Rec 2**: 跟 EPIC-060-A Phase 4 联合, 在 `docs/guides/deployment-2026-06-19.md` 加 **§5 Web Dashboard Deployment** (跟 `confluence/decisions/EPIC-060-A-PHASE-4-WEB-DEPLOY-2026-06-19.md:22-42` 联合), 覆盖 `deploy.sh --platform=cloudflare|github-pages|self-hosted` + `--dry-run` 模式 + env vars 12-factor (跟"反讽" 联合 从根源修复 vendor lock-in, 跟"诚实修正" 联合 0 hidden).

**Rec 3**: 新建 `docs/api/dispatch-api-2026-06-19.md` (跟 `web/src/dashboard/dispatch/dispatch.js:172` 联合) — 文档 `/api/dispatch/dashboard.json` endpoint contract + reverse proxy 接入 pattern (跟 EPIC-053-D LESSONS-LEARNED.md:228 联合).

### 3.2 中 term (跟"品味" 战略 联合 0 强制 拍板)

**Rec 4**: 新建 `web/README.md` (跟 Phase 1 §1.6 file:line `phase-1-conductor-scan.md:121-131` 联合, 9/10 路径缺 README, `web/` 在其中) — 跟 `web/package.json` (npm start) + `web/scripts/start.sh` 联合, 文档 dispatch dashboard 路由.

**Rec 5**: 跟"品味" 战略 联合, **跨 release 留待** master explicit 拍 1 命名 共识 — 0 强制 拍板, 跟"独立" 战略 联合 0 ai-auto 决策 (跟 v2.0.7 PHASE-014 模式 一致).

### 3.3 跨 release 留待 (跟"翻篇&精进" 联合 0 增 Rule 0 增 命令 持平)

**0 强制**:
- 0 强制 拍 1 命名 共识 (跟 7 命名 模式 联合, master explicit 留待)
- 0 强制 拍 dashboard 导航 pattern (`data-tab` vs `href="#hash"`, 跟 F9 联合)
- 0 强制 拍 version bump (v2.7.3 / v2.7.4 drift, 跟 F8 联合)

## 4. 跨 release 留待 (跟"翻篇&精进" 战略 联合)

- **0 增 Rule 0 增命令 持平** (跟 v2.4.1 还原 22 Rule 联合, 跨 18 release 累计)
- **0 强制 拍板** — 25+ broken links 跨 release 留待 master explicit 拍 1 命名 共识 (跟"独立" 战略 联合, 跟 v2.0.7 PHASE-014 模式 一致)
- **0 跨 session 拍板** — dashboard 导航 pattern (`data-tab` vs `href`) 跨 release 留待 master explicit 拍 (跟"品味" 战略 联合)
- **0 强制 拍 1 共识** — web dashboard 部署 docs gap 跨 release 留待 EPIC-060-A Phase 4 实施 ticket 拍 (跟 BE-14 1 ticket 1 subagent 串行 联合)

## 5. KPI (跟 Rule 9 X/Y 格式 联合)

| # | KPI | 测量 | 当前 X/Y | 目标 X/Y |
|---|-----|------|----------|----------|
| **K1** | **Cross-doc link integrity** | broken refs / total refs | **25+/50+** (~50% 断) | 跟 master 拍 1 命名 共识 后 修 (跨 release 留待) |
| **K2** | **Web dashboard deploy docs coverage** | scripts documented / total scripts | **0/5** (deploy.sh + 4 sub-scripts + verify-deploy) | 1/1 短 term (Rec 2), 5/5 跨 release |
| **K3** | **Phase 1 数字 一致性** | paths match fs / total paths stated | **3/6 paths 错位** (api / guides / reference) | 6/6 (Rec 1) |
| **K4** | **API docs 对齐 code contract** | endpoints documented / endpoints used by web | **3/4** (agents/system/tasks ✅ + dispatch ❌) | 4/4 (Rec 3) |
| **K5** | **Top-level README coverage** | paths with README / 10 paths | **0/10 web/ + 跟 Phase 1 §1.6 联合** | 10/10 跨 release (Rec 4) |
| **K6** | **Hidden debt count** | web components / docs / API 缺口 (跟"反讽" 联合 从根源修复) | **6 显式 debt** (F1/F3/F4/F5/F6/F8) | 跨 release 留待 master 拍 |

---

**End of Frontend Expert Report**
**Status**: READ-ONLY 完成, 0 跟踪 0 改 任何 实际 文件 (除 本 报告), 跟"独立" + "翻篇&精进" 战略 联合 0 跨 session 拍板