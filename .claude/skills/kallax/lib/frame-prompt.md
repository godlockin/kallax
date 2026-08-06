# Frame-based Task Classifier — LLM Prompt Template

> **EPIC-180-A**: `/kallax <任意诉求>` 入口先调 `scripts/frame-task.sh classify`, 输出 FRAME 表单 + score + 档位, 按 4 档路由执行.

## 何时调 frame-task

每条用户消息进来后, **第一时间** 跑:

```bash
bash scripts/frame-task.sh classify "<用户原话>"
```

框架会输出 6 字段预填 + 4 维评分 + 4 档判定 + 9 类破坏性检测.

## 4 档路由表

> 跟 `scripts/frame-task.sh` 阈值 1:1 同步 (0-10 scale, bash 整数算, 0-100 边界统一)

| 档位 | score (0-10) | 行为 | 模板输出 |
|------|-------|------|----------|
| **TRIVIAL** | < 2 | 1 行 diff preview → 直接做 | `[TRIVIAL] <1 句目标> + <1 行 diff>` |
| **SIMPLE** | 2-4 | 表单 1 句 → 直接做 | `[SIMPLE] 6 字段精简版` |
| **MEDIUM** | 5-7 | 表单 → 主公确认 → 做 | `[MEDIUM] 完整 6 字段 + score + 路径` |
| **COMPLEX** | ≥ 8 | 多轮问 + 表单 → 主公确认 → 做 | `[COMPLEX] partial + Q3-Q6 待澄清` |

## LLM 调用约定

`classify` 当前版本用 heuristic (regex + 计数) 给 stub, 后续替换为 LLM 调用时:

```python
# 伪代码 (EPIC-180-A.1 升级, 跟 0-10 scale 1:1 兼容)
def classify(user_msg: str, ctx: dict) -> FrameResult:
    prompt = render_template("frame-prompt.md", user_msg=user_msg, ctx=ctx)
    response = llm.complete(prompt, model="haiku", temperature=0)
    return parse_frame(response)
```

LLM 替换时必须保留 4 维评分公式 (跟 heuristic 1:1 兼容, 0-10 scale):
```
total = (4 * step_score + 3 * blast_score + 3 * (10 - ambiguity_score)) / 10
      + (risk_score > 5 ? 3 : 0)
# 输出 0-10 整数, 跟 SCORE_TRIVIAL=2 / MEDIUM=5 / COMPLEX=8 阈值对应
```

## 9 类破坏性操作 (跟 CLAUDE.md 联合)

无论档位, 检测到以下任一, **必停下问** (即使 SIMPLE 也要主公拍板):

| # | 模式 | 例 |
|---|------|----|
| 1 | 删文件 | `rm file`, `rm -rf dir`, `git rm file` |
| 2 | 危险 reset/checkout | `git reset --hard`, `git checkout -- file` |
| 3 | force push | `git push --force`, `--force-with-lease`, `-f` |
| 4 | rebase / no-ff merge | `git rebase`, `git merge --no-ff` |
| 5 | 主分支 push | (后续可加 branch allowlist 检测) |
| 6 | 公开化 | `README.md`, `CHANGELOG.md` (改) |
| 7 | Rule 改 | `CLAUDE.md`, `SKILL.md` (改) |
| 8 | immutable scripts | `check-decorative-claim.sh`, `check-narrative.sh`, `check-fail-closed.sh`, `check-self-heal.sh`, `check-claim-evidence.sh` |
| 9 | 网络发布 | `gh pr create`, `gh issue create`, `npm publish`, `docker push` |

## 跟 EPIC 体系联合

| EPIC | 联合点 |
|------|--------|
| EPIC-056-A | 3 阶段治理 — frame 是第 0 阶段 (进入判定) |
| EPIC-119 | 3-class 工具 — frame 输出指导 AUTO-PERMS 范围 |
| EPIC-059-D | Fact-Forcing — frame 输出必带 evidence 引用 |
| EPIC-177-G | run-history emit — frame 后 emit decision 事件到 run-history.jsonl |
| EPIC-074 | 4-branch — frame 触发 worktree + 4-PR 流程 |
| EPIC-180-A.1 | LLM 替换 v2 — heuristic → LLM 语义理解 (后续 ticket) |
| EPIC-187 | AUTO-PERMS 扩展 — git fetch/pull/log/diff 等 read-only 命令默认通过 |

## AUTO-PERMS 详细清单 (EPIC-187, 跟 SKILL.md 1:1)

> 跟 SKILL.md "AUTO-PERMS" 段同步, 0 改 source code, 0 增 Rule.

```
读 (read-only):
  Read, Glob, Grep, WebFetch, WebSearch
  Bash (cat, ls, jq, head, tail, wc, less, file, find, sort, uniq, awk, sed -n)

Git read-only:
  git fetch, git pull --ff-only, git log, git diff, git status, git show,
  git ls-files, git ls-remote, git rev-parse, git branch --list, git remote -v

Git 写非破坏 (feature/* 分支内):
  git add, git commit, git checkout (feature/*), git switch (feature/*),
  git branch (new), git worktree add/remove, git stash list/show/pop,
  git tag (annotated), git notes add

Bash 实用:
  mkdir, touch (空), chmod +x (脚本), cp, mv (跨 worktree),
  which, type, pwd, date, env, echo, printf

GitHub 查询 (GET only):
  gh pr view / list / status / checks / diff / api
  gh issue view / list / status
  gh repo view

写非破坏:
  Write, Edit, NotebookEdit, MultiEdit

跳过的网络发布 (9 类 #9):
  gh pr create / merge, gh issue create, npm publish, docker push
```

## 跟 Rule 联合 (0 增)

| Rule | 联合 |
|------|------|
| Rule 4 (4-branch) | frame 触发 worktree 创建 + 4-PR wrapper |
| Rule 5 (DRY) | frame 表单模板复用, 0 重写 |
| Rule 9 (KPI X/Y) | frame 输出 self-test PASS 格式 |
| Rule 13 (decision-gate) | 9 类破坏性 → 触发 ASK |

## 模板版本

- v1 (2026-08-06): 初始 heuristic 版本, 4 档 (0-10 scale, 阈值 2/5/8) + 9 类 + 10 自测用例 + 21 集成断言
- v2 (EPIC-180-A.1): LLM 语义理解替换 heuristic (跟 0-10 scale 公式 1:1 兼容)