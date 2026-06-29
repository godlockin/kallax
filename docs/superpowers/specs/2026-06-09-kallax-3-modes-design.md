# KALLAX 3 模式决策权分配设计

> **日期**: 2026-06-09
> **作者**: master (主公 2026-06-09 拍板)
> **状态**: Approved — 待 writing-plans
> **关联**: EKET `interactive:start` 借鉴 (UX §5.1 + 主公原话)

---

## 1. 背景与目标

主公 2026-06-09 原话: **"任务 Drive 的时候分 ai-auto (由 ai 做绝大部分决策, 只在 block 决策、危险操作的时候询问我)、ai-copilot (简单任务由 ai 决策, 复杂的任务和我协商决策)、manual (大部分场景 ai 提案+执行, 我来确认每一步要不要做)"**

**目标**: 把 Conductor + Performer 的"决策权分配"显式建模为 3 个 session-level 模式, 解决:
- 日常开发主公想"放手让 AI 干"
- 高风险操作主公想"每步确认"
- 中间状态用"协商"模式

---

## 2. 3 模式定义

| 模式 | 决策权分配 | 触发场景 | 启用频率 |
|---|---|---|---|
| **ai-auto** | AI 决策所有事, 仅"block 决策 + 危险操作"停下问 | 任务明确 / 低风险 / 批量 | 低 (跑 Sprint 3 之类) |
| **ai-copilot** | AI 决策"简单"阶段, 跟主公协商"复杂"阶段 | 默认模式, 日常开发 | 高 (主公多数场景) |
| **manual** | AI 提案 + 执行, 主公确认**每阶段** | 高风险 / 新领域 / 学习 | 中 (新 EPIC 设计) |

---

## 3. 决策粒度 (3 模式 × 4 维度)

| 维度 | ai-auto | ai-copilot | manual |
|---|---|---|---|
| **Block 决策** | 停下问 | 停下问 | 停下问 |
| **危险操作** | 停下问 (3 类) | 停下问 (3 类) | 停下问 (3 类) |
| **Performer 失败/超时** | 停下问 (重试/换人/接管) | 停下问 | 停下问 |
| **Performer 5 阶段切换** | AI 自主 | AI 决策"简单"阶段, 协商"复杂"阶段 | **主公确认每阶段** |

---

## 4. Block 决策的 5 类触发 (3 模式都触发)

1. **多个选项无明显最优** (AC 模糊/选型争议/多种实现路径, TrustScore 无法选)
2. **Performer 失败/超时** (API error/3 次 retry fail/30min 超时)
3. **规则冲突/Exception 请求** (跟 Rule 1-12 冲突需主公拍)
4. **EPIC 交付关键节点** (PHASE review/Rule 升级/EPIC close)
5. **可能有重大影响/风险** (主公原话新增, 兜底类)

---

## 5. 危险操作定义 (3 模式都停下问, 3 类)

| # | 危险操作 | 来源 |
|---|---|---|
| 1 | 修改 miao 分支 (commit/push/merge) | Rule 1 + 主公 2026-06-09 |
| 2 | 安全相关 (pre-commit FAIL/anti-fab FAIL/5 levels FAIL/凭据变动) | Rule 9/10 |
| 3 | 删除/恢复数据 (rm -rf/reset --hard/push --force/worktree drop/db drop) | 通用红线 |

---

## 6. ai-copilot "复杂阶段" 判定 (Performer 5 阶段)

| Performer 阶段 | ai-copilot 行为 | 复杂度 | 协商提示 |
|---|---|---|---|
| **claim** | AI 决定是否 claim | 简单 | 不停 |
| **analysis** | **停下协商** (技术方案/选型争议) | **复杂** | "📋 技术方案:\n[方案]\nApprove / Modify / Reject?" |
| **in_progress** | AI 决策实现细节 | 简单 | 不停 |
| **test** | **停下协商** (测试是否充分/是否 PASS) | **复杂** | "🧪 测试结果:\n[PASS/FAIL 详情]\nApprove / Re-test / Rollback?" |
| **review** | **停下协商** (PR 是否合并/如何修 feedback) | **复杂** | "🔍 Review 反馈:\n[反馈]\nMerge / Fix / Cancel?" |

---

## 7. 模式切换机制

**每个 session_start 选一次**, 写到 `state.json`:
```json
{
  "role": "master",
  "instance_id": "master_xxx",
  "mode": "ai-copilot",        // NEW
  "mode_set_at": "2026-06-09T22:30:00+08:00",
  "mode_lock": true            // NEW: 防热切换冲突
}
```

**session_start.sh 增加选择菜单** (跟 EKET 借鉴 P1-3 集成):
```
┌─ KALLAX ────────────────────────────────
│ ROLE     ▸ master
│ INSTANCE ▸ master@miao
│ MODE*    ▸ [?]  1.ai-auto  2.ai-copilot  3.manual
│ INBOX    ▸ [0] .
│ NEXT     ▸ ...
└────────────────────────────────────────
```

**不能在 session 中热切换** (避免状态不一致), 如需换模式 → `/kallax-init --mode xxx` 重启 session。

**mode_lock**: 同一 instance 同时只能持有 1 个 mode, 避免多 session 冲突。

---

## 8. 落地位置 (跟 EKET 借鉴 P1-3 集成)

| 改动 | 位置 | 借鉴 |
|---|---|---|
| session_start.sh 加 MODE 选择 | `.kallax/hooks/session_start.sh` | UX §5.1 interactive:start + 主公 3 模式 |
| state.json 加 `mode` + `mode_lock` 字段 | `.kallax/state/state.json` schema | EPIC-021 §3.1 (state 字段) |
| 5 阶段 AI-copilot 协商检查 | `scripts/performer/stage-gate.sh` (新) | Performer §2.2 5 阶段 |
| 危险操作 / Block 决策统一检查 | `scripts/permission/decision-gate.sh` (新) | Conductor §5.3 waiting-for-expert + Security §4 |
| AI 决策审计 | `.kallax/audit/decision-YYYY-MM-DD.jsonl` | P1-5 EKET 借鉴 |
| `--mode` CLI flag | `/kallax-init --mode ai-auto\|ai-copilot\|manual` | EPIC-021 persona 字段扩展 |

---

## 9. 落地状态机

```
[kallax-init --mode X]
    │
    ▼
[session_start.sh] ───检测 mode───→ state.json.mode = X
    │
    ▼
[Conductor/Performer 工作循环]
    │
    ├─→ 普通操作 ──→ AI 自主
    │
    ├─→ Block 决策 (5 类) ──→ decision-gate.sh ──→ 停下问主公
    │
    ├─→ 危险操作 (3 类) ──→ decision-gate.sh ──→ 停下问主公
    │
    └─→ Performer 5 阶段切换
         │
         ├─→ claim / in_progress (简单) ──→ AI 自主
         │
         └─→ analysis / test / review (复杂) ──→ 模式分流
              │
              ├─→ ai-auto ──→ AI 自主
              ├─→ ai-copilot ──→ 停下问主公
              └─→ manual ──→ 停下问主公
```

---

## 10. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| ai-auto 模式 "危险操作" 漏判 | 中 | HIGH | pre-commit hook 加 `decision-gate.sh` 调用, 强制询问 |
| manual 模式主公疲劳 | 高 | 中 | 每阶段提示包含 1 句 TL;DR, 主公可 `approve all` |
| mode 状态被多 session 改冲突 | 中 | 中 | mode_lock 文件, session 启动时检测冲突 |
| Performer 5 阶段"复杂"判定不一致 | 中 | 中 | stage-gate.sh 维护判定规则版本, 跟 KALLAX 升级一起发版 |
| Block 决策被 AI 自决 | 中 | HIGH | decision-gate.sh 维护 block 决策 whitelist, 强制 exit 1 |

---

## 11. 验收标准 (5 levels Fact-Forcing)

### L1 存在性
- [ ] `state.json` 加 `mode` + `mode_lock` 字段, type 验证
- [ ] `session_start.sh` 加 MODE 选择菜单
- [ ] `scripts/permission/decision-gate.sh` 存在
- [ ] `scripts/performer/stage-gate.sh` 存在

### L2 实质性
- [ ] decision-gate.sh 真实检查 3 类危险操作 + 5 类 block 决策, 命中即 `AskUserQuestion` 等价
- [ ] stage-gate.sh 真实检查 5 阶段分流, 跟 mode 匹配
- [ ] session_start.sh 真实写 mode 到 state.json, 启动时检测 mode_lock

### L3 接线正确
- [ ] pre-commit hook 串联 decision-gate.sh (跟 Rule 10 联动)
- [ ] Performer `task:claim` / `task:complete` Saga 串联 stage-gate.sh
- [ ] `kallax-init --mode X` CLI 写入 state.json

### L4 数据流动
- [ ] 集成测试: 3 模式 × 4 阶段 = 12 场景 (E2E)
- [ ] 集成测试: 3 类危险操作 × 3 模式 = 9 场景 (E2E)
- [ ] 集成测试: 5 类 block 决策 × 3 模式 = 15 场景 (E2E)
- [ ] AI 决策审计: 模拟 session, 验证 `.kallax/audit/decision-YYYY-MM-DD.jsonl` 内容完整

---

## 12. 关联文档

- **EKET 借鉴清单**: `confluence/decisions/CONDUCTOR-VIEW-EKET-VS-KALLAX-2026-06-09.md` §5, `UX-VIEW-EKET-VS-KALLAX-2026-06-09.md` §5.1
- **EKET 全量借鉴路线图**: brainstorming 输出 (10 P0 + 8 P1 + 8 P2)
- **KALLAX Rules**: Rule 1 (miao 禁写), Rule 9 (5 levels), Rule 10 (anti-fab), Rule 11 (Master 写代码禁令)
- **EPIC-021 战略**: `confluence/research/eket-surpass-strategy-2026-06-07.md` §3.1 state 字段

---

## 13. 下一步

主公拍板"同意, 开干" → 下一步是 **writing-plans skill 写实施计划** → 派 Performer 拆 ticket 开干 (跟 EPIC-029 EKET 借鉴合并落地, 3 模式作为 P0 优先级)。

---

**维护者**: master (主公拍板 2026-06-09)
**下次 review**: 落地完成后 PHASE review
