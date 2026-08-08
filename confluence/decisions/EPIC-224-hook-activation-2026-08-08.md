# EPIC-224 — 死文件激活: hook 体系整体失效修复

> **来源**: prime-agent roadmap (`prime-agent-research-2026-08-08.md`) Sprint N+1 最高优先项
> **raw test output**: `tests/integration/epic-224-hook-activation-test.sh` → 21 PASS / 0 FAIL, exit 0
> **附带**: `epic-223-ticket-archive-test.sh` → 21 PASS / 0 FAIL (数字断言从锁定值改为一致性检查)

---

## 1. 关键发现 (远超预期)

原计划: "3 个脚本 merge 了但没接 hook" (EPIC-219/220/223) + "commitlint 只有 config 无 runner" (EPIC-221).

**实际查证**:

```
$ git config core.hooksPath
/tmp/kallax-fix-epic131/.githooks

$ ls -la /tmp/kallax-fix-epic131/.githooks
"/tmp/kallax-fix-epic131/.githooks": No such file or directory (os error 2)
```

`core.hooksPath` 指向**已删除的临时目录** → **所有 pre-commit hook 从未运行**.

**后果**: 5 immutable scripts (`check-decorative-claim` / `check-narrative` / `check-fail-closed` / `check-self-heal` / `check-claim-evidence`) 存在于 repo, `pre-commit` 里有正确的调用逻辑, 但**一个都没触发过**.

这不是"3 个死文件"问题, 是**整套治理 gate 静默失效**. 本轮之前的所有 commit 都是在无 gate 状态下提交的.

**教训**: 脚本存在 ≠ 脚本生效. 治理 gate 必须有"验证 gate 本身在运行"的元检查.

---

## 2. 修复内容

### 2.1 `scripts/hooks/install.sh` 重写

| 检查 | 行为 |
|------|------|
| `core.hooksPath` 指向不存在目录 | 报 BROKEN + `git config --unset` 修复 |
| `pre-commit` / `pre-push` 未安装 | 复制 + chmod +x |
| `pre-commit` / `pre-push` 跟源文件不一致 | `cmp -s` 检出 STALE + 更新 |
| `commitlint.config.js` 存在但无 `commit-msg` hook | 安装 runner |

新增 `--verify` 模式: 只检查不改, exit 1 = 有问题. 供 CI 用.

**worktree 兼容**: 用 `git rev-parse --git-common-dir` 而非 `${REPO_ROOT}/.git` — worktree 下 `.git` 是文件不是目录.

### 2.2 `scripts/hooks/commit-msg` 新建 (激活 EPIC-221)

EPIC-221 只加了 `commitlint.config.js`, 没装 runner. 本 EPIC 补纯 bash 实现 (不依赖 `npx commitlint`, 免 node_modules):

| 检查 | 对应 config rule |
|------|-----------------|
| DCO `Signed-off-by:` trailer 必填 | 自定义 `dco-signoff` |
| Conventional Commits type | `type-enum` |
| header ≤ 100 字符 | `header-max-length` |

豁免: `Merge*` / `Revert*` / `fixup!*` / `squash!*` commit.

### 2.3 `scripts/hooks/pre-commit` 接入 3 gate

| Gate | 触发条件 | 阻塞? |
|------|---------|-------|
| EPIC-220 `check-disclaimer.sh` | staged 有 `.md` | 是 |
| EPIC-219 `snapshot-claude-md.sh` | staged 有 `CLAUDE.md` / `.claude/rules/*.md` | **否 (advisory)** — 无 snapshot tag 时提醒 |
| EPIC-223 `check-ticket-schema.sh` | staged 有 `jira/tickets/*/ticket.json` | 是 (仅 exit 1, exit 3 ARCHIVED_SKIP 放行) |

**exit 3 处理**: `check-ticket-schema.sh` 的 exit 3 表示"历史 EPIC 不适用", pre-commit 只拦 exit 1 — 否则所有历史 ticket 改动都会被误拦.

### 2.4 CI `hook-health` job 新增

| Step | 验证 |
|------|------|
| 1 | 3 个 hook 源文件存在 + 可执行 |
| 2 | 4 个脚本 `bash -n` 语法 |
| 3 | **负向测试**: 故意设坏 `hooksPath`, `--verify` 必须 exit 1 |
| 4 | installer 修复后 `--verify` exit 0 |
| 5 | 3 个 gate 确实 wire 进 `pre-commit` (grep) |

Step 3 是关键 — 验证"检测机制本身有效", 防止 installer 变成又一个死文件.

### 2.5 数字更新 5 → 8

3 脚本已真接入 hook, 按 `.claude/rules/immutable-scripts.md` §3 强制流程同步 3 处:

| 位置 | 改前 | 改后 |
|------|------|------|
| `CLAUDE.md` §5 标题 | 5 不可更改 | 8 不可更改 |
| `SKILL.md` #8 | 4 verify + 1 hook = 5 | 8 total: 7 verify + 1 hook |
| `immutable-scripts.md` §2 | 5 行表 + 待接入 3 | 8 行表 (含 hook 接入点列) |

CLAUDE.md 193 行 ≤ 200 ✅

---

## 3. Dogfood 验证

改 CLAUDE.md 前先用 EPIC-219 脚本打了 snapshot:

```
$ bash scripts/verify/snapshot-claude-md.sh snapshot "EPIC-224 immutable 5->8 (3 脚本已接入 hook)"
OK snapshot created: claude-md-pre-20260808-110906
rollback cmd: snapshot-claude-md.sh rollback claude-md-pre-20260808-110906
```

EPIC-219 脚本从"死文件"变成实际用上了.

---

## 4. 测试

### 4.1 EPIC-224 (21 TC / 6 组)

```
$ bash tests/integration/epic-224-hook-activation-test.sh
=== Result: 21 PASS / 0 FAIL (total 21) ===
```

| Group | TC | 覆盖 |
|-------|----|------|
| 1 源文件 | 3 | 3 hook 存在 + 可执行 |
| 2 语法 | 4 | `bash -n` × 4 脚本 |
| 3 hooksPath | 2 | 坏路径检出 exit 1 / 修复后 exit 0 |
| 4 commit-msg | 6 | 合规 / 缺 DCO / 非法 type / Merge 豁免 / 超长 / bypass |
| 5 pre-commit gate | 4 | 3 gate wire + exit 3 放行逻辑 |
| 6 CI | 2 | hook-health job + 负向测试 step |

### 4.2 EPIC-223 回归 (21 TC)

数字从 5 改 8 导致 2 TC 失败 (断言锁定了具体值). 改为:
- 宽松断言: `^## 5\. [0-9]+ 不可更改` (有明确数字即可)
- **新增一致性 TC**: 提取 CLAUDE.md §5 数字 vs SKILL.md #8 数字, 必须相同

第一版一致性 TC 抓错了数字 (`## 5.` 的章节号 5 而非 immutable 数 8), 报 "数字漂移 CLAUDE.md=5 SKILL.md=8" — 修正为取第 2 个数字后 PASS. 这个 TC 现在能真正防数字漂移.

```
$ bash tests/integration/epic-223-ticket-archive-test.sh
=== Result: 21 PASS / 0 FAIL (total 21) ===
```

---

## 5. 不做什么

| 项 | 为什么 |
|---|-------|
| 装 husky | 纯 bash `commit-msg` 已够, 免 node_modules 依赖 |
| 用 `npx commitlint` | 同上; 且 CI/本地都要能跑, bash 更可靠 |
| 把 `snapshot-claude-md.sh` 改成阻塞 | 打 snapshot 是建议不是硬要求, 阻塞会阻碍紧急修复 |
| 追溯补历史 commit 的 gate 检查 | 无意义, 已合并 |

---

## 6. 联动

| 联动项 | 关系 |
|--------|------|
| EPIC-110 (4-law 接进 pre-commit) | 本 EPIC 修复其失效前提 |
| EPIC-069-D (check-claim-evidence) | 同上 |
| EPIC-219 / EPIC-220 / EPIC-223 | 3 脚本从"落地"到"生效" |
| EPIC-221 (commitlint.config.js) | 补 runner 激活 |
| EPIC-131/132 (`/tmp/kallax-fix-epic131`) | 坏 hooksPath 的来源 — 当时临时 worktree 遗留 |
| `.claude/rules/immutable-scripts.md` | §0 新增失效事故记录 + §3 加"先接入再登记"前置条件 |

---

## 7. 遗留 (下一 Sprint)

| # | 项 | 优先级 |
|---|---|--------|
| 1 | CHANGELOG 补 EPIC-203~224 共 22 条 | 高 |
| 2 | `recent-epics.md` 补 EPIC-209~224 | 中 |
| 3 | 12 in_progress ticket 定性 + EPIC-150/154/177-G 收口 | 中 |
| 4 | testing 分支恢复 + 备案 | 中 |
| 5 | EPIC-205~222 测试缺口 (18 EPIC 无 test) | 中 |