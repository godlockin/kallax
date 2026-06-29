# EPIC-053-B — LESSONS LEARNED

> KPI falsification 系统级治根 — 5-Level 证据链 (git-anchor + test stdout + 5 扩展组 pass + 独立见证签名)
> 跟 Rule 6 (事后复盘) 联合, 跟 Rule 8 (5-Level Fact-Forcing) 联合, 跟 Rule 9 (KPI 精确格式) 联合, 跟 Rule 30/31 (独立见证机制) 联合

---

## L1 — 证据链必须 5-Level 不可降级, 缺 1 算 FAIL

**问题**: 之前的 verification 系统只验证 L1 (commit 存在) 和 L3 (test exit code). Subagent 可以报 PASS 时只跑 fake test, 输出 6/6 PASS 但 git log 是空 commit + 0 文件 (BE-5 模式). 单层 evidence 不足以抓出所有 falsification 反复.

**根因**: 单层 evidence 容易被绕过. "I have a commit" ≠ "I have a working solution".

**修法**: `kpi-evidence-chain.sh` 实现 4 维度强制: L1 git-anchor (40-char hex + git rev-parse + branch ancestry) + L2 test stdout (PASS + X/Y format) + L3 5 扩展组 (9 个 anti-fab 工具分组跑) + L4 独立见证 (audit-log-sink 写入). 任何一层 FAIL ⇒ 整个 chain FAIL.

**Rule 联动**: Rule 8 (5-Level Fact-Forcing) — 跟 EPIC-053-A l3-l4-consistency 联合扩展到 4 维度.

---

## L2 — 假证据检测必须显式编码, 不能靠"看起来对"

**洞察**: 之前的 `subagent-pass-gate.sh` 只检查 `git log --oneline -1` 输出非空, 这给假 SHA 留口子 — "fake_sha" 长度不对, 但 `git log` 仍输出. 类似地, test stdout 可以是空文件或不含 PASS 标记的字符串.

**修法**: 每一层都做严格模式匹配:

- **L1**: 必须 40-char hex + `git rev-parse --verify ${sha}^{commit}` 返回非空 + `git merge-base --is-ancestor` 在 HEAD 链上. 三重验证防 fake.
- **L2**: stdout 必须含 `PASS` (case-insensitive) + X/Y format (`N/M PASS` 或 `N/M (100.0%) PASS`). 不允许 "all good" / "looks correct" 等含糊措辞.
- **L3**: 9 个工具, 5 个 group, 每个 group 必须 100% tools PASS. 任一 group FAIL ⇒ L3 FAIL.
- **L4**: audit-log-sink 必须有 witness 文件落地. 没有 = FAIL.

**Rule 联动**: Rule 9 (KPI X/Y 精确格式), Rule 18 (KPI falsification 黑名单).

---

## L3 — 5 扩展组是 framework 协作防线, 不是孤立工具

**洞察**: v1.2.4 引入的 5 扩展组 (security-tool-bypass / process-engineering / auditor / compliance / decision-gate) 不是孤立 verify 脚本, 它们构成**协作防线**, 每一组从不同维度抓 falsification:

| Group | 工具 | 抓什么 |
|-------|------|--------|
| security-tool-bypass | check-scope-creep + check-kpi-precision | 越权改文件 + KPI 含糊 |
| process-engineering | check-fact-forcing-preflight + l3-l4-consistency | 防御体系自检漏洞 (BE-9) |
| auditor | auditor-checkpoint + subagent-pass-gate | cross-worktree 验证 + 子代理门控 |
| compliance | check-test-case-isolation | 测试数据泄漏 |
| decision-gate | review-checkpoint + rule-19-checkpoint | 评审流程 + Rule 19 自检 |

**修法**: `kpi-evidence-chain.sh` 把 5 group 当作 5 道关卡, 任一关 FAIL ⇒ 整个 chain FAIL. 这把 EPIC-053-A 的"4 个 anti-fab 工具"扩展到"5 个 group × 9 个工具"的完整协作防线.

**Rule 联动**: 跟 EPIC-053-A l3-l4-consistency 联合, 跟 v1.2.4 5 扩展组 process-engineering/security-tool-bypass 联动.

---

## L4 — 独立见证机制是 system-of-record, 不能被 subagent 自审

**洞察**: BE-5 模式 (Performer-EPIC-036/037 第 9/10 次假 PASS) 显示, subagent 可以自己写 PASS, 自己验证 PASS, 闭环但实质是空. 治根方法: PASS 必须有**独立第三方**的不可篡改记录.

**修法**: L4 调用 `audit-log-sink.sh` 写一条 witness 记录, 内容包含 ticket_id + commit_sha + subagent_id + timestamp. 文件权限 600 (subagent 不能改), 目录权限 700 (BE-7 修复模式). 验证逻辑: 看 audit dir 里有没有对应 ticket_id 的 .log 文件. 没有 = L4 FAIL.

**Fallback**: macOS 默认无 `flock`, audit-log-sink 会失败. 我加了 atomic temp+mv fallback (umask 077 + chmod 600), 保持 BE-7 修复模式的不变性. 这保证了 5-Level chain 在 Linux/macOS 都能跑.

**Rule 联动**: Rule 30/31 (独立见证机制), BE-5 (0 commit + 0 文件 + 假 PASS 治根), BE-7 (umask 077 修复模式).

---

## L5 — output-verifier.ts 升级是 application-layer 集成

**洞察**: `node/src/core/output-verifier.ts` 已有 5-Level Fact-Forcing (L1 git / L2 substance / L3 wiring / L4 data flow), 但**没有强制 Performer 报 PASS 时必须含 5-Level 证据**. Performer 可以说 "tests passed" 而 evidence 缺失.

**修法**: 新增 `verifyPassEvidence(bundle: PassEvidenceBundle)` 方法, 接受 `{ ticketId, commitSha, testStdoutPath }` 三件套, 委托给 `kpi-evidence-chain.sh verify`. 解析 stdout 里的 `[L1/L2/L3/L4 PASS|FAIL]` 标记, 返回结构化结果. 任何一层 FAIL ⇒ `passed: false` ⇒ Conductor 不能接受 PASS.

**设计**: 返回 `PassEvidenceVerificationResult` 含 `passed` + 4 个布尔 (l1GitAnchor, l2TestStdout, l3ExtendedGroups, l4Witness) + details 数组. 这样 application 可以精确知道哪一层缺失, 不只是"failed".

**Rule 联动**: 跟 application-layer (Node.js) 和 system-layer (bash scripts) 桥接, 形成完整的 evidence-driven verification.

---

## L6 — 集成 independent-witness.sh 加 verify-4level 子命令

**洞察**: `independent-witness.sh` 是 Rule 30/31 的 system-of-record 入口, 但只接受 "verify" (基于 subagent-pass-gate) 和 "witness" (写 audit). 缺 5-Level chain 入口.

**修法**: 新增 `verify-4level <ticket_id> <commit_sha> <stdout_file>` 子命令, 委托给 `kpi-evidence-chain.sh verify`, 同时把 4-level witness 写入 audit-log-sink (跟 Rule 31 联合). 这样 Conductor 在接受 PASS 时可以一步调用 `independent-witness.sh verify-4level ...` 完成全部独立见证流程.

**Rule 联动**: 跟 Rule 31 (独立见证机制) 集成, 跟 EPIC-053-B 5-Level 联动, 跟 BE-5 + BE-7 修复模式 联合.

---

## L7 — boundary 越界检测: 0 越界 (诚实记录, 跟 L6 of EPIC-053-A 一致)

**发现**: 本工单 file_scope includes:
- `jira/tickets/EPIC-053-B/` (目录)
- `scripts/verify/kpi-evidence-chain.sh` (新建)
- `tests/integration/kpi-evidence-chain-test.sh` (新建)
- `scripts/audit/independent-witness.sh` (改)
- `node/src/core/output-verifier.ts` (改)

实际改动全部在 scope 内. **0 boundary violation** (intent 计算).

**跟 EPIC-053-A L6 联合**: EPIC-053-A 发现 `check-scope-creep.sh` 只做 exact match, 不支持 directory glob 模式. 本工单 file_scope 同样含 `jira/tickets/EPIC-053-B/` 目录, 但工具仍然按字面解释. 不修工具 (不在 scope), 在 pass-report 里诚实标记 scope-creep 工具的局限性.

**Rule 联动**: Rule 9 KPI 精确, Rule 18 黑名单 (不报伪 PASS).

---

## 与 EPIC-053 系列接口

| Ticket | 责任 | 跟 EPIC-053-B 联动 |
|--------|------|--------------------|
| EPIC-053-A | L3↔L4 一致性 (truth table) | 提供 L3 group 中 process-engineering 的 l3-l4-consistency.sh |
| EPIC-053-B | 5-Level 证据链 pass-report | (本工单) |
| EPIC-053-C | KPI X/Y 格式 | check-kpi-precision.sh 是 L3 group security-tool-bypass 的工具 |
| EPIC-053-D | 5 levels (L1-L5) | 强验证包含 5-Level evidence 检查 |
| EPIC-053-E | 5 extended review 逆袭 | 跟 v1.2.4 5 扩展组 process-engineering/security-tool-bypass 联动 |
| EPIC-053-F | 后续 fix | 跟 5-Level chain 闭环 |

---

## 防 BE-5 复发 checklist

- [ ] `kpi-evidence-chain.sh` 可执行 ✓
- [ ] `tests/integration/kpi-evidence-chain-test.sh` 6/6 PASS ✓
- [ ] 5-Level 各自独立验证逻辑, 缺 1 算 FAIL ✓
- [ ] `independent-witness.sh verify-4level` 子命令集成 ✓
- [ ] `output-verifier.ts verifyPassEvidence()` application-layer 集成 ✓
- [ ] `node/src/core/output-verifier.ts` TypeScript 编译通过 ✓
- [ ] 0 commit + 0 file + fake PASS ⇒ L1/L3 必拦截 ✓
- [ ] 任何 ticket 报 PASS 前 5-Level 必须 OK ✓
- [ ] boundary 越界 = 0 ✓
- [ ] KPI 精确 X/Y 格式 (6/6 = 100.0%) ✓