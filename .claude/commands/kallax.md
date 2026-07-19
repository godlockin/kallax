---
description: Smart router entry — `/kallax <任意诉求>` 一键入口,框架自动把诉求路由到合适的 sub-command。命令全表: init / start / status / help / expert / panel / list / task / claim / submit-pr / review-pr / verify-pr / merge / save / resume / board / instances / check-progress / phase-review / ask / skill / analyze / office-hours / onramp / takeover / mode / role / load / route. 判定方法: 看用户诉求最像哪个 → 直接以 `/kallax-<subcmd> <args>` 形式执行,并在开头打印一行 `🔀 routed: /kallax-<subcmd>` 让主公看到路由结果。无参数时跑 `/kallax-help`。
argument-hint: "[query] — free-form, framework will route"
---

# /kallax — Smart Router Entry

## 你的角色

**主公输入 `/kallax <任意内容>` 时**, 你**不要立刻自己回答**, 而是:

1. **判定诉求 → 路由到 sub-command**
2. **打印路由说明** (`🔀 routed: /kallax-<subcmd>`)
3. **按 sub-command 的 SKILL.md / 命令文件执行**

## 路由表 (主公诉求 → sub-command)

主公诉求可能用**任意措辞**, 下面的映射是**语义等价**不是字面匹配:

| 主公在说... | 路由到 | 备注 |
|------|------|------|
| 状态 / 进度 / 现在怎么样 / 还有几个 ticket | `/kallax-status` | |
| 帮助 / 命令 / 怎么用 / 命令列表 | `/kallax-help` | |
| 初始化 / 启动 / 接入 / 进入工作 | `/kallax-start` | 自动选 role |
| 我是 master / 我是 conductor / 我是 performer | `/kallax-mode` + role | |
| 切角色 / 切换到... / 我现在是... | `/kallax-role` | |
| 召唤 <role> / 找专家 / 问 <role> / 让 <role> 看看 | `/kallax-expert <role> <context>` | role 从上下文抽 |
| 召唤面板 / 全面评审 / 4 个专家 / 9 专家 | `/kallax-panel <topic>` | |
| 问个问题 / 问专家们 / panel 问 | `/kallax-ask <q>` | |
| 跑 <skill> / 执行 <skill> | `/kallax-skill <name> [target]` | |
| ticket / 认领 / 接活 / 干活 | `/kallax-claim [TASK_ID]` | 有 ID 才带 |
| 提交 / 完工 / 提 PR / 提了 | `/kallax-submit-pr [TASK_ID]` | |
| 验 PR / 验输出 / 5 级验证 | `/kallax-verify-pr [PR_NUMBER]` | |
| 评审 PR / 评论 PR | `/kallax-review-pr [PR_NUMBER] [BASE]` | |
| 合并 / merge / 收 PR | `/kallax-merge [PR]` | |
| 看板 / board / 总览图 | `/kallax-board` | |
| 实例 / instance / 谁在线 | `/kallax-instances` | |
| 阶段复盘 / EPIC 闭环 / PHASE review | `/kallax-phase-review <PHASE\|EPIC>` | |
| 分析 / 分析项目 / 看看结构 | `/kallax-analyze [TARGET]` | |
| 需求分析 / 6 问 / office hours | `/kallax-office-hours <TOPIC>` | |
| 接入 / onramp / 新项目 | `/kallax-onramp <path> <need>` | |
| 中期接管 / takeover / 现状 | `/kallax-takeover <path> <need>` | |
| 保存 / save / 存档 | `/kallax-save` | |
| 恢复 / resume / 接着干 | `/kallax-resume` | |
| load / 加载 | `/kallax-load [target]` | |
| route / 路由 | `/kallax-route` | 调试路由 |

## 路由失败防范 (主公 "parameters error" 的 6 大元凶)

LLM 路由时,**不要瞎猜 enum / 必填参数**。下表列每个 sub-command 的必填 + enum:

| Sub-command | Args 必填? | Enum / 约束 | 瞎路由会怎样 |
|---|---|---|---|
| `init` | 0 | (无) | — |
| `start` | 0/1 | role: `master\|conductor\|performer` | 不传 prompt |
| `status` | 0 | — | — |
| `help` | 0 | — | — |
| `expert` | **1** | `<role>` (e.g. backend/architect/security) | 无 role 走 list fallback 不报错 |
| `panel` | 0/1 | `[TOPIC]` | 无 topic 自动 show help |
| `list` | 0 | — | — |
| `task` | 0/1 | `[action TASK_ID]`, action ∈ {claim/complete/status/list} | 无效 action 报错 |
| `claim` | 0/1 | `[TASK_ID]` | 无 ID auto-claim |
| `submit-pr` | 0/1 | `[TASK_ID]` | 无 ID 从 branch 自动推 |
| `review-pr` | 0/1/2 | `[PR_NUMBER] [BASE_BRANCH]` | 无效 PR exit 1 |
| `verify-pr` | 0/1 | `[PR_NUMBER]` | — |
| `merge` | 0/1 | `[PR_NUMBER]` | 无 ID 列 open PRs |
| `save` / `resume` | 0 | — | — |
| `board` / `instances` / `check-progress` | 0 | — | — |
| `phase-review` | 0/1 | `[PHASE\|EPIC]` | — |
| `ask` | **1** | `<question>` | 无 q 显示 help |
| `skill` | **1** | `<skill-name>`, 可选 `[target]` | 无 name 走 list |
| `analyze` / `office-hours` | 0/1 | `[TARGET] / [TOPIC]` | — |
| `onramp` / `takeover` | **2** | `<project_path> <user_need>` (均必填) | **缺 1 个 = exit 1** ⚠️ |
| `mode` | 0/1 | `conductor\|performer\|standalone` | **其他值 exit 1** ⚠️ |
| `role` | 0/1 | `master\|conductor\|performer` | **其他值 exit 1** ⚠️ |
| `load` / `route` | 0/1 | — | — |
| `review-analysis` / `review-merge` | 0/1 | `[PR_NUMBER]` (merge) | — |

**规则**: LLM 路由时, 如果主公只给了诉求没给必填参数 →
1. 优先 fallback (status/help/expert/list/board 都能无参)
2. 其次提示「主公需要 X 参数」(onramp/takeover/mode/role)
3. 绝不**瞎填占位值**当参数

## 输出格式 (强制)

每次路由回复必须**先打印 1 行**:

```
🔀 routed: /kallax-<subcmd> <args>
```

然后**按 sub-command 的命令文件 / SKILL.md 执行** — 不要重复主公的诉求内容, 不要解释为什么这么路由。

## 例

| 输入 | 输出 |
|------|------|
| `/kallax 现在状态` | `🔀 routed: /kallax-status` 然后调 `kallax-status.sh` |
| `/kallax 我想看 ticket` | `🔀 routed: /kallax-board` |
| `/kallax 帮我召唤架构师看看微服务` | `🔀 routed: /kallax-expert architect 看一下微服务拆分` |
| `/kallax` (无 args) | `🔀 routed: /kallax-help` |
| `/kallax fastapi 怎么用?` | `🔀 routed: /kallax-ask fastapi 怎么用?` (问专家组) |

## 路由失败

如果诉求**不在上面 26 个里** (例如闲聊 / 不知道问啥), 不要瞎路由:

```
🔀 routed: <subcmd> — fallback
提示: 主公诉求「<原话>」不在 26 个 sub-command 路由表里。
建议: 试试 /kallax-help 看完整命令, 或 /kallax-ask <重构后的问题>。
```

## 为什么是 description 而不是 bash

Claude Code slash 命令的执行路径有 2 种:

| 触发方式 | 谁决策 | 何时用 |
|----------|--------|--------|
| `description:` frontmatter | **LLM 读 description + 用户 input → 自己路由** | 需要语义理解 / 模糊匹配 |
| `!bash <script>` 强制脚本 | bash 脚本拿到 $ARGUMENTS 跑 | 命令固定, 不需要 LLM 决策 |

路由需要"看诉求语义挑命令" — **必须 LLM 决策**, 不能 bash (bash 不会理解自然语言)。所以这个 .md 只放 `description:`, **不放 `!bash`**。

LLM 拿 description 看到全表 → 看到主公 input → 直接路由并执行。
