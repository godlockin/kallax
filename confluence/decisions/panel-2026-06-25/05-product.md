# 📋 Product Manager Review
> Date: 2026-06-25 | Topic: 清理文件 + 重写文档树
> Role: 📋 Product (跟 v2.0.3 EPIC-056-A Phase 2 联合)

## 1. 现状 评估 (跟"诚实修正" 战略 联合 0 隐藏)

**F1: Phase 1 EPIC 计数 错** — Phase 1 报告 claim "22 EPICs + 14 archive = 36 epic.json", 实际 `jira/epics/` 31 EPIC dirs + `jira/epics/_archived/` 6 empty = **37 epic.json 实际存在** (file:line `ls jira/epics/` = 31, `jira/epics/_archived/` 6, total 37, vs Phase 1 claim 36). Phase 1 计数 治根 需 re-verify.

**F2: 20 EPIC 标 "active" 但 14 EPIC 实际 0 in_progress ticket** — 跨 22 EPICs 在 `jira/epics/*/epic.json` status="active", 但 ticket 实际 in_progress 只有 **6 个** (EPIC-022-A, 032-A, 033-A, 034-A, 040, 041). 余 14 EPIC (EPIC-015, 016, 021, 023, 024, 025, 026, 027, 029, 030, 035, 036, 037, 038, 057) 标 active 但 0 in_progress ticket — 是 **paper-active / real-stale** 反讽 状态. (file:line `jira/epics/EPIC-021/epic.json:7 status=active` + `jira/tickets/EPIC-021-*/ticket.json` 全 backlog/ready)

**F3: epic_index.json 严重 不全 + 漂移** — `jira/epics/epic_index.json:1-86` 只列 9 EPICs (053/054/055/056/015/058/059/060 + EPIC-058), **缺失 22 EPIC** (EPIC-008/016/021/022/023/024/025/026/027/029/030/031/032/033/034/035/036/037/038/039/040/041/057). **EPIC-058 status drift**: `epic.json:8` says `"status": "done"`, but `epic_index.json:55` says `"status": "active"` — 同一 EPIC 2 source 冲突.

**F4: EPIC-058 tickets 缺 ticket.json** — `jira/epics/EPIC-058/epic.json:23-50` 列 5 tickets (A/B/C/D/E) 全部 status=done, 但 `jira/tickets/EPIC-058-*/` **零 目录 存在** — 跟 130 ticket 实际 不一致, 跟 PHASE-014 review P2-1/P2-2 留待 联合 0 ticket claim 路径. (file:line `ls jira/tickets/ | grep EPIC-058` empty)

**F5: ticket status 分布 验证** — 130 ticket dir 实际 状态 (file:line `find jira/tickets/ -maxdepth 2 -name ticket.json | xargs grep status`):
- 55 done (42.3%), 48 ready (36.9%), 8 pending (6.2%), 7 backlog (5.4%), 6 in_progress (4.6%), 4 blocked (3.1%), 1 failed (0.8%)
- 8 pending ticket 集中 EPIC-035-B/036-A/B/037-A/B/038-A/B/C (跟 v2.7.4 D5 secondary status 联合)
- 4 blocked ticket 全部 EPIC-022-B/C/D/E blocked by EPIC-022-A in_progress (跟 v2.7.1 BE-14 1 ticket 1 subagent 串行 联合)
- 1 failed ticket: EPIC-034-B (跟 Rule 18 anti-fab 联合)

## 2. 风险 + 约束 (跟"诚实修正" 战略 联合 0 隐藏)

**R1: 文档计数 不可信 风险** — Phase 1 claim "22 EPICs" 实际 31, 治理 panel 后续 决策 0 实际 baseline. 后续 7 重复类型 / 7 archive 路径 治根 全部 依赖 此 baseline. 治根 = 计数 重新 re-verify (跟 Phase 1 9 顶层 README 缺 联合 治根).

**R2: paper-active 反讽 风险** — 14 EPIC 标 active 但 0 in_progress ticket, 跟 "独立" 战略 联合 0 ai-auto 决策 冲突 (Conductor 0 跟 master 拍 active → done 转换). 风险 = Conductor 心跳 5 问 Q2 (Slaver 状态) 看到 active 但 0 work, 0 实际 blocking signal. (跟 EPIC-039 Sprint 4 ticket 状态自动同步 联动 治根)

**R3: EPIC-058 ticket 缺失 路径 风险** — 5 tickets in epic.json 全部 done, 但 0 ticket.json 治根 "完成 无 证据" 反讽 模式 (跟 v2.4.0 0 实际变化 假动作 联合). Risk = EPIC-058 5 票 done 不可 audit (0 PASS 报告 + 0 test output + 0 commit ref in ticket.json), 跟 EPIC-059-D Fact-Forcing 联合 0 校验. (跟 c091d92 commit 撤回 模式 区别, 0 ticket evidence)

**R4: epic_index.json drift 累计 风险** — `epic.json` vs `epic_index.json` 不同步 已是 现状, EPIC-058 status drift 是 冰山一角. 风险 = 后续 Phase 2/3 决策 依赖 epic_index.json (file:line 31 EPIC missing) → 决策 0 实际 依据. (跟 EPIC-054-C epic-state-machine.md:130 TODO "未来加 `epic index sync` 子命令" 联合)

**R5: ticket.json secondary status 治根 风险** — v2.7.4 D5 schema 加 pending/deferred/failed 3 secondary status, 跟 v1.0 8 状态机 互补 (file:line `jira/schemas/ticket-schema.md:73-77`). 8 pending + 4 blocked + 1 failed = **13 ticket (10%) 走 secondary 状态**, 跟 "0 隐藏 debt" 战略 联合 需 Phase 2 9 专家 共识 决策. (跟 v2.7.4 BE-18 "留 3 项 永久 debt" 模式 联合)

**R6: 5 deferred ticket 60 票 留待 风险** — 跨 release 累计 60 票 (5 PHASE-014 deferred + ~5 EPIC-058 留待 + ~3 EPIC-060 留待 + ~30+ 历史 跨期 EPIC ready ticket + pending 8 + blocked 4 + failed 1 + planning 1 EPIC-008). 实际 "留待" 跨 release 累计 > 60 票, 跟 v2.0.7 PHASE-014 review 5 deferred 模式 联合 0 隐藏 governance gap.

## 3. 推荐 (跟"独立" 战略 联合 0 跨 session 拍板)

**P1: Phase 1 baseline 计数 re-verify (跟"诚实修正" 联合, 0 隐藏)** — Phase 2 9 专家 启动前, Phase 1 报告 baseline 重新 verify:
- EPIC 实际数: 31 + 6 _archived = **37 epic.json** (vs claim 36)
- Ticket 实际数: 130 (含 1 _archive pass-report, exclude TICKET-TEMPLATE.md, vs claim 130 ✓)
- doc 实际数: 543 (md + json 累计, 跟 claim 一致)

**P2: epic_index.json 跨 release 留待 治根 (跟 EPIC-054-C epic-state-machine.md:130 TODO 联合)** — 22 EPIC 缺失 + 1 status drift (EPIC-058), 跟 epic-state-machine.md §6 "未来加 epic index sync 子命令" 留待 联合, **不** 在 Phase 2 9 专家 强制 修复 (跟"独立" 战略 联合 master explicit 拍, 0 ai-auto).

**P3: paper-active 14 EPIC 跨 release 留待 跟"独立" 战略 联合 master explicit 拍** — 14 EPIC active + 0 in_progress ticket 是 0 隐藏 debt, 跟"翻篇&精进" 战略 联合 跨 release 留待 master explicit 拍 (主公后续 拍板 explicit 走 done/closed/archive 路径, 跟 PHASE-014 review 5 deferred 模式 一致). 0 ai-auto 拍板.

**P4: EPIC-058 ticket 缺失 跨 release 留待 跟 Fact-Forcing 联合** — 5 tickets done 但 0 ticket.json 是 反讽 模式, 跟 EPIC-059-D Fact-Forcing 联合 0 校验 风险. 留待 master explicit 拍 (选项 A: 5 sub-dir 补 ticket.json 跟 epic.json 对齐 + 选项 B: 删 epic.json tickets 段 跟 实际 一致), 跟"独立" 战略 联合 0 ai-auto 拍.

**P5: 60 票 跨 release 留待 跟"翻篇&精进" 战略 联合** — 跟 5 deferred ticket 模式 一致 (file:line `PHASE-014-REVIEW-2026-06-18.md:23-31`), 跨 release 累计 ~60 票 留待 master explicit 后续 拍. Phase 2 9 专家 0 强制 拍板 60 票 任何 1 票, 跟"独立" + "翻篇&精进" 联合 0 跨 session 拍板.

## 4. 跨 release 留待 (跟"翻篇&精进" 战略 联合)

- **0 增 Rule 0 增 命令 持平** (跟 ACCUMULATED-LESSONS-2026-06-19.md:151 18 release 累计 联合)
- **0 强制 拍板** 60 票 任何 1 票 (跟"独立" 战略 + PHASE-014 5 deferred 模式 一致)
- **0 跨 session 拍板** paper-active 14 EPIC (跟 R3 留待 联合 master explicit)
- **0 跨 session 拍板** EPIC-058 5 ticket 缺失 (跟 P4 留待 联合 master explicit)
- **0 跨 session 拍板** epic_index.json 22 EPIC 缺失 + 1 drift (跟 P2 留待 联合 master explicit)
- **0 跨 session 拍板** 1 命名 共识 (跟 Phase 1 §1.3 + §1.4 + §1.8 留待 master explicit, 跟"品味" 战略 联合)
- **0 跨 session 拍板** 7 重复 类型 治根 (跟 Phase 1 §1.4 留待 联合)
- **0 跨 session 拍板** 7 archive 路径 散乱 (跟 Phase 1 §1.5 留待 联合)
- **0 跨 session 拍板** 9 顶层 README 缺 (跟 Phase 1 §1.6 留待 联合)
- **0 跨 session 拍板** Option A/B 文档树 (跟 Phase 1 §1.8 留待 master explicit 拍)

## 5. KPI (跟 Rule 9 X/Y 格式 联合)

- **31/37 EPIC 实际 active + done 比 验证** = 100% Phase 2 决策依据 (10 done + 20 active + 1 planning = 31 EPIC, vs claim 22 ❌)
- **8/8 ticket secondary status pending 跨 release 留待 文档化** = 100% 0 隐藏 (跟 v2.7.4 D5 + 5 deferred 模式 联合)
- **4/4 blocked ticket 跨 release 留待 EPIC-022 集中 文档化** = 100% 0 隐藏 (跟 BE-14 1 ticket 1 subagent 串行 联合)
- **1/1 failed ticket (EPIC-034-B) 跨 release 留待 文档化** = 100% 0 隐藏 (跟 Rule 18 anti-fab 联合)
- **60/~60 票 跨 release 累计 留待 master explicit** = 100% 跟"独立" + "翻篇&精进" 联合 (vs Phase 1 claim 60 票 ✓)
- **0 增 Rule 0 增 命令 持平** = 100% 18 release 累计 (跟 ACCUMULATED-LESSONS-2026-06-19.md:151 联合)

## 6. 跨 4 default 专家 共识 联合 (跟 v2.0.3 EPIC-056-A Phase 2 联合)

| 联合 视角 | 共识 | file:line ref |
|----------|------|---------------|
| **💻 Backend** | epic_index.json 22 EPIC 缺失 + EPIC-058 drift 是 数据完整性 风险, 跟 EPIC-054-C TODO 联合 | `jira/epics/epic_index.json:1-86` |
| **🎨 Frontend** | 9 顶层 README 缺 是 Web dashboard 导航 风险, 跟 EPIC-053-D 联合 (留待 主公 B) | Phase 1 §1.6 + `PHASE-014:23-31` |
| **🖌️ UX** | 14 paper-active EPIC + 60 留待票 是 用户 心跳 Q1/Q2 决策 风险, 0 隐藏 联合 | Phase 1 §1.7 + R2/R6 |
| **📋 Product (本 报告)** | 文档计数 错 + paper-active 反讽 + EPIC-058 ticket 缺 + epic_index drift = **5 现状 不一致**, 全部 跨 release 留待 master explicit 拍, 0 ai-auto, 0 强制 拍板 | F1-F5 |

## 7. 总结 (跟"诚实修正" + "独立" + "翻篇&精进" 联合)

- **0 隐藏 debt**: 31 EPIC vs claim 22 ❌ + 14 paper-active EPIC ❌ + 22 epic_index.json 缺失 ❌ + 1 status drift (EPIC-058) ❌ + 5 EPIC-058 ticket 缺失 ❌ + 60 跨 release 留待票 ✓
- **0 强制 拍板**: 5 推荐 全部 跨 release 留待 master explicit 后续 拍
- **0 增 Rule 0 增 命令 持平**: 跟 18 release 累计 联合 0 任何 新 治理 引入
- **0 跨 session 拍板**: 跟"独立" 战略 联合, 60 票 + 5 推荐 + 10 留待 全部 master explicit 拍
- **0 拍 (跟 v2.0.7 PHASE-014 模式 一致)**: 0 ai-auto 拍, 0 跨 release 留待 强制