# EPIC-245 — heartbeat-daemon-runtime.test.sh 修不稳定 (16/16 0 fail)

- **日期**: 2026-08-10
- **拍板**: 主公 ("继续")
- **前置**: EPIC-244 §6 标记 "heartbeat-daemon-runtime.test.sh 不稳定, 需另开 EPIC 修"
- **版本**: v3.34.19

## 1. 为什么

EPIC-244 §6 记录: 同一份代码两天跑出不同 pass/fail 组合.

| 维度 | v1 (2026-08-09, EPIC-228) | v2 (2026-08-10, EPIC-244) |
|---|---|---|
| 结果 | 15 pass, 2 fail | 16 pass, 1 fail |
| fail 项 | TC8 (`L4=2` 写死断言) | TC6 (`heartbeat-daemon.log` not found) |

## 2. 实测根因: 测试写死了不该写死的值

### 2.1 TC8 写死 `L4=2`

```
$ bash scripts/scan-dead-code.sh > /dev/null 2>&1
$ echo $?
0     ← 主仓库 node_modules 在, 全 stage 跑通, 返回 0
```

`scan-dead-code.sh` 退出码契约 (P0-7 治理):
- `0` = PASS (全阶段跑通)
- `1` = FAIL (真违规)
- `2` = BLOCKED-env (node_modules 缺失, 阶段跳过)

测试写死 `L4=2`, 假设永远 BLOCKED-env. 但**主仓库有 node_modules → L4=0 → 误报 fail**.

### 2.2 TC6 假设 `heartbeat-daemon.log` 存在

测试 TC1-TC5 都是**直接调用** `quota.sh` / `scheduler-hint.sh` / `run-history.sh`, **从不实跑 daemon**. `heartbeat-daemon.sh` 里 `LOG_FILE="${STATE_DIR}/heartbeat-daemon.log"` 只在 daemon 长跑时写.

所以 TC6 检查这个文件 = **永远 fail** (除非环境里恰好有历史残留).

v1 时该文件存在 (之前 daemon 跑过留下的), v2 时被清掉了 → 同一测试两次结果不同.

## 3. 修法

### 3.1 TC6: 去掉 daemon log 假设

```diff
-echo "TC6: state persistence"
-for f in heartbeat-daemon.log quota-db.json run-history.jsonl; do
+# 注: heartbeat-daemon.log 仅在 daemon 长跑时生成, 测试不实跑 daemon.
+echo "TC6: state persistence (daemon log excluded — test doesn't run daemon long)"
+for f in quota-db.json run-history.jsonl; do
```

`quota-db.json` 跟 `run-history.jsonl` 是 TC2-TC5 真实生成的, 检查它们有意义.

### 3.2 TC8: L4 接受 0 或 2, 只拒 1

```diff
-L4=$(bash ".../scan-dead-code.sh" > /dev/null 2>&1; echo $?)
-if [ -n "$L1" ] && [ -z "$L2" ] && [ "$L4" = "2" ]; then
+L4_cwd=$(bash ".../scan-dead-code.sh" > /dev/null 2>&1; echo $?)
+L4_repo=$(cd ".../.." && bash "scripts/scan-dead-code.sh" > /dev/null 2>&1; echo $?)
+if [ -n "$L1" ] && [ -z "$L2" ] && [ "$L4_cwd" != "1" ] && [ "$L4_repo" != "1" ]; then
```

跑两次 (当前 cwd + 仓库根), 两次都不能是 `1`. `0` 跟 `2` 都算 pass.

## 4. 实跑证据

### 4.1 worktree 内 (无 node_modules → L4=2)

```
$ bash tests/integration/heartbeat-daemon-runtime.test.sh
TC6: state persistence (daemon log excluded — test doesn't run daemon long)
  ✓ quota-db.json exists (3 bytes)
  ✓ run-history.jsonl exists (...)

TC8: 5-Level Verify L1-L5
  ✓ L1 git + L2 build + L4 (0=PASS 或 2=BLOCKED-env, 实际 L4_cwd=2 L4_repo=2)

===============================================
  EPIC-168-F: 16 pass, 0 fail
===============================================
```

### 4.2 主仓库内 (有 node_modules → L4=0)

```
$ bash tests/integration/heartbeat-daemon-runtime.test.sh
TC8: 5-Level Verify L1-L5
  ✓ L1 git + L2 build + L4 (0=PASS 或 2=BLOCKED-env, 实际 L4_cwd=0 L4_repo=0)

  EPIC-168-F: 16 pass, 0 fail
```

**两种环境都 16/16 0 fail** — 这才是修法正确的证据 (L4=0 跟 L4=2 都通过).

### 4.3 三次演进

| 版本 | 环境 | 结果 | fail 项 |
|---|---|---|---|
| v1 (EPIC-228) | 主仓库 | 15/17 | TC8 (L4 实际 0, 断言要 2) |
| v2 (EPIC-244) | 主仓库 | 16/17 | TC6 (daemon log 被清) |
| **v3 (本 EPIC)** | **worktree (L4=2)** | **16/16** | **无** |
| **v3 (本 EPIC)** | **主仓库 (L4=0)** | **16/16** | **无** |

## 5. EPIC-168-F ticket

`status` 已由 EPIC-244 判 `done` (证据: 16/17 pass, 1 fail 是环境假设). 本 EPIC 追加 `_audit_history` 3 版本记录, **不改 status**.

## 5. 附带修: pre-commit hook 静默 abort (跟 EPIC-232 bug 3 同型)

提交本 EPIC 时 hook 在 `check-claim-evidence: PASS` 后**静默返回 1**, 无任何 fail 原因:

```
$ git commit -F <msg>
PASS: record_authz_event
WARN: check-scope-creep skipped
check-claim-evidence: scanning 2 staged file(s)...
check-claim-evidence: PASS
RC=1        ← 无输出, 无原因
```

`bash -x` trace 定位到停在:

```
+ bash .../scripts/verify/check-ticket-schema.sh EPIC-168-F
```

单独跑:

```
$ bash scripts/verify/check-ticket-schema.sh EPIC-168-F
ARCHIVED_SKIP: EPIC-168-F (num=168 <= archived_before=222)
  历史 EPIC 不回溯
RC=3
```

**根因**: hook 里写法是

```bash
bash "$TICKET_SCHEMA_CHECK" "$_epic" >/dev/null 2>&1
_rc=$?
if [[ "$_rc" -eq 1 ]]; then   # exit 3 = ARCHIVED_SKIP → 放行
```

分支判断**是对的** (只在 `_rc -eq 1` 时 fail). 但 `set -euo pipefail` 下, 命令返回 3 时脚本**在 `_rc=$?` 之前就中断**了 — 那行永远执行不到.

跟 **EPIC-232 bug 3 同型** (`jq` exit 2 在 `set -e` 下中断, 友好报错打不出来).

**修法**:

```diff
+_rc=0
-bash "$TICKET_SCHEMA_CHECK" "$_epic" >/dev/null 2>&1
-_rc=$?
+bash "$TICKET_SCHEMA_CHECK" "$_epic" >/dev/null 2>&1 || _rc=$?
```

**验证**: 本 EPIC 的 commit `a5eb0ddf` **0 bypass 0 --no-verify** 走通全部 gate — 这就是端到端证明.

同文件扫了一遍, 只此 1 处 `cmd; _rc=$?` 模式.

## 6. 影响

**正面**:
- 测试在两种环境 (有/无 node_modules) 都稳定 16/16
- "测试不稳定" 标签解除
- `L4=1` (真违规) 仍会 fail — 没放松真实检查

**代价**:
- TC6 少检查 1 个文件 (但那个检查本来就无意义)
- TC8 从"精确断言 2"变成"排除 1", 判定宽松了一点 — 但符合 `scan-dead-code` 的三态契约

## 7. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| L4 接受 0/2 放宽检查, 真违规漏过 | 低 | `L4=1` 仍 fail, 那才是真违规 |
| 其他测试有类似写死假设 | 中 | 未系统扫描, 留待发现 (可另开 EPIC) |
| daemon 真跑路径永远没测 | 中 | TC1-5 覆盖各子命令, 但 daemon 主循环确实没端到端跑过 |

## 8. 未验证

- **CI 环境跑该测试** — 本地两种环境都 16/16, CI 应该也过 (L4 会是 2, 已接受)
- **其他测试的写死假设** — 未系统扫描
- **daemon 主循环端到端** — 本 EPIC 不加这个测试 (需长跑 60s, 另开 EPIC)

## 9. 教训

**测试写死假设是常见债**:

| 反例 | 后果 | 正确做法 |
|---|---|---|
| 断言 `L4 = 2` | 环境变了就误报 | 先实测 baseline, 再决定断言范围 |
| 断言某文件存在 | 该文件其实不由被测代码生成 | 只断言被测路径真实产出的东西 |

下次写测试**先跑一遍看真实值**, 再写断言 — 跟 Rule 34 独立复现的要求同一个道理.

## 10. 串联

- **EPIC-244 §6**: 标记问题 → 本 EPIC 修
- **EPIC-168-F**: ticket 已 done (EPIC-244 判), 本 EPIC 追加 audit_history
- **EPIC-131/132**: `scan-dead-code.sh` 三态退出码契约来源
- **Rule 34**: 独立复现 — 先实测再断言

## 11. 0 增 Rule, 0 改 Immutable, 0 改 CLAUDE.md

仅 test 断言修 + ticket audit_history + 本文档.
