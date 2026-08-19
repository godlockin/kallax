# EPIC/Ticket 编号冲突 — 现状摸底与方案对比

调查时间: 2026-08-11 | 仓库: kallax (branch miao) | 调查者自跑命令, 原始输出在 `/tmp/probe/out1.md` ~ `out11.md`

---

## 1. 现状摸底

### 1.1 编号散落的 11 处

| # | 位置 | 形态 | 是否被 `next-epic-id.sh` 覆盖 |
|---|------|------|------|
| 1 | `jira/tickets/EPIC-NNN[-X]/` 目录名 | 权威载体 | 是 (远端 + 本地) |
| 2 | `confluence/decisions/EPIC-NNN-*.md` 文件名 | 45 个编号只有这个 | 是 (仅文件名) |
| 3 | `confluence/decisions/*.md` 正文交叉引用 | 大量 | **否** (脚本注释里明说是有意取舍) |
| 4 | branch 名 (local + remote, 含 `e248-main-to-miao` 这种非标准格式) | 有人在做未建卡 | 部分 — regex `EPIC-[0-9]{3}` 匹配不到 `e248-` 这种 |
| 5 | commit message | `origin/miao` 最近 300 commit 里最大 255 | **否** |
| 6 | `CHANGELOG.md` | 最大 197 | **否** |
| 7 | `CLAUDE.md` + `.claude/rules/*.md` | 最大 242 (Rule 引用) | **否** |
| 8 | `ticket.json` 内部字段 | 实际字段是 `ticket_id` + `epic`, **不是** `id` | 否 |
| 9 | `jira/tickets/EPIC-*/pass-report-EPIC-*.json` 文件名 | 冗余第二份 | 否 |
| 10 | `jira/tickets/.archive-baseline.json` 的 `archived_before: 222` / `archived_range.from/to` | 纯整数, 无 `EPIC-` 前缀 | 否 |
| 11 | 占位编号: `EPIC-999` 出现 22 处, `EPIC-351` 1 处, `EPIC-0313` 1 处 | 假编号污染统计 | 否 — `EPIC-0313` 会被 3 位 regex 截成 `031` |

**发现的 schema 事实**: `ticket.json` 用 `ticket_id` 字段, 不是 `id`。但 `.archive-baseline.json` 的 `new_ticket_required_fields` 第一项写的是 `"id"`。任何按 `id` 字段做编号校验的方案会在 191 个现存 ticket 上全部读到空值 (已实测)。

### 1.2 编号总量与最大值 — 每个来源给出不同答案

| 来源 | 最大编号 |
|------|---------|
| 本地工作副本 `jira/tickets/` | **177** |
| `origin/miao` 的 `jira/tickets/` | **255** |
| 本地 `confluence/decisions/` | 244 |
| `origin/miao` 的 `confluence/decisions/` | 248 |
| `CHANGELOG.md` | 197 |
| `CLAUDE.md` + rules | 242 |
| local branch | 259 |
| remote branch | 258 |
| `origin/miao` commit message | 255 |

已占编号 (≤259, 去重, 含 branch): **215 个**。`≤259` 范围内的空号 45 个:
```
2-10 11 13 14 17-20 43 44 46 47 61 66 67 78 90 96 100 104 106
123 125 126 128 129 179 192 195 230 233 234 246 249 250 256 257
```
**这份空号表本身就是陷阱**: 249 / 250 在本地看是空号, 在 `origin/miao` 上是 `status: done` 的真卡。事故就长这样。

### 1.3 已存在的冲突 (不是假设, 现在就有)

三个 worktree 全部落后 `origin/miao` 21~23 commits:
```
kallax              21 behind   HEAD 2026-08-10
kallax-wt-EPIC-245  21 behind   HEAD 2026-08-17
kallax-wt-EPIC-258  23 behind   HEAD 2026-08-17
kallax-wt-EPIC-259  23 behind   HEAD 2026-08-17
```

**语义冲突 3 例**:

| 编号 | `origin/miao` 上是什么 | 本地 worktree 上是什么 | 状态 |
|------|---------------------|-------------------|------|
| **248** | ticket `status: done`, "EPIC-170 判定推翻 — 测试计数 bug" + `EPIC-248-249-250-triple-2026-08-10.md` | EPIC-245 计划文档曾编成新卡 | 已发现, 已纠正 |
| **245** | `EPIC-245-heartbeat-test-stable-2026-08-10.md` (decision doc) | ticket `status: todo`, "check-doc-budgets.sh + budgets.manifest.json" | **未纠正, 撞着** |
| **247** | `EPIC-247-workspace-recursion-2026-08-10.md` | ticket `status: todo`, "verify-agent-note-format.sh + ADR lifecycle" | **未纠正, 撞着** |

EPIC-245 worktree 的计划文档第 10 行写着 "初版计划写 EPIC-256~259。实测 repo 最大真实编号 = EPIC-244"。这次"诚实修正"把编号从 (实际空闲的) 256-259 改到了 (实际已占的) 245-248 — 修正方向是反的, 因为它数的是落后 21 commits 的目录。

**格式冲突**: 8 个编号有 2~3 个 decision 文档 (132 / 175 / 196 / 197 / 199 / 200 / 201 / 202), 语义各不同 (如 `EPIC-200-doc-audit-2` vs `EPIC-200-retrospective-supplement`)。`EPIC-016` 有 19 个子目录, `EPIC-029` 有 11 个。**编号今天已经不是唯一键, 是带子命名空间的松散标签** — 这个事实影响所有方案的必要性判断。

### 1.4 `.archive-baseline.json` 的 `archived_before` 机制

`scripts/verify/check-ticket-schema.sh:34` 用
```
echo "$epic" | sed -E 's/^EPIC-0*([0-9]+).*/\1/'
```
把 `EPIC-223` → `223`, `EPIC-168-BG` → `168`, 然后跟 `archived_before=222` 做整数比较:
- `≤ 222` → exit 3 `ARCHIVED_SKIP`, 不检查
- `> 222` → 强制 `new_ticket_required_fields` 全填

**跟编号分配的关系**: 它不分配编号, 但它**依赖编号单调递增且可比大小**。它是"新卡强制 schema"的唯一判据。任何非整数编号 (方案 C) 会让这个 sed 输出原字符串, 整数比较报错或静默判成 0 → 所有新卡被当历史卡跳过检查。这是 C 的硬伤, 不只是"数值比较失效"这么轻。

Rule 36 指标 #4 同样读这个文件做 `ARCHIVED_SKIP`。

### 1.5 已有的编号管理机制 — 基本没有

- `scripts/epic/epic-create.sh` (119 行): 编号靠 `--id EPIC-XXX` **人手传**。唯一保护是第 67 行 `if [[ -f "$EPIC_JSON" ]]; then ERROR: already exists` — 只查**本地** `jira/epics/`, 且查的是 `jira/epics/` 不是 `jira/tickets/`。本地落后时这个检查必然放行。
- `scripts/next-epic-id.sh` (在 `kallax-wt-EPIC-259` worktree, 未合并, 10924 字节): 查询工具。查 4 个来源, 默认**不 fetch** (`DO_FETCH` 默认 0), 只打印 ref 的 commit 时间让人自己判断新旧。有 `--fetch` 但是 opt-in。**不预留**。
- pre-commit hook 装了 14+ 个检查 (jargon / disclaimer / ticket-schema / decorative-claim / …), **没有一个查编号占用**。
- 15 个 CI workflow, `rg -l -i 'numbering|epic-id|next-epic' .github/` 结果为空 — CI 整体不管编号。
- 无 git notes, 无 registry 文件, 无锁。

**一句话**: 现在的机制是"人肉数目录 + 希望本地是新的"。`next-epic-id.sh` 把"数目录"自动化了, 但把"希望本地是新的"这个前提原封不动保留下来 (默认不 fetch)。

---

## 2. 方案对比

### 方案总表

| | 方案 | 落地成本 | 并发安全 | 防住已发生事故? |
|---|------|---------|---------|----------------|
| A | 中心化 registry 文件 `jira/tickets/.numbering.json` | 中 (新文件 + 写入路径 + merge 策略) | **不安全** | 只在 registry 是新的时候能防 → 同源失效 |
| B | 编号段预分配 (worktree A 用 260-269) | 低 (纯约定) | 安全 (段内无争用) | 只在分段动作基于新 base 时能防 |
| C | 去中心化 ID (`EPIC-20260817-A` / hash) | **极高** | 安全 | 能防 (无争用点) |
| D | 分配时机后移 (`EPIC-DRAFT-<slug>`) | 高 | 安全 | 能防 |
| E | git 层 pre-commit 拒绝已占编号 | 低 | 不安全 (无原子性) | **看实现** — 查本地=不能防, 查远端=能防 |
| **F** | **git ref/tag 做 compare-and-swap 预留** | 中低 | **安全 (服务端原子)** | **能防** |
| G | 不解决, 只加事后检测 (CI 报冲突) | 极低 | — | 不防, 只早发现 |

---

### A. 中心化 registry 文件

`jira/tickets/.numbering.json` 记录 `{number, allocated_at, allocated_by, branch, purpose}`。

- **落地成本**: 中。需要写入脚本、schema、pre-commit 校验、以及**一次性回填 215 个已用编号** (可脚本生成, 但 245/247/248 这类冲突要人来裁定归谁)。
- **失效模式**:
  1. registry 自己是冲突热点。两个 worktree 各追加一行 → 同一位置 merge conflict。JSON 数组尾部追加几乎必然冲突, 需要改成"一编号一文件" (`.numbering/259.json`) 才能靠 git 天然免冲突 — 那就退化成"再数一遍目录", registry 的价值只剩元数据。
  2. **跟事故根因同源**: 落后 21 commits 的 worktree 读到的是落后 21 commits 的 registry。EPIC-245 事故里人数的是目录, 换成数 registry 结果一样。
  3. 双写不相同: registry 说 259 已分配, 但没人建目录; 或建了目录忘记写 registry。需要第三个 check 来对账。
- **跟现有机制的冲突**: 跟 `.archive-baseline.json` 并列出现两个"编号真相源", 违反 DRY。pre-commit 已有 14 个检查, 再加一个的边际成本主要是维护而非运行。
- **什么情况下失败**: 本地 registry 陈旧 (常态); 或有人绕过脚本手建目录; 或两个 worktree 同时分配后各自 merge。

### B. 编号段预分配

worktree A 拿 260-269, B 拿 270-279。

- **落地成本**: 最低 — 可以是纯口头约定, 0 代码。
- **失效模式**:
  1. **谁来分段** = 把同一个争用问题上移一层。分段动作本身需要知道"当前最大段", 如果在落后的 base 上分段, 分出去的段可能已被占。
  2. 段耗尽: 一个 worktree 做 12 张卡就溢出 10 段。溢出时的行为未定义 → 回到人肉数目录。
  3. 段浪费: 现在 ≤259 已有 45 个空号 (17% 空洞率)。分段会把空洞率推到 40%+, 三个月后编号跑到 400 而实际卡数 250。
  4. 段跟 worktree 生命周期不匹配: worktree 用完删掉, 段的归属没人回收。
  5. 一次性任务 (不开 worktree, 直接在主副本建卡) 没有段。
- **跟现有机制的冲突**: `archived_before` 整数比较仍然工作 (编号还是整数, 只是更稀疏)。跟 Rule 35 "每 Sprint 最多 5 个 EPIC" 反而配合得不错 — 一段 10 个够一个 Sprint。
- **什么情况下失败**: 分段者本地陈旧; 或段耗尽; 或有人不开 worktree 直接建卡。

### C. 去中心化 ID

`EPIC-20260817-A` 或 `EPIC-a3f9`。

- **落地成本**: **极高, 建议直接淘汰**。要改: 191 个 ticket 目录名 + 98 个 decision 文件名 + `ticket_id`/`epic` 字段 + 22 处 `EPIC-999` 占位 + `CHANGELOG` + `CLAUDE.md` + `.claude/rules/*` 的 Rule 引用 (Rule 34 = EPIC-152, Rule 36 = EPIC-194, 这些引用是有语义的) + 88 个 git tag 关联 + 全部 branch 名 + `pass-report-*.json` 文件名。
- **失效模式**:
  1. `check-ticket-schema.sh:34` 的 sed 整数比较崩掉 → `archived_before: 222` 语义消失。必须改成显式 archived 名单 (215 项枚举)。Rule 36 指标 #4 同时受影响。
  2. 日期编号在同一天多张卡时**仍需后缀区分** → 后缀又是争用点 (`-A` 还是 `-B`?)。8 月 8 日一天新增 20 个编号, 后缀会到 `-T`。
  3. 短 hash 整体不可读。主公口头说 "EPIC-259" 可行, 说 "EPIC-a3f9" 不可行。
  4. 混合期间两种格式共存, 所有 regex (`EPIC_NUM_RE`, `check-ticket-schema.sh`, metrics 脚本) 都要双轨。
- **什么情况下失败**: 迁移只做了一半 (最可能的结局)。

### D. 分配时机后移

建卡用 `EPIC-DRAFT-doc-budgets`, 合并进 main/miao 时才换成真编号。

- **落地成本**: 高。需要一个"重命名 + 改引用"的合并前步骤 (目录名、`ticket_id`、`epic`、branch 名、decision 文件名、PR 标题、commit message 里的引用)。commit message 无法回改 — 会留下 `EPIC-DRAFT-xxx` 的历史。
- **失效模式**:
  1. **合并时刻才分配 = 争用推迟到合并时刻**, 而 4-branch flow 下合并是最忙的时刻 (feature→testing→main→miao 四次)。在哪一步分配? 若在 feature→testing, 后面三步基于已分配编号, 但 testing 可能被别人的 PR 抢先。
  2. slug 自己会撞 (两个人都叫 `doc-budgets`)。
  3. 破坏 Rule 34 的 ticket 追溯: bugfix ticket 的 `reproduction_raw_output` 里可能含编号。
  4. `check-ticket-schema.sh` 的 `archived_before` 比较对 `EPIC-DRAFT-*` 无法取整数 → draft 期间 schema 检查静默跳过, 正好是最该检查的时候。
- **优点不能忽略**: 它是唯一能同时消灭"编号浪费"和"争用"的方案 — 因为编号只在确定要留下时才发。
- **什么情况下失败**: 分配点选在 4-branch 流程的哪一环没有定论时; 或改名步骤漏了某处引用。

### E. pre-commit 拒绝已占编号

- **落地成本**: 低。复用 `next-epic-id.sh --check` 的逻辑, 在 pre-commit 里扫 staged 的新增 ticket 目录 / decision 文件名。hook 体系已有 (`scripts/hooks/install.sh --verify`), 挂载点现成。
- **失效模式**:
  1. **查本地 = 跟事故根因同源, 防不住**。落后 21 commits 时 `git ls-tree origin/miao` 读的是陈旧的 remote-tracking ref, 会说 249 空闲。
  2. **查远端 (强制 fetch) = 能防**, 代价是 pre-commit 要联网。离线时的行为必须定: fail-closed (拒绝 commit) 会在飞机上整体卡死工作; fail-open 就等于没有。
  3. 无原子性: 两个 worktree 同一秒各自 commit EPIC-260, 两边 hook 都说空闲。hook 只防"跟已推送的撞", 不防"跟并行的撞"。
  4. `git commit --no-verify` 是官方逃逸路径 (CLAUDE.md 里明写"主公明确批准时"可用)。
  5. **最关键的漏点**: EPIC-248 事故里编号是先出现在**计划 markdown** 里的, 不是先建目录。hook 必须扫 `.md` 的正文里新出现的 `EPIC-NNN`, 否则整条事故路径整体不经过它。
- **什么情况下失败**: 离线 + fail-open; 或不 fetch; 或编号只出现在正文而 hook 只扫文件名。

### F. git ref / tag 做 compare-and-swap 预留 (调查中新提的方向)

用 remote 上的 ref 命名空间当分布式锁。分配编号 = 向 `origin` 推一个"仅当不存在时才创建"的 ref:

```
git push origin HEAD:refs/kallax/epic/259 --force-with-lease=refs/kallax/epic/259:
```
`--force-with-lease=<ref>:` 空期望值的含义是"该 ref 必须不存在"。判定在**服务端**做, 两个 worktree 同时推同一个编号, 一个成功一个被拒。

fallback (若 GitHub 拒收自定义 ref 命名空间): 用轻量 tag `epic-num/259`, 推已存在的 tag 默认被拒。

- **落地成本**: 中低。一个 `reserve-epic-id.sh` (~100 行) + `next-epic-id.sh` 增一个"读远端 ref 列表"的来源 + fetch 配置排除这个命名空间避免污染 (`git config remote.origin.fetch` 或 `--no-tags`)。**0 迁移** — 现存 191 个 ticket 不动, 编号格式不变。可以选择回填 215 个已用编号的 ref (脚本 1 分钟), 也可以只从 260 起管。
- **为什么能防住已发生的事故**: 判定不在本地。本地落后 21 commits 不影响服务端 ref 是否存在。这是唯一一个把"权威"真正搬出本地工作副本的方案。
- **失效模式**:
  1. **需要联网**。离线无法分配。但分配是低频人为动作 (峰值 20 次/天), 不像 pre-commit 那样每次 commit 都要网。离线时 fail-closed 是可以接受的。
  2. **GitHub 是否接受 `refs/kallax/*` 推送需要实测** — `refs/pull/*` 是被禁的, 自定义命名空间通常可以但我没有在这个仓库上验证过。这是本方案最大的未验证假设。tag fallback 风险低但污染 tag 空间 (已有 88 个 release tag)。
  3. **预留后放弃 → 编号泄漏**。人开了 260 又不做了, 260 永久空洞。需要一个"回收未使用预留"的清理脚本, 或者接受空洞 (现在已有 45 个空洞, 边际影响小)。
  4. 有人不跑 reserve 脚本直接建目录 → 整体绕过。需要 E 作为第二道 (pre-commit 检查"你要提交的编号有没有对应的 ref 预留")。
  5. 预留 ref 跟 `origin/miao` 上的实际内容会不相同 (预留了但 PR 未合)。这是**期望行为**, 但会让 `next-epic-id.sh` 的输出跟目录列表不相同, 需要在输出里区分"已占用"和"已预留"。
- **跟现有机制的冲突**: 编号仍是 3 位整数 → `archived_before: 222` 比较完好。跟 `next-epic-id.sh` 是增量关系 (加第 5 个来源), 不是替换。

### G. 不解决, 只加事后检测

CI 加一个 job: 扫 PR 引入的编号, 跟 base 上已占的比, 撞了就 fail PR。

- **落地成本**: 极低 (~40 行 workflow)。
- **失效模式**: 不预防, 只在 PR 阶段拦。撞了要改名, 改名成本 = 目录 + 文件名 + branch + 已推的 commit message (改不了)。
- **优点**: CI runner 天然基于新 base fetch, **不受本地落后影响** — 这一点上它比 E 的本地实现强。
- **什么情况下失败**: PR 前已经写了 20 个文件引用旧编号 → 改名成本已经产生。

---

## 3. 六维评分表

评分 3 = 好 / 2 = 一般 / 1 = 差。维度 1 是硬门槛。

| 维度 | A registry | B 段预分配 | C 去中心化 ID | D 时机后移 | E pre-commit | **F ref CAS** | G 仅检测 |
|------|-----------|-----------|-------------|-----------|-------------|-------------|---------|
| **1. 防住"落后 base 上算编号"** | **1** 同源失效 | **1** 分段者也可能落后 | 3 无争用点 | 3 无编号可撞 | **1** 本地实现 / **3** 强制 fetch | **3** 判定在服务端 | 2 PR 阶段才拦 |
| **2. 并发安全 (两 worktree 同时建卡)** | 1 merge conflict | 3 段内独立 | 3 | 3 | 1 无原子性 | **3** 服务端原子 | 1 |
| **3. 迁移成本 (191 ticket + 98 doc + CLAUDE.md)** | 2 回填 215 项 | **3** 0 改动 | **1** 全量重写 | 2 流程改 | **3** 0 改动 | **3** 0 改动 | **3** 0 改动 |
| **4. `archived_before: 222` 整数比较兼容** | 3 | 3 | **1** sed 整数比较崩 | **1** DRAFT 取不到整数 | 3 | **3** | 3 |
| **5. 人类可读 / 口头引用** | 3 | 3 | **1** hash 不可读 | 2 draft 期不可读 | 3 | **3** | 3 |
| **6. 失败时的表现** | 2 fail-open 给出可能撞的号 | 1 段耗尽后无定义 | 3 不会失败 | 2 改名漏项 | 2 离线时二选一都难受 | **3** fail-closed 明确拒绝 | 2 fail-open |
| 合计 (维度 1 未过则淘汰) | 12 淘汰 | 14 淘汰 | 12 | 13 | 13 (需强制 fetch) | **18** | 14 |

淘汰理由 (维度 1 未过): A 和 B 都把权威留在本地工作副本, 事故会原样复发。

---

## 4. 业界做法与 git-only 约束

| 系统 | 编号分配 | 机制 |
|------|---------|------|
| Jira | `PROJ-1234` 递增 | 服务端 DB sequence, 单点串行 |
| Linear | `TEAM-123` 递增 | 服务端, 每 team 独立 counter |
| GitHub Issues/PR | 单一递增序列 (issue 和 PR 共用) | 服务端, 强串行 — 这也是为什么 PR 号和 issue 号不会重叠 |
| Gerrit | Change-Id = **内容 hash** (commit message 里的 `Change-Id: I<sha1>`) + 服务端另发一个递增 change number | **双轨**: 客户端生成的去中心化 ID + 服务端生成的短号 |
| Git 自己 | commit sha | 整体去中心化, 内容寻址 |

**共同点**: 除 Gerrit 的 Change-Id 和 git sha, 所有"人类友好的递增短号"都由**服务端单点**发出。这不是偶然 — 递增整数和去中心化在数学上不兼容 (要知道"下一个"必须知道"全部")。

**git-only 约束改变了什么**:

1. KALLAX 没有 issue tracker 服务, `jira/tickets/` 是文件系统里的目录。**但它有一个远端 git 服务 (GitHub)**, 而 git 服务端在 ref 更新上是**强串行原子**的 (这是 git push 的核心保证)。所以 KALLAX 并不是真的"无服务端" — 它有一个被当成哑存储用的服务端。方案 F 的全部价值就是把这个已有的原子性拿来用。
2. Gerrit 的双轨模式值得抄: **内部唯一性用去中心化 ID, 对人展示用递增短号**。KALLAX 可以把 branch 名/worktree 名用 slug (去中心化), ticket 编号用预留的递增号 — 这跟现状差别不大, 因为 branch 名已经是 `feature/v3.35.0-EPIC-259-numbering` 这种带 slug 的形式。
3. **真正被 git-only 排除的是"乐观分配 + 服务端纠正"**。Jira 里你点 Create 就拿到号, 不会撞。git-only 下客户端先写文件后推送, 撞不撞在推送时才知道 — 所以要么在写之前去服务端问 (F), 要么接受撞了再改名 (G)。没有第三条路。

---

## 5. "不解决"这个选项的评估

### 支持不解决的依据

1. **编号今天已经不是唯一键**。8 个编号有 2-3 个语义不同的 decision 文档; `EPIC-016` 有 19 个子目录。编号实际扮演的是"松散分组标签"。为一个松散标签建立强相同的分配机制, 是给不需要精度的地方上精度。
2. **≤259 已有 45 个空号 (17%)**。编号连续性早就不成立, 说明历史上大量分配即弃, 而没有人为此付出可见代价。
3. **撞号是可检测的**。撞了不会静默产生错误结果, 会在有人查 ticket 时暴露。
4. **修复成本在 merge 前很低**: 改目录名 + 文件名 + `ticket_id` 字段, 一个脚本可做。EPIC-248 这次就是这么处理的。

### 反对不解决的依据

1. **频率不低且在上升**: 2 周内 3 例 (248 已纠正, 245/247 还撞着)。编号生成速率峰值 20 个/天 (2026-08-08), 并行 worktree 从 1 个增到 3 个。撞号概率大致跟 (并行度 × 分配速率) 成正比。
2. **merge 后修复成本跳一个量级**: commit message 里的编号改不了; 两个 `status: done` 的卡共用一个编号会让 Rule 36 的指标 #4 (`mis_dispatch_rate`) 和 `check-ticket-schema.sh --all` 的输出无法解释。
3. **本次事故的代价已经花掉了**: 一个 worktree (EPIC-259) 加一个 10924 字节的脚本, 全部用于"查编号"。这笔钱已付, 但买到的东西不预防事故 (默认不 fetch)。**继续不解决 = 这笔投入沉没**。
4. **245/247 现在正撞着且无人处理**。"不解决"的实际含义是接受 `origin/miao` 上 `EPIC-245-heartbeat-test-stable` 和本地 `EPIC-245 doc-budgets` 长期共存。

### 判断

**不值得上重方案 (C / D), 值得上轻方案 (F + E)**。理由: C 和 D 的成本 (全量重命名 / 流程改造) 明显超过撞号的实际代价; 但 F 的成本 (~100 行脚本 + 0 迁移) 低于"两周 3 例 + 并行度还在涨"的代价。这不是"要不要解决", 是"用 100 行还是用 2000 行解决"。

---

## 6. 推荐方案

### 推荐: F (git ref CAS 预留) 为主 + E (pre-commit 校验预留存在) 为辅, 保留 3 位整数格式

分三层:

| 层 | 做什么 | 失败行为 |
|----|-------|---------|
| L1 分配 | `reserve-epic-id.sh` — 向 `origin` 推 `refs/kallax/epic/<N>` (`--force-with-lease=<ref>:`), 服务端拒绝即换下一个号重试 | fail-closed: 无网 / 推不上去 → 拒绝分配, 明确报错 |
| L2 查询 | `next-epic-id.sh` 加第 5 个来源 = 远端预留 ref, 且**默认 fetch** (把现在的 opt-in 反过来, `--no-fetch` 才跳过) | 无网 → exit 3, 不给可能错的建议 (现有脚本已有这个 exit code) |
| L3 提交门 | pre-commit: staged 里新增的 `jira/tickets/EPIC-NNN/` 或 `confluence/decisions/EPIC-NNN-*.md` **或 staged .md 正文里新出现的 `EPIC-NNN`**, 必须有对应预留 ref | fail-closed, `--no-verify` 可绕 (跟现有 14 个检查同一档) |

L3 必须扫 markdown 正文, 因为 EPIC-248 事故里编号是在计划文档里诞生的, 只扫目录名的门整体拦不到那条路径。

### 它在什么条件下会失败

1. **GitHub 拒收 `refs/kallax/*` 命名空间** — 这是最大的未验证假设。我没有实测。落地第一步必须是推一个测试 ref 验证, 失败则退到轻量 tag `epic-num/<N>` (会污染 88 个 release tag 的命名空间, 需要配 `fetch --no-tags` 或 refspec 过滤)。
2. **离线工作** — 无网时无法分配编号。当前节奏 (峰值 20 个/天, 三个本地 worktree) 下影响有限, 但如果主公在无网环境要建卡, 这个方案直接卡住。需要一个明确的 offline 逃逸门 (预先批量预留 10 个号备用, 等于退化成方案 B 的段, 但段是从服务端原子拿到的 — 这是 B 唯一可行的变体)。
3. **有人不跑脚本手建目录 + `--no-verify`** — 两道门都绕开。这跟现有 14 个 pre-commit 检查同一个弱点, 不是本方案独有, 但也不是本方案能修的。
4. **预留后放弃导致空洞增长** — 需要一个 `cleanup-stale-reservations.sh` (预留超过 N 天且远端无对应 ticket → 删 ref), 否则空号率会从 17% 继续爬。清理脚本本身有误删风险 (删掉别人正在做但还没推的号)。
5. **编号超过 999** — `next-epic-id.sh` 的 3 位假设。现有脚本有 `check_overflow` 告警但不阻塞。当前 259, 按 10 个/天算大约 2 个月后到 999。这是一个**已知的定时问题**, 跟本方案无关但会同时炸掉 `EPIC_NUM_RE`、所有 `%03d`、以及 `EPIC-0313` 这类已存在的畸形数据。

### 落地步骤

1. **先验证假设**: 在 kallax 仓库推一个 `refs/kallax/test/1` 看 GitHub 收不收。收 → 走 ref; 不收 → 走 tag fallback。**这一步没过, 后面全部作废。**
2. **修 245/247 的现存撞号** (这个跟方案无关, 现在就该做): 把 EPIC-245 worktree 的三张 todo 卡改到实际空闲的号。当前 `origin/miao` 的真实最大是 255, branch 到 259, 所以下一个安全号是 **260**, 不是空号表里的 246/249/250 (那三个已被 `origin/miao` 占)。
3. 回填 215 个已用编号的预留 ref (脚本, 一次性)。
4. 写 `reserve-epic-id.sh`, 改 `next-epic-id.sh` 默认 fetch + 加第 5 来源。
5. 加 pre-commit L3 检查 (含 markdown 正文扫描)。
6. 加 CI job (方案 G, 便宜且跟 F 互补 — CI 天然基于新 base, 是 L3 被 `--no-verify` 绕过后的最后一道)。
7. 写 `cleanup-stale-reservations.sh`。

### 需要主公拍板的点

1. **离线时 fail-closed 是否可接受** — 无网不能建卡。如果不可接受, 需要批准"批量预留备用号"这个逃逸门, 并接受它带来的空号增长。
2. **tag fallback 是否可接受污染 tag 命名空间** — 若 GitHub 不收自定义 ref。88 个 release tag 旁边多出几百个 `epic-num/*`。
3. **245/247 怎么改名** — 是改本地新卡 (推荐, 未推送成本低), 还是改 `origin/miao` 上已有的 decision 文档 (成本高, 涉及已合并历史)。
4. **`.archive-baseline.json` 的 `new_ticket_required_fields` 第一项 `"id"` 是错的** — 实际字段名是 `ticket_id`。这不属于本次编号问题, 但顺手发现: 191 个现存 ticket 全部读不到 `id` 字段。要不要一起修。
5. **3 位编号上限 (999)** — 按当前速率约 2 个月触顶。要不要现在就规划 4 位迁移 (影响 `EPIC_NUM_RE` / 所有 `%03d` / `check-ticket-schema.sh` 的 sed), 还是等触顶再说。
6. **EPIC-259 worktree 里的 `next-epic-id.sh` 要不要先合并** — 它现在只存在于一个未合并的 worktree, 其他两个 worktree 用不到它。合了才有第 2 步的基础。
