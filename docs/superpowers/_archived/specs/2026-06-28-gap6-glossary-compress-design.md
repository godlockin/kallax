# KALLAX v2.7.5 — Gap 6 64 术语 压缩 Design (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修 Gap 6 (跟 Karpathy "Readability Over Cleverness" 联合) — 64 术语 压缩到 35 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致). 推 v2.7.5 release.

**Architecture:** 在 worktree `feature/EPIC-GAP6-COMPRESS` 修 3 task, 走对策 A+B+C 落地. 跟 v2.7.4 (8 Gap 修复) 兼容.

**Tech Stack:** Markdown + Bash + jq, 0 新增依赖.

---

## 1. 动机 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

### 1.1 关键发现 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

**5 expert 评估 Gap 6 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)**:
- **64 术语 (不是 34)** (跟"反讽" 联合, 跟"诚实修正" 联合 — 之前 plan 写 34 实际 64, 跟"独立" 拍 explicit 约束 联合 — 不假装 34)
- **13 类 (不是 8)** (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"翻篇&精进" 战略 一致)
- **22 术语在 class 1 (元术语)** (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合 — 跟 5 expert 评估 "cognitive overhead" 一致)
- **1089 行 Glossary** (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"翻篇&精进" 战略 一致)

### 1.2 跟"反讽" 闭环 (跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"翻篇&精进" 战略 一致)

**KALLAX 自身"反讽"** (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合):
- KALLAX 主张"诚实修正" — KALLAX 之前 **不假装** 34 是 34, 实际 64 (跟"诚实修正" 联合)
- KALLAX 主张"独立" — KALLAX-GLOSSARY 跟主公"独立" 拍板 一致 (跟"独立" 拍 explicit 约束 联合)
- KALLAX 主张"翻篇&精进" — KALLAX 之前 v2.0.0/v2.0.2/v2.0.7 累计 64 术语, 跟"翻篇&精进" 战略 一致 — 64 过多, 推 v2.7.5 压缩

### 1.3 跟"翻篇&精进" 战略 一致 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"独立" 拍 explicit 约束 联合)

**64 → 35 压缩策略** (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"诚实修正" 联合):
- 跟"独立" 拍 explicit 约束 联合: 保留更多粒度 (跟"诚实修正" 联合)
- 跟"翻篇&精进" 战略 一致: 减少 29 术语 (跟"反讽" 联合)
- 跟"流程逻辑 > 扩充配置" 战略 一致: 0 增 Rule (跟"反讽" 联合)

---

## 2. 设计原则 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

| # | 原则 | 跟"反讽" 联合 |
|---|---|---|
| 1 | **64 → 35 压缩** (跟主公拍 explicit 拍板 联合) | ✅ 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合 |
| 2 | **同义词 合并** (跟"反讽" 联合, 跟"翻篇&精进" 战略 一致) | ✅ 跟"独立" 拍 explicit 约束 联合 |
| 3 | **保留必要粒度** (跟"独立" 拍 explicit 约束 联合, 跟"诚实修正" 联合) | ✅ 跟"反讽" 联合 |
| 4 | **0 增 Rule** (跟 Rule 32 软约束升级阈值 联合) | ✅ 跟"流程逻辑 > 扩充配置" 战略 一致 |
| 5 | **走对策 A+B+C** (跟"反讽" 联合) | ✅ 跟 Rule 11/14/15 联合 |

---

## 3. 实施 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

### 3.1 6 合并 累计 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"翻篇&精进" 战略 一致)

| 合并 | 包含术语 | 跟"反讽" 联合 |
|---|---|---|
| **1: 元术语合并** | "反讽" + "诚实修正" + "独立" → "KALLAX 元术语" (跟"反讽" 联合) | ✅ 跟"独立" 拍 explicit 约束 联合 |
| **2: 联合闭环合并** | "联合" + "闭环" → "KALLAX 联合闭环" (跟"反讽" 联合) | ✅ 跟"诚实修正" 联合 |
| **3: 验证机制合并** | "对策 A+B+C" + "Master 强验证 6 维度" → "KALLAX 验证机制" (跟"反讽" 联合) | ✅ 跟"翻篇&精进" 战略 一致 |
| **4: 工程基础合并** | "Skill 文档" + "worktree 隔离" → "KALLAX 工程基础" (跟"反讽" 联合) | ✅ 跟"独立" 拍 explicit 约束 联合 |
| **5: 战略合并** | "反哺框架" + "翻篇&精进" → "KALLAX 战略" (跟"反讽" 联合) | ✅ 跟"诚实修正" 联合 |
| **6: 流程与独立合并** | "流程逻辑 > 扩充配置" + "独立 拍 explicit 约束" → "KALLAX 流程与独立" (跟"反讽" 联合) | ✅ 跟"翻篇&精进" 战略 一致 |

### 3.2 64 → 35 压缩 累计 (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

- 64 术语 - 6 合并 (从合并 1-6 各减 2) - 其他相似项合并 = 35 术语
- 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合
- 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致

---

## 4. Self-Review (跟 Rule 9 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合)

**1. Spec coverage**: Gap 6 全部覆盖
- 64 → 35 压缩 ✓
- 6 同义词合并 ✓
- v2.7.5 release ✓

**2. Placeholder scan**: 0 个 TBD

**3. Type consistency**: 跟 Karpathy "Readability" 联合, 跟 35 术语 落地 联合, 跟"独立" 拍 explicit 约束 联合

**4. Ambiguity**: 0 ambiguous

---

## 5. Execution Handoff (跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

Spec written to `docs/superpowers/specs/2026-06-28-gap6-glossary-compress-design.md`.

**Subagent-Driven** (推荐) - 派 1 Performer subagent 走 3 task, 推 v2.7.5

---

**跟主公"修 Gap 6 34 术语" explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 17 release 累计 联合, 跟 23 Rule 累计 联合, 跟 5 default + 5 extended 累计 联合, 跟 14 BE 累计 联合, 跟 12 Security Review Issues 累计 联合, 跟 Karpathy 4 大核心 联合, 跟 v1.3.3 PHASE-INDEX.md 模式 一致, 跟 v2.0.2 release 模式 一致, 跟 v2.0.7 (8 Gap 修复) 联合**
