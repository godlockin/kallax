# Sprint 事故与技术债复盘 (独立核实)

核实基准: `origin/miao` = `53d3e2aa` (2026-08-11)。
注意: **本地工作树 `miao` 停在 `97c4d45f` (PR #361)**，落后远端 20+ commit。所有核实用 `git show origin/miao:<path>` 或临时 worktree (`/tmp/retro/wt2` @ `53d3e2aa`) 做的，不是读工作树。

所有 PR 走 squash merge，所以 feature 分支的原始 commit sha (如 `2e13df66`) **不是** `origin/miao` 的祖先；进主干的是 squash 后的 PR-3 commit。下面两列都给。

---

## 7 条事故核实

| # | 事故 | 已修? | 进 miao 的 commit | 复发? |
|---|---|---|---|---|
| 1 | ticket status 改错位置 | 部分 | `e9efd516` (PR #415) | **是，已复发** |
| 2 | vitest env blocker 4 层误诊 | 是 | `53d3e2aa` (PR #421) | 否 |
| 3 | `grep -c` 输出污染 | 部分 | `48430ef1` (PR #418) | 否，但**扫描范围只覆盖 scripts/** |
| 4 | 扫描正则漏引号变体 | 是（当次） | 同上 | 否，但同型问题换成"漏目录" |
| 5 | immutable delete-only diff bug | 是 | `ccc55f84` (PR #407) | 否 |
| 6 | 写 test 时 set -e 没关 | 是 | `48430ef1` | 否 |
| 7 | immutable STAGED_ONLY 误诊 | 无需修 | `a5427125` (PR #404) | 否 |

### 1. ticket status 改错位置 — 已复发，证据确凿

13 张卡确实修好了。`origin/miao` 上 EPIC-157/159/160/251/252/253 全部 `status=done`。

但 EPIC-254/255 复发：

```
jira/tickets/EPIC-254/ticket.json  status=in_progress   pr_chain=null  updated_at=null
jira/tickets/EPIC-255/ticket.json  status=in_progress   pr_chain=null  updated_at=null
```

这两张卡描述的工作本身已经 merge 进 miao (PR #418 / #421)。所以是**同一个坑第 2 次**，而且这次连 `pr_chain` / `updated_at` 都是 null——比第一次更整个地漏了。

`check-ticket-schema.sh` 对这两张卡返回 exit 0（我实跑过：`OK: EPIC-254 ticket.json schema 齐 (type=bugfix)`）。因为 `.archive-baseline.json` 的 `new_ticket_required_fields` 只要求 `status` **字段存在**，不校验 status 值跟 PR 状态是否吻合。gate 存在但管不到这件事。

我全仓找了：**没有任何 hook / CI / script 校验 ticket status 与已 merge PR 的相同性**。`scripts/conductor/ticket-status-sync.sh` 本应干这件事，但它是个 stub：

```
echo "[STUB] Iter 5 will implement: status field sync + claimed_at/in_progress_at/done_at timestamps"
echo "PASS: stub-ok (Iter 5 will replace)"
exit 0
```

它 print "PASS" 然后 exit 0。任何调用方看到 exit 0 都会认为同步成功了。

### 2. vitest env blocker — 修好了

`node/package-lock.json` 在 `origin/miao` 上已不存在。剩下 `package-lock.json`（根）+ `web/package-lock.json`。

根因诊断是对的，我独立验证了三方对不上的机制：根 lockfile 锁 vitest `4.1.10`，`node/package.json` 声明 `^4.1.10`，已删的 `node/package-lock.json` 锁 `1.6.1`。vitest v1 依赖 `tinypool`、v4 不依赖，hoisting 到根 `node_modules` 时找不到对应版本 → worker 报错。

CI 侧也跟着改了 (`.github/workflows/kallax-ci.yml:57-58`)：从 `working-directory: node` + `npm ci` 改成仓库根 `npm install`。

`.claude/rules/testing.md:39-46` 明确列了 4 张受影响 ticket 的 BLOCKED-env 判断并声明不追溯改写。EPIC-157/159/160/251 现在 status 都是 done。这个处理方式是干净的——保留了错误判断的痕迹而不是抹掉。

守卫 test 实跑通过（`/tmp/retro/wt2`）：`EPIC-255 Lockfile Single Source Tests: 10 passed, 0 failed`。

### 3 + 4. grep -c 污染 — scripts/ 清了，其他目录没清

`scripts/` 目录确实 0 残留，守卫 test 实跑 `12 passed, 0 failed`。

但按目录统计 `origin/miao` 上剩余的污染模式（排除注释行）：

```
scripts  = 0     ← 修了
tests    = 36    ← 没修
.claude  = 9     ← 没修
.github  = 1     ← 没修
hooks    = 0
.kallax  = 0
```

守卫 test 自己写死了只扫 `scripts/`（`grep-count-pollution.test.sh:89`）：
```bash
N1=$(grep -rn 'grep -c' scripts/ 2>/dev/null | grep '|| echo' | ...)
```

所以事故 4 的教训（"首轮扫描范围不全就宣称全修完"）**在事故 3 的修复里又发生了一次**——只是这次漏的不是引号变体，是目录。ticket EPIC-254 的 AC1 措辞其实是诚实的（"全仓 scripts/ 代码行"），但 EPIC-254 commit message 写的是"全仓清 grep -c 输出污染 (32 处)"，两者不相同。

**关于严重度的一个重要修正**: 我实测了污染的触发条件——

```
真实计数 > 0 → grep -c rc=0 → `|| echo` 不触发 → 值干净
真实计数 = 0 → grep -c rc=1 → `|| echo` 触发 → 值变 "0\n0"
```

污染**只在真实计数为 0 时发生**。所以 `[ "$X" -gt 0 ]` 这种判断，污染后 `[` 返回 rc=2 被当 false，跟正确值 0 的行为**相同**——不产生错判。只有 `[ "$X" -eq 0 ]`（期待 0 走 pass 分支）和 `$(( X + 1 ))` 算术会真出问题。

我按这个模型重跑了 merge-validator 的 pre-fix 版本（`/tmp/retro/s36.sh`）：`CHECKS="[]"` 时 buggy 版 `FAILED="0\n0"`，`[ "$FAILED" -gt 0 ]` rc=2 不触发 fail，`EXIT_CODE=0`；fixed 版 `FAILED="0"`，同样不 fail，`EXIT_CODE=0`。**两者最终 exit code 相同**。

所以 EPIC-254 ticket 里"CI 失败可能不被拦 (fail-open)"这个说法**没有被我复现出来**。真的 CI 失败时 `grep -c` 会匹配到内容、rc=0、污染不发生、`FAILED` 是正确的正整数、`-gt 0` 正常触发 fail。修是对的（噪声 + `-eq 0` 分支静默），但严重度被高估了一档。这属于事故 2 同型的问题：**诊断写在 ticket 里当结论，没做独立复现**——Rule 34 要求 Performer 复现，但 Master 自己写的 diagnosis 没人复现。

### 5. immutable delete-only diff bug — 修好了

`scripts/verify/check-decorative-claim.sh:94`：
```bash
ADDED=$(git diff --cached -U0 -- "$file" 2>/dev/null | grep '^+' | grep -v '^+++' | sed 's/^+//' || true)
```
`|| true` 在，行 91-93 有注释说明。

我独立复现了原始 bug（`/tmp/retro/s13.sh`，临时 git repo，纯删除 staged diff）：`git diff --cached -U0 | grep '^+' | grep -v '^+++'` → rc=1。`set -euo pipefail` 下会中断。复现成立。

只有 `check-decorative-claim.sh` 需要这个修复；`check-narrative` / `check-fail-closed` / `check-self-heal` 是直接对文件内容 `grep`（不读 diff），不暴露在这个 bug 下。

### 6. set -e 泄漏 — 当次修了

`grep-count-pollution.test.sh` 顶部现在是 `set -uo pipefail`（无 `-e`），行 66-67 有注释记录踩坑经过。

### 7. immutable STAGED_ONLY 误诊 — 确认是误诊，0 改 immutable 是对的

`KALLAX_STAGED_ONLY` 引入于 `256d6aca feat(EPIC-110): 4 immutable-law hook + exemption + staged-only`。4 个原始 immutable 全部有 `git diff --cached --name-only --diff-filter=ACM`，引用数 4-7 次。`pre-commit:270` 传 `KALLAX_STAGED_ONLY=1`。EPIC-252 结论正确。

值得注意: EPIC-224 后接入的 3 个新 immutable 里，`check-ticket-schema.sh` 和 `snapshot-claude-md.sh` **0 处** `STAGED_ONLY` 引用——它们靠 pre-commit 侧先过滤 staged 文件再调用，机制不同。CLAUDE.md 说"9 immutable 全部已接入 hook"是对的，但这 9 个的 staged-only 语义不统一，这是 EPIC-252 那类误诊的土壤。

---

## 根因归类

7 条事故收敛到 **4 类**。

### 根因 A: bash 退出码与输出语义混淆 (事故 3、5、6，占 3/7)

三条都是同一个认知缺口：**bash 里"输出内容"和"退出码"是两个独立通道，`grep` 系列把"没找到"编码进退出码而不是输出**。

- `grep -c` 无匹配: 输出 `0` + rc=1（输出已完整，rc 只是信号）
- `grep '^+'` 无匹配: 无输出 + rc=1
- `set -e` 下 rc=1 = 致命；`|| echo X` 把信号误当成"要补默认值"

**机制性防御建议 — 该放在 hook 层，不是 test 层。**

理由: test 层已经试过了，`grep-count-pollution.test.sh` 只扫 `scripts/`，漏了 45 处（tests 36 + .claude 9）。test 的扫描范围是人手写死的字符串，会跟目录结构脱节。而 pre-commit hook 天然只看 staged 文件——**不需要维护扫描范围，改到哪扫到哪**，正好避免事故 4 那类"范围没覆盖全"。

具体: pre-commit 加一个 shell 反模式 gate，扫 staged `*.sh` / `*.yml`：
1. `grep -c ... || echo <数字>` → 报错，提示改 `|| true` + `${VAR:-0}`
2. 无 `|| true` / `|| :` / `-q` 保护的裸 `grep` 出现在 `set -e` 文件的赋值里 → 警告
3. 文件末尾最后一个 `set` 切换是 `set +e` → 报错（见残留问题 P1-3）

配合把这个 gate 的规则写进 `.claude/rules/` 而不是 CLAUDE.md 主文件（主文件已 188 行贴着 200 硬阈值）。

**不建议**再写第 4 个全仓扫描 test——那是重复事故 4。

### 根因 B: 单一真相来源缺失 (事故 2)

`node/package-lock.json` 是 `npm audit fix` 在错误的工作目录跑出来的副产物（`080eb414`，只有 1 次提交）。产生的瞬间就有两份依赖真相，但没有任何东西发现它。

**机制性防御 — hook 层 + 已有 test 层足够，但要扩范围。**

`lockfile-single-source.test.sh` 已经存在且实跑 10 passed，但它硬编码只检查 `node/package-lock.json` 一个路径。应该改成**通用规则**: "`package.json` 的 `workspaces` 列出的每个成员目录都不许有 lockfile"。这样将来加 workspace 成员自动覆盖。

更强的一层放 pre-commit: staged 文件里出现 `<workspace-member>/package-lock.json` 直接拒绝 commit。这是最便宜的位置——文件根本进不来仓库，就不会有"1 次提交后没人发现"。

### 根因 C: 先声明成功，后验证 (事故 1、3-的严重度、4，占 3/7)

三个不同表现，同一个行为：

- 事故 4: 扫到 12 处 → 宣称"全修完" → test 报 23 处残留
- 事故 3: ticket 写 "CI 失败可能不被拦 (fail-open)" → 我实跑复现不出来，严重度高估一档
- 事故 1: 改完主仓副本 → 认为 status 已同步 → 实际 commit 走的是 worktree

事故 3 的 ticket 有完整的 `reproduction_command` / `exit_code` / `raw_output` 三字段（Rule 34），raw_output 证明了**症状**（`[: 0\n0: integer expression expected`），但没证明**后果**（fail-open）。Rule 34 现在要求复现症状，不要求复现声称的影响。

**机制性防御 — 文档层（改 Rule 34 措辞），不是 hook 层。**

hook 拦不住"影响判断没复现"这种事——它需要读懂 ticket 的语义。合适的做法是把 Rule 34 的 3 字段扩成 4 字段，加一条 `verification.impact_reproduction`：如果 ticket 声称严重度是 P0/fail-open，必须附上让 gate 真的放行错误输入的 raw output；复现不出来就把严重度降级。

这条改动成本极低（改 `.archive-baseline.json` 的 `new_ticket_required_fields` + `check-ticket-schema.sh` 就能强制），但只对声称 fail-open 的卡生效，不然会变成所有卡的负担。

### 根因 D: worktree / 主仓双份工作副本 (事故 1)

`git worktree` 让同一个仓库有多个工作副本。在主仓编辑 `jira/tickets/*/ticket.json`，然后在 worktree 里 `git commit` —— 主仓的改动整体不在 commit 里，而且**两边都没有任何报错**。`git status` 在 worktree 里看不到主仓的 dirty 文件。

这是事故 1 复发的直接原因，也是最难用工具防的一类——因为两个副本都是合法的 git 工作树。

**机制性防御 — hook 层，但要装在正确的位置。**

`scripts/hooks/pre-commit:42-44` 已经有相关踩坑记录: `BASH_SOURCE[0]` 在 worktree 里解析到主仓 `.git/hooks/`，所以 `KALLAX_ROOT` 永远指主仓 → worktree 内改动检测不到。修法是改用 `--show-toplevel`（EPIC-227 做的）。

但那修的是**反方向**（hook 看不到 worktree 的改动）。事故 1 是**正方向**（在 worktree commit 时，主仓有未提交的相关改动）。建议 pre-commit 加一步：如果当前在 worktree 里 commit，且 `git -C <主仓路径> status --porcelain -- jira/tickets/` 非空，就警告"主仓有未提交的 ticket 改动，确认是否该一起提交"。

**不建议**做成硬拦截——主仓有无关 dirty 文件是常态，硬拦会天天误报。警告 + 列出具体文件路径就够了，因为这个坑的本质是"整体无声"，只要有声音就能避免。

补充: 全仓 grep `主仓|main repo`，`.claude/rules/` 和 CLAUDE.md 里**只有 1 处**命中（`testing.md:19`，讲 npm install 位置的）。worktree/主仓的编辑边界整体没有成文规则。这本身就该补一段。

---

## 残留同类问题

严重度定义: **P0 = gate 该拦没拦（fail-open）** / **P1 = 产生错误判断或静默中止** / **P2 = 噪声、误导性文字**。

### P0-1 `ticket-status-sync.sh` 是 stub 但输出 "PASS" 并 exit 0

`scripts/conductor/ticket-status-sync.sh:25-31`
```bash
echo "[STUB] Iter 5 will implement: status field sync + claimed_at/in_progress_at/done_at timestamps"
echo "PASS: stub-ok (Iter 5 will replace)"
exit 0
```

这是唯一一个本该防止事故 1 的脚本，它对所有输入返回成功。任何 gate 把它串进流程都会得到假 PASS。而事故 1 已经复发了 2 次（EPIC-254/255），正好是它该管的事。

同型的还有 `scripts/verify/test-fact-forcing-preflight.sh:11`（同样 `[STUB]` + exit 0）。

修法: stub 应 exit 2（未实现），不是 exit 0。或者删掉——留一个永远返回成功的验证脚本比没有更危险。

### P0-2 EPIC-254 / EPIC-255 ticket status 仍是 `in_progress`

`jira/tickets/EPIC-254/ticket.json` / `jira/tickets/EPIC-255/ticket.json`（`origin/miao` @ `53d3e2aa`）

`status=in_progress`，`pr_chain=null`，`updated_at=null`。工作已 merge (PR #418 / #421)。`check-ticket-schema.sh` 对两者 exit 0（实跑确认）。

这条列 P0 不是因为它自己是 fail-open，而是因为**它证明了现有 ticket gate 对这类错误零覆盖**——Rule 36 指标 #4 (`mis_dispatch_rate`) 的数据源就是这些字段，字段是 null 就等于指标无输入。

### P1-1 `check-glossary-size.sh` 静默 exit 1（裸 grep -c + set -e）

`scripts/verify/check-glossary-size.sh:55`
```bash
set -euo pipefail          # line 45
term_count=$(grep -cE "^### [0-9]+\." "$GLOSSARY")   # line 55, 无任何保护
```

无匹配时 rc=1 → `set -e` 立即终止，**行 57 之后的判断和输出全部不执行**，脚本静默 exit 1。调用方看到 exit 1 会理解成"glossary 超标"，实际是"glossary 里没有 `### N.` 格式的条目"。这是事故 5 的整体同型（`set -euo pipefail` + 裸 grep → 静默误判）。

我实跑复现了（`/tmp/retro/s30.sh`）: 喂一个 0 条目文件 → `rc=1`，**stdout / stderr 全空**。

额外发现: 这个脚本默认路径是 `docs/kallax-glossary.md`，而 `origin/miao` 上 `find docs -iname '*glossary*'` 只找到 4 个 `_archived/` 里的文件——**默认目标文件不存在**。不过行 50-53 有 `-f` 检查会 `exit 0` 跳过，所以实际不触发。是死代码，但一旦有人建了那个文件就会踩上面的静默 exit。

顺带: 这个文件行 41-43 的注释里有 `全程` / `沿用` / `长期` / `相同`，正是 EPIC-225 黑名单要禁的词。我实跑 `check-jargon.sh scripts/verify/check-glossary-size.sh` → `OK: 0 jargon violations`，因为它被 baseline 历史豁免了。属 P2，一并记在这。

### P1-2 `auditor-l4.sh` / `performer-complete-test.sh` 裸 grep -c

- `scripts/verify/auditor-l4.sh:136` — `matches=$(grep -cE "$ap" "$f" 2>/dev/null | head -1)`。这个**有防御**: 行 131 `set +e`、行 148 `set -e`、行 79-80 `matches="${matches:-0}"` + `=~ ^[0-9]+$` 校验。实际安全，但依赖 3 层手工防御而不是一个 `|| true`，脆弱。
- `tests/integration/performer-complete-test.sh:144` — `HARDCODED_STEPS=$(grep -cE '^echo "── Step [0-9]+/9:' "${SCRIPT}")`，文件顶部 `set -e`，**无任何保护**。目标 script 一改格式，test 就静默 exit 1 而不是报 FAIL。

### P1-3 `epic-197-doc-audit-test.sh` 全局 `set +e` 从未恢复

`tests/integration/epic-197-doc-audit-test.sh:10-15`
```bash
set -euo pipefail          # line 10
# Disable -e just for grep count (returns 1 on 0 hits)
set +e                     # line 15  ← 文件剩余 131 行全部无 -e 保护
```

我扫了 `tests/` + `scripts/` + `hooks/` 全部 `.sh`，用"最后一个 `set` 切换是 `set +e`"作判据，**只有这 1 个文件**命中。其余的 `set +e` / `set -e` 都配对。

严重度是 P1 而非 P0，因为该 test 末尾有显式 `if [ "$FAIL_COUNT" -eq 0 ]; then exit 0; else exit 1`，最终判定靠计数器不靠 `set -e`。但中间 131 行里任何命令失败都不会被发现。

另外这个 test **没有被任何 CI workflow 或 runner 脚本调用**（见 P2-1）。

### P1-4 `docs-link-check-test.sh:262` 污染值进算术展开

`tests/integration/docs-link-check-test.sh:262`
```bash
V205_TOTAL=$(( $(grep -cF "v2.0.5" "$INSTALL_GUIDE" 2>/dev/null || echo 0) + $(grep -cF "v2.0.5" "$CHANGELOG" 2>/dev/null || echo 0) ))
```

这是 36 处 `tests/` 残留里**唯一进算术上下文的**，也是唯一能造成真实中断的。我实测了算术展开碰上 `"0\n0"`：

```
bash: 0
0 + 1 : syntax error in expression (error token is "0 + 1 ")
rc=1
```

该文件顶部是 `set -uo pipefail`（无 `-e`），所以不会中断，但 `V205_TOTAL` 会变空，`[ "$V205_TOTAL" -ge 1 ]` 报 integer expression error 走 else 分支 → **误报 FAIL**。

实跑该 test 当前 rc=1（`3/5 exit 0`），TC2 0/3 + TC4 1/3 已经在失败——但这些失败跟本条无关（v2.0.5 引用当前存在，`grep -cF` 匹配到、rc=0、污染不触发）。是潜伏问题，不是当前失败原因。

### P1-5 `.claude/commands/` 9 处污染，且这些文件多数无 `set` 声明

- `.claude/commands/kallax-verify-pr.sh:61` — `STUB_COUNT=$(... grep -ci ... || echo "0")`，行 62 `[ "$STUB_COUNT" -gt 0 ]`。`-gt 0` 方向安全（污染值 rc=2 当 false，跟真 0 行为相同）。
- `.claude/commands/kallax-verify-pr.sh:75` — `IMPORT_ISSUES`，行 76-78 `-gt 0` 后 **`exit 1`**。同上，方向安全，不会假放行。
- `.claude/commands/kallax-check-progress.sh:51-53` + 行 58 `COMPLETION=$(( (DONE * 100) / TOTAL ))` — **算术展开**，跟 P1-4 同型。行 57 有 `[ "${TOTAL:-0}" -gt 0 ]` 守卫，但守卫本身在污染时 rc=2 走 else，反而不进算术。侥幸安全。
- 其余 6 处（`kallax-analyze.sh:86,88`、`kallax-research.sh:66`、`kallax-check-progress.sh`、`kallax-phase-review.sh:50`）只用于 echo 展示 → P2 噪声。

另外 28 个 `.claude/commands/*.sh` 里**只有 2 个有 `set` 声明**（`_kallax_common.sh`、`kallax-research.sh`），其余 26 个裸奔无 `set -e` / `set -u`。这是独立于本 sprint 的技术债，但意味着这个目录整体不适用 `set -e` 相关的分析。

### P2-1 shell test 全部不在 CI 里跑

我把 `.github/workflows/` 全扫了一遍: **0 个 workflow 引用 `tests/` 目录**（`git grep -n 'tests/' origin/miao -- '.github/workflows/*'` → rc=1，无输出）。

CI 只跑: `cargo test --workspace`、`npx vitest run`（node/）、`bash -n` 语法检查（`scripts/verify/check-*.sh`）、几个 hook 自检。

所以 `grep-count-pollution.test.sh` 和 `lockfile-single-source.test.sh` 这两个新写的守卫 test **只能靠人手跑**。EPIC-254/255 的 AC 引用了它们的 raw output（`12 passed` / `10 passed`），我也实跑确认通过——但它们不会阻止将来的回归。

这条是 P2 而非 P0，因为它不产生错误判断，只是防护不生效。但它解释了为什么根因 A 的防御该放 hook 层：**hook 会真的跑，tests/ 下的 .sh 不会**。

### P2-2 EPIC-254 commit message 范围声明与实际不符

`a80cfcd9` / `2e13df66` 标题: `全仓清 grep -c 输出污染 (32 处)`。

实际只清了 `scripts/`。全仓剩 46 处（tests 36 + .claude 9 + .github 1）。ticket 的 AC1 措辞是准确的（"全仓 scripts/ 代码行"），commit message 不准确。这正是事故 4 的教训该防的表述方式。

### P2-3 `web/package-lock.json` — 是第二份 lockfile，但不是双份真相

`web/package-lock.json`（598 行，49 packages）。

我核实了它**不构成** EPIC-255 那类问题:
- 根 `package.json` 的 `workspaces` 只有 `["node"]`，`web/` 不是 workspace 成员
- `web/package.json` name = `kallax-web-dashboard`，唯一依赖 `http-server`
- 根 lockfile **不含** `http-server`（`jq '.packages | has("node_modules/http-server")'` → `false`）

零重叠，是独立的子项目。**不是残留问题**，列在这里是为了闭掉"还有没有其他重复 lockfile"这个问题——答案是没有。

同样核实过无重复的: `Cargo.lock` 只 1 份（`rust/`）、`tsconfig.json` 只 1 份（`node/`）、`vitest.config.ts` 只 1 份（`node/`）、声明 vitest 的 `package.json` 只 1 份（`node/`）、`CLAUDE.md` 只 1 份。

### P2-4 9 个 immutable 的 staged-only 语义不统一

`STAGED_ONLY` 引用数: `check-decorative-claim` 7 / `check-narrative` 4 / `check-fail-closed` 4 / `check-self-heal` 4 / `check-disclaimer` 1 / `check-claim-evidence` 0 / `snapshot-claude-md` 0 / `check-ticket-schema` 0 / `check-jargon` 0（用 `--staged` flag 而非环境变量）。

后 4 个靠 pre-commit 侧先过滤 staged 文件列表再传参，机制不同但结果正确。CLAUDE.md §5 说"9 immutable 全部已接入 hook"没错，但这种不统一正是 EPIC-252 那次误诊（"以为没实现 staged-only"）的成因。建议在 `.claude/rules/immutable-scripts.md` 里为每个脚本标明它用哪种 staged 机制。

---

## 最有价值的发现

**用 test 层做全仓反模式扫描，结构上必然重演事故 4；这三条事故（3、4、和 P0-2/P1-5）是同一个机制的三次显影。**

事故 4 的教训被理解成"正则要写全"，于是 EPIC-254 补了引号变体。但真正的失效点不是正则——是**扫描范围由人手写的字符串常量决定**。`grep-count-pollution.test.sh:89` 写死 `scripts/`，于是 `tests/` 36 处 + `.claude/` 9 处 + `.github/` 1 处 全部逃过，而 test 输出 `12 passed, 0 failed` 给出"已清零"的信号。同一个 sprint 里，同一个坑，换了个维度（目录 vs 引号）又踩一次——而且这次是**在修那个坑的 PR 里踩的**。

再叠一层: 这个 test 连 CI 都不跑（`.github/workflows/` 0 处引用 `tests/`）。所以它既扫不全，又不会自动执行。

对比 pre-commit hook: 它只看 `git diff --cached`，范围由 git 决定而非人手维护，改到哪扫到哪，而且必然执行。同样的检查逻辑放 hook 层，事故 4 这一类"范围没覆盖到"在结构上就不可能发生。

这个判断还能解释另外两件事: 事故 1 复发（唯一该防它的 `ticket-status-sync.sh` 是个 exit 0 的 stub，不是 hook）、以及为什么 `check-ticket-schema.sh` 装在 pre-commit 里就真的每次都跑、只是校验规则没覆盖 status 语义。

**可执行的收敛**: 别写第 4 个全仓扫描 test。把 grep 反模式 + set +e 泄漏 + workspace 成员 lockfile 三条检查合成一个 pre-commit gate（staged-only，跟现有 9 immutable 同机制），然后把 `grep-count-pollution.test.sh` 降级成 gate 自身的单元测试（测 gate 能识别已知的好/坏样本），而不是让它承担全仓普查的职责。
