# EPIC-053-A — LESSONS LEARNED

> L3 集成测试 vs L4 verify 一致性检查 (治 H2 / BE-9)
> 跟 Rule 6 (事后复盘) 联合, 跟 Rule 8 (4-Level Fact-Forcing) 联合

---

## L1 — 矛盾即自检漏洞, 必须硬约束

**问题**: L3 (集成测试) 跟 L4 (verify 脚本) 出现矛盾 (L3 pass + L4 fail) 时, 传统做法是"以 L4 为准"或"重跑 L3", 但这恰好给防御体系自检漏洞开了口子 — 当 verify 系统本身出 bug 时, 没人能发现.

**根因**: 没有强制约束 L3 L4 的一致性. 单边 signal 被信任, 矛盾被掩盖.

**修法**: `l3-l4-consistency.sh` 把矛盾作为 ERROR 硬约束, exit=1. 同状态 (pass+pass, fail+fail) 才是 OK. 这把"自检漏洞"从无声掩盖变成显式失败.

**Rule 联动**: Rule 8 (4-Level Fact-Forcing) — L3 + L4 不许矛盾.

---

## L2 — 4-Level Fact-Forcing 的关键不是 L1/L2, 是 L3↔L4

**洞察**: Rule 8 的核心约束在 L3 (集成) 跟 L4 (verify) 的**互证**, 不是 L1/L2 单层. 单层 pass 容易, 双层互证才能抓出"defense system lying about its own checks".

**应用**: 任何 verify 工具的 PASS 都需要至少一个独立 signal 互证. l3-l4-consistency 正是这个互证机制的最小可执行版本.

**Rule 联动**: Rule 8 L3+L4 联合.

---

## L3 — Truth table 必须显式编码, 不能靠 if/else 散落

**反模式**: 散落的 if/else 判定一致性容易遗漏 case. 比如漏掉 fail+fail 的"双失败"也可能掩盖真实问题.

**修法**: 显式 truth table:

```
       L3 PASS   L3 FAIL
L4 PASS  OK      ERROR
L4 FAIL  ERROR   OK
```

写在脚本注释里 + 实现里都明确出现. 测试覆盖全部 4 个 cell.

**Rule 联动**: TDD 4/4 = 100.0% 精确格式 (Rule 9 KPI 联合).

---

## L4 — Preflight 必须是 framework 自我检查, 不是单工具拼凑

**洞察**: 4 个 anti-fab 工具 (check-test-case-isolation, check-kpi-precision, check-scope-creep, check-fact-forcing-preflight) 不是孤立的, 它们构成**一个防御体系**. preflight 必须验证体系完整, 不是单工具 PASS.

**修法**: `check-fact-forcing-preflight.sh` 做 6 项检查: 4 工具可执行 + l3-l4-consistency 双向 self-test (PASS/PASS=OK, PASS/FAIL=ERROR). 任一失败 ⇒ preflight FAIL ⇒ 整个体系不可信.

**Rule 联动**: Rule 8 (4-Level), Rule 18 (黑名单 #6 — 自检漏洞).

---

## L5 — 边界约束: 不复制其他 anti-fab 工具的实现

**约束**: 4 个 anti-fab 工具各有专长 (isolation, kpi, scope, preflight). `l3-l4-consistency` 是新维度 (L3↔L4 一致性), 不能复制粘贴其他工具的检测逻辑. 命名/风格/退出码约定参考, 实现从零写.

**Rule 联动**: DRY + Single Responsibility.

---

## 与 EPIC-053-B/C/D 的接口

| Ticket | 责任 | 跟 EPIC-053-A 联动 |
|--------|------|--------------------|
| EPIC-053-B | 4-Level 证据链 pass-report | 用 `l3-l4-consistency` 验证 pass-report 信号一致 |
| EPIC-053-C | KPI X/Y 格式 | 跟 `check-kpi-precision` 联动 |
| EPIC-053-D | Master 强验证 6 维度 | 强验证 L3 跑 test, L4 跑 preflight, 一致性 OK |

---

## 防 BE-9 复发 checklist

- [ ] l3-l4-consistency.sh 可执行 ✓
- [ ] tests/integration/l3-l4-consistency-test.sh 4/4 PASS ✓
- [ ] check-fact-forcing-preflight.sh 6/6 PASS ✓
- [ ] preflight 在所有 L4 verify gate 前跑
- [ ] 任何 ticket 报 PASS 前 preflight 必须 OK
- [ ] 矛盾出现 ⇒ 立即 ticket REJECT, 不允许"重试到一致"绕过
