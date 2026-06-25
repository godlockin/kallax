# EPIC-053-E Implementation Plan

> 5 调用点接入 l3-l4-consistency.sh (治 BE-5 反讽, B 组 5 extended 逆袭发现 #1)
> P0 critical | 8h | branch: feature/EPIC-053-E-preflight-wiring-gap
> Performer: performer-EPIC-053-E | base SHA: 48e76f1

---

## 1. 目标 (跟 AC 1:1 对齐)

把 EPIC-053-A 治 BE-9 的工具 `scripts/verify/l3-l4-consistency.sh` 接入 ROOT-level preflight + ticket-gate 链 5 个调用点, 治 BE-5 反讽 (治 BE-9 工具 = 工具自己就是 lying — 不在生产路径跑).

| AC | 描述 | 验证方法 |
|----|------|----------|
| AC1 | `l3-l4-consistency.sh` 接入 ROOT-level preflight (`scripts/verify/check-fact-forcing-preflight.sh` 已 done, 本工单 verify + 扩 consistency 维度) | preflight 跑测试 PASS |
| AC2 | `scripts/audit/subagent-pass-gate.sh` 升级 — 调 l3-l4-consistency.sh | subagent-pass-gate 跑 l3-l4 self-test |
| AC3 | `scripts/audit/conductor-receive-gate.sh` 升级 — 调 l3-l4-consistency.sh | conductor-receive-gate 跑 l3-l4 self-test |
| AC4 | `scripts/master/strong-verify-6d.sh` 升级 — L4 preflight 包含 l3-l4-consistency | strong-verify-6d L4 段跑 PASS |
| AC5 | `scripts/conductor/review.sh` 升级 — 调 l3-l4-consistency.sh | review.sh 跑 l3-l4 self-test |
| AC6 | `tests/integration/l3-l4-wiring-test.sh` 6/6 PASS (5 调用点 + 1 E2E) | 跑新测试 |
| AC7 | BE-5 反讽 治根闭环 — 治 BE-9 工具在自己生产路径跑 | 5 调用点全 verify |
| AC8 | Rule 9 KPI 精确 X/Y 格式 — 6/6 = 100.0% | 测试报告 X/Y 格式 |

---

## 2. 设计 (跟 Rule 8 + Rule 18 联合, 跟 BE-5 反讽 闭环)

### 2.1 BE-5 反讽定义

EPIC-053-A 治 BE-9 的工具 `l3-l4-consistency.sh` 只在 `scripts/verify/check-fact-forcing-preflight.sh` (新 preflight) 跑. ROOT-level preflight + ticket-gate 链 (subagent-pass-gate, conductor-receive-gate, strong-verify-6d, review.sh) 0 命中.

**反讽**: 治 BE-9 (defense system self-check failure) 的工具自己就是 BE-9 实例 — 工具不在生产路径跑, 治根闭环失效.

### 2.2 5 调用点 拓扑

```
                       ROOT-level preflight chain
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
   audit/subagent-pass-gate.sh  audit/conductor-receive-gate.sh  master/strong-verify-6d.sh
        │                         │                         │
        └─────────────────────────┼─────────────────────────┘
                                  │
                          conductor/review.sh
                                  │
                  ┌───────────────┴───────────────┐
                  │                               │
   verify/check-fact-forcing-preflight.sh (EPIC-053-A, 已 done)
                  │
                  └─ 5 调用点 共调用 l3-l4-consistency.sh
```

### 2.3 调用契约 (统一接口)

每个调用点 加 1-2 行, 跑 `l3-l4-consistency.sh --self-test` (或等价):

```bash
# Self-test mode (一致契约, 跟 EPIC-053-A preflight 一致):
#   PASS/PASS → 0 (OK)
#   PASS/FAIL → 1 (ERROR — 矛盾)
#   FAIL/PASS → 1 (ERROR — 矛盾)
#   FAIL/FAIL → 0 (OK)
#
# 单参数 --self-test 跑双向 self-test (PASS/PASS + PASS/FAIL), 任一失败则 gate FAIL.
```

**注**: `l3-l4-consistency.sh` 当前接口只接受 `--l3-status` + `--l4-status`. 各调用点用 `bash l3-l4-consistency.sh --l3-status=PASS --l4-status=PASS` 验证工具 alive, 然后 `bash l3-l4-consistency.sh --l3-status=PASS --l4-status=FAIL` 验证工具矛盾检测能力.

### 2.4 与 EPIC-053-A 接口

- 不修改 `l3-l4-consistency.sh` (EPIC-053-A 边界)
- 不修改 `tests/integration/l3-l4-consistency-test.sh` (EPIC-053-A 边界)
- `scripts/verify/check-fact-forcing-preflight.sh` 在 EPIC-053-A scope 内已 done, 本工单不重复改 (verify only)

---

## 3. 步骤 (15 步中我的子集, Step 1-8, 11-12)

| Step | 动作 | 状态 |
|------|------|------|
| 1 | 验证 worktree (Master 已建, 我验证 SHA 48e76f1) | ✓ |
| 2 | 读 ticket.json + 6 调用点现状 | ✓ |
| 3 | 加载 expert profile (backend) | ✓ |
| 4 | 深度分析 (5 调用点 当前内容 + 已有 preflight 模式) | ✓ |
| 5 | 写本 plan | 写入中 |
| 6 | TDD 写测试 `tests/integration/l3-l4-wiring-test.sh` (6 case) | 待执行 |
| 7 | 升级 5 调用点 (4 文件: subagent-pass-gate + conductor-receive-gate + strong-verify-6d + review.sh, 第 5 个 scripts/verify/check-fact-forcing-preflight.sh 已 done by EPIC-053-A) | 待执行 |
| 8 | 跑 6/6 PASS | 待执行 |
| 9-10 | A/B review (Conductor 责任) | 跳过 |
| 11 | 写 LESSONS-LEARNED.md | 待执行 |
| 12 | 报 PASS (outbox/pass-report-EPIC-053-E.json) | 待执行 |
| 13-15 | Master 强验证 / merge (Master/Conductor 责任) | 跳过 |

---

## 4. 文件清单 (跟 file_scope 1:1)

**创建**:
- `tests/integration/l3-l4-wiring-test.sh` — 6 case TDD 测试
- `jira/tickets/EPIC-053-E/IMPLEMENTATION-PLAN.md` — 本文件
- `jira/tickets/EPIC-053-E/LESSONS-LEARNED.md` — 教训沉淀
- `.kallax/outbox/performer-EPIC-053-E/pass-report-EPIC-053-E.json` — PASS 报告

**修改** (5 调用点中的 4 个; 第 5 个 scripts/verify/check-fact-forcing-preflight.sh 已被 EPIC-053-A done):
- `scripts/audit/subagent-pass-gate.sh` — 加 L3L4 验证段
- `scripts/audit/conductor-receive-gate.sh` — 加 L3L4 验证段
- `scripts/master/strong-verify-6d.sh` — L4 preflight 加 l3-l4-consistency
- `scripts/conductor/review.sh` — 加 L3L4 验证段

**不动** (边界):
- `scripts/verify/l3-l4-consistency.sh` (EPIC-053-A 边界)
- `tests/integration/l3-l4-consistency-test.sh` (EPIC-053-A 边界)
- `scripts/verify/check-fact-forcing-preflight.sh` (EPIC-053-A 已实现, 不需重复)
- docs/ confluence/ node/ rust/ web/

---

## 5. 测试设计 (AC6 6 case)

| Case | 验证 | 期望 |
|------|------|------|
| 1 | `scripts/verify/check-fact-forcing-preflight.sh` 含 l3-l4-consistency 调用 | PASS |
| 2 | `subagent-pass-gate.sh` 含 l3-l4-consistency 调用 + 双向 self-test | PASS |
| 3 | `conductor-receive-gate.sh` 含 l3-l4-consistency 调用 + 双向 self-test | PASS |
| 4 | `strong-verify-6d.sh` L4 preflight 包含 l3-l4-consistency 验证 | PASS |
| 5 | `review.sh` 含 l3-l4-consistency 调用 + 双向 self-test | PASS |
| 6 | E2E: 模拟 ticket close 全流程 (preflight → subagent-pass → conductor-receive → strong-verify → review), 全部 l3-l4-consistency 段跑通 | PASS |

**子检查**: AC8 — 6/6 = 100.0% (精确 X/Y, no estimate).

---

## 6. 风险 + 反模式 (跟 Rule 18 联合)

| 风险 | 缓解 |
|------|------|
| 改 l3-l4-consistency.sh (越界) | 严格只调不改 |
| 改 l3-l4-consistency-test.sh (越界) | 严格不碰 |
| 只接入 1-2 调用点 (简化 AC) | 6 case 全覆盖, 5 调用点全跑 |
| 把 wiring 推到 pre-commit hook (BE-5 反讽根源) | 强制 ROOT-level (audit/master/conductor) 调用 |
| 重复 EPIC-053-A preflight 已做的 wiring | scripts/verify/check-fact-forcing-preflight.sh verify only, 不重复 |
| 自审 (Rule 2) | A/B review 跳过 (Performer 不审自己) |
| KPI falsification 反复 | commit message 用 X/Y 精确格式 (6/6 = 100.0%) |
| boundary 越界 | `check-scope-creep.sh EPIC-053-E` 验证 (注: tool 局限, directory glob 已知 issue, EPIC-053-F 修) |

---

## 7. BE-5 反讽 治根验证

AC7 验证方法:
- 5 调用点 都包含 `l3-l4-consistency.sh` 字符串引用 ✓
- 5 调用点 跑 `bash l3-l4-consistency.sh --l3-status=PASS --l4-status=PASS` 退出码 0 ✓
- 5 调用点 跑 `bash l3-l4-consistency.sh --l3-status=PASS --l4-status=FAIL` 退出码 1 ✓
- ticket close 链 (subagent-pass-gate → conductor-receive-gate → strong-verify-6d → review.sh → preflight) 全路径命中 l3-l4-consistency ✓

治根: 治 BE-9 工具 (l3-l4-consistency.sh) 自己现在在生产路径跑 — 不再是 lying.

---

**跟主公 §2 explicit 拍板 联合, 跟"诚实修正" 联合, 跟"反讽" 闭环, 跟 Rule 8/9/18 联合.**
