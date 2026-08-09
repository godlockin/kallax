# EPIC-223 — ticket 归档基线 + CLAUDE.md 数字对齐

> **主公 2026-08-08 拍板**: "已完成的 ticket 归档, check 不再检查和回溯, 新的卡都要符合标准" + "claude.md 里面数字对齐"
> **来源**: prime-agent 调研 roadmap (`confluence/decisions/prime-agent-research-2026-08-08.md`) 后续债务收口
> **raw test output**: `tests/integration/epic-223-ticket-archive-test.sh` → 20 PASS / 0 FAIL (total 20), exit 0

---

## 1. 问题 (Why)

### 1.1 45 EPIC 无 ticket

| 事实 | 数据 |
|------|------|
| ticket 目录止于 | `EPIC-177-G` |
| EPIC-178~222 decisions doc | 全部存在 |
| EPIC-178~222 已 merge miao | 全部 (miao HEAD `27d739d9`) |
| EPIC-178~222 有 ticket.json | **0 个** |
| CHANGELOG 记录的 | 12 个 (178/180~188/194/197), 缺 33 |

**关键**: 这 45 个 EPIC **工作已完成并合并**, 缺的只是 `ticket.json` 元数据. 从 EPIC-178 起工作流实际改成"只写 decisions doc, 不建 ticket".

**追溯填表 0 价值**:
1. 工作已完成, 反向填表不产生新信息
2. 现存 ticket 本身就不合规 — `EPIC-157/ticket.json` 的 `performer` 字段是 `null`, 指标 #4 (`mis_dispatch_rate` = performer 空 或 file_scope 跨 specialization) 在历史 ticket 上**本来就算不出来**
3. Rule 36 要求 "4 指标全 PASS 才算 Sprint 闭环", 但 45 EPIC 的指标 #4 永远 NO_DATA → Rule 36 在这些 EPIC 上无法执行

### 1.2 CLAUDE.md §5 数字 4 处不一致

| 位置 | 数字 | 判定 |
|------|------|------|
| §5 标题 "4 不可更改 法律" | 4 | ❌ 历史遗留 (从 4 个时代起未更新) |
| §5 P0-7 注 "5 个 immutable scripts" | 5 | ✅ 正确 |
| §5 表格行数 | 7 | ⚠️ 混装 5 immutable + 2 smoke 辅助 |
| SKILL.md AUTO-PERMS "5 verify + 1 hook = 6" | 6 | ❌ verify 实际 4 个 |

**根因**: 表格把 immutable (fail-closed, 改动需主公亲自) 跟辅助脚本 (可迭代) 混在一起, "数几行" 得出的数字跟 "真正 immutable 数" 不一致.

### 1.3 §4 备案债描述已过期

CLAUDE.md:148 写 "EPIC-155/176 + EPIC-208 计划 Q3 2026 retractively re-promote", 但 `confluence/decisions/epic-178-q3-repromote-2026-08-05.md` 记录 **5 commits 已 re-apply 完毕** (带 `[Q3-repromote]` prefix + DCO, §6 标 "9 专家 review HIGH blocker 闭环").

---

## 2. 方案 (What)

### 2.1 归档基线 (`jira/tickets/.archive-baseline.json`)

```
archived_before: 222
cutoff_date:     2026-08-08
cutoff_commit:   27d739d9
```

**语义**:
- EPIC 编号 ≤ 222 → `ARCHIVED_SKIP`, 不检查不回溯
- EPIC 编号 > 222 → 强制 `new_ticket_required_fields` 全填

**新卡强制字段** (8 项):
`id` / `status` / `title` / `performer` / `file_scope.includes` / `verification.reproduction_command` / `verification.reproduction_exit_code` / `verification.reproduction_raw_output`

**豁免规则** (2 类, 跟现有 Rule 1:1):
| 条件 | 豁免字段 | 联动 |
|------|---------|------|
| `type == docs` && 0 source change | reproduction 3 字段 | EPIC-198 + EPIC-204 docs-only exempt |
| `type != bugfix` | reproduction 3 字段 | Rule 34 仅约束 bugfix |

### 2.2 `scripts/verify/check-ticket-schema.sh`

| 命令 | 行为 | exit |
|------|------|------|
| `<EPIC-XXX>` (≤222) | ARCHIVED_SKIP, 不回溯 | 3 |
| `<EPIC-XXX>` (>222) 有 ticket 且字段齐 | PASS | 0 |
| `<EPIC-XXX>` (>222) 无 ticket | FAIL "新 EPIC 必建 ticket" | 1 |
| `<EPIC-XXX>` (>222) 字段缺 | FAIL + 列出缺失字段 | 1 |
| `--all` | 扫所有 >222 ticket | 0/1 |
| `--baseline` | 打印归档基线 | 0 |

**exit 3 语义跟 EPIC-204 `DOCS_ONLY_SKIP` 同型** — 既不是 PASS 也不是 FAIL, 是"不适用".

### 2.3 `metrics.sh` 归档跳过 (DRY)

抽 2 个公共 helper, 两处 mis_dispatch 函数复用:

| Helper | 职责 |
|--------|------|
| `is_archived_epic <num>` | 返回 0 = 已归档, 1 = 非归档 |
| `emit_archived_skip <metric> <epic> <target>` | 输出 `status: "ARCHIVED_SKIP"` JSON |

**接入 2 处** (漏一处就是假归档):
- `compute_mis_dispatch_rate` (指标 #4 主函数)
- `compute_mis_dispatch_binding_rate` (EPIC-157 binding variant)

raw output 验证:
```
[WARN]  event=mis_dispatch_rate epic=EPIC-157 reason=archived_skip archived_before=222
[WARN]  event=mis_dispatch_binding_rate epic=EPIC-157 reason=archived_skip archived_before=222
```

### 2.4 数字对齐

**统一口径**:
- **5 immutable** = 4 `scripts/verify/` + 1 `scripts/hooks/` (fail-closed 0=PASS/1=FAIL)
- **2 辅助** = smoke retention 检测 + 报告 (非 immutable, 可迭代)
- **不算 immutable**: `scan-dead-code.sh` (三态 0/1/2, 跟二态契约不同)
- **待接入不登记**: `snapshot-claude-md.sh` (EPIC-219) + `check-disclaimer.sh` (EPIC-220) + `check-ticket-schema.sh` (本 EPIC) — 已 merge 但 `.githooks`/`.github` 0 引用, 接入后 5 → 8

**改 3 处** (缺一处即漂移):
1. `CLAUDE.md` §5 标题 4 → 5 + 表格分区 (immutable / 辅助)
2. `.claude/skills/kallax/SKILL.md` "5 verify + 1 hook = 6" → "4 verify + 1 hook = 5"
3. `.claude/rules/immutable-scripts.md` (新建, 单一真相来源 + 改数字强制流程)

**§4 备案债修正**: "计划 Q3 re-promote" → "EPIC-155/176 已闭环 (EPIC-178), EPIC-208 待办" + 备案本次 testing 删除债.

### 2.5 CLAUDE.md 行数控制

| 阶段 | 行数 |
|------|------|
| 改前 | 193 |
| 展开表格分区后 | 209 ❌ 超 200 |
| 移长注释到 `.claude/rules/immutable-scripts.md` 后 | **190** ✅ |

跟 EPIC-159 + EPIC-209 path-scoped lazy load 1:1.

---

## 3. 测试 (raw output)

```
$ bash tests/integration/epic-223-ticket-archive-test.sh
=== Result: 20 PASS / 0 FAIL (total 20) ===
```

| Group | TC | 覆盖 |
|-------|----|------|
| 1 归档基线 | 3 | baseline 可读 / EPIC-157 skip / EPIC-222 边界 |
| 2 新卡强制 | 3 | EPIC-999 无 ticket FAIL / --all / 非法参数 |
| 3 数字对齐 | 6 | §5 标题 / SKILL.md 正反向 / rules 文件 / §7 引用 |
| 4 Rule 36 语义 | 5 | CLAUDE.md / metrics.sh / 2 helper DRY |
| 4b metrics 真跑 | 2 | 两个 mis_dispatch 变体均 archived_skip |
| 5 行数阈值 | 1 | 190 ≤ 200 |

**边界 TC 说明**: EPIC-222 (== archived_before) 测的是 `<=` 而非 `<`, 防 off-by-one.

---

## 4. 不做什么 (0 scope creep)

| 项 | 为什么不做 |
|---|-----------|
| 补 45 个历史 ticket.json | 工作已完成, 追溯填表 0 价值; 且现存 ticket 字段本身不合规 |
| 改 Rule 36 指标 #4 定义 | 归档跳过已解决问题, 不需改 Rule 语义 |
| 接入 EPIC-219/220 到 hook | 独立 EPIC (死文件激活), 本 EPIC 只登记"待接入" |
| 补 CHANGELOG 33 条 | 独立 EPIC (文档一致性) |
| 12 个 in_progress ticket 定性 | 独立 EPIC (ticket 体系收口) |

---

## 5. 联动

| 联动项 | 关系 |
|--------|------|
| Rule 34 (bugfix 3 字段) — EPIC-152 | `new_ticket_required_fields` 含 reproduction 3 字段, 非 bugfix 豁免 |
| Rule 36 (4 北极星) — EPIC-194 | 指标 #4 加 ARCHIVED_SKIP 路径 |
| EPIC-198 + EPIC-204 (docs-only exempt) | exit 3 语义同型 + docs 豁免规则复用 |
| EPIC-157 (ticket expert_binding) | binding variant 同步加归档跳过 |
| EPIC-159 + EPIC-209 (lazy load) | 长注释移 `.claude/rules/immutable-scripts.md` |
| EPIC-178 (Q3 re-promote) | §4 备案债描述修正指向该 doc |
| EPIC-219 / EPIC-220 | 登记为"待接入", 不计入 immutable 数 |
| EPIC-221 (PR template Rule 34) | PR 门控跟 ticket schema 门控 1:1 |

---

## 6. 遗留 (下一 Sprint)

| # | 项 | 优先级 |
|---|---|--------|
| 1 | 3 个死文件接入 hook/CI (snapshot / disclaimer / ticket-schema) | 最高 — merge 了但不运行 |
| 2 | commitlint 装 husky (EPIC-221 只加 config 无 runner) | 最高 — 同类问题 |
| 3 | CHANGELOG 补 EPIC-203~222 共 20 条 | 高 |
| 4 | recent-epics.md 补 EPIC-209~222 | 中 |
| 5 | 12 in_progress ticket 定性 + EPIC-150/154/177-G 收口 | 中 |
| 6 | testing 分支恢复 + 备案 | 中 |