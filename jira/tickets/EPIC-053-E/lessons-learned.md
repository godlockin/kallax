# EPIC-053-E — LESSONS LEARNED

> 5 调用点接入 l3-l4-consistency.sh (治 BE-5 反讽, B 组 5 extended 逆袭发现 #1)
> 跟 Rule 6 (事后复盘) 联合, 跟 Rule 8 (5-Level Fact-Forcing) 联合, 跟"诚实修正" 联合

---

## L1 — 治根工具必须在生产路径跑, 否则自己就是 BE-5 反讽实例

**问题**: EPIC-053-A 治 BE-9 (defense system self-check failure) 的工具 `l3-l4-consistency.sh` 创建后只在 `scripts/verify/check-fact-forcing-preflight.sh` (新 preflight) 跑. ROOT-level preflight + ticket-gate 链 (subagent-pass-gate, conductor-receive-gate, strong-verify-6d, review.sh) 0 命中.

**反讽**: 治 BE-9 的工具自己就是 BE-9 实例 — 工具不在生产路径跑, 治根闭环失效. "治根工具不治自己".

**修法**: 把 `l3-l4-consistency.sh` 接入 5 个调用点 (1 已有 by EPIC-053-A + 4 新加), 让它在 ticket close 链全程跑 (subagent 自检 → conductor 接收 → master 强验证 → conductor review → preflight).

**Rule 联动**: Rule 8 (5-Level Fact-Forcing), Rule 18 (黑名单 — 自检漏洞).

---

## L2 — Wiring gap 修复模式: 工具调用契约一致化, 不要分散实现

**洞察**: 4 个新接入点 (subagent-pass-gate, conductor-receive-gate, strong-verify-6d, review.sh) 各自的代码上下文差异大 (gate / verify / master / conductor), 如果每个点用不同的调用方式 (有的 grep 有的 eval 有的 source), 后续维护成本指数增长.

**修法**: 用一致的 self-test 契约 — 每个调用点跑相同 2 行:
```bash
bash l3-l4-consistency.sh --l3-status=PASS --l4-status=PASS  # expect exit 0 (OK)
bash l3-l4-consistency.sh --l3-status=PASS --l4-status=FAIL  # expect exit 1 (ERROR)
```
契约一致 ⇒ 测试一致 ⇒ 维护一致. 跟 EPIC-053-A 的 preflight 完全一致 (`scripts/verify/check-fact-forcing-preflight.sh` Checks 3+4).

**Rule 联动**: DRY (Single Source of Truth) + Rule 18 (诚实).

---

## L3 — 5 调用点 协调: ticket close 链全路径命中, 缺一不可

**拓扑**:
```
   subagent-pass-gate.sh (subagent 自检)
        ↓
   conductor-receive-gate.sh (conductor 接收)
        ↓
   strong-verify-6d.sh L4 preflight (master 强验证)
        ↓
   review.sh (conductor 合并前 review)
        ↓
   check-fact-forcing-preflight.sh (verify framework preflight, EPIC-053-A)
```

**洞察**: 任何一个调用点不接入 l3-l4-consistency, BE-5 反讽就没治根 — 攻击者只需绕过那一个点 (例如只过 subagent-pass-gate 不进 conductor-receive-gate), 就能让自检漏洞检测器失声.

**验证**: tests/integration/l3-l4-wiring-test.sh Case 6 (E2E) 严格断言 5/5 命中, 任一缺失即 FAIL. 这把"必须 5 点全接"从口头约束变成可执行门禁.

**Rule 联动**: 深度防御 (defense in depth) — 多层独立 gate.

---

## L4 — 跟 v1.2.4 5 扩展组 联动: process-engineering + security-tool-bypass 双闭环

**联动 1 (process-engineering)**: 5 调用点的 self-test 模式本身就是 process-engineering — 把"工具 alive" 变成可执行验证, 不是文档约束. 跟 EPIC-053-A 的 preflight 联动形成 "framework-of-frameworks" (verify framework + l3-l4-consistency framework).

**联动 2 (security-tool-bypass)**: BE-5 反讽的根因是 "治根工具自己被 bypass" — 治 root-cause 工具不在生产路径 ⇒ 治根失效. 这正是 security-tool-bypass 关注的"防御机制自身缺陷" 模式. 接入 5 调用点 = 防御机制自我防御.

**Rule 联动**: Rule 14/15 (Isolation), Rule 18 (黑名单).

---

## L5 — 跟 EPIC-053-B (5-Level 证据链) 联动: pass-report 信号互证

**联动**: EPIC-053-B 用 l3-l4-consistency 验证 pass-report 信号 (PASS/PASS = OK, PASS/FAIL = ERROR). 本工单接入的 5 调用点恰好是 pass-report 信号采集的关键 gate — subagent 自报 PASS → conductor 验证 PASS → master 强验证 PASS → conductor review PASS → preflight PASS. 每一步 PASS 都跑 l3-l4-consistency, 形成 pass-report 信号的 L3↔L4 互证.

**应用**: 任何 ticket close 必须先过 5 调用点 + l3-l4-consistency PASS/PASS 一致, 否则 ticket REJECT.

**Rule 联动**: Rule 8 (5-Level) + Rule 16 (5 步 close 链).

---

## L6 — check-scope-creep 工具局限性 (诚实记录, 跟 EPIC-053-A L6 一致)

**发现**: 本工单 `IMPLEMENTATION-PLAN.md` 在 `jira/tickets/EPIC-053-E/` 目录下, ticket scope 包含 `jira/tickets/EPIC-053-E/` (directory). `check-scope-creep.sh` 仍报 `IMPLEMENTATION-PLAN.md` 越界 (exit=1).

**真相**: 6 个文件全部在 file_scope.includes 里 — 4 exact match + 2 directory match (directory prefix). 是工具的目录 glob 局限性, 不是边界越界.

**修法**: 跟 EPIC-053-A 一样, 不修 check-scope-creep (不在 file_scope). 在 pass-report 里诚实标记为 `FAIL (tool limitation)`, boundary_violations = 0 (按 intent 算). EPIC-053-F 是修 ticket.

**Rule 联动**: Rule 9 KPI 精确, Rule 18 黑名单 (不报伪 PASS).

---

## 防 BE-5 复发 checklist

- [x] 5 调用点 全接入 l3-l4-consistency (1 已有 + 4 新加)
- [x] tests/integration/l3-l4-wiring-test.sh 6/6 PASS (100.0%)
- [x] 5 anti-fab tool PASS (test-case-isolation, kpi-precision, scope-creep*, fact-forcing-preflight, l3-l4-consistency)
- [x] ticket close 链 0 跳点 — 全路径命中
- [x] boundary_violations = 0 (按 intent, scope-creep 工具局限 EPIC-053-F 修)
- [x] LESSONS-LEARNED.md 沉淀 6 lessons (跟 EPIC-053-A 6 lessons 对齐)

---

## 与 EPIC-053 系列接口

| Ticket | 责任 | 跟 EPIC-053-E 联动 |
|--------|------|--------------------|
| EPIC-053-A | 治 BE-9 (l3-l4-consistency 实现 + preflight 联动) | 本工单 verify-only, 不重复改 |
| EPIC-053-B | 5-Level 证据链 pass-report | 用 5 调用点 验证信号 |
| EPIC-053-C | KPI X/Y 格式 | 6/6 PASS = 100.0% 精确格式 |
| EPIC-053-D | 5 levels (L1-L5) | strong-verify-6d L4 加 l3-l4-consistency |
| EPIC-053-F | check-scope-creep glob bug fix + test 重命名 | 本工单 L6 引用其 fix |

---

**跟主公 §2 explicit 拍板 联合, 跟"诚实修正" 联合, 跟"反讽" 闭环, 跟 Rule 6/8/9/14/15/16/18 联合, 跟 v1.2.4 5 扩展组 联动, 跟 EPIC-053-A/B/C/D/F 系列 联合.**
