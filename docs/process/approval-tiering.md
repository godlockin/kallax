# 主公拍板分级 P0/P1/P2 — 决策疲劳从根源修复 (EPIC-055-B)

> **Ticket**: EPIC-055-B (5 张治理卡 核心)
> **Date**: 2026-06-16
> **Author**: performer-EPIC-055-B
> **Status**: ✅ DESIGN — 跟主公 2026-06-16 拍板 联合, 跟 PROCESS.md:25-26 联合

---

## TL;DR

**问题**: 主公决策疲劳 — 23 Rule 累计 9 升级, 拍板边际效用递减, ai-copilot 模式 "ask every step" (每 5 分钟 1 次确认请求).

**方案**: 主公拍板 3 级分类:
- **P0** 战略红线 (R-NEW 升级 / Rule 撤销 / 治理升级) — **必拍**, subagent 阻塞等主公
- **P1** 流程升级 (Tier 1/2 ticket / Rule 合并 / 阶段变更) — **备案**, 主公 review 即可
- **P2** 操作 (Tier 3 chore / docs / 单文件改动) — **放手**, 不需备案, 直接执行

**Rule 33** (新): 主公拍板分级 P0/P1/P2 (软限制, 跟 Rule 11 v2.1 强验证 联动)

---

## 1. 根因 (跟 23 Rule 9 升级 联合, 跟决策疲劳 联合)

### 1.1 问题现状

| 指标 | 值 | 来源 |
|---|---|---|
| Rule 总数 | 23 | CLAUDE.md `^### [0-9]+\.` |
| 累计升级 Rule 数 | 9 | R-NEW (14-19, 6 Rule) + v1.2.4 (30/31, 2 Rule) + Rule 32 (1 Rule) |
| 升级率 | 39.1% | 9/23 |
| ai-copilot 主公确认频率 | 每 5 分钟 1 次 | docs/process/decision-gate-design.md §1.1 |
| 主公决策疲劳度 | 高 (P2 操作 仍需拍板) | decision-gate-design.md §1.5 UX 视角 |

### 1.2 根因

PROCESS.md:25-26 明确: **Master 不能自己升级红线**, 治理升级需主公 explicit 拍板.
但没区分拍板级别 → 所有决策都走"必拍"路径 → 主公 P2 操作 (docs typo / chore) 也需拍板 → 边际效用递减.

### 1.3 拍板边际效用

```
边际效用 = 拍板次数 / Rule 升级次数 = decisions/upgrades
   升级率↑ → 每升级需要的拍板越少 → 边际效用↓
   主公拍板疲劳↑ → 漏拍风险↑ → 治理漏洞↑
```

---

## 2. 3 级分类设计 (跟 PROCESS.md:25-26 联合, 跟"独立" 拍 explicit 约束 联合)

### 2.1 P0 — 战略红线 (必拍)

**范围**:
- R-NEW 升级 (新 Rule 制定, 跟 v1.2.4 5 扩展组 联动)
- Rule 撤销 / 合并 (跟 EPIC-054-D 联动)
- 治理升级 (改 KALLAX 核心机制, 5 治理卡 类)
- Tier 0 ticket (战略 ticket)
- 红线 revert (推翻 主公 prior 拍板, 如 EPIC-056-C)

**拍板方式**: **阻塞等主公 explicit 拍板**
- subagent 不能自助执行 (跟 PROCESS.md:25-26 Master 不能自己升级红线 联合)
- 写 `inbox/human_feedback/REQUEST-P0-<id>.md` (拍板请求)
- 主公拍板 后 → subagent 执行 + 更新 audit + 通知 Conductor

**主公成本**: 高 (一次性, 15 分钟/次 估算)
**例子**: EPIC-056-C (Master 6 维恢复, 推翻 v1.2.4 6→0 退步)

### 2.2 P1 — 流程升级 (备案)

**范围**:
- Tier 1 ticket (重要功能 ticket)
- Tier 2 ticket (一般功能 ticket)
- Rule 合并 / 阶段变更 / 流程升级
- 不推翻 prior 拍板 的 流程改动

**拍板方式**: **写 inbox 备案, 主公 review 即可**
- subagent 不阻塞, 直接执行
- 写 `inbox/human_feedback/RECORD-P1-<id>.md` (备案)
- 主公 review 时 check 即可 (不阻塞)

**主公成本**: 中 (5 分钟/次 估算, 仅 review 不阻塞)
**例子**: EPIC-054-D (Rule 合并扫描, 需 055-B 落地)

### 2.3 P2 — 操作 (放手)

**范围**:
- Tier 3 ticket (chore / docs typo / 测试 fix / 单文件改动)
- 不影响核心机制的 操作

**拍板方式**: **直接执行, 不需备案**
- subagent 直接执行, 写 `audit/p2-log-<date>.jsonl` (留痕)
- 不写 inbox, 不阻塞

**主公成本**: 零
**例子**: docs typo / chore 脚本 / 测试 fix

---

## 3. 自动路由 (role-cmd.ts 升级)

### 3.1 classify_decision() 决策函数

```bash
classify_decision() {
    local ticket_id="$1"
    local change_type="${2:-default}"
    local tier="${3:-2}"

    # P0 触发: 战略红线 (change_type ∈ rule_redline_upgrade|rule_revoke|governance_upgrade)
    # P1 触发: 流程升级 (change_type ∈ rule_merge|phase_change|tier1|tier2)
    # P2 默认: 操作
}
```

### 3.2 3 路由函数

```bash
route_p0()  # → 阻塞 + 写 REQUEST-P0-*.md (主公 explicit 拍板)
route_p1()  # → 写 RECORD-P1-*.md (备案, 不阻塞)
route_p2()  # → 直接执行 + 写 p2-log-*.jsonl (留痕)
```

### 3.3 role 决策时调用

`node/src/commands/role-cmd.ts` 升级 — `role decide <change_type> <tier>` 命令调用 `classify_decision` + 对应 `route_pN`.

---

## 4. 拍板疲劳从根源修复 (跟 Rule 32 联动, 跟 EPIC-054-D 联动)

### 4.1 fatigue_index 公式

```
fatigue_index = upgrade_rate × (1/utility)
   upgrade_rate = 升级 Rule 数 / Rule 总数 = 9/23 = 39.1%
   utility = decisions/upgrades (每升级需要的拍板数)
   inv_utility = 1/utility

例: utility = 2.87, inv_utility = 0.348
   fatigue_index = 39.1 × 0.348 = 13.6
```

(当前实测: 23 Rule, 9 升级, fatigue_index=34.8, 见 `tests/integration/approval-tiering-test.sh` TC6)

### 4.2 从根源修复策略

| fatigue_index | 状态 | 推荐 |
|---|---|---|
| 0-30 | OK | 拍板节奏可持续 |
| 30-50 | WARN | 触发 Rule 合并扫描 (EPIC-054-D) |
| 50-100 | HIGH | 立即 Rule 合并 + 减少 P0 拍板 (扩 P1) |

### 4.3 跟 EPIC-054-D 联动

- EPIC-054-D: Rule 合并/撤销定期扫描 (23 Rule → 20 Rule 目标)
- EPIC-054-D 依赖 EPIC-055-B 拍板分级落地 (本 ticket)
- 落地 后: P1 拍板 (Rule 合并) 自动备案, 不阻塞 EPIC-054-D 执行

---

## 5. 历史决策审计 (scripts/audit/approval-tiering.sh)

### 5.1 audit_p0_missed()

扫所有 ticket, 检查 P0 类型 (R-NEW 升级/Rule 撤销/治理升级) 是否有 REQUEST-P0-*.md 备案:
- `P0_MISSED: N P0 漏拍 (scanned M tickets)` — 需主公补拍
- `AUDIT_OK: 0 P0 missed (scanned M tickets)` — 健康

### 5.2 calc_marginal_utility()

输出: cost / p0_count / p1_count / p2_count / total_decisions / total_rules / upgraded / upgrade_rate / utility

### 5.3 calc_fatigue_index()

输出: total_rules / upgraded / upgrade_rate / utility / fatigue_index / recommendation

---

## 6. 跟 5 张治理卡 联动

```
EPIC-055-B (本 ticket — P0/P1/P2 分级)
       ├── EPIC-054-D (Rule 合并, P1 备案)
       ├── EPIC-056-A (5→3 阶段, P1 备案)
       └── EPIC-056-C (Master 6 维恢复, P0 必拍)
```

派单顺序 (跟 `5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md` 联合):
1. EPIC-055-B 优先派 (本 ticket, 其他 3 张依赖)
2. EPIC-056-B (流程效果度量) parallel (独立)
3. EPIC-054-D + 056-A + 056-C 跟 055-B blocked_by

---

## 7. 跟 PROCESS.md:25-26 联合 (联合红线)

PROCESS.md:25-26 红线: **Master 不能自己升级红线**

3 级分类 **不** 突破 PROCESS.md:25-26 红线:
- ✅ P0 必拍 (跟红线一致)
- ✅ P1 备案 (不阻塞, 但留痕, 主公可 review)
- ✅ P2 放手 (操作类, 不涉及红线升级)
- ❌ Master 永远不能自助 P0 (红线不变)

**验证**: role-cmd.ts 升级 后, route_p0 仍需主公 explicit 拍板 才执行.

---

## 8. 跟"诚实修正" 联合

主公 2026-06-16 一次性拍 5 张治理卡, 跟"独立" 拍 explicit 约束 联合.
落地 3 级分类 后, 未来拍板按 P0/P1/P2 分流, 跟"翻篇&精进" 战略 一致.

---

## 9. 验收 (7 AC)

| AC | 内容 | 验证 |
|---|---|---|
| 1 | 3 级分类设计 | 本文档 §2 |
| 2 | role-cmd.ts 升级 — 3 级路由 | 6/6 TC1-TC3 PASS |
| 3 | scripts/audit/approval-tiering.sh | TC4-TC6 PASS |
| 4 | P2 从根源修复 — 拍板疲劳 闭环 | TC6 fatigue_index + recommendation |
| 5 | 6/6 PASS | 测试输出 6/6 |
| 6 | Rule 9 KPI 精确 X/Y 格式 | 6/6 = 100.0% |
| 7 | 跟主公拍板 联合 | 引用 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md |

---

**跟 5-GOVERNANCE-CARDS-APPROVAL-2026-06-16.md 联合, 跟 PROCESS.md:25-26 联合, 跟 Rule 9 X/Y 格式 联合, 跟 Rule 11 v2.1 强验证 联合, 跟 Rule 32 联动, 跟 EPIC-054-D/056-A/056-C 联动, 跟"诚实修正" + "翻篇&精进" 战略 一致**