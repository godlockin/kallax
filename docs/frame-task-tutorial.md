# KALLAX Frame-Task Tutorial — 智能路由使用指南

> **EPIC-189**: frame-task 实战教程 (跟 EPIC-180-A 联合, 跟 EPIC-187 AUTO-PERMS 联合)
> **作者**: KALLAX team
> **日期**: 2026-08-07
> **版本**: v3.34.1 (跟 miao)

## 是什么

`frame-task.sh` 是 KALLAX 智能路由引擎。每条用户诉求进来时, **第一时间** 跑 `classify` 输出 FRAME 表单 (Q1-Q6 + 4 维评分 + 4 档判定 + 9 类破坏性拦)。

## 4 档路由

| 档位 | score | 行为 | 主公介入 |
|------|-------|------|----------|
| **TRIVIAL** | < 2 | 1 行 diff preview → **直接做** | 0 阻塞 |
| **SIMPLE** | 2-4 | 表单 1 句 → **直接做** | 0 阻塞 |
| **MEDIUM** | 5-7 | 表单 → **主公确认** → 做 | 1 次 |
| **COMPLEX** | ≥ 8 | partial/answer/complete 多轮 → **主公确认** → 做 | 多轮澄清 |

## 6 字段 (FRAME 表单)

每个诉求必填 6 字段:

1. **Q1. 目标** — 1 句明确目标
2. **Q2. 输入/上下文** — 依赖的现状/前置条件
3. **Q3. 输出/交付** — 产出物 / 验收标准
4. **Q4. 边界** — 涉及文件/EPIC/分支清单
5. **Q5. 约束** — Rule / 不变量 / 兼容性
6. **Q6. 风险** — 破坏性/数据丢失/公开影响

## 4 维评分

```bash
total = (4 * step_score + 3 * blast_score + 3 * (10 - ambiguity_score)) / 10
      + (risk_score > 5 ? 3 : 0)
# 0-10 scale, 跟阈值 2/5/8 对应
```

- **step_score** (0-10): 多步骤数
- **blast_score** (0-10): 涉及模块数
- **ambiguity_score** (0-10): 模糊度
- **risk_score** (0-10): 风险度 (>5 加 +3)

## 9 类破坏性 (无论档位, 默认问)

| # | 模式 | 例子 |
|---|------|------|
| 1 | 删文件 | `rm file`, `rm -rf dir`, `git rm file` |
| 2 | 危险 reset/checkout | `git reset --hard`, `git checkout -- file` |
| 3 | force push | `git push --force`, `--force-with-lease`, `-f` |
| 4 | rebase / no-ff merge | `git rebase`, `git merge --no-ff` |
| 5 | 主分支 push | (后续扩) |
| 6 | 公开化 | `README.md`, `CHANGELOG.md` 改 |
| 7 | Rule 改 | `CLAUDE.md`, `SKILL.md` 改 |
| 8 | immutable scripts | 5 个 verify + 1 hook |
| 9 | 网络发布 | `gh pr create`, `npm publish`, `docker push` |

## 用法

### 1. classify

```bash
bash scripts/frame-task.sh classify "<user_msg>"
# 输出 FRAME 表单 + 4 维评分 + 4 档判定 + 9 类 BLOCKED-OPS
```

### 2. check-blocked

```bash
bash scripts/frame-task.sh check-blocked "<cmd>"
# exit=0 (PASS) / exit=1 (BLOCKED, 含破坏性操作)
```

### 3. partial (Round 1, COMPLEX 档)

```bash
bash scripts/frame-task.sh partial "设计 X 系统" --field Q3 --field Q4
# 输出 PARTIAL FRAME 待澄清模板
```

### 4. answer (Round 2+, 主公澄清)

```bash
bash scripts/frame-task.sh answer /tmp/state \
  --field Q3 "API 输出 JSON" \
  --field Q4 "scripts/api/*.sh"
# 输出 ANSWER MERGED + 重评分
```

### 5. complete (终态)

```bash
bash scripts/frame-task.sh complete /tmp/state
# 输出 COMPLETE FRAME → AUTO-PERMS 触发 → 直接执行
```

### 6. self-test

```bash
bash scripts/frame-task.sh --self-test
# 10/10 PASS
```

## AUTO-PERMS (EPIC-187 扩展)

不需要问的命令 (0 阻塞):

**Git read-only**: `git fetch` / `git pull --ff-only` / `git log` / `git diff` / `git status` / `git show` / `git ls-files` / `git ls-remote`

**Bash read-only**: `head` / `tail` / `wc` / `jq` / `find` / `sort` / `uniq` / `awk`

**Bash 实用**: `mkdir` / `touch` / `chmod +x` / `cp` / `mv`

**GitHub GET**: `gh pr view/list` / `gh issue list` / `gh repo view`

## 实战示例

### Demo 1: SIMPLE 档 (查)

```bash
$ bash scripts/frame-task.sh classify "EPIC-161 是什么"

┌─ FRAME: EPIC-161 是什么 ─────────────────────────┐
│ Q1. 目标        : EPIC-161 是什么
│ Q2. 输入/上下文  : 已知 EPIC 上下文
│ Q3. 输出/交付   : 信息回答 (1 段)
│ Q4. 边界        : 文件: 未明确
│ Q5. 约束        : 默认 Rule 5+9+4
│ Q6. 风险        : none
│
│ SCORE:
│   - 多步骤:  1/10
│   - blast:   1/10
│   - 模糊度:  4/10
│   - 风险:    1/10
│   - 总分:    2 → SIMPLE 档
│
│ BLOCKED-OPS: none
```

### Demo 2: 9 类破坏性拦

```bash
$ bash scripts/frame-task.sh check-blocked "rm -rf /tmp/test"
BLOCKED: 检测到破坏性操作: \brm\s+...
exit=1

$ bash scripts/frame-task.sh check-blocked "git fetch origin miao"
PASS: 0 破坏性操作
exit=0
```

### Demo 3: COMPLEX 档多轮澄清

```bash
$ bash scripts/frame-task.sh classify "4-PR 错乱 彻查然后出根因然后写follow-up EPIC-179然后落地再跑测试 涉及 scripts/branch-4pr.sh 和 CLAUDE.md"
# 总分 35 → COMPLEX 档

$ bash scripts/frame-task.sh partial "4-PR 错乱彻查" --field Q3 --field Q4
# Round 1: PARTIAL FRAME

$ bash scripts/frame-task.sh answer /tmp/state --field Q3 "根因报告" --field Q4 "scripts/branch-4pr.sh"
# Round 2: ANSWER MERGED

$ bash scripts/frame-task.sh complete /tmp/state
# Round N: COMPLETE FRAME → 直接执行
```

## 联动 EPIC

- EPIC-056-A — 3 阶段治理 (frame 是 Phase 0 入口)
- EPIC-119 — 3-class 工具 (frame 输出指导 AUTO-PERMS)
- EPIC-059-D — Fact-Forcing (frame 输出必带 evidence)
- EPIC-177-G — run-history emit (frame 后 emit decision)
- EPIC-074 — 4-branch flow (frame 触发 worktree + 4-PR)
- EPIC-181 — wrapper 硬化 (跟 frame 联合)
- EPIC-187 — AUTO-PERMS 扩展 (跟 frame check-blocked 联合)

## 详细文档

- `lib/frame-prompt.md` — LLM 替换模板 (v2)
- `SKILL.md` — KALLAX skill 入口
- `branch-4pr.sh` — 4-PR wrapper (跟 frame 联合)
- `retrospective-routine.sh` — 6 阶段复盘 (跟 EPIC-188)