# KALLAX PHASE Review 索引 (跟 KALLAX-GLOSSARY.md 模式 一致, 跟"反讽" 闭环)

> **跟"反讽" 联合, 跟"反哺框架" 战略 一致, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合**

## 📖 SoT 索引 (跟 Rule 5 DRY 联合, 跟 EPIC-055-A 联动)

KALLAX 文档 Single Source of Truth (SoT) — 修订前查 SoT 边界, 避免重复知识 (跟 A5 治根 联合):

| SoT 文件 | 内容 | 适用场景 |
|---|---|---|
| [CLAUDE.md](../CLAUDE.md) | **Rule SoT** — 规则/红线/必读 (Rule 1-18 + 29-33) | 改 Rule / 加红线 / 必读章节 |
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
| **PHASE-015-EKET-BORROW-2026-06-18** | jira/epics/EPIC-059/ | **EKET 借鉴 Phase 1 (8 项, 跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合) — 9 Hard Rules 简化 + Rule of 500 + PR ~100 行上限 + Fact-Forcing 原则 + Post-Process 11 步骤 + 派遣 Checklist 11 项 + 文档卫生 + 新建前先想 + 多级记忆分层 L0-L4, 24h, P2, backend/docs, 8 票 ready 1 ticket 1 subagent 串行 (BE-14)** | 跟主公 2026-06-18 '需要都建卡并行处理' explicit 派单 联合 + 跟 v2.6.0 经验教训 整理 release 联合 + 跟 ~/.claude/knowledge/core/methodologies/borrowing-from-external.md 5 维评分 联合 + 跟"借方法论 不借代码" 联合 + 跟"反讽" + "翻篇&精进" + "反哺框架" 3 战略 联合 + 跟 EKET-BORROW-PROGRESS-2026-06-11.md 26 P0/P1/P2 联合 + 跟 v2.4.1 Rule 合并反思 联合 (治根 "Rule 数通胀" 迷信) + 跟 v2.4.0 反思 联合 (治根 "0 实际变化 假动作" 反讽) |
| **ACCUMULATED-LESSONS-2026-06-17** | confluence/decisions/ | **跨 PHASE 累计 v2.0.6 升级版 (531 行), 10 release + 13 BE + 18 卡 (14+4) + 5 治理卡 + 5 战略 + 4 工具 + 14 术语** | 跟 v2.0.3 + v2.0.5 ACCUMULATED-LESSONS 累计升级 + 跟"反哺框架" 战略 一致 |
| ACCUMULATED-LESSONS-2026-06-13 | confluence/decisions/ | 429 行 + 5 视角 + 4 共同根因 + 5 战略建议 | 跟"反讽" 联合 |
| PROJECT-STATUS-AND-LESSONS-2026-06-12 | confluence/decisions/ | 跟之前模式 一致 | 跟"反讽" 联合 |
| PROJECT-STATUS-AND-LESSONS-2026-06-13 | confluence/decisions/ | 跟之前模式 一致 | 跟"反讽" 联合 |
| PROJECT-STATUS-AND-LESSONS-2026-06-13 | . | 跟之前模式 一致 | 跟"反讽" 联合 |
| KALLAX-VS-INDUSTRY-REV2 | docs/ | 5+1 痛点 × 业内 4 框架 | 跟"反讽" 联合 |
| KALLAX-GLOSSARY.md | docs/ | 34 术语 (跟"反讽" 联合, 跟"诚实修正" 联合) | ✅ |
| 2026-06-14-kallax-onramp-design.md | docs/superpowers/specs/ | 391 行 KALLAX Onramp 完整 spec | 跟"反讽" 联合 |
| 2026-06-14-onramp-v1.3.1-fix.md | docs/superpowers/plans/ | 4-bug 修复 plan | 跟"反讽" 联合 |
| 2026-06-15-onramp-v1.3.3-cleanup.md | docs/superpowers/plans/ | 4-task 清理 plan | 跟"反讽" 联合 |

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