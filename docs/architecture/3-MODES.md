# KALLAX 3 模式决策权分配 — 用户文档

> **3 模式 = ai-auto / ai-copilot / manual**
> 主公 2026-06-09 拍板, 跟 EKET `interactive:start` 借鉴集成.

## 1. 怎么选?

每个 session 启动时 (`.kallax/hooks/session_start.sh`) 选一次:

```
┌─ KALLAX MODE ─────────────────────────────
│ 1) ai-auto     (AI 决策, 仅 block/danger 停下问)
│ 2) ai-copilot  (简单自主, 复杂协商) [默认]
│ 3) manual      (每阶段主公确认)
└──────────────────────────────────────────
```

或者用 `kallax-init --mode ai-auto|ai-copilot|manual` CLI.

## 2. 什么时候选哪种?

| 场景 | 推荐模式 |
|---|---|
| 跑 Sprint 3 批量 4 expert | ai-auto |
| 日常开发 (主公多数场景) | **ai-copilot (默认)** |
| 新 EPIC 设计 | manual |
| 高风险 migration | manual |
| 修复紧急 bug | ai-copilot |

## 3. 3 模式行为差异

### 3.1 ai-auto
- AI 决策所有事
- 仅"block 决策" + "危险操作" 停下问
- 5 阶段全 AI 自主

### 3.2 ai-copilot (推荐默认)
- 简单阶段 (claim / in_progress) AI 自主
- 复杂阶段 (analysis / test / review) 停下协商
- "block 决策" + "危险操作" 停下问

### 3.3 manual
- 每阶段都停下问主公
- "block 决策" + "危险操作" 停下问
- 适合学习新领域 / 高风险操作

## 4. 5 类 Block 决策 (3 模式都触发)

1. **ambiguous_options** — 多个选项无明显最优
2. **performer_failure** — Performer 失败/超时/3 次 retry
3. **rule_exception** — 规则冲突/Exception 请求
4. **epic_critical** — EPIC 交付关键节点
5. **high_impact** — 可能有重大影响/风险

## 5. 3 类危险操作 (3 模式都触发)

1. **miao_modify** — 修改 miao 分支 (commit/push/merge)
2. **security_failing** — 安全检查 FAIL (pre-commit/anti-fab/4-Level)
3. **data_destruction** — rm -rf / reset --hard / drop table

## 6. 怎么改模式?

每个 session 只能选一次. 改模式 → 重新启动 session:

```bash
# 在主 session 退出后
exit  # 或 Ctrl+D

# 启动新 session
/kallax-init --mode ai-auto
# 或
/kallax-init --mode ai-copilot
# 或
/kallax-init --mode manual
```

不能在 session 中热切换, 避免状态不一致 (mode_lock 保护).

## 7. 派发权让渡比例 (主公 D2 决策, 渐进升级)

> **主公 2026-06-11 D2 决策**: EKET P1 #1 派发权让渡比例从 60% AI → 80% AI 渐进升级.
> 未来可调至 90% AI (待主公拍板).

### 7.1 3 模式 × 3 派发权比例矩阵 (9 场景)

| 模式 | 60% AI | 80% AI | 90% AI |
|---|---|---|---|
| **ai-auto** | 60% AI 默认 Accept, 40% 显式 override 必填 | 80% AI 默认 Accept, 20% 显式 override 必填 | 90% AI 默认 Accept, 10% 显式 override 必填 |
| **ai-copilot (默认)** | 默认 Accept (60% AI 默认), 40% 人工 override 显式 | 默认 Accept (80% AI 默认), 20% 人工 override 显式 | 默认 Accept (90% AI 默认), 10% 人工 override 显式 |
| **manual** | 100% 人工, 显式 override 必填 | 100% 人工, 显式 override 必填 | 100% 人工, 显式 override 必填 |

### 7.2 派发权让渡比例演进

| EPIC | AI 比例 | 人工比例 | 决策 | 状态 |
|---|---|---|---|---|
| EPIC-031 | 60% AI | 40% 人工 | 主公 2026-06-11 拍 | 已完成 |
| **EPIC-033** | **80% AI** | **20% 人工** | **主公 2026-06-11 D2 决策** | **本次升级** |
| 未来 (待定) | 90% AI | 10% 人工 | 主公未来拍板 | 规划 |

### 7.3 env var 配置

```bash
# KALLAX_AI_DELEGATION_RATIO: 60 = 60% AI / 40% 人工, 80 = 80% AI / 20% 人工, 90 = 90% AI / 10% 人工
export KALLAX_AI_DELEGATION_RATIO=80  # 默认 80% AI (主公 D2 决策)

# 查看当前配置
echo $KALLAX_AI_DELEGATION_RATIO
```

### 7.4 20% 人工 override 场景

当 `KALLAX_AI_DELEGATION_RATIO=80` 时:
- 80% AI: Conductor 默认 Accept ALGO_SUGGEST (一键 Approve)
- 20% 人工: 必须显式 `--dispatch-to <performer_id>` 或 `--human-override-required <performer_id>`

示例:
```bash
# 80% AI 模式: 默认 Accept ALGO (一键 Approve)
kallax-dispatch.sh --ticket EPIC-033-T001 --expertise bash

# 20% 人工 override: 显式指定 performer
kallax-dispatch.sh --ticket EPIC-033-T001 --expertise bash --dispatch-to performer-beta
```

## 8. 怎么回应 AI 的"停下问"?

AI 写 ask file 到 `.kallax/inbox/`:
- `ask-stage-<TICKET>-<STAGE>.md` (ai-copilot 复杂阶段)
- `ask-manual-<TICKET>-<STAGE>.md` (manual 阶段)
- `decision-<ACTION>-<TIMESTAMP>.md` (block/danger)

主公回应:
1. 编辑 ask file 写 "Approve" / "Modify" / "Reject"
2. AI 读 ask file 继续执行

## 9. 审计

所有 AI 决策写到 `.kallax/audit/decision-YYYY-MM-DD.jsonl`:
- 每条记录: timestamp / actor / mode / action / cmd (redacted) / context
- 每日轮转, 永久留存
- Conductor 可在 review 时查

**安全特性 (3 轮加固)**:
- action 严格 allowlist (regex `^[a-z_]+\.[a-z_]+$`)
- JSONL 用 jq -n 构建 (不 echo 拼字符串)
- 9-pass redaction (Authorization/Token/X-Auth-Token + password/secret + GNU-style + -a/-p + Basic Auth URL 多种 scheme + 已知 token prefix ghp_/sk-/AKIA + JWT + env-var + 数字要求兜底)

## 10. 故障排查

| 问题 | 排查 |
|---|---|
| mode 没生效 | `bash scripts/permission/whoami.sh` 看 mode 字段 |
| decision-gate 误报 | 检查 `state.json.mode` 是否正确 |
| 改 mode 无效 | 确认 session 已重启 (不能热切换) |
| ask file 没出现 | 检查 `.kallax/inbox/` 目录权限 |
| audit jsonl 没记录 | 检查 `.kallax/audit/` 目录权限, 看 mode 是否为 ai-copilot (default) |
| 派发权比例没生效 | 检查 `KALLAX_AI_DELEGATION_RATIO` env var 是否设置 (默认 80) |

## 11. 关联文档

- [CLAUDE.md Rule 13](../CLAUDE.md)
- [设计 spec](../superpowers/specs/2026-06-09-kallax-3-modes-design.md)
- [实施 plan](../superpowers/plans/2026-06-09-kallax-3-modes.md)
- [派发权升级 EPIC-033](../epics/EPIC-033/epic.json)