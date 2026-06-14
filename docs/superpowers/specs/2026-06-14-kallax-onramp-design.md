# KALLAX Onramp Design — 多层次项目分析器 (v1.3.0)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 1 个 `/kallax-onramp` 命令, 按"项目现状 + 目标 + ROI"自动推荐 3 深度专家组组合, 主公可确认 / 调整 / 自选, 输出 Markdown 报告 + audit log.

**Architecture:** 单脚本入口 + 4 步数据流 (Scan → Assess → Route → Output). 复用现有 5 default + 5 extended = 10 skill 文档, 0 重写. 1 LLM 预审 + 1 LLM 召唤 = 2 次调用, 0 误判 (heuristic 兜底).

**Tech Stack:** Bash + jq + git, 0 新增依赖. 跟 KALLAX v1.2.4 (miao HEAD 5192c79) 兼容.

**跟"召唤合适专家" 拍 explicit 约束 联合:** 主公拍"根据项目现状和我的目标进行不同层次的分析".

---

## 1. 动机 (Motivation) — 跟"反讽" 闭环

主公当前痛点 (2026-06-14):
- 主公/Conductor 进入新项目时, 5min 理解 + 30min 出 EPIC 拆解建议, 散落 30+ 命令中 (`kallax-analyze` / `kallax-ask` / `kallax-phase-review`), **没有统一入口**.
- **没有"项目维度" onramp** (区别于"session 维度" init).
- **没有"按场景路由"逻辑** (overview/audit/refactor/new-epic/handoff).
- **5 扩展组专家 (security + process-engineering + auditor + compliance + decision-gate) 还没接进 panel**, 主公不知道什么时候该召.
- **没有"亮点/缺点/隐患" 抽取的 guidance 工作流**, 跟"guidance 用来指导其他项目" 拍 explicit 约束 联合.

**反讽** (跟 5 战略建议 5.2 反讽 联合):
- KALLAX 体系已经 23 Rule + 5 default + 5 extended + 5 release + 15 BE 累计.
- 但"项目初始化/接手" 这条路径还是空白.
- 不落地, KALLAX 仍是"内部流程优化" 工具, 不是"项目全生命周期" 工具.

---

## 2. 设计原则 (跟"反讽" 闭环, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"目标专家" 拍 explicit 约束 联合)

| # | 原则 | 跟"反讽" 联合 |
|---|---|---|
| 1 | **1 入口** (1 个 `/kallax-onramp` 命令) | ✅ 跟 Rule 32 软约束升级阈值 联合, 不增加 Rule |
| 2 | **不增加 Rule** (跟 v1.2.4 23 Rule 联合) | ✅ 跟"反讽" 闭环, 跟 Rule 32 联合 |
| 3 | **0 重写** (复用 5 default + 5 extended skill 文档) | ✅ 跟 Rule 5 DRY 联合 |
| 4 | **2 次 LLM** (1 预审 + 1 召唤) | ✅ 跟"决策疲劳" 反讽 联合, 跟"Token 限撞墙" 联合 |
| 5 | **路由器主动给方案** (不是被问"你想要什么") | ✅ 跟"决策疲劳" 联合, 跟 Rule 33 联合 |
| 6 | **引导式而非关键词** (主公说"调整" 才再问 1 个) | ✅ 跟主公"引导式" 拍 explicit 约束 联合 |
| 7 | **3 深度按 ROI 调权** (ROI 高 → 推荐 5+5) | ✅ 跟"ROI 评估" 拍 explicit 约束 联合 |
| 8 | **L3 强制抽 3 件套** (亮点/缺点/隐患) | ✅ 跟主公"guidance" 拍 explicit 约束 联合 |
| 9 | **降级而非崩溃** (3/5/7 错误走 partial success) | ✅ 跟 Rule 3 联合, 跟"反讽" 闭环 |
| 10 | **audit log 必写** (跟 Rule 31 不可篡改 联合) | ✅ 跟"独立" 拍 explicit 约束 联合 |

---

## 3. 架构 (Architecture)

```
┌─────────────────────────────────────────────────────┐
│ User: /kallax-onramp "/path/to/project <需求>"      │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ scripts/kallax-onramp.sh                            │
│ ┌─────────────┐ ┌──────────────┐ ┌──────────────┐   │
│ │ Step 1: Scan│→│ Step 2: Ask  │→│ Step 3: Route│   │
│ │ (3-5 min)   │ │ (1-2 Q)      │ │ (3 depth)    │   │
│ └─────────────┘ └──────────────┘ └──────────────┘   │
│                       ↓                              │
│              ┌─────────────────┐                     │
│              │ Step 4: Output  │                     │
│              │ Markdown Report │                     │
│              └─────────────────┘                     │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ 5 default + 5 extended skills (trigger on-demand)    │
│ L1: 1 Architect  L2: 5 default  L3: 5+5 = 10         │
└─────────────────────────────────────────────────────┘
                       ↓
docs/analysis/ONRAMP-<project>-<date>.md
```

**4 步数据流** (跟 Rule 16/17 联合, 跟"反讽" 闭环, 跟"独立" 拍 explicit 约束 联合):
1. **Step 1 扫描**: 1a shell (0 LLM) + 1b LLM 预审 (1 调用)
2. **Step 2 引导**: 路由器主动给 2 推荐方案 + 1 自选 fallback (0/1 LLM)
3. **Step 3 路由**: 按主公选召 1 / 5 / 10 专家 (1 LLM)
4. **Step 4 输出**: Markdown 报告 + audit log

---

## 4. 组件 (Components) — 跟 Rule 5 DRY 联合, 跟"反讽" 闭环

```
scripts/kallax-onramp.sh                  ← 主入口 (1 文件)
├── lib/
│   ├── scan.sh                            ← Step 1a 扫描 (0 LLM)
│   ├── pre-assess.sh                      ← Step 1b LLM 预审
│   ├── recommend.sh                       ← Stage 1 自动推荐 (heuristic)
│   ├── route.sh                           ← Stage 2 展示 + Stage 3 确认/调整
│   └── output.sh                          ← Step 4 Markdown 输出
├── templates/
│   ├── L1-light.md                        ← 200-400 字符总结
│   ├── L2-deep.md                         ← 详细拆解 + EPIC 建议
│   └── L3-audit.md                        ← 5+5 = 10 视角 + 3 件套 (亮点/缺点/隐患)
└── tests/
    └── onramp-test.sh                     ← 4-Level 集成测试
```

**7 文件结构** (跟"反讽" 闭环, 跟"流程逻辑" 战略 一致, 跟"流程逻辑 > 扩充配置" 联合):
- **1 主入口** `kallax-onramp.sh` (跟 23 Rule 不增加, 跟"反讽" 闭环)
- **4 lib** 拆分 (单一职责, 易测试, 跟 Rule 5 DRY 联合)
- **3 模板** 按 3 深度 (跟"目标专家" 拍 explicit 约束 联合)
- **1 集成测试** 4-Level (跟 Rule 9 Fact-Forcing 联合, 跟 Rule 16 5 步强制流程 联合)

**关键复用** (跟"反讽" 闭环, 跟"流程逻辑" 战略 一致):
- L2 复用 `/kallax-panel` 已有的 5 default 调度 (跟"反讽" 联合 — 0 重写)
- L3 复用 5 扩展组 skill 文档 (跟"反讽" 联合 — 已落地)
- Step 1a 复用 `git status` / `wc -l` 纯 shell (跟"反讽" 联合 — 0 LLM 浪费)

**输出位置** (跟"流程逻辑" 战略 一致):
- `docs/analysis/ONRAMP-<project>-<date>.md` (跟现有 4 文档 REV2 模式 一致)

---

## 5. 数据流 (Data Flow) — 跟"反讽" 闭环, 跟"独立" 拍 explicit 约束 联合

### 5.1 Step 1a: scan.sh (0 LLM, < 1 min)

**Input**: `$1` (project path)

**Output**: `scan.json`
```json
{
  "project": "kallax",
  "loc": 45230,
  "files": 287,
  "modules": 5,
  "has_claude_md": true,
  "has_readme": true,
  "git_log_days": 14,
  "language_mix": "TS:60,Shell:30,MD:10",
  "smell_indicators": ["no_tests", "many_scripts"]
}
```

### 5.2 Step 1b: pre-assess.sh (1 LLM 调用, 30s-1min)

**Input**: `scan.json`

**Prompt** (跟"ROI 评估" 拍 explicit 约束 联合):
```
基于以下项目扫描数据, 评估 4 维度:
1. 规模: small (<5k LOC) / medium (5k-50k) / large (50k-500k) / huge (>500k)
2. 领域: backend / frontend / fullstack / ml / data / infra / mixed
3. 研究价值: low / medium / high / critical
   (是否值得抽"亮点/缺点/隐患"guidance 供其他项目复用)
4. ROI: 1-5 星
   (按主公需求"<user_need>", 评估深入分析的回报)

输出 JSON: { scale, domain, research_value, roi, rationale }
```

**Output**: `pre-assess.json`
```json
{
  "scale": "medium",
  "domain": "backend",
  "research_value": "high",
  "roi": 4,
  "rationale": "KALLAX 多 Agent 框架, 含 23 Rule + 5 default + 5 extended, 值得抽亮点/缺点"
}
```

### 5.3 Stage 1: recommend.sh (heuristic, 0 LLM)

**Input**: `scan.json` + `pre-assess.json`

**Logic** (跟"ROI 评估" 拍 explicit 约束 联合):
```bash
if roi >= 4 && research_value in {high, critical}; then
  recommend_c = "5+5 = 10 专家 (完整审计 + 3 件套)"
elif roi >= 3; then
  recommend_b = "3-5 专家 (深入研究, 按 smell 选)"
else
  recommend_a = "1 Architect (简单分析)"
fi
```

**Fallback** (跟 Rule 3 联合, 跟"反讽" 闭环):
- 若 `pre-assess.json` 不存在 (Step 1b 失败), 用 `scan.json` 单独跑 heuristic.
- 若两者都失败, 默认推荐 A.

### 5.4 Stage 2 + 3: route.sh (跟"决策疲劳" 反讽 联合, 跟 Rule 33 联合)

**Stage 2 展示** (默认 0 问):
```
📊 项目扫描结果: 中型, 10k LOC, 多模块, 含 1 安全痛点
ROI: ⭐⭐⭐⭐ (4/5), 研究价值: high

推荐方案:
A. 简单分析 (1 单专家)
   - 🏗️ Architect (架构 + 模块边界)

B. 深入研究 (推荐 5 专家组合)
   - 🏗️ Architect (架构 + 模块边界)
   - 💻 Backend (API + 数据库)
   - 🛡️ Security (痛点修复)
   - ⚙️ Process-Engineering (流程审视)
   - 🔍 Auditor (合规审计)

[C] 自定义: 你来选 (single / combination / 全组 5+5)

确认召唤? (y/n/调整/C)
```

**Stage 3 处理**:
| 主公回复 | 动作 | 跟"反讽" 联合 |
|---|---|---|
| `A` / `B` / `y` | 召唤推荐方案 | ✅ |
| `n` / 取消 | 0 副作用, exit 0 | ✅ 跟 Rule 17 联合 |
| `C` | 进入"自选"模式, 引导 1-2 问 | ✅ 跟"目标专家" 拍 explicit 约束 联合 |
| `调整` | 路由器再 1 问 (专家组侧重哪方面) | ✅ 跟 Rule 33 联合 |

**关键 UX** (跟"反讽" 联合):
- 默认 0 问题 (Stage 1 自动判断)
- 主公说"调整" 才问 1 个 (Stage 3 fallback)
- 主公说"自选" 才进入引导 (Stage 3 终态)

### 5.5 Step 3: 召唤专家 (跟 Rule 5 DRY 联合, 跟"反讽" 闭环)

| 深度 | 专家数 | 调用方式 | 跟"反讽" 联合 |
|---|---|---|---|
| **L1** | 1 Architect | call `.claude/skills/kallax/default/architect.md` | ✅ 复用 |
| **L2** | 5 default | call `.claude/skills/kallax/default/{architect,backend,frontend,ux,product}.md` | ✅ 复用 `/kallax-panel` |
| **L3** | 5+5 = 10 | call `.claude/skills/kallax/default/*.md` + `.claude/skills/kallax/extended/*.md` | ✅ 复用 5 扩展组 skill |

**L3 3 件套** (跟"guidance" 拍 explicit 约束 联合):
- **亮点** (可复用): 5 default + 5 extended 各提 1-2 个, 去重合并
- **缺点** (需修): 同上
- **隐患** (需防): 同上

### 5.6 Step 4: output.sh (跟 Rule 31 联合, 跟"反讽" 闭环)

**Output**: `docs/analysis/ONRAMP-<project>-<date>.md`

**Template rendering** (跟 3 深度对齐):
- L1 → `templates/L1-light.md` (200-400 字符)
- L2 → `templates/L2-deep.md` (详细拆解 + EPIC 建议)
- L3 → `templates/L3-audit.md` (5+5 = 10 视角 + 3 件套)

**Side effects** (跟 Rule 31 联合):
- 写 audit log: `.kallax/logs/onramp-YYYY-MM-DD.jsonl`
- 不可篡改 (BE-7 修复模式 umask 077 + install -d -m 700 + flock + atomic write + chmod 600)

**Atomic write** (跟 Rule 17 联合):
- 写 `/tmp/ONRAMP-<project>-<date>.md.tmp.<pid>` → atomic mv 到 final
- 失败保留 tmp, 主公可手动恢复

---

## 6. 错误处理 (Error Handling) — 跟"反讽" 闭环, 跟 Rule 3/4/16/17/31 联合, 跟"独立" 拍 explicit 约束 联合

| # | 错误类目 | 处理 | 跟"反讽" 联合 |
|---|---|---|---|
| 1 | 路径错误 | exit 2 + stderr "ERROR: path not accessible" | ✅ 跟 Rule 4 Fail Fast 联合 |
| 2 | 扫描失败 (无 git / 无 README) | exit 3 + stderr "ERROR: not a git repo" | ✅ 跟 Rule 4 联合 |
| 3 | LLM 预审失败 | 降级到纯 shell 推荐 | ✅ 跟"反讽" 联合 |
| 4 | 路由用户取消 | 0 副作用, exit 0, 清理 tmp | ✅ 跟 Rule 17 联合 |
| 5 | 专家召唤失败 (1 个 N-1 降级) | 降级到 N-1 专家, 不重试 | ✅ 跟"反讽" 联合 |
| 6 | 输出写失败 | 临时目录 + atomic mv | ✅ 跟 Rule 17 联合 |
| 7 | 审计日志失败 | 不影响主流程, stderr WARN | ✅ 跟 Rule 31 联合 |

**关键设计** (跟"反讽" 闭环):
- **3 降级路径** (3/5/7): 都不崩溃, 走 partial success
- **2 启动错** (1/2): Fail Fast, 立刻退出
- **1 取消** (4): 0 副作用, 干净退出
- **1 atomic** (6): 跟 Rule 17 一致

---

## 7. 测试策略 (Testing) — 跟"反讽" 闭环, 跟 Rule 9 4-Level Fact-Forcing 联合

### 7.1 L1 存在性
- 7 文件存在: `scripts/kallax-onramp.sh` + `lib/4` + `templates/3` + `tests/1`
- `tests/onramp-test.sh` 必跑
- 跟"反讽" 闭环 (不靠"应该没问题")

### 7.2 L2 实质性
- 1 集成测试覆盖 3 深度 + 2 引导路径 + 7 错误类目
- mock LLM 调用 (可重复, 不靠真实 API)
- 跟"反讽" 闭环 (不靠"看起来对")

### 7.3 L3 接线正确
- `/kallax-onramp` → `scripts/kallax-onramp.sh` 真连上
- lib/4 + templates/3 真 import
- 5 default + 5 extended skill 真引用
- 跟"反讽" 闭环 (不靠"应该连上了")

### 7.4 L4 数据流动
- 真实跑 1 个 demo project (e.g. mini-kallax 10 LOC)
- 验证输出: `scan.json` + `pre-assess.json` + `onramp.md`
- 验证 audit log 写入
- 跟"反讽" 闭环 (不靠"应该输出了")

### 7.5 测试 fixtures (跟"反讽" 闭环, 跟 Rule 9 联合)
- `tests/fixtures/mini-kallax/` (10 LOC demo project)
- `tests/fixtures/medium-project/` (5k LOC)
- `tests/fixtures/large-project/` (50k+ LOC)

### 7.6 关键测试场景 (跟"反讽" 联合)
- 3 深度各跑 1 次 (L1/L2/L3)
- 2 引导路径各跑 1 次 (确认 / 自选)
- 7 错误类目各跑 1 次 (注入错路径, 注入错 git, mock LLM fail 等)

---

## 8. 落地计划 (Implementation Plan) — 跟"反讽" 闭环, 跟"流程逻辑" 战略 一致

| Task | 描述 | 估时 | 跟"反讽" 联合 |
|---|---|---|---|
| **T1** | 写 skeleton (kallax-onramp.sh + 4 lib + 7 占位) | 0.5h | ✅ 骨架先落地, 后填 |
| **T2** | Step 1a shell 扫描 + scan.json + 1 测试 | 0.5h | ✅ 0 LLM 浪费 |
| **T3** | Step 1b LLM 预审 + Stage 1 heuristic | 1h | ✅ 跟"ROI 评估" 拍 explicit 约束 联合 |
| **T4** | Stage 2 + 3 路由器 (引导 + 确认/调整) | 1h | ✅ 跟"决策疲劳" 反讽 联合, 跟 Rule 33 联合 |
| **T5** | Step 3 召唤专家 (复用 skill 文档) | 1h | ✅ 跟 Rule 5 DRY 联合, 0 重写 |
| **T6** | Step 4 输出 (3 模板 + audit log) | 1h | ✅ 跟 Rule 31 联合 |
| **T7** | 4-Level 测试 + 3 fixtures | 1h | ✅ 跟 Rule 9 联合 |
| **总计** | **6h, 7 Task, 1 Performer (跟 1+2/1+4 容量 联合)** | **6h** | ✅ 跟"反讽" 闭环 |

**关键设计** (跟"反讽" 闭环):
- **6h 总计** (跟 1+2/1+4 容量 联合, 跟 1 Performer 4-6h 真实开发 联合)
- **1 Performer 1 worktree** (跟 Rule 15 subagent 第一条 联合)
- **不增加 Rule** (跟 Rule 32 软约束升级阈值 联合, 跟"反讽" 闭环)
- **落地推 v1.3.0** (跟 5 release 累计 联合, 跟"反哺框架" 战略 一致)

**执行**:
- 派 1 Performer subagent 走 Rule 16 5 步强制流程
- Performer 必跑对策 A (subagent-pass-gate) + 对策 B (conductor-receive-gate) + 对策 C (Master 强验证 6 维度)
- 跟"独立" 拍 explicit 约束 联合

---

## 9. 验收标准 (Acceptance Criteria)

- [ ] 7 文件落地 (1 主入口 + 4 lib + 3 templates + 1 tests)
- [ ] 3 深度各跑通 1 个 demo project
- [ ] 2 引导路径 (确认 / 自选) 跑通
- [ ] 7 错误类目各跑 1 次测试
- [ ] audit log 必写 (跟 Rule 31 联合)
- [ ] Master 强验证 6 维度全 PASS (跟 Rule 11 v2.1 联合)
- [ ] 落地推 v1.3.0 (跟 5 release 累计 联合)

---

## 10. 跟"反讽" 闭环 (跟"目标专家" 拍 explicit 约束 联合, 跟"独立" 拍 explicit 约束 联合, 跟"流程逻辑 > 扩充配置" 战略 一致)

| 反讽点 | 应对 | 跟"反讽" 联合 |
|---|---|---|
| 23 Rule 升级率 100% | 不增加 Rule (1 入口复用现有) | ✅ 跟 Rule 32 联合 |
| 5+5 = 10 专家可能假 PASS | 走对策 A+B+C, Master 强验证 6 维度 | ✅ 跟"反讽" 联合 |
| Token 限撞墙 | 2 次 LLM 调用, 0 误判 (heuristic 兜底) | ✅ 跟"反讽" 联合 |
| 决策疲劳 | 默认 0 问, 路由器主动给方案 | ✅ 跟 Rule 33 联合 |
| 5 default + 5 extended 没人接 | 0 重写, 复用 skill 文档 | ✅ 跟 Rule 5 DRY 联合 |
| "亮点/缺点/隐患" guidance 工作流缺失 | L3 强制抽 3 件套 | ✅ 跟"guidance" 拍 explicit 约束 联合 |

**跟"独立" 拍 explicit 约束 联合**:
- 1 入口 / 1 路由器 / 3 模板 (跟 23 Rule 不增加, 跟"反讽" 闭环)
- 5+5 = 10 专家复用 (跟 Rule 5 DRY 联合, 跟"反讽" 联合)
- audit log 必写 (跟 Rule 31 联合, 跟"独立" 拍 explicit 约束 联合)

---

## 11. 后续迭代 (Future Iterations)

| 迭代 | 内容 | 跟"反讽" 联合 |
|---|---|---|
| v1.4.0 | 跟其他工具集成 (e.g. git worktree / gh CLI) | ✅ 跟"反讽" 联合 |
| v1.5.0 | 跨项目 guidance 知识库 (跟 L0-L4 分层 联合) | ✅ 跟"反讽" 联合 |
| v2.0.0 | 主动 onramp (监听 git clone 自动触发) | ✅ 跟"反讽" 联合 |

---

## 12. 总结 (跟"反讽" 闭环, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"目标专家" 拍 explicit 约束 联合)

**KALLAX Onramp** = 1 入口 + 1 路由器 + 3 深度 + 2 次 LLM + 0 Rule + 0 重写.

**核心价值** (跟"反讽" 联合, 跟"目标专家" 拍 explicit 约束 联合):
- 主公 5min 理解 + 30min 出 EPIC 拆解建议 (vs 当前散落 30+ 命令)
- 自动按 ROI 调权 (高 ROI → 5+5 = 10 专家, 低 ROI → 1 Architect)
- L3 强制抽 3 件套 (亮点/缺点/隐患) → guidance 复用
- 跟现有 5 default + 5 extended skill 文档无缝集成
- 不增加 Rule, 不增加 LLM 调用, 不增加复杂度

**落地推 v1.3.0** (跟 5 release 累计 联合, 跟"反哺框架" 战略 一致).

---

**跟主公"同意" explicit 授权 联合, 跟"反讽" 闭环, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟"目标专家" 拍 explicit 约束 联合, 跟"独立" 拍 explicit 约束 联合, 跟"ROI 评估" 拍 explicit 约束 联合, 跟"guidance" 拍 explicit 约束 联合, 跟 5 release 累计 联合, 跟 23 Rule 累计 联合, 跟 5 default + 5 extended 累计 联合, 跟 Rule 9 4-Level Fact-Forcing 联合, 跟 Rule 11 v2.1 Master 强验证 6 维度 联合, 跟 Rule 16 5 步强制流程 联合, 跟 Rule 31 不可篡改 audit log 联合, 跟 Rule 32 软约束升级阈值 联合, 跟 Rule 33 复杂才问 联合, 跟"决策疲劳" 反讽 联合, 跟"反讽" 闭环**
