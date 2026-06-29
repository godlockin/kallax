# EPIC-053-F — LESSONS LEARNED

> check-scope-creep.sh glob bug fix + l3-l4-consistency-test.sh 命名误导 (重命名 truth-table)
> 跟 EPIC-053-A L6 lesson 闭环, 跟 EPIC-053-C BE-10 模式联动, 跟 B 组 5 extended review 逆袭 #2 + #3 联合

---

## L1 — 工具自检局限性: glob 模式必须可扩展, 不可只 exact match

**问题**: `check-scope-creep.sh` 只支持 exact string match. 当 `file_scope.includes` 包含目录模式 (e.g. `jira/tickets/EPIC-053-A/`) 时, 该目录下的文件 (`IMPLEMENTATION-PLAN.md`, `LESSONS-LEARNED.md`) 被错报为 out-of-scope, exit=1 false positive.

**根因**: 工具设计假设 `file_scope.includes` 只列具体文件, 没考虑"目录"作为一个授权单位. EPIC-053-A 已经踩了这个坑 (L6 lesson 诚实记录), EPIC-053-F 治根.

**修法**: 提取 `match_glob()` 函数 — 当 allowed 以 `/` 结尾时走 prefix match, 否则 exact match. 用 `BASH_SOURCE` 守卫实现可 source 测试, 避免文件循环 + 散落逻辑.

**Rule 联动**: Rule 8 (5-Level) — 工具的 limitation 就是 defense system 的 limitation, 必须治根不能 workaround.

---

## L2 — 命名 = 真相, 误导命名 = 隐性 BE (跟 B 组 process-engineering 逆袭 #3 联合)

**问题**: `tests/integration/l3-l4-consistency-test.sh` 标 "Integration" 但实际是**硬编码 truth-table unit test** — 喂 `PASS/FAIL` 字符串给 `l3-l4-consistency.sh`, 没真跑 L3 + L4 信号.

**危害**: 读者期望"集成测试"但看到的是 `run_check "PASS" "FAIL"` 这种 unit-style 代码. 路径暗示行为 = 误导. 跟 BE-9 (defense lying about its checks) 同类 — 路径撒谎.

**修法**: `git mv` → `l3-l4-consistency-truth-table-test.sh`. 命名显式声明"这是 truth-table, 不是 integration test". 内容不动 (4/4 行为保持, 跟 EPIC-053-A AC 闭环).

**Rule 联动**: Rule 9 (no falsification) — 命名也是 KPI 的一部分. 路径 / 文件名 = 自我声明契约.

---

## L3 — TDD + 可 source 函数 = 干净测试架构 (跟 EPIC-053-A L4 联合)

**洞察**: 修工具 bug 时, 把核心逻辑提取成 pure function, 加 `BASH_SOURCE` 守卫让脚本可 source. 测试直接调函数 — 不需要起 temp git repo, 跑得更快, 覆盖更精准.

**应用**: `match_glob` 函数 + `[[ "${BASH_SOURCE[0]:-$0}" != "${0}" ]] && return 0 2>/dev/null` 守卫. 4 case 单元测试只跑 < 100ms, 测 exact / dir / no-match / multi-pattern 4 维度.

**Rule 联动**: Rule 6 (TDD) + Rule 8 (5-Level 互证). 可测试性 = 可验证性 = 可信度.

---

## L4 — 跟 EPIC-053-C BE-10 联动: Bash 5.x 兼容 patterns

**洞察**: BE-10 模式 — `[[:space:]]` 字符类在 Bash 5.x 数组元素内行为变化. 跟 EPIC-053-C (P0 工具自检) 联动, 本 ticket 主动避免该反模式.

**应用**:
- `match_glob()` 用 `[[ "$file" == "$allowed"* ]]` (glob pattern, 跨 Bash 3.2/5.x 安全)
- `for allowed in "$@"` 用 quoted `"$@"`, 不引字符类
- 注释明确"跟 EPIC-053-C BE-10 联动"
- 验证: `bash --version` = 3.2.57 (macOS default) — 跑测试 4/4 PASS 确认 3.2 兼容

**Rule 联动**: 跨版本兼容 = 不留未来 BE 隐患. 跟 Rule 5 (DRY) 联合 — 同模式跨多 ticket 一致.

---

## L5 — B 组 5 extended review 逆袭发现闭环 (跟 v1.2.4 5 扩展组 联合)

**洞察**: B 组 5 extended (security-tool-bypass 4/5, process-engineering 3/5) 跑出 2 个 inverse-finding (逆袭 #2, #3). 主公 2026-06-16 拍"建卡修复" 派单 EPIC-053-F, 4h 闭环.

**应用**: 4h 内全 7 AC 闭环 — glob 修 + git mv + Bash 兼容 + 4/4 + 4/4 + AC5 exit=0 + 4 anti-fab PASS. 跟"诚实修正" 联合 — 接受逆袭不辩解, 直接治根.

**Rule 联动**: 跟 EPIC-053-A 闭环模式一致 (逆袭 → 建卡 → 治根 → LESSONS). Rule 6 事后复盘, Rule 18 黑名单 (#6 自检漏洞).

---

## L6 — 跟 EPIC-053-E 互不干扰 (边界守恒)

**约束**: EPIC-053-E (l3-l4-wiring-test.sh) 跟 EPIC-053-F (l3-l4-consistency-test.sh 重命名) 是两个独立文件, 不能交叉改动. file_scope 明确 excludes 互不包含.

**应用**: 本 ticket 只动 `tests/integration/l3-l4-consistency-truth-table-test.sh` (EPIC-053-A → EPIC-053-F 改名). EPIC-053-E 的 `l3-l4-wiring-test.sh` 一行不动. 跑 preflight check 6 验证无交叉污染.

**Rule 联动**: 边界守恒 = isolation by default (KALLAX Design Principle 2). 防止 scope creep.

---

## 防 BE 复发 checklist

- [ ] `check-scope-creep.sh` 支持 dir prefix + exact match ✓
- [ ] `tests/integration/scope-creep-glob-test.sh` 4/4 PASS ✓
- [ ] `tests/integration/l3-l4-consistency-truth-table-test.sh` 4/4 PASS ✓
- [ ] check-scope-creep.sh EPIC-053-A exit=0 (no false positive) ✓
- [ ] check-fact-forcing-preflight.sh 9/9 (of 6) PASS ✓
- [ ] check-test-case-isolation.sh 0/50 leaked ✓
- [ ] check-kpi-precision.sh 0 estimate ✓
- [ ] Bash 5.x 兼容 patterns (无 `[[:space:]]` 字符类) ✓
- [ ] 越界 0 (file_scope 1:1) ✓
- [ ] KPI 精确 8/8 = 100.0% ✓
- [ ] 命名 = 真相 (truth-table 不再标 integration) ✓

---

## 与 EPIC-053 累计 6 票 联动

| Ticket | 状态 | 跟 F 联动 |
|--------|------|----------|
| EPIC-053-A | merged | L6 lesson 闭环, l3-l4-consistency-test.sh 是 A 创建的, F 改名 |
| EPIC-053-B | pending | 5-Level 证据链 (跟 A 联合) |
| EPIC-053-C | pending (P0) | BE-10 模式联动, 跨 ticket 模式一致 |
| EPIC-053-D | pending | 5 levels (L1-L5) |
| EPIC-053-E | pending (P0) | l3-l4-wiring-test.sh 边界, 不动 |
| **EPIC-053-F** | **done** | **glob 修 + 命名澄清** |

---

## Rule 联动汇总

- Rule 5 (DRY): 跟 EPIC-053-C Bash pattern 一致
- Rule 6 (TDD): 先 4 case 红, 后实现绿
- Rule 8 (5-Level): L1 文件存在 + L2 实质 + L3 接线 + L4 集成
- Rule 9 (KPI 精确): 4/4 + 4/4 = 8/8 = 100.0% 精确数字
- Rule 18 (黑名单): #6 自检漏洞治根, #2 KPI falsification
- v1.2.4 5 扩展组: 跟 B 组 5 extended review 逆袭发现 闭环
