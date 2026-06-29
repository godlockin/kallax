# Iter 1 P0 验证报告 (Baseline 测试)

**日期**: 2026-06-29
**验证者**: S-03 (Performer/tester sub-role)
**Worktree**: /Users/steven.chen/working/sourcecode/research/iter1-tester
**Branch**: feature/iter1-tester (基于 miao d875daa)
**范围**: S-01 (docs) + S-02 (coder) 4 块改动

> **重要**: 本报告是基于 miao d875daa 基线 (S-01/S-02 未 commit 未 push 前) 的 baseline 验证.
> S-01 worktree 仅有 untracked docs/CHEATSHEET.md, S-02 worktree clean (无 commit).
> merge 步骤跳过, 直接对 miao 跑 7 测试, 报告作为 baseline 对比 起点.

---

## Test 1: docs/CHEATSHEET.md ≤ 30 行

- **期望**: ≤ 30 行 (含 30 命令速查 + 5 levels + 4 roles)
- **实际 raw stdout**:
  ```
  === Test 1: docs/CHEATSHEET.md ≤ 30 行 ===
  FILE NOT FOUND
  ---
  ls: docs/CHEATSHEET.md: No such file or directory
  ```
- **结果**: **FAIL** (基线缺失, S-01 待 commit)
- **file:line**: S-01 worktree 有 `?? docs/CHEATSHEET.md` (untracked, 未 commit)

## Test 2: KALLAX-GLOSSARY.md 移到 _archived

- **期望**: `docs/_archived/KALLAX-GLOSSARY.md` 存在, `docs/` 根 0 hits
- **实际 raw stdout**:
  ```
  === Test 2: KALLAX-GLOSSARY.md 移到 _archived ===
  ls: docs/_archived/KALLAX-GLOSSARY.md: No such file or directory
  PASS: 在 docs/ 根目录 已 0 hits
  ```
- **结果**: **FAIL** (archived 路径不存在, S-01 待 commit)
- **file:line**: KALLAX-GLOSSARY.md 仍在 `docs/KALLAX-GLOSSARY.md` (未归档)

## Test 3: 5 levels + 4 roles lazy load 文档

- **期望**: 100-200 行
- **实际 raw stdout**:
  ```
  === Test 3: 5 levels + 4 roles lazy load 文档 ===
  0
  ```
  (无 5-levels.md / 4-roles.md 文件, wc 输出 0 行因 stdin 缺失)
- **结果**: **FAIL** (S-01 待 commit)

## Test 4: P0-1 API key fail-closed

- **期望**: grep `kallax-dev-key` 在 3 个文件 0 hits (除 .env.example), `process.exit` 有 fail-closed 逻辑
- **实际 raw stdout**:
  ```
  === Test 4: P0-1 API key fail-closed ===
  4 matches in 3 files:

  node/src/api/server.ts:69:if (config.apiKey === 'kallax-dev-key') {
  node/src/api/server.ts:70:..., 'Using default API key "kallax-dev-key". Set KALLAX_API_KEY env var for produc...
  node/src/api/server/standalone.ts:20:const apiKey = process.env['KALLAX_API_KEY'] ?? 'kallax-dev-key';
  node/src/api/types.ts:63:apiKey: z.string().default('kallax-dev-key'),

  2 matches in 1 files:

  node/src/api/server/standalone.ts:25:...: dbResult.error.message }, 'failed to initialize database'); process.exit(1); }
  node/src/api/server/standalone.ts:40:...err.message : String(err) }, 'failed to start API server'); process.exit(1); });
  ```
- **结果**: **FAIL** (4 处 `kallax-dev-key` 默认值, 无 fail-closed 逻辑 — process.exit 仅 db/server 启动失败, 无 API key 缺失分支)
- **关键问题 file:line**:
  - `node/src/api/server/standalone.ts:20` — `?? 'kallax-dev-key'` fallback (应改为 throw / process.exit(1))
  - `node/src/api/types.ts:63` — `z.string().default('kallax-dev-key')` (Zod schema 默认值)
  - `node/src/api/server.ts:69-70` — `'kallax-dev-key'` 字面量检测 + 警告 (应改为 hard fail)

## Test 5: P0-2 CLI 冒号 → 空格

- **期望**: `kallax (task|epic|system|conductor|performer|master|expert|ticket|agent|gate|verify|knowledge|team):` 在命令上下文 0 hits
- **实际 raw stdout** (节选):
  ```
  === Test 5: P0-2 CLI 冒号 → 空格 ===
  README.md:150:kallax task:create "实现用户登录功能" --type feature --priority P1
  README.md:153:kallax task:claim TASK-001
  README.md:156:kallax task:complete TASK-001
  README.md:168:kallax task:create "title"          # 创建票据
  README.md:169:kallax task:claim [TASK-NNN]        # 原子领取任务
  README.md:170:kallax task:complete TASK-NNN       # Saga 5步完成
  README.md:171:kallax task:status TASK-NNN         # 查看状态
  README.md:172:kallax task:progress                # DAG 进度 + 关键路径
  README.md:173:kallax task:resume TASK-NNN         # checkpoint 恢复
  README.md:178:kallax conductor:heartbeat          # 心跳检查（5 问）
  README.md:179:kallax conductor:poll               # 处理 Performer 上报
  README.md:180:kallax conductor:delegate           # 委派给助理
  README.md:185:kallax performer:register --role backend   # 注册 Performer
  README.md:186:kallax performer:poll                      # 长轮询邮箱
  README.md:187:kallax performer:resume TASK-NNN           # 恢复执行
  README.md:192:kallax knowledge:index --dir jira/  # 构建 FTS 索引
  README.md:193:kallax knowledge:search "keyword"   # 全文搜索
  README.md:199:kallax system:doctor                # 系统诊断
  README.md:200:kallax team:status                  # 团队状态
  CLAUDE.md:56:kallax task:claim TASK-001  # 自动创建 worktree 隔离
  ```
- **结果**: **FAIL** (20+ 处 `kallax <sub>:` 命令, S-02 待 commit)
- **关键问题 file:line**: README.md 150-200, CLAUDE.md:56, AGENTS.md (未列出)

## Test 6: P0-3 5 缺失脚本

- **期望**: 4 个脚本/文件全部 PASS
- **实际 raw stdout**:
  ```
  === Test 6: P0-3 5 缺失脚本 ===
  test-fact-forcing-preflight.sh: FAIL
  ticket-status-sync.sh: FAIL
  outbox-isolation.sh: FAIL
  instance_config.yml: FAIL
  ```
- **结果**: **FAIL** (4/4 FAIL, S-02 待 commit)
- **关键问题 file:line**:
  - `scripts/verify/test-fact-forcing-preflight.sh` — 缺失
  - `scripts/conductor/ticket-status-sync.sh` — 缺失
  - `scripts/conductor/outbox-isolation.sh` — 缺失
  - `.kallax/state/instance_config.yml` — 缺失

## Test 7: P0-2.5 GitHub URL

- **期望**: `your-org` 在 README.md + CONTRIBUTING.md 0 hits
- **实际 raw stdout**:
  ```
  === Test 7: P0-2.5 GitHub URL ===
  4 matches in 2 files:

  CONTRIBUTING.md:29:git clone https://github.com/your-org/kallax.git
  CONTRIBUTING.md:233:- 搜索 [Issues](https://github.com/your-org/kallax/issues)
  CONTRIBUTING.md:234:- 提问 [Discussions](https://github.com/your-org/kallax/discussions)
  README.md:108:git clone https://github.com/your-org/kallax.git
  ```
- **结果**: **FAIL** (4 处 `your-org` 占位符, S-02 待 commit)
- **关键问题 file:line**: CONTRIBUTING.md:29, 233, 234, README.md:108

---

## 总结 (Baseline)

- **7/7 FAIL** (基于 miao d875daa 基线)
- 这是预期结果 — S-01/S-02 改动尚未 commit/push, baseline 必然 fail
- 本报告作为 **pre-merge baseline** 用于 S-01/S-02 commit 后的对比验证

## 下一步 (Conductor 流程)

1. **Conductor** 跟踪 S-01 (Task #85) + S-02 (Task #86) commit + push
2. S-03 收到 push 通知后, 在此 worktree pull + re-run 7 tests
3. 期望: 7/7 PASS (S-01 docs 改动 + S-02 4 P0 修复)
4. 如有 FAIL, 明确列出 + 提交 issue 回 S-01/S-02

## 文件:line 引用 (Baseline FAIL 列表)

| Test | FAIL file:line |
|------|----------------|
| Test 1 | S-01 untracked `docs/CHEATSHEET.md` |
| Test 2 | `docs/KALLAX-GLOSSARY.md` 未归档 (无 `_archived/` 路径) |
| Test 3 | 无 `docs/5-levels.md` + 无 `docs/4-roles.md` |
| Test 4 | `node/src/api/server/standalone.ts:20`, `node/src/api/types.ts:63`, `node/src/api/server.ts:69-70` |
| Test 5 | `README.md:150-200`, `CLAUDE.md:56`, `AGENTS.md` (S-02 需替换) |
| Test 6 | `scripts/verify/test-fact-forcing-preflight.sh`, `scripts/conductor/ticket-status-sync.sh`, `scripts/conductor/outbox-isolation.sh`, `.kallax/state/instance_config.yml` |
| Test 7 | `CONTRIBUTING.md:29,233,234`, `README.md:108` |

## 关键发现 (Conductor 关注)

- **S-01 + S-02 状态**: 两个 worktree 都没有 commit 改动, 这是 baseline 测试的唯一解释
- **风险**: S-01 docs/CHEATSHEET.md 是 untracked, 可能 S-01 还没意识到要 commit
- **建议**: Conductor ping S-01 (Task #85) + S-02 (Task #86) 确认 commit + push 状态
- **S-03 follow-up**: 收到 push 通知后立即 re-test, 7/7 PASS 才能 close Task #87

## raw stdout 来源 (可复现)

所有 raw stdout 已粘贴在 Test 1-7 章节, 验证命令:
```bash
cd /Users/steven.chen/working/sourcecode/research/iter1-tester
wc -l docs/CHEATSHEET.md
ls -la docs/_archived/KALLAX-GLOSSARY.md
ls docs/ | grep -E "KALLAX-GLOSSARY"
wc -l docs/5-levels.md docs/4-roles.md
grep -n "kallax-dev-key" node/src/api/server/standalone.ts node/src/api/types.ts node/src/api/server.ts
grep -n "process.exit" node/src/api/server/standalone.ts
grep -nE "kallax (task|epic|system|conductor|performer|master|expert|ticket|agent|gate|verify|knowledge|team):" README.md CLAUDE.md AGENTS.md docs/guides/quick-start-2026-06-19.md
test -x scripts/verify/test-fact-forcing-preflight.sh
test -x scripts/conductor/ticket-status-sync.sh
test -e scripts/conductor/outbox-isolation.sh
test -e .kallax/state/instance_config.yml
grep -n "your-org" README.md CONTRIBUTING.md
```

---

**报告状态**: BASELINE (待 S-01/S-02 push 后 re-test)
**S-03 状态**: 持续 in_progress, 等 push 通知后 re-run 7 tests
**Conductor 责任**: 跟踪 S-01 (Task #85) + S-02 (Task #86) commit 状态
