# KALLAX PHASE Review 索引 (跟 KALLAX-GLOSSARY.md 模式 一致, 跟"反讽" 闭环)

> **跟"反讽" 联合, 跟"反哺框架" 战略 一致, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合**

## 📖 SoT 索引 (跟 Rule 5 DRY 联合, 跟 EPIC-055-A 联动)

KALLAX 文档 Single Source of Truth (SoT) — 修订前查 SoT 边界, 避免重复知识 (跟 A5 治根 联合):

| SoT 文件 | 内容 | 适用场景 |
|---|---|---|
| [CLAUDE.md](../CLAUDE.md) | **Rule SoT** — 规则/红线/必读 (Rule 1-18 + 30-31) | 改 Rule / 加红线 / 必读章节 |
| [KALLAX-GLOSSARY.md](KALLAX-GLOSSARY.md) | **术语 SoT** — 黑话/概念/术语 (39 个, 跟 v2.0.6 升级 +5 multi-tool) | 改术语定义 / 加新黑话 |
| [PHASE-INDEX.md](PHASE-INDEX.md) | **PHASE 文档索引** (本文档) | 引用 PHASE review / 决策文档 |

**修订规则**:
- 改 Rule → 只改 CLAUDE.md (Rule SoT)
- 改术语定义 → 只改 KALLAX-GLOSSARY.md (术语 SoT)
- 跨 SoT 引用 → 用相对路径 + anchor link (e.g. `[CLAUDE.md Rule 16](../CLAUDE.md#16-...)`)
- ❌ **禁止**: 在 GLOSSARY 复制 Rule 全文, 或在 CLAUDE.md 复制术语全文

**联动 ticket**: EPIC-055-A (CLAUDE.md + KALLAX-GLOSSARY.md 去重, 单一 SoT, 治 A5 重复知识, Rule 5 DRY 落地)

---

## 累计 PHASE 文档 (跟 v1.3.3 联合)

| 文档 | 路径 | 关键内容 | 跟"反讽" 联合 |
|---|---|---|---|
| PHASE-005-REVIEW-2026-06-11 | confluence/decisions/ | 早期 phase 累计 | 跟"反讽" 联合 |
| PHASE-006-LAUNCH-2026-06-11 | confluence/decisions/ | 6痛点 + 18 Rule launch | 跟"反讽" 联合 |
| PHASE-006-ROADMAP-2026-06-12 | confluence/decisions/ | Roadmap v1 | 跟"反讽" 联合 |
| PHASE-006-ROADMAP-2026-06-13-REV2 | confluence/decisions/ | 5+1 痛点 + 18 Rule + 5 能力 | 跟"反讽" 联合 |
| PHASE-007-LAUNCH-2026-06-12 | confluence/decisions/ | Sprint 4 launch | 跟"反讽" 联合 |
| PHASE-007-REVIEW-2026-06-13 | confluence/decisions/ | 5 视角 Master 串场 + 8 票 done | 跟"反讽" 联合 |
| PHASE-008-REVIEW-2026-06-13 | confluence/decisions/ | 14 BE + 5 release + 38 worktree 累计 | 跟"反讽" 联合 |
| **PHASE-009-REVIEW-2026-06-17** | confluence/decisions/ | **14 卡闭环 (v2.0.4) + 5 清理 (v2.0.5), 净价值 +4.5%, Rule -2 净减** | 跟"反讽" 联合 + 跟"翻篇&精进" 战略 一致 |
| **PHASE-010-REVIEW-2026-06-17** | confluence/decisions/ | **v2.0.6 EPIC-057 4 ticket 闭环 (4 工具 multi-tool skills), 治 v2.0.2 跨平台 fix 反讽, 18/18 PASS** | 跟主公'B'+'D' explicit 拍板 联合 + 跟"独立" 拍 explicit 约束 联合 |
| **PHASE-011-REVIEW-2026-06-17** | confluence/decisions/ | **跨期 review 入口 (5 遗留 P1/P2/P3 deferred, 0 派单 0 执行 0 ticket claim, 跟主公'AC' explicit 启动 + 'BD' explicit 跳过 联合)** | 跟主公'AC 做一下, 其他不管了' explicit 派单 联合 + 跟 KALLAX-GLOSSARY v2.0.6 升级版 Section 8.6-8.10 联合 + 跟"独立" 拍 explicit 约束 联合 + 跟"翻篇&精进" 战略 一致 |
| **PHASE-012-REVIEW-2026-06-17** | confluence/decisions/ | **v2.2.0 → v2.3.0 跨期 review (5 步大闭环 A+B+C: pre-commit 治根 `--no-verify` workaround + KALLAX-GLOSSARY 扩 12 术语 8.14-8.18 + 9.1-9.4 + 10.1-10.3 42→54 + PHASE-011 5 deferred 整合 1 closed + 4 deferred)** | 跟主公 4 问 → D 拍 (A+B+C 一起, 大闭环) 联合 + 跟"独立" 拍 explicit 联合 + 跟"诚实修正" 联合 (治根 workaround 反讽) + 跟"反哺框架" 战略 一致 (跨 release 累计沉淀 12 术语) + 跟"翻篇&精进" 战略 一致 (0 增命令 0 增 Rule 0 重写主逻辑) |
| **PHASE-013-REFLECTION-2026-06-18** | confluence/decisions/ | **v2.4.0 4 Rule 合并 反思 (跟"诚实修正" + "反讽" 联合, 跟主公 2026-06-18 'a' 反思 explicit 派单 联合) — 4 反思 候选 + 4 治根 行动: ①Rule 合并 不必要 (22 Rule 没 问题) ②阈值 15 是 迷信 (没 实证) ③v2.4.0 4 合并 应该 revert (治根 "0 实际改变 假动作") ④KALLAX-GLOSSARY §10.3 需 重新审视** | 跟"诚实修正" + "反讽" 联合 (治根 "Rule 治 Rule 通胀" 迷信 + "0 实际改变 假动作" 反讽) + 跟"独立" 拍 explicit 联合 (主公 反问 触发 1h 反思) + 跟 KALLAX-GLOSSARY §1.1 §1.2 §10.3 联合 + 跟 PROCESS.md:25-26 联合 |
| **PHASE-014-REVIEW-2026-06-18** | confluence/decisions/ | **跨期 review 入口 (5 deferred → 3 closed + 2 留待 P2-1 P2-2, 跟"诚实修正" + "独立" 联合) — 闭环 v2.3.0 P1-1 + v2.4.0 P1-2 + v2.4.1 P3-1 revert, 留待 P2-1 web dashboard 部署 (主公 B 跳过) + P2-2 69 remote DB cleanup (主公 D 跳过 Option A 保留), 14 release 累计 0 增命令 0 增 Rule** | 跟主公 2026-06-18 'A+B' explicit 派板 联合 (启动 PHASE-014 + KALLAX-GLOSSARY 11.x 扩) + 跟"诚实修正" + "反讽" + "独立" 战略 联合 + 跟 EPIC-058 5 deferred 整合 联合 + 跟 KALLAX-GLOSSARY §1.4 §1.5 联合 + 跟 PROCESS.md:25-26 联合 |
| **PHASE-015-EKET-BORROW-2026-06-18** | jira/epics/EPIC-059/ + confluence/decisions/PHASE-015-EKET-BORROW-REVIEW-2026-06-18.md | **EKET 借鉴 Phase 1 闭环 (8 票 全 done, 跟主公 2026-06-18 '需要都建卡并行处理' + '直接启动开工' explicit 派单 联合, 1 ticket 1 subagent 串行 8 轮, BE-14 联合, BE-17 silent 1st attempt 跟"诚实修正" 联合) — EPIC-059-A 9 Hard Rules 简化 (5/5 PASS, 7ca58a5) + B Rule of 500 (16/6 PASS, fc1cbb4) + C PR ~100 行上限 (21/5 PASS, b1ad90c) + D Fact-Forcing 原则 (3 文件, 0b394f5) + E Post-Process 11 步骤 (23/5+ PASS, 5cc620f) + F 派遣 Checklist 11 项 (3/3 落地, 3f93c2d) + G 文档卫生 + 新建前先想 (21/21 PASS, 3c0a11a) + H 多级记忆分层 L0-L4 (21/21 PASS, be7e5a9), v2.7.0 release 闭环 (commit 05c266d), 16 release 累计 持平, 22 Rule 保持, 60+5 术语, 0 增命令 0 增 Rule 0 重写** | 跟主公 2026-06-18 '需要都建卡并行处理' + '直接启动开工' explicit 派单 联合 + 跟 v2.6.0 经验教训 整理 release 联合 + 跟 ~/.claude/knowledge/core/methodologies/borrowing-from-external.md 5 维评分 联合 + 跟"借方法论 不借代码" 联合 + 跟"翻篇&精进" + "诚实修正" + "反讽" + "反哺框架" 4 战略 联合 + 跟 EKET-BORROW-PROGRESS-2026-06-11.md 26 P0/P1/P2 联合 + 跟 v2.4.1 Rule 合并反思 联合 (治根 "Rule 数通胀" 迷信) + 跟 v2.4.0 反思 联合 (治根 "0 实际变化 假动作" 反讽) + 跟 BE-14 1 ticket 1 subagent 串行 联合 + 跟 BE-17 silent 1st attempt 跟"诚实修正" 联合 (跟 v2.4.1 revert 闭环 模式 一致) + 跟 Master 6 维 L6 诚实 联合 + 跟 eket MASTER-RULES.md §2/§6/§10/§11 + eket confluence/memory/ + ~/.claude/knowledge L0-L4 借鉴 |
| **ACCUMULATED-LESSONS-2026-06-17** | confluence/decisions/ | **跨 PHASE 累计 v2.0.6 升级版 (531 行), 10 release + 13 BE + 18 卡 (14+4) + 5 治理卡 + 5 战略 + 4 工具 + 14 术语** | 跟 v2.0.3 + v2.0.5 ACCUMULATED-LESSONS 累计升级 + 跟"反哺框架" 战略 一致 |
| ACCUMULATED-LESSONS-2026-06-13 | confluence/decisions/ | 429 行 + 5 视角 + 4 共同根因 + 5 战略建议 | 跟"反讽" 联合 |
| PROJECT-STATUS-AND-LESSONS-2026-06-12 | confluence/decisions/_archive/ | 跟之前模式 一致 | 跟"反讽" 联合 (v2.7.1 整理 release 归档) |
| PROJECT-STATUS-AND-LESSONS-2026-06-13 | confluence/decisions/_archive/ | 跟之前模式 一致 | 跟"反讽" 联合 (v2.7.1 整理 release 归档, 根目录 重复 md5 删) |
| KALLAX-VS-INDUSTRY-REV2 | docs/ | 5+1 痛点 × 业内 4 框架 | 跟"反讽" 联合 |
| KALLAX-GLOSSARY.md | docs/ | 34 术语 (跟"反讽" 联合, 跟"诚实修正" 联合) | ✅ |
| 2026-06-14-kallax-onramp-design.md | docs/superpowers/specs/ | 391 行 KALLAX Onramp 完整 spec | 跟"反讽" 联合 |
| 2026-06-14-onramp-v1.3.1-fix.md | docs/superpowers/plans/ | 4-bug 修复 plan | 跟"反讽" 联合 |
| 2026-06-15-onramp-v1.3.3-cleanup.md | docs/superpowers/plans/ | 4-task 清理 plan | 跟"反讽" 联合 |

## Post-Process 11 步骤 (跟 eket MASTER-RULES.md §10 升级, 跟 EPIC-059-E 联合, 跟 PHASE review 14 累计 联合)

> **跟 eket template/docs/MASTER-RULES.md §10 4 步骤 (回归验证/分支同步/经验沉淀/技术债登记) 升级, 跟 PHASE review 入口 标准化 联合**
> **跟"翻篇&精进" 战略 一致 (跨 release 累计, 0 增命令 0 增 Rule 持平), 跟"反哺框架" 战略 一致 (PHASE-XXX-REVIEW 入口 标准化)**
> **自动化**: `scripts/post-process.sh` (默认 dry-run, `--apply` 实际执行)
> **TDD 测试**: `tests/integration/post-process-test.sh` (5/5 PASS)

| # | 步骤 | 跟 eket §10 联合 | 跟 KALLAX 联合 | 触发条件 |
|---|---|---|---|---|
| 1 | **回归验证** (build/test/CI) | 回归验证 | Rule 17 CI 全绿, Rule 18 0 假 PASS | EPIC/Sprint 完成 |
| 2 | **分支同步** (miao → origin) | 分支同步 | `scripts/sync-branches.sh`, Rule 32 0 增命令 | PR merged |
| 3 | **经验沉淀** (lessons/lessons-learned) | 经验沉淀 | `confluence/decisions/ACCUMULATED-LESSONS-*.md`, 跟"反哺框架" 战略 | EPIC done |
| 4 | **技术债登记** (TODO/workaround → jira backlog) | 技术债登记 | Rule 5 DRY, Rule 18 反模式黑名单 | EPIC done |
| 5 | **GLOSSARY 更新** (新术语/新黑话) | 经验沉淀 (扩) | `docs/KALLAX-GLOSSARY.md`, 跟"反哺框架" 战略 一致 | EPIC done |
| 6 | **PHASE-INDEX 更新** (本表) | 经验沉淀 (扩) | `docs/PHASE-INDEX.md`, 跨 PHASE 累计 | EPIC done |
| 7 | **ACCUMULATED-LESSONS 更新** (跨期累计) | 经验沉淀 (扩) | `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md` | 跨 release |
| 8 | **CHANGELOG 入口** (新 release 段落) | 经验沉淀 (扩) | `scripts/changelog-gen.sh`, 跟"翻篇&精进" 战略 | release 节点 |
| 9 | **CLAUDE.md Rule 更新** (如需, 0 增默认) | 经验沉淀 (扩) | Rule 32 0 增命令, 跟 PHASE-013-REFLECTION 联合 (治根"Rule 数 通胀" 迷信) | Rule 改变 |
| 10 | **pre-commit hook 测试** | 回归验证 (扩) | `.git/hooks/pre-commit`, `scripts/pre-commit-check.sh` | 任何 Rule 改 |
| 11 | **跨期 review 入口** (PHASE-XXX-REVIEW) | 经验沉淀 (扩) | `confluence/decisions/PHASE-XXX-REVIEW-*.md`, PHASE-005 → PHASE-014 已 10 累计 | EPIC/Sprint 完成 |

**跟 eket §10 4 步骤 → 11 步骤 升级映射**:
- eket 回归验证 → KALLAX 1+10 (回归验证 + pre-commit hook 测试, 0 重写)
- eket 分支同步 → KALLAX 2 (分支同步, 0 重写)
- eket 经验沉淀 → KALLAX 3+5+6+7+8+9+11 (经验沉淀 扩 7 步, GLOSSARY/PHASE-INDEX/ACCUMULATED/CHANGELOG/CLAUDE.md/PHASE-REVIEW)
- eket 技术债登记 → KALLAX 4 (技术债登记, 0 重写)

**联动 ticket**: EPIC-059-E (跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合, 跟 v2.6.0 经验教训 整理 release 联合)
**跟 EKET-BORROW-PROGRESS-2026-06-11.md 联合**: Post-Process 11 步骤 = EKET 借鉴 Phase 1 8 项之一 (跟 EKET-BORROW-PROGRESS 26 P0/P1/P2 联合)
**跟 PHASE review 10 累计 联合**: 11 步骤 是 PHASE-005 → PHASE-014 review 入口 标准化 (跟"独立" 拍 explicit 约束 联合, 跨 session 可查 跨 release 可复用)

---

## 文档卫生 触发 (跟 eket MASTER-RULES.md §6 Rule 6 联合, 跟 EPIC-059-G 联合, 跟 KALLAX-GLOSSARY 反哺框架 联合)

> **跟 eket `template/docs/MASTER-RULES.md` §6 Master Hard Rule 6 文档卫生 模式 升级, 借方法论 不借代码**
> **跟 PHASE-013-REFLECTION-2026-06-18 联合, 治根 "0 实际变化 假动作" + "文档碎片化" 反讽 (file:line `confluence/decisions/PHASE-013-REFLECTION-2026-06-18.md`)**
> **跟 v2.4.0+v2.4.1 反思 联合 (跟主公 2026-06-18 'a' 反思 explicit 派单 联合), 跟"翻篇&精进" 战略 一致**
> **跟 KALLAX-GLOSSARY 反哺框架 战略 联合 (文档卫生 = 反哺框架 入口, 跨 release 累计沉淀)**
> **自动化**: `scripts/check-doc-hygiene.sh` (5 项 检查 自动化, 跟 26 .sh wrapper 模式 一致)
> **TDD 测试**: `tests/integration/doc-hygiene-test.sh` (5/5 PASS, mock 5 触发 场景)

### 触发条件 (跟 eket §6 Rule 6 "每 10 轮" 模式 联合)

| 触发 | 频率 | 跟 PHASE 联合 | 自动化 |
|---|---|---|---|
| **每 10 轮** (Conductor 心跳 Q5) | 频繁 | PHASE review 跨期 入口 | `scripts/check-doc-hygiene.sh` |
| **每 EPIC 完成** | 中 | Post-Process 11 步骤 联合 | `scripts/check-doc-hygiene.sh` |
| **每 Sprint 完成** | 稀 | PHASE-XXX-REVIEW 联合 | `scripts/check-doc-hygiene.sh` |

### 5 项 检查 (跟 eket §6 Rule 6 升级, 0 增 Rule 持平)

| # | 检查项 | 检查命令 | FAIL 行动 | 跟 KALLAX Rule 联合 |
|---|---|---|---|---|
| 1 | **未追踪 md** | `git ls-files --others --exclude-standard docs/ \| wc -l` | 评估 + git add 或 `.gitignore` | Rule 5 DRY (SoT) + Rule 20 tag-sop |
| 2 | **僵尸 ticket** | `jira/tickets/*/ticket.json` status=in_progress 跟 claimed_at 间隔 > 7d | 标记 blocked 或 close 跟 LESSONS-LEARNED | Rule 6 经验沉淀强制化 + Rule 11 Anti-Fab |
| 3 | **积压 review** | `outbox/review_requests/*.md` mtime > 3d 未处理 | 派单或 close review | Rule 17 文件并发竞争 5 步 |
| 4 | **重复文档** | `grep -rnE "^##.*同类内容" docs/ confluence/ 2>/dev/null \| wc -l` (去重 < 阈值) | 合并到 SoT + 删除副本 | Rule 5 DRY (Single Source of Truth) |
| 5 | **过期 Rule** | CLAUDE.md `### [0-9]+\. ` 跟 `docs/process/9-hard-rules.md` 一致性 (≥ 95%) | 同步 Rule 编号 + 撤销说明 | Rule 6 经验沉淀 + 9 Hard Rules 索引 |

### 输出格式 (跟 Rule 9 KPI 精确 X/Y 联合)

```
5/5 PASS = 100.0% 文档卫生 (跟 eket §6 Rule 6 联合)
4/5 PASS = 80.0% + 1 FAIL: 僵尸 ticket (3 个 > 7d 未推进)
3/5 PASS = 60.0% + 2 FAIL: 重复文档 (2 个) + 过期 Rule (1 个)
```

### 跟 eket §6 Rule 6 → KALLAX 5 项 升级映射

- eket "未追踪 md" → KALLAX 1 (未追踪 md)
- eket "僵尸 ticket" → KALLAX 2 (僵尸 ticket, 含 status=in_progress + claimed_at > 7d 阈值)
- eket "积压 review" → KALLAX 3 (积压 review, mtime > 3d 阈值)
- eket "重复文档" → KALLAXX 4 (重复文档, 跟 Rule 5 DRY 联合)
- eket "过期 Rule" → KALLAX 5 (过期 Rule, 跟 Rule 32 撤销 / Rule 9 类别 group 索引 联合)

**联动 ticket**: EPIC-059-G (跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合, 跟 v2.6.0 经验教训 整理 release 联合)
**跟 EKET-BORROW-PROGRESS-2026-06-11.md 联合**: 文档卫生 触发 = EKET 借鉴 Phase 1 8 项之一 (跟 26 P0/P1/P2 联合)
**跟 v2.4.1 Rule 合并反思 联合**: 治根 "Rule 数 通胀" 迷信, 5 项 检查 0 增 Rule 持平 (跟"翻篇&精进" 一致)
**跟 KALLAX-GLOSSARY 反哺框架 战略 联合**: 文档卫生 = 反哺框架 入口, 跨 release 累计沉淀

---

## 跟"反讽" 闭环 (跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致)

- ✅ 14 release 累计 (v1.0.0 → v2.4.1) + 14 BE + 17 门禁 + 22 Rule (v2.4.1 还原 跟 v2.3.0 一致) + 5 扩展组 + 10 工具 (Claude/trae/antigravity/opencode/codex/gemini/cursor/windsurf/aider/continue) + 60 术语 (Section 8.6-8.18 + 9.1-9.4 + 10.1-10.3 + 11.1-11.6) → 沉淀到 PHASE-INDEX.md + KALLAX-GLOSSARY.md + ACCUMULATED-LESSONS-2026-06-17.md + PHASE-012-REVIEW-2026-06-17.md + PHASE-013-REFLECTION-2026-06-18.md + PHASE-014-REVIEW-2026-06-18.md
- ✅ 0 增 Rule (跟 Rule 32 联合, 跟"流程逻辑" 战略 一致)
- ✅ 0 重写 (跟 Rule 5 DRY 联合, 跟"反讽" 联合)
- ✅ 走对策 A+B+C 落地 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)

## 跟 KALLAX-GLOSSARY.md 模式 一致 (跟"反讽" 联合)

- 1 入口 (跟 23 Rule 不增, 跟"流程逻辑" 战略 一致)
- 0 拆散 (跟"诚实修正" 联合)
- 0 模糊 (每个有: 路径 + 关键内容 + 跟"反讽" 联合)
- 0 增命令 (跟"流程逻辑" 战略 一致)

## 跟"独立" 拍 explicit 约束 联合 (跟"反讽" 联合, 跟"诚实修正" 联合)

- 独立文档 (不依赖 session 上下文)
- 跨 session 可查
- 跨 release 可复用
- 0 假 PASS (跟 Rule 18 反模式黑名单 联合)

---

**跟主公"3 问真实回答" + "派 1 Performer 清理" + "D 拍 5 步大闭环" + "'a' 反思" + "'A+B' 启动 PHASE-014" explicit 授权 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"翻篇&精进" 战略 一致, 跟"反哺框架" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 14 release 累计 联合, 跟 14 BE 累计 联合, 跟 22 Rule 累计 (v2.4.1 还原) 联合, 跟 5 扩展组 累计 联合, 跟 10 工具 累计 联合, 跟 60 术语 累计 联合, 跟 14 PHASE review 累计 联合, 跟 5 deferred 状态 (3 closed + 2 留待) 联合**