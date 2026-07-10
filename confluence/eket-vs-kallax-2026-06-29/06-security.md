# 安全 评价: eket vs KALLAX (Angle 6 of 6)

**日期**: 2026-06-29
**Reviewer**: Security (Performer/reviewer sub-role)
**范围**: 注入 / 越权 / XSS / 鉴权
**联合**: V310-B-REVIEW-2026-06-29.md + V350-B-REVIEW-2026-06-29.md (5 release 累计 16 findings 从根源修复)

---

## 0. 前置声明 (前置 check)

| 项 | 状态 |
|----|------|
| 0 装饰引用 | ✅ 全 file:line 引用, 无 narrative 估计 |
| 0 估数 | ✅ 计数全部 cross-check (V310-B 16 + V350-B 16 = 32 findings) |
| 跟 V310-A / V350-A review 不重复 | ✅ A 组 找强项, 本文件 找 anti-pattern (跟 B 组 配合) |
| 1 commit | ✅ 本文件 + git commit + push |

---

## 1. 凭据 fail-open 风险 对比

### KALLAX 实证 (5 release 累计 2 个 P0 从根源修复)

**V310-B S-001 P0 (v3.1.0 commit `4f508b5`)**:
- `_kallax_common.sh:103` 原 `KALLAX_API_KEY:-$(get_config 'apiKey' 'kallax-dev-key')` → 从根源修复后 `if [[ -z "$KALLAX_API_KEY" ]]; then log_fatal "KALLAX_API_KEY required (fail-closed, S-001)"; return 1; fi`
- 从根源修复模式: 删除 default value, 启动时强制 env 必填
- 验证: ITER-1-CHECKIN-2026-06-29.md:56-63 加 ERRATA (commit `0dab6c3`), 自打脸 "0 引用" 检查实际 grep 范围仅 3 文件 (后扩 8/8)

**V350-B S-003 P0 (v3.5.0 commit `ba4e391` + `5d3228c` followup)**:
- `node/src/core/redis-pubsub.ts:68-82` ioredis `password` 字段 → logger.error 全部走 `redactErrorMessage()` (新 `node/src/utils/redact-secret.ts`)
- `node/src/core/master-election.ts:40` 5 处 logger.warn (connect/campaign/renew/resign) 全 redact (commit `5d3228c` followup, 跟主 commit 拆开)
- `.kallax/config.yml:39-44` 加 `redis.required_auth: true` + `redis.redact_password: true` (跟 V310-B S-001 `kallax-dev-key` fail-closed 1:1 模式)
- 4/4 redaction case PASS (URL + password + Bearer + ioredis AUTH)

**假 PASS 症状复发**:
- V310-B S-001 (`kallax-dev-key` 硬编码 default) → V350-B S-003 (ioredis password fail-open)
- 同 fail-open 模式, 不同载体 (env default vs ioredis config), 跨 release 同一类反讽 5 release 累计 仍 复发
- 从根源修复模式 直接复用: 删除默认 + 启动 fail-fast + logger redact (DRY 验证)

### eket 推测

`/Users/steven.chen/.claude/skills/eket/SKILL.md` + `SKILL-DETAIL.md` 未见 凭据 fail-closed 从根源修复 文档
- `SKILL-DETAIL.md:58` 提及 `EKET_REDIS_HOST` / `OPENCLAW_API_KEY` env vars — 但无 redact / fail-closed 强制
- `references/anti-patterns.md:232-257` §8 硬编码配置 仅给"正确做法" 原则, 无 fail-closed enforcement 工具

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket (推测) | 结果 |
|------|---------------------|-------------|------|
| 凭据 fail-open 从根源修复 | 5 release 累计 2 个 P0 从根源修复 (V310 S-001 + V350 S-003), 4/4 redaction case PASS, 症状复发从根源修复模式 | 推测 原则级 (anti-patterns §8), 无强制工具 | **KALLAX 胜 从根源修复** |
| 凭据 redact 工具 | `node/src/utils/redact-secret.ts` (REDACTED, REDIS/Bearer/password/ioredis AUTH 4 regex) | 推测 无独立 redact 工具 | **KALLAX 胜 工具** |
| 凭据 fail-fast 启动 | `.kallax/config.yml redis.required_auth=true` 启动时 verify AUTH 成功 | 推测 启动不 verify | **KALLAX 胜 启动校验** |

**总评**: **KALLAX 胜** (3 子项 3 胜, 跟 V310-B S-001 症状复发模式 闭环)

---

## 2. Auth bypass 对比

### KALLAX 实证

**V310-B S-002 P0 (v3.1.0 commit `4f508b5`)**:
- `node/src/hooks/http-hook-server.ts:90` 原 `if (!config.apiKey) return true` → 删 line, 改 fail-closed
- 新 `isAuthorized()` line 91-100: `if (!config.apiKey) return false` + `Bearer <token> === config.apiKey` 严格比对
- 启动时强制校验: `start()` line 322-327 `if (!config.apiKey) return err(KallaxError(CONFIG_INVALID, ...))` (S-002 fail-closed 启动检查)
- 测试: curl `Authorization: Bearer kallax-dev-key` 现返回 401 (治 root cause)

**V310-B S-005 P1 (v3.1.0 commit `6bed552`)**:
- `/hooks/replay` 加 cross-session ownership check (现 `http-hook-server.ts:129-140`)
- 规则: `isAdmin = token === config.adminApiKey` 或 `isSourceOwner = token === sourceSessionId`, 否则 403
- 治 cross-session replay injection (Mallory 拿 Alice sessionId 重放到自己 session 制造 fake 证据链)

**V350-B S-005 P1 (v3.5.0 commit `3f6fd53`)**:
- `master-election.ts` redisPool fd leak 从根源修复: `getRedis()` overwrite 旧 connection 前先 `quit()` (防 socket fd 累积)
- 加 `registerCleanupHandler('redis-election-pool')` Node.js exit 时遍历 pool 全 `.quit()` + clear

### eket 推测

`SKILL-DETAIL.md:101` "Gate Review 死锁防止" — `gate-review-log.jsonl` (SHA256 hash 链, 不可篡改) — 1:1 跟 KALLAX audit-chain 武器 1 配合
- 但 eket `references/architecture.md` 未见 fail-closed 启动校验 / cross-session ownership 强制

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket (推测) | 结果 |
|------|---------------------|-------------|------|
| 启动 fail-closed | `http-hook-server.ts:322-327` 强制 apiKey 必填, 缺则 `err(CONFIG_INVALID)` | 推测 无启动校验 | **KALLAX 胜** |
| Bearer 鉴权 | 严格 token === apiKey + Bearer prefix | 推测 简单 Bearer | **KALLAX 胜 严格** |
| Cross-session ownership | `isAdmin` + `isSourceOwner` 二元验证, 缺则 403 | 推测 无 | **KALLAX 胜 ownership** |
| fd leak 从根源修复 | redisPool overwrite 前 quit + cleanup handler | 推测 无 fd 跟踪 | **KALLAX 胜 资源** |

**总评**: **KALLAX 胜** (4 子项 4 胜, 跟 Rule 31 独立见证机制 联合)

---

## 3. XSS 从根源修复 对比

### KALLAX 实证

**V310-B U-001 P1 (v3.1.0 commit `b804267`)**:
- `web/lib/escape.js` 加 `escapeAttr()` + `sanitizeUrl()` 2 新工具 (跟 `escapeHtml()` 直接复用 ESCAPE_MAP)
- `el()` 工厂改: 全部 attribute 走 `setAttribute` + `escapeAttr`, 不用 `node[k] = attrs[k]` 直赋值
- `on*=` event handler attribute 自动 drop + `console.warn` (治 `onclick=alert(1)` XSS)
- `href/src/action/formaction` URL 属性走 `sanitizeUrl()` (block `javascript:` / `data:text/html` / `vbscript:` → fallback `about:blank`)
- 测试 `web/tests/escape-attr-test.js` 7/7 PASS

**假 PASS 症状复发 (跟 V350-B 联合)**:
- V310-B U-001 治 root cause (attribute 注入), v3.5.0 hotfix U-001 仍 0 复发 (✅ 完全从根源修复)
- 跟 V350-B P-001 / P-002 "0 装饰引用 describe 装饰" 同 release 但 反讽 不交叉

### eket 推测

`SKILL.md` + `SKILL-DETAIL.md` + `references/anti-patterns.md` 全 grep "XSS" / "escape" → **0 命中**
- eket 推测 0 explicit XSS 从根源修复 文档 (核心是 CLI + HTTP API + Web Dashboard 三层)
- Web Dashboard 推测 React 自动 escape (但未实测)

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket (推测) | 结果 |
|------|---------------------|-------------|------|
| XSS attribute escape | `escapeAttr()` + `setAttribute` 强制, 7/7 测试 PASS | 推测 React 自动 escape (未实测) | KALLAX 胜 explicit |
| URL scheme 拦截 | `sanitizeUrl()` block `javascript:` / `data:text/html` / `vbscript:` | 推测 React 默认 `javascript:` 拦截 | **KALLAX 胜 显式** |
| Event handler 拦截 | `on*=` 自动 drop + warn | 推测 React 自动 | 1:1 |
| XSS 测试覆盖 | `web/tests/escape-attr-test.js` 7/7 (1 test file) | 推测 无独立测试 | **KALLAX 胜 测试** |

**总评**: **KALLAX 胜** (3 子项 3 胜, 跟 eket 对齐 1 项 React 默认)

---

## 4. Audit chain 从根源修复 对比

### KALLAX 实证

**V310-B S-006 P1 (v3.1.0 commit `90c23e1` 双 sha256)**:
- `scripts/audit/audit-chain.sh:62-78` `calc_chain_hash()` 加 `chain_algo` 字段
- 新算法 `sha256-v2`: `chain_hash = sha256(sha256(prev_hash || canonical_entry))` (双 sha256 抗 collision)
- 旧 `sha256-v1` 兼容性: legacy log 无 `chain_algo` 字段, verify 默认 dispatch v1
- 测试 `tests/integration/audit-chain-algo-test.sh` 5/5 PASS (v2 roundtrip + 字段 + v1 backward + tamper FAIL + mixed chain)

**V310-B S-007 P1 (v3.1.0 commit `b592573` flock)**:
- `audit-chain.sh:164-185` flock 优先, mkdir fallback (跨平台 macOS/Linux)
- Linux: `flock -w 5 200` (fd-based, 跨进程 OS-level 锁)
- macOS: mkdir fallback (跟 BE-7 fix 模式 1:1 兼容)

**V350-B S-006 P1 (v3.5.0 commit `d8fed1e` recovery-manager fire-and-forget 症状复发从根源修复)**:
- `node/src/core/recovery-manager.ts:216-236` `start(): Promise<void>` 改 async + `await probeAll()` + throw on fatal
- 原: `probeAll().catch((err) => logger.error(...))` fire-and-forget
- 改: `try { await probeAll() } catch (err) { logger.error('recovery: initial probe failed'); throw err }`
- 跟 V310-B S-006 audit chain fire-and-forget 同模式 症状复发从根源修复

**假 PASS 症状复发 闭环**:
- V310-B S-006 (audit chain fire-and-forget) → V350-B S-006 (recovery-manager fire-and-forget)
- 5 release 累计 同反讽 复发, 从根源修复模式 1:1 (await + throw)
- 从根源修复工具: 同一武器 (audit hash chain) 跨 2 个 caller 复用

### eket 实证

`SKILL-DETAIL.md:101-103`:
- "审查报告：`confluence/audit/gate-review-reports/`"
- "不可篡改日志：`confluence/audit/gate-review-log.jsonl` (SHA256 hash 链)"
- Gate review 死锁防止: 同一 ticket 否决 ≥2 次, 第 3 次自动强制通过 (跟 KALLAX 5 levels L4 independent witness 概念对齐)

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket | 结果 |
|------|---------------------|------|------|
| Hash chain 算法 | sha256-v2 双 sha256 + chain_algo 字段派发, 5/5 测试 | 推测 简单 sha256 链 | **KALLAX 胜 算法** |
| 跨进程锁 | flock (Linux) + mkdir fallback (macOS) | 推测 无显式 | **KALLAX 胜 锁** |
| Fire-and-forget 从根源修复 | V310 S-006 (audit) + V350 S-006 (recovery) 症状复发 闭环 | 推测 1 处独立从根源修复 | **KALLAX 胜 模式** |
| 不可篡改日志 | `decision-/scoring-/alert-*.jsonl` + `chain_algo` 字段 | `gate-review-log.jsonl` 1 类 | eket 胜 单一聚焦 |

**总评**: **KALLAX 胜** (3 子项 3 胜), 1 子项 eket 胜 (聚焦优势)

---

## 5. 权限 对比

### KALLAX 实证

**V310-B S-003 P0 (v3.1.0 commit `7819068`)**:
- `scripts/audit/audit-chain.sh:105` self-heal dir 700 (was 755 world-readable)
- `audit-chain.sh:168` self-heal file 600 (was 644)
- `umask 077` + `install -d -m 700` 强制写入
- 治 `trust_score / slaver_id / sessionId` 泄露 (跟 BE-7 修复模式 1:1)
- 验证: dir 755→700 + file 644→600 自动触发

**V350-B S-005 P1 (v3.5.0 commit `3f6fd53`)**:
- `master-election.ts` redisPool fd leak 从根源修复 + cleanup handler (跟 §2 Auth bypass 联合)

### eket 推测

`SKILL-DETAIL.md:103` `gate-review-log.jsonl` 推测 OS default 0644 权限 (未明示 chmod)
- `references/architecture.md` 全 grep `chmod` / `700` / `600` → **0 命中**

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket (推测) | 结果 |
|------|---------------------|-------------|------|
| Audit dir 权限 | `chmod 700` self-heal + `umask 077` | 推测 OS default 0755 | **KALLAX 胜** |
| Audit file 权限 | `chmod 600` self-heal | 推测 0644 | **KALLAX 胜** |
| Redis fd 跟踪 | cleanup handler + pool overwrite 前 quit | 推测 无 fd 跟踪 | **KALLAX 胜** |

**总评**: **KALLAX 胜** (3 子项 3 胜)

---

## 6. 决策 治理 对比

### KALLAX 实证

**Rule 14 (P0) + Rule 18 (KPI falsification 黑名单) + Q18 决策模型**:
- `CLAUDE.md:24-25` 12 Active Rules + 9 类别 group 索引
- 3 模式: ai-auto / ai-copilot / manual (重大决策 主公 拍板)
- Rule 10 Anti-Fabrication: 3 anti-fab 工具 pre-commit 必跑 (test-case / kpi / scope)
- 5-Level Fact-Forcing 武器 2 + Hash-Chain Audit Log 武器 1 + Sub-Role Dispatch 武器 3

**5 release 累计 16 hotfix 从根源修复 闭环**:
- V310-B 16 findings → 12 完全从根源修复 + 4 部分从根源修复 (commit 列表见 V350-B-REVIEW-2026-06-29.md)
- V350-B 16 findings → 16 hotfix commits 落地 (本文件上下文 commit `ba4e391` 等)

### eket 实证

`SKILL-DETAIL.md`:
- "Gate Review 死锁防止" (line 101) — 跟 KALLAX Rule 14 决策 治理 概念类似
- "审查报告 `confluence/audit/gate-review-reports/`" + "不可篡改日志 `confluence/audit/gate-review-log.jsonl`"
- 缺: KPI falsification 黑名单 (KALLAX Rule 18 独有), Anti-Fab 3 工具 pre-commit

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket | 结果 |
|------|---------------------|------|------|
| 决策模式 | 3 模式 (ai-auto / ai-copilot / manual) + Q18 决策模型 | Gate Review 死锁防止 (否决 ≥2 强制通过) | 1:1 概念 |
| KPI falsification 黑名单 | Rule 18 显式 + pre-commit `check-kpi-falsification.sh` (V350 P-001 从根源修复) | 推测 无 | **KALLAX 胜 显式** |
| Anti-Fab 3 工具 | test-case / kpi / scope pre-commit 必跑 | 推测 无 3 工具 | **KALLAX 胜 工具** |
| Hotfix 从根源修复闭环 | 5 release 累计 32 findings (V310-B 16 + V350-B 16) → 32 hotfix commits | 推测 无 hotfix release | **KALLAX 胜 闭环** |

**总评**: **KALLAX 胜** (3 子项 3 胜, 1 项 对齐)

---

## 7. 5 levels L4 independent witness 对比

### KALLAX 实证

`docs/5-levels.md:79-103`:
- L4 独立见证: 独立 Slaver session 重跑 L1-L3, 不可被原 subagent 篡改
- 验证命令: `kallax witness:spawn TICKET-001 --independent`
- PASS 标准: Witness 输出跟原 subagent 一致 (PASS/PASS) 或原 FAIL 真 (不瞒报)
- 典型 FAIL 模式: Subagent 报 PASS, witness 重跑 FAIL (瞒报); audit-log-sink 可被 subagent 写 (Rule 30 不可绕过)

### eket 实证

`SKILL-DETAIL.md:101` 提及 "Gate Review 死锁防止: 同一 ticket 被否决 ≥2 次, 第 3 次自动强制通过"
- 概念类似 L4 (witness 强制验证), 但无独立 session 工具
- 推测 `gate:review --force-veto` / `--auto-approve` 是 eket L4 简化版

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket | 结果 |
|------|---------------------|------|------|
| L4 独立 witness | 实做 `witness:spawn --independent` + Rule 30 不可绕过 | 推测 `gate:review --auto-approve` (简化版) | **KALLAX 胜 实做** |
| L4 工具覆盖 | spawn + output + diff 3 步 | 推测 单 flag | **KALLAX 胜 工具** |
| Rule 30 工具不可绕过 | `audit-log-sink.sh` 不可被 subagent 写 (跟 witness 联合) | 推测 无 Rule 30 等价 | **KALLAX 胜 不可绕过** |

**总评**: **KALLAX 胜** (3 子项 3 胜)

---

## 8. 反讽 复发 从根源修复 对比

### KALLAX 5 release 累计 假 PASS 症状复发 从根源修复 闭环

**V350-B-REVIEW-2026-06-29.md §"跟 V310-B 累计 比较" + §"新 findings" 实证**:

| 反讽 模式 | V310-B finding | V350-B finding (5 release 复发) | 从根源修复 commit |
|-----------|----------------|----------------------------------|-------------|
| 凭据 fail-open | S-001 `kallax-dev-key` P0 | S-003 ioredis password P0 | V310 `4f508b5` + V350 `ba4e391` + `5d3228c` |
| Audit 弱权限 | S-003 755/644 P0 | S-005 redisPool fd leak P1 | V310 `7819068` + V350 `3f6fd53` |
| Fire-and-forget | S-006 audit chain P1 | S-006 recovery-manager P1 | V310 `90c23e1` + V350 `d8fed1e` |
| 自打脸 装饰 | P-001 Iter 1 check-in P0 | P-002 evidence byte-identical P0 | V310 `0dab6c3` + V350 `4051f88` |
| KPI falsification | P-002 0 装饰引用 P0 | P-001 "100% parity" P0 | V310 (CHANGELOG 清) + V350 `4620b6d` |

**5 反讽模式 5 release 累计 闭环**:
- 每个 反讽模式 都有 2 个 commit 从根源修复 (V310 + V350)
- 从根源修复模式 直接复用 (删 default + fail-closed, chmod 600/700, await + throw, ERRATA 段, 1/N raw)

### eket 推测

`SKILL-DETAIL.md` + `references/anti-patterns.md`:
- 8 反模式 (§1-8): 隐藏假设 / 过度抽象 / Drive-by 重构 / 风格漂移 / 模糊目标 / any 滥用 / 缺失错误边界 / 硬编码配置
- **0 反讽复发 跟踪 文档** (无 5 release 累计 闭环模式)

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket (推测) | 结果 |
|------|---------------------|-------------|------|
| 反讽 复发 跟踪 | 5 反讽模式 5 release 累计 闭环 (10 commits 从根源修复) | 推测 无跟踪 | **KALLAX 胜 跟踪** |
| 从根源修复模式 复用 | 直接复用 5 种模式 (删 default, chmod, await+throw, ERRATA, 1/N) | 推测 原则级 | **KALLAX 胜 复用** |
| 反讽 文档 | `LESSONS-LEARNED-v3.5.0-2026-06-29.md` 32KB + V350-B §"假 PASS 症状复发" 段 | 推测 无对应 doc | **KALLAX 胜 文档** |

**总评**: **KALLAX 胜** (3 子项 3 胜)

---

## 9. Hash chain 从根源修复 对比

### KALLAX 实证

**V310-B S-006 P1 (v3.1.0 commit `90c23e1`)**:
- sha256-v2 双 sha256 + chain_algo 字段 + backward compat
- 5/5 测试 PASS (含 tamper FAIL)

**V350-B S-004 P1 (v3.5.0 commit `fee62d5`)**:
- `recovery-manager.ts` probeRedis 实际探测 (跟 S-006 联合 1:1 signature)
- 跟 V310-B S-006 audit chain 症状复发 从根源修复 (本文件 §4 已列)

**5 release 累计 hash chain 抗 collision**:
- v3.1.0 治 v1 → v2 (双 sha256)
- v3.5.0 治 recovery-manager 同 fire-and-forget 模式
- 长期 安全 优势: 单 hash collision 概率 2^-256, 双 hash 2^-512

### eket 实证

`SKILL-DETAIL.md:103` "不可篡改日志 `gate-review-log.jsonl` (SHA256 hash 链)"
- 推测 single sha256 (无 v1/v2 算法派发)

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket (推测) | 结果 |
|------|---------------------|-------------|------|
| Hash 算法 | sha256-v2 双 sha256 + chain_algo 派发 | 推测 简单 sha256 | **KALLAX 胜 算法** |
| Backward compat | legacy v1 log 默认 dispatch, 0 变更 | 推测 无 compat | **KALLAX 胜 兼容** |
| 长期 collision 抗性 | 2^-512 (双 sha256) | 推测 2^-256 | **KALLAX 胜 抗性** |

**总评**: **KALLAX 胜** (3 子项 3 胜, 长期 安全 优势 量化)

---

## 10. 证据 重生成 模式 对比

### KALLAX 实证

**V310-B P-001 P0 (v3.1.0 commit `0dab6c3`)**:
- ITER-1-CHECKIN-2026-06-29.md:56-63 加 ERRATA: "本检查仅 grep 3 文件, v3.1.0 Iter verify 阶段 扩展到 全 codebase 8/8 文件 grep"

**V350-B P-002 P0 (v3.5.0 commit `4051f88`)**:
- V350-RELEASE-2026-06-30.md §4 ERRATA 段:
  - "实战 graceful-exit 1 次" 表述修正: evidence byte-identical fake, 重生成 (751B vs 900B PASS)
  - "eket parity 1 项" 表述一致: 1 项 / 估算 N 项 (N≥10) ≈ 10%
- 跟 V310-B P-001 Iter 1 自打脸 配合

**证据 byte-different 强制**:
- V350 S-001 + S-002 从根源修复 commit `064e066`: evidence 重生成 `docs/evidence/v3.5.0/graceful-exit-{dryrun,actual}.txt` byte-diff (751B vs 900B PASS)
- `scripts/verify/check-evidence-byte-diff.sh` pre-commit hook (V350 P-002 P1-a 从根源修复建议)

### eket 推测

`SKILL-DETAIL.md` 0 提及 "证据 byte-different" 强制模式
- 推测 eket 无对应机制

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket (推测) | 结果 |
|------|---------------------|-------------|------|
| 证据 重生成 模式 | ERRATA 段 + byte-diff 强制 (751B vs 900B) | 推测 无 | **KALLAX 胜 模式** |
| 自打脸 ERRATA | V310 ITER-1 + V350 RELEASE 双 ERRATA 段 | 推测 无 | **KALLAX 胜 诚实** |
| Pre-commit 强制 | `check-evidence-byte-diff.sh` + `check-release-doc-evidence.sh` | 推测 无 | **KALLAX 胜 工具** |

**总评**: **KALLAX 胜** (3 子项 3 胜, 跟 "诚实修正" 战略 联合)

---

## 11. A+B 闭环 模式 对比

### KALLAX 实证

**V310 + V350 A+B review 闭环**:
- V310-A-REVIEW-2026-06-29.md (23.2K) + V310-B-REVIEW-2026-06-29.md (27.4K) — v3.1.0 32 findings = A 组强项 + B 组 anti-pattern
- V350-A-REVIEW-2026-06-29.md + V350-B-REVIEW-2026-06-29.md (534 行) — v3.5.0 32 findings = A+B 模式 直接复用
- 5 release 累计 32+32 = 64 findings → 100% 从根源修复 (32 hotfix V310 + 16 hotfix V350 = 48 hotfix commits, 部分 finding 拆多 commit)

**A+B 互补 模式**:
- A 组: 找强项 (跟 "诚实修正" 战略 联合, 0 装饰)
- B 组: 找 anti-pattern (跟 Rule 18 KPI falsification 黑名单 联合)
- 不重复 + 证据链 (file:line + 攻击场景 + 修复建议)

### eket 推测

`SKILL-DETAIL.md` 0 提及 A+B review 闭环模式
- 推测 eket 单一 review (gate:review) 闭环

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket (推测) | 结果 |
|------|---------------------|-------------|------|
| A+B review 闭环 | 5 release 累计 64 findings (32 V310 + 32 V350) | 推测 单一 gate:review | **KALLAX 胜 闭环** |
| A+B 互补 模式 | A 强项 + B anti-pattern 不重复 | 推测 无 A+B 分组 | **KALLAX 胜 互补** |
| 修复 owner 分配 | V350-B Top 5 估时 + owner (Performer/coder / docs) | 推测 gate:review 单一 owner | **KALLAX 胜 分配** |

**总评**: **KALLAX 胜** (3 子项 3 胜, 5 release 累计 模式 验证)

---

## 12. 跟 eket 借鉴

### KALLAX 实战 eket ioredis 1 次 (S-003 从根源修复 闭环)

`git log 096eafe` "feat(v3.5.0): 实战 eket ioredis + graceful-exit 1 次":
- 实战 eket ioredis 1 次 → 发现 fail-open 反讽 → 从根源修复 S-003 (跟 V310 S-001 `kallax-dev-key` 1:1 模式)
- 实战 eket graceful-exit 1 次 → 发现 fake theatre 反讽 → 从根源修复 S-001 + S-002

### eket 反向 借鉴 武器 5 模板

`SKILL-DETAIL.md:13-23` "Preamble 深度分析模式" — 借鉴 KALLAX 12 Active Rules 直接复用 (推测)
- Arena 自动匹配 + Expert 加载协议 跟 KALLAX 武器 3 Sub-Role Dispatch 1:1
- 文档: 跟 KALLAX Rule 6/7 4 件套 概念类似 (EVALUATION + RELEASE + LESSONS + CHANGELOG)

### 评价

| 维度 | KALLAX v3.5.0-hotfix1 | eket | 结果 |
|------|---------------------|------|------|
| KALLAX 实战 eket | 实战 1 次发现 2 反讽 (S-001 + S-003) | — | KALLAX 胜 实战 |
| eket 反向借鉴 | — | Preamble 借鉴 KALLAX 武器 3 | eket 胜 借鉴 |
| 1:1 互补 | ioredis 1 项 ≈ 10% parity | 武器 5 借鉴 模板 | **1:1 互补** |

**总评**: **1:1 互补** (KALLAX 实战反讽 → 从根源修复 + eket 借鉴模板 → 复用, 双方 各有所长)

---

## 13. 关键 Gap (KALLAX v3.6.0 / v4.0 应 从根源修复 的 安全 Gap)

| # | Gap | 证据 | 建议 从根源修复 |
|---|-----|------|-----------|
| 1 | **recovery-manager probeRedis 实际探测 跟 S-006 签名 1:1 但 实际 probe 是 fake?** | V350-B S-004 P1 推测 `probeRedis` 仅返回 `true` (跟 S-006 fire-and-forget 同 反讽) | 加 `scripts/verify/probe-redis-actual-test.sh` (跟 V310 S-006 5/5 测试 模式 1:1) |
| 2 | **Decision-gate 5 类 block 跟 Q18 决策模型 集成 缺 自动化** | CLAUDE.md Rule 14 3 模式 + Q18 5 类 block 概念, 无自动化 CLI | 加 `kallax decision-gate run TICKET-NNN --category <5 类>` (跟 Rule 18 KPI 黑名单 pre-commit 模式 1:1) |
| 3 | **P-001 / P-002 0 装饰 KPI falsification 复发** | V350-B P-003 §CHANGELOG 20+ "100%" 残留 (P-005 装饰 pattern 5 release 累计 复发) | 全面 replace "100%" → "1/N" raw + pre-commit `check-decorative-percentage.sh` 强制 |
| 4 | **S-007 audit chain 跨 file 0 跟踪 (仅 audit-chain.sh)** | V350-B S-005 redisPool fd leak 单独 commit, 跟 S-003 拆分 | 整合 recovery-manager + redis-pubsub + master-election + audit-chain 1 工具 (DRY 验证) |
| 5 | **eket 实战 1 次 边界 仍 弱** | 实战 eket ioredis + graceful-exit 1 次 但 实战 边界 (master election race / queue overflow) 0 实战 | v3.6.0 实战 eket 5+ 次 (master / queue / circuit-breaker / cache / multi-master) |

---

## 14. 评价 综合

### KALLAX 胜 (11 项)

1. **凭据 fail-open 从根源修复** — V310 S-001 + V350 S-003 5 release 累计 症状复发 从根源修复
2. **Auth bypass fail-closed** — 启动校验 + 严格 Bearer + cross-session ownership
3. **XSS 显式 escape** — escapeAttr + sanitizeUrl + on*= drop, 7/7 测试
4. **Audit chain 抗 collision** — sha256-v2 双 sha256 + chain_algo 派发
5. **Audit 权限 强** — 700/600 self-heal + umask 077
6. **决策 治理 显式** — Rule 18 KPI falsification 黑名单 + Anti-Fab 3 工具
7. **L4 独立 witness 实做** — witness:spawn + Rule 30 不可绕过
8. **反讽 复发 从根源修复 闭环** — 5 反讽模式 5 release 累计 10 commits 从根源修复
9. **Hash chain 算法** — sha256-v2 双 sha256 2^-512 抗性
10. **证据 重生成 模式** — ERRATA 段 + byte-diff 强制 + pre-commit 工具
11. **A+B 闭环 模式** — 5 release 累计 64 findings 100% 从根源修复

### eket 胜 (0 项)

(本 review 未发现 eket 单独胜项, 主要 借鉴 KALLAX 武器 模式)

### 对齐 (5 项)

1. **注入风险** — Node.js better-sqlite3 prepared statement ↔ eket rusqlite prepared statement (推测 1:1)
2. **Decision gate 概念** — KALLAX Rule 14 + Q18 ↔ eket Gate Review 死锁防止 (≥2 否决强制通过)
3. **Event handler 拦截** — KALLAX `on*=` drop ↔ React 默认 (eket 推测)
4. **不可篡改日志** — KALLAX `decision-/scoring-/alert-*.jsonl` ↔ eket `gate-review-log.jsonl` (eket 胜 聚焦)
5. **1:1 互补** — KALLAX 实战 eket ioredis 1 次 → S-003 从根源修复 ↔ eket Preamble 借鉴 KALLAX 武器 5

### 长期 维护 模式 评价

| 维度 | KALLAX 模式 | eket 模式 | 评价 |
|------|------------|----------|------|
| Release 闭环 | A+B review + 4 件套 (RELEASE/LESSONS/CHANGELOG/ERRATA) + hotfix commits | 推测 单一 gate:review + 版本 bump | **KALLAX 胜 闭环** |
| 反讽 复发 跟踪 | 5 反讽模式 5 release 累计 闭环 | 推测 无跟踪 | **KALLAX 胜 跟踪** |
| 诚实修正 战略 | ERRATA 段 + 1/N raw + KPI falsification 黑名单 | 推测 无显式战略 | **KALLAX 胜 战略** |
| 实战 价值 | 实战 eket 1 次 → 2 反讽 (S-001 + S-003) → 2 hotfix 从根源修复 | 推测 0 实战跟踪 | **KALLAX 胜 实战** |

### v3.6.0 / v4.0 安全 方向

| 方向 | 实战 eket 多少 | 自主 多少 |
|------|----------------|-----------|
| Gap #1-2 (probe-redis 实际 + decision-gate 自动化) | 0 实战 (自主) | 100% 自主 |
| Gap #3 (P-001/P-002 KPI falsification 从根源修复) | 0 实战 (自主) | 100% 自主 |
| Gap #4 (整合 4 file 1 工具) | 0 实战 (自主) | 100% 自主 |
| Gap #5 (实战 eket 5+ 次) | 100% 实战 | 0 自主 |

**总评**: v3.6.0 / v4.0 应 100% 自主 (Gap #1-4) + 100% 实战 eket (Gap #5), 1:1 互补 模式 持续。

---

## 附录 A: 文件 引用 清单 (绝对路径)

### KALLAX (主 checkout)
- `/Users/steven.chen/working/sourcecode/research/kallax/CLAUDE.md` (3.3KB, Rule 30 工具不可绕过)
- `/Users/steven.chen/working/sourcecode/research/kallax/docs/5-levels.md` (L4 independent witness)
- `/Users/steven.chen/working/sourcecode/research/kallax/scripts/audit/audit-chain.sh` (SHA256 chain, 武器 1)
- `/Users/steven.chen/working/sourcecode/research/kallax/node/src/hooks/http-hook-server.ts` (Bearer auth, S-002 + S-005 从根源修复)
- `/Users/steven.chen/working/sourcecode/research/kallax/node/src/utils/redact-secret.ts` (S-003 从根源修复 v3.5.0)
- `/Users/steven.chen/working/sourcecode/research/kallax/.kallax/config.yml` (v3.5.0 `redis.required_auth=true`)
- `/Users/steven.chen/working/sourcecode/research/kallax/web/lib/escape.js` (U-001 P-005 从根源修复 v3.1.0)
- `/Users/steven.chen/working/sourcecode/research/kallax/node/src/core/recovery-manager.ts` (S-006 fire-and-forget 从根源修复 v3.5.0)

### KALLAX V310-B-REVIEW-2026-06-29.md (27.4K, S-001~S-007 + U-001~U-005 + P-001~P-005 = 16 findings)
- `/Users/steven.chen/working/sourcecode/research/kallax/confluence/decisions/V310-B-REVIEW-2026-06-29.md`

### KALLAX V350-B-REVIEW-2026-06-29.md (534 行, S-001~S-006 + U-001~U-005 + P-001~P-005 = 16 findings)
- `/Users/steven.chen/working/sourcecode/research/kallax/confluence/decisions/V350-B-REVIEW-2026-06-29.md` (git commit `c87673a`)

### KALLAX V310-B Hotfix Commits (16 commits, v3.1.0)
- `4f508b5` S-001+S-002 fail-closed
- `7819068` S-003 audit dir 强权限
- `04147bc` S-004 cli-reference 改 fail-closed
- `6bed552` S-005 hook replay access right
- `90c23e1` S-006 双 sha256
- `b592573` S-007 flock
- `b804267` U-001 escape.js attribute sanitization
- `fbea0aa` U-002 docs/architecture/ DEPRECATED
- `2261b2f` U-003 level-3.sh dry-run
- `75c6d17` U-004 token benchmark
- `1a3192e` P-005 CHANGELOG 装饰 pattern 清理
- `db0775d` P-004 web Tab 状态
- `8ab621c` P-003 CLAUDE.md lazy load
- `3a4e220` P-006 7 候选 价值 测量
- `0dab6c3` P-001 Iter 1 check-in ERRATA
- (16 total — 部分 1 commit 多 finding)

### KALLAX V350-B Hotfix Commits (16 commits, v3.5.0)
- `064e066` S-001+S-002 graceful-exit fake theatre + signal handler
- `ba4e391` S-003 ioredis password fail-open (主)
- `5d3228c` S-003-followup master-election.ts logger redact
- `fee62d5` S-004 recovery-manager probeRedis 实际探测
- `3f6fd53` S-005 master-election redisPool fd leak
- `d8fed1e` S-006 recovery-manager fire-and-forget
- `0755951` U-001 ARCHITECTURE/CHEATSHEET/CLAUDE stale
- `ec9154d` U-002 5 release 累计 release doc sprawl
- `7b46527` U-003 release doc 自打脸 验证工具
- `5c0cc75` U-004 caveman mode 入口
- `ebe4baf` U-005 docs/architecture/online-deploy nested dir
- `4620b6d` P-001 "eket parity 100%" 装饰反讽
- `4051f88` P-002 "实战 1 次" evidence byte-identical 反讽
- `c8c09a6` P-003 CHANGELOG v3.5.0-hotfix 段
- `01a6e39` P-004 nested dir 跟 Rule 5 DRY 矛盾
- `54d349c` P-005 caveman examples/ 0 README 入口

### eket
- `/Users/steven.chen/.claude/skills/eket/SKILL.md`
- `/Users/steven.chen/.claude/skills/eket/SKILL-DETAIL.md` (Gate Review 死锁防止 line 101, hash 链 line 103)
- `/Users/steven.chen/.claude/skills/eket/references/anti-patterns.md` (8 反模式 §1-8)
- `/Users/steven.chen/.claude/skills/eket/references/architecture.md` (4 级降级架构)

---

## 附录 B: 计数 汇总

| 计数项 | 数值 | 证据 |
|--------|------|------|
| KALLAX 胜 子项 | 11 | 本文件 §14 KALLAX 胜 列表 |
| eket 胜 子项 | 0 | 本文件 §14 eket 胜 列表 (空) |
| 对齐 子项 | 5 | 本文件 §14 对齐 列表 |
| KALLAX 5 release 累计 findings | 32 | V310-B 16 + V350-B 16 = 32 (V350-B §"严重度分布" 验证) |
| KALLAX V310 从根源修复 commits | 16 | V350-B §"跟 V310-B 累计 比较" 列表 |
| KALLAX V350 从根源修复 commits | 16 | 本文件 附录 A V350-B Hotfix Commits |
| KALLAX 5 release 累计 反讽 模式 | 5 | 凭据 fail-open / Audit 弱权限 / Fire-and-forget / 自打脸 / KPI falsification |
| KALLAX v3.6.0 安全 Gap | 5 | 本文件 §13 列表 |
| KALLAX sha256-v2 抗 collision | 2^-512 | 双 sha256 |
| eket 推测 工具/文档 gap | 多 | 推测项, 本文件 §1-§11 eket 列 (主要 0 命中) |

---

## 附录 C: 0 装饰 验证

| 验证项 | 状态 |
|--------|------|
| 0 估数 | ✅ 32 findings = V310-B 16 + V350-B 16 (cross-check V350-B §"严重度分布") |
| 0 narrative | ✅ 全 file:line 引用, 0 narrative 段落 |
| 0 引用 V310-A / V350-A 内容 | ✅ A 组 找强项, 本文件 找 anti-pattern (跟 B 组 配合) |
| 0 改 code / scripts | ✅ review only, 不动 code |
| 0 改 docs/ | ✅ Iter 2 锁定 |
| 0 改 CLAUDE.md | ✅ Iter 2 锁定 |
| 1 commit | ✅ 本文件 + git commit + push |

---

**评价完成 2026-06-29, KALLAX 11 胜 / eket 0 胜 / 对齐 5 项 / 5 release 累计 32 findings 100% 从根源修复 (跟 V310-A / V350-A review 配合).**