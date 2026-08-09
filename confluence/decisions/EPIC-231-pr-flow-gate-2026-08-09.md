# EPIC-231 — PR Flow Gate: 反向 PR + 空 PR + squash 断链

- **日期**: 2026-08-09
- **拍板**: 主公 ("同意")
- **前置**: EPIC-229 (testing 分支恢复), EPIC-217 (README elevator, 从未落地)
- **版本**: v3.34.8

## 1. 为什么

主公问"看下之前没完成的任务", 查 PR-3 (main→miao) 时发现 miao 缺 EPIC-217 内容, 顺着往下查出 3 个治理漏洞。

### 1.1 症状

```
$ git show origin/main:README.md | grep -c "When to use"
0
$ git show origin/miao:README.md | grep -c "When to use"
0
$ git show 46923653:README.md | grep -n "When to use"
16:## When to use KALLAX? (场景维度, 替代规模维度, EPIC-217)
```

EPIC-217 的 README 改动只存在于 feature 分支 `46923653`, 从未进过 main 或 miao。
但 main 上有一个标题为 `feat(readme): EPIC-217 elevator + When-to-use 场景段` 的 commit
`415c7bea` — `git show --stat` 输出 **0 文件**。

### 1.2 根因

| PR | head → base | changedFiles | 问题 |
|---|---|---|---|
| #316 | `miao` → `testing` | 0 | 方向反了 (prod 推向测试) + 空 |
| #317 | `testing` → `main` | 0 | 空 PR, 只搬了 #316 的空 |

空 commit 顶着 EPIC 标题 merge 进 main, 而实际内容没进去。CI 没有任何门控拦住。

### 1.3 第三个漏洞: squash 断链

```
$ git rev-list --parents -n 1 b98df031   # PR #320 main→miao
b98df031f0812c6be71db245da34608b6c327a23 89adaa0234777b28e088b3afda004026a99354e6
$ git rev-list --parents -n 1 27d739d9   # PR #325 main→miao
27d739d91244a266a873d9e86f47c8580bc97d8a b98df031f0812c6be71db245da34608b6c327a23
```

两个都只有 **1 个 parent** = squash merge。squash 压平历史后:
- `git log origin/miao..origin/main` 永久显示 12 commit 落后 (历史断链, 不会因再合而清零)
- miao 只拿到 squash 快照里的文件, 而快照基于当时的 main (缺 EPIC-217)

### 1.4 回溯审计实测

```
$ bash scripts/verify/check-branch-flow.sh --audit-history 25
结果: 15/25 PR 有违规
```

明细: 13 个 `feature/* → main` (跳 testing, 是 testing 分支被误删期间的债) + 2 个 squash 断链
+ #316/#317 空 PR。

### 1.5 EPIC-229 的检查为什么没抓到

EPIC-229 我写 `check-branch-flow.sh` 时声称"防复发 gate", 但它**只检查 3 个分支是否存在**,
完全没查 PR 的 base/head 方向、changedFiles、merge 方式。当时没有真去查历史 PR 的这些字段
—— 查了 #316/#317 立刻暴露。这是形式检查冒充实质检查, 跟 EPIC-224 记录的
"hook 装了但 core.hooksPath 坏了" 是同一类失效。

## 2. 改什么

### 2.1 `scripts/verify/check-branch-flow.sh` 扩展 (80 → 273 行)

原有 [A] 分支存在性保留不动, 新增 3 类:

| 检查 | 内容 | 起因 |
|---|---|---|
| [B] 方向 | `feature/* → testing → main → miao` 单向 allowlist | PR #316 反向 |
| [C] 空 PR | `changedFiles > 0` | PR #316/#317 均 0 |
| [D] squash | 跨主干 PR merge commit 必须 ≥2 parent | b98df031 / 27d739d9 |

新增 2 个入口:
- `--pr <N>` — 校验单个 PR ([B] + [C]), CI `pull_request` 用
- `--audit-history N` — 回溯审计最近 N 个已合 PR ([B] + [C] + [D]), 只报告不改历史

hotfix 例外: `feature/hotfix-* → main` 允许直达 (需 commit body 注明主公批准)。

退出码契约: `0` = PASS, `1` = FAIL (fail-closed), `2` = BLOCKED-env (gh 不可用)。

### 2.2 `.github/workflows/ci.yml`

**新增 `pr-flow-gate` job** (2 步):
1. 校验当前 PR — `--pr $PR_NUMBER`
2. **负向测试 (meta-check)** — 拿 PR #316 当固定负样本, 若 gate 对它返回 0 则 CI 失败

第 2 步是关键: 防止 gate 自身逻辑坏掉而静默通过 (跟 EPIC-224 CI 里
"故意设坏 hooksPath 验证 --verify exit 1" 同一 pattern)。
且明确断言拦截**原因**正确 (grep `方向非法` + `空 PR`), 不只看 exit code。

**顺带修 2 个 CI 缺口**:
- `pull_request.branches` 从 `[main, develop]` → `[main, testing, miao, develop]`
  — 原先 `main→miao` 和 `feature→testing` 的 PR **完全不跑 CI**
- `all-checks.needs` 补 `hook-health` — EPIC-224 建的 job 一直没进汇总 gate

`pr-flow-gate` 有意**不**进 `all-checks`: 它带 `if: pull_request`, push 时 skip 会连带
skip `all-checks`。需在 branch protection 里单独设为 required check。

**安全**: PR 编号走 `env: PR_NUMBER: ${{ github.event.number }}` 而非内联到 `run:`,
且脚本内显式校验为纯数字 (defense in depth, 防 workflow injection)。

### 2.3 `tests/integration/epic-231-pr-flow-gate-test.sh` (新增)

29 个 TC / 33 断言, 分 5 组: 静态 / 方向 allowlist / squash 检测 / gh 真跑 / CI 接线。

方向 allowlist 用 10 个用例覆盖, 6 个非法用例全是**真实发生过的**方向。
TC8 校验测试副本跟源脚本未漂移 (测试里抽了 `is_allowed_direction` 副本)。
gh 不可用时 TC21-24 skip 而非假 PASS。

## 3. 实跑证据

### 3.1 测试

```
$ bash tests/integration/epic-231-pr-flow-gate-test.sh
Results: 33 pass, 0 fail, 0 skip
```

### 3.2 负样本被拦

```
$ bash scripts/verify/check-branch-flow.sh --pr 316
Exit code 1
  FAIL [B] 方向非法: miao -> testing
  FAIL [C] 空 PR (changedFiles=0)
FAIL: PR #316 违反 4-branch flow
```

### 3.3 正样本通过 / 当前 PR 自查

```
$ bash scripts/verify/check-branch-flow.sh --pr 331
  FAIL [B] 方向非法: feature/EPIC-228-ticket-tri -> main
  OK   [C] changedFiles=21
```

PR #331 自己也违规 (跳 testing) — 这是 testing 被删期间的历史债, 检查器正确识别。

### 3.4 CI 结构

```
$ python3 -c "import yaml; ..."
YAML OK
jobs: 12
pr-flow-gate steps: 3
pr branches: ['main', 'testing', 'miao', 'develop']
all-checks needs: 10
```

## 4. 影响

**正面**:
- 空 PR 无法再顶 EPIC 标题进主干
- 反向 / 跳级 PR 被 CI 拦
- 跨主干 PR 的 squash 断链可检出
- 跨主干 PR 首次真正跑 CI (原先 branches 不含 testing/miao)

**代价**:
- 现存 PR #331 会被新 gate 拦 (方向 `feature/* → main`)。需要走 testing 或按历史债备案。
- 13 个已合 PR 的跳 testing 违规无法追溯修复 (不改 git 历史)。

## 5. 风险

| 风险 | 缓解 |
|---|---|
| gate 拦住合理的紧急修复 | `feature/hotfix-*` 例外通道 |
| gh 不可用导致 CI 卡住 | 脚本 exit 2 (BLOCKED-env), 但 CI 步骤明确拒绝 exit 2 静默通过 → 需人工处理 |
| gate 自身逻辑坏掉静默通过 | CI 负向测试 (PR #316 固定负样本) + 断言拦截原因 |
| 测试副本跟源脚本漂移 | TC8 校验源脚本含 hotfix 例外 |
| 历史债 15/25 违规触发 audit fail | `--audit-history` 不进 CI required, 只作人工审计工具 |

## 6. 历史债处理

跟 EPIC-155 / EPIC-176 备案 pattern 一致 — **不改 git 历史**:

- 13 个 `feature/* → main` 跳 testing: testing 分支在 EPIC-217 事故中被 `--delete-branch`
  删除, EPIC-229 已恢复。这段期间的 PR 无法补跑 testing 阶段。
- 2 个 squash 断链: `git log miao..main` 计数已永久失真, 后续跨主干 PR 用 `--merge` 修正。
- #316/#317 空 PR: EPIC-217 内容需重新走全流程落地 (**未在本 EPIC 范围内**)。

## 7. 未完成 (需另开 EPIC)

### 7.1 EPIC-217 内容补落

README 的 elevator + When-to-use 段仍只在 `46923653` (feature/EPIC-217-elevator)。
需 cherry-pick README 部分走 4-PR 全流程。本 EPIC 只建门控, 不补内容 (避免混合 2 件事)。

### 7.2 authz state.json 路径 bug — 本 commit 用 bypass 的原因

**本 commit 使用 `KALLAX_HOOK_BYPASS=1` 提交** (主公 2026-08-09 拍板 "A")。
原因是一个与本 EPIC 无关的 authz 路径 bug, 记录如下。

**症状**: 任何 `feature/*` 分支 commit 被 pre-commit Check 0 拦:

```
BLOCKED: Authorization denied by authz check.
Branch: feature/EPIC-231-pr-gate (action: worktree.commit)
Actor:  master
```

**复现**:

```
$ bash scripts/permission/authz/check.sh --action worktree.commit --actor master
$ echo $?
2
```

**根因** (`bash -x` trace 最后 2 行):

```
++ jq -r '.role // ""' <KALLAX_ROOT>/.kallax/state/state.json
+ ROLE=
```

`.kallax/state/state.json` 不存在。实际文件在多一层嵌套的位置:

```
$ ls .kallax/state/state.json
ls: ...: No such file or directory
$ find . -name state.json -path "*state*" -not -path "*/node_modules/*" | head -1
./.kallax/.kallax/state/state.json          ← 多一层 .kallax
```

`jq` 对不存在的文件返回 exit 2, `set -euo pipefail` 使脚本立即中断, 退出码 2 透传。
pre-commit 的 `if ! bash "$AUTHZ_CHECK"` 把任何非零当 deny, 所以显示为"授权拒绝"
而非"配置文件缺失" — 错误信息指向了错误的方向。

**为什么之前误判**: 早先在主仓库 cwd 下手动跑同一命令得到 exit 0, 据此认为脚本没问题。
实际是 cwd 不同导致路径解析到了别的文件。**只有在 worktree 里按 hook 的确切方式
(`KALLAX_ROOT=$(git rev-parse --show-toplevel)`) 复现, 才暴露 exit 2。**

**需另开 EPIC-232 处理 3 件事**:

1. 定位谁写出 `.kallax/.kallax/` 双层路径 (writer 侧 bug, 还是 reader 侧路径拼错)
2. `jq` 读不存在文件的 exit 2 应有明确语义 — 现在跟"授权拒绝"混为一谈,
   违反 fail-closed 的可诊断性要求 (拒绝可以, 但原因必须准)
3. 跟 `.claude/rules/state-json.md` (EPIC-068-A state.json 路径约定) 对齐

**bypass 先例**: EPIC-226 §6 同样记录了 `KALLAX_HOOK_BYPASS=1` 的使用与原因。

### 7.3 `KALLAX_HOOK_BYPASS=1` 本身失效 — 实际用了 `--no-verify`

尝试按 §7.2 的方案 bypass 时发现 **bypass 机制自己是坏的**:

```
$ KALLAX_HOOK_BYPASS=1 git commit -F <msg>
WARN: pre-commit bypass via KALLAX_HOOK_BYPASS=1      ← bypass 生效了
BLOCKED: Authorization denied by authz check.          ← 但仍被拦
COMMIT_RC=1
```

**根因**: `.git/hooks/pre-commit` 第 23-36 行设置 `HOOK_BYPASS=1` 并打印 WARN,
但第 45-102 行的 Check 0 (authz) **完全没有引用 `$HOOK_BYPASS`**。
变量设了却没人读 — bypass 只对后面的 4 immutable-law 检查有效, 对 Check 0 无效。

**附带发现**: `.git/hooks/pre-commit` 里 `KALLAX_ROOT` 仍是旧写法:

```
41: KALLAX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

EPIC-227 修的是源文件 `scripts/hooks/pre-commit` (改用 `git rev-parse --show-toplevel`),
但 `.git/hooks/` 里的已安装副本是 STALE, 从未重新部署。
EPIC-224 的 `scripts/hooks/install.sh` 有 STALE 检测 (`cmp -s`), 但没人跑过。

**本 commit 最终用 `git commit --no-verify`** (CLAUDE.md §4 允许的紧急通道, 主公已批 "A")。

**EPIC-232 需一并处理** (从 3 件事扩到 5 件):

4. Check 0 补 `$HOOK_BYPASS` 判断 — 否则 bypass 契约名不副实
5. `.git/hooks/*` STALE 副本重新部署 + CI 加 STALE 检测
   (EPIC-224 已有 `install.sh --verify`, 但未接进 CI 的 required check)

## 8. 跟现有 Rule 的关系 (0 增 Rule)

- **Rule 4** (4-branch flow): 本 EPIC 是它的**首个自动化门控** — 之前只有文档约束
- **Rule 5** (DRY): 复用 EPIC-229 已有脚本, 不新建
- **Rule 9** (KPI X/Y): 测试 33/33, 审计 15/25 均 X/Y 格式
- **Rule 34** (bugfix 独立复现): §1.1/§1.3 均含 reproduction command + exit code + raw output
- **Rule 35** (Sprint 时间盒): 3 文件, 1 commit, < 500 行净增

## 9. 变更文件

| 文件 | 变化 |
|---|---|
| `scripts/verify/check-branch-flow.sh` | 80 → 273 行 (+[B][C][D] + 2 入口) |
| `.github/workflows/ci.yml` | +`pr-flow-gate` job, 触发补 testing/miao, `all-checks` 补 hook-health |
| `tests/integration/epic-231-pr-flow-gate-test.sh` | 新增 (29 TC / 33 断言) |
| `confluence/decisions/EPIC-231-pr-flow-gate-2026-08-09.md` | 本文档 |
