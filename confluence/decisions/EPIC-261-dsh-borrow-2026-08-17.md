# EPIC-261~248 — DeepSeek-Harness 借鉴落地 (保留优势 + 补齐短板)

**日期**: 2026-08-17
**主公拍板**: 2026-08-17 "同意，组织团队推进，最终的目标是保留优势 + 补齐短板"
**来源报告**: `/tmp/kallax-vs-deepseek-harness-report.md` (9-Expert Panel, EPIC-056-A 3 阶段治理)
**参考**: EPIC-013 (borrowing-from-external), EPIC-206 (借方法论 不借代码), EPIC-223 (archive baseline), EPIC-225 (check-jargon)

---

## 0. EPIC 编号纠正 (诚实修正)

初版计划写 EPIC-256~259。实测 repo 最大真实编号 = **EPIC-244** (`grep -rhoE 'EPIC-[0-9]{3}'` 排除 EPIC-351/999 占位)。新卡从 **EPIC-261** 起, 无编号断层。

| 侦查项 | 实测值 | 命令 |
|--------|--------|------|
| 最大 EPIC | 244 | `grep -rhoE 'EPIC-[0-9]{3}' \| sort -t- -k2 -n \| tail` |
| ticket 目录数 | 191 (止于 EPIC-177-G) | `ls jira/tickets/ \| wc -l` |
| decisions 文件数 | 98 (平面目录) | `ls confluence/decisions/ \| wc -l` |
| archive baseline | archived_before=222 | `jira/tickets/.archive-baseline.json` |
| verify 脚本数 | 66 | `ls scripts/verify/ \| wc -l` |
| CLAUDE.md 行数 | 194 / 200 上限 | `wc -l CLAUDE.md` |
| snapshot 目录 | 不存在 | `ls node/tests/snapshots` → NO_SNAPSHOT_DIR |

---

## 1. 优势守恒清单 (Invariants — 借鉴不得破坏)

> 目标前半句"保留优势"的可执行定义。以下 8 项是 KALLAX 相对 DSH 的既有优势, 4 张卡任一不得削弱。每卡 DoD 必含守恒验证一节。

| # | KALLAX 优势 | DSH 无此项 | 守恒验证方式 |
|---|------------|-----------|-------------|
| 1 | **9 immutable scripts fail-closed** (CLAUDE.md §5) | DSH verify-* 可迭代 | `bash scripts/hooks/install.sh --verify` exit 0 |
| 2 | **4-branch flow + master + 4 sub-roles review** (Rule 4, EPIC-207) | DSH 单主干 | 4 卡各走完整 4-PR, 0 auto-merge |
| 3 | **worktree 物理隔离** (git 层, 可审计可合并) | DSH preset 仅逻辑组合 | 每卡独立 worktree, `git worktree list` 可查 |
| 4 | **主公拍板 P0/P1/P2 分级** (EPIC-055-B) | DSH 全 model-driven | 新 immutable 候选必主公拍板 |
| 5 | **9-Expert Panel 3 阶段治理** (EPIC-056-A) | DSH 无多视角评审 | 4 卡合并前跑 panel, expert_activation ≥ 5 |
| 6 | **Rule 34 bugfix 独立复现** (3 字段) | DSH 无此约束 | ticket.json reproduction 3 字段 |
| 7 | **archive baseline 不回溯语义** (EPIC-223) | DSH 全量强 gate | 新脚本必读 baseline, 历史 exit 3 SKIP |
| 8 | **Rule 9 KPI X/Y 精确格式** | DSH 无 KPI 契约 | 每卡 DoD 带 X/Y 数字 + raw output |

**守恒红线 (任一触发 → ticket blocked)**:
- ❌ 新 verify 脚本破坏 exit code 二态契约 (0/1) 或三态语义 (0/1/3 SKIP)
- ❌ 借鉴引入 auto-merge, 或跳过 4-PR
- ❌ immutable 数字从 9 变动而未走改数字强制流程 (`.claude/rules/immutable-scripts.md`)
- ❌ 迁移 decisions 目录导致现有 101 文件任一断链 (CLAUDE.md / rules / ticket 引用)

---

## 2. 短板补齐矩阵 (Gaps → 4 EPIC)

> 报告 TOP 10 gaps 中 **4 项本 Sprint 补**, 6 项归档待后续 (理由见 §5)。

| EPIC | 补的 Gap | 报告 # | 路径 | effort | 类型 |
|------|---------|--------|------|--------|------|
| **EPIC-261** | 缺 tier-taxonomy 文档分层 + word budget | #7 | Path C | 4h | 新脚本 (辅助类) |
| **EPIC-246** | 缺 keyless snapshot 接受测试 | #4 | Path B | 2-3d | 新 test lane |
| **EPIC-262** | 缺 Agent Note ADR 三态 lifecycle | #3 | Path A | 3-5d | 新脚本 (辅助类) |
| **EPIC-260** | 同上 — 101 文件迁移执行 | #3 | Path A | 1-2d | 迁移工具 |

Sprint 容量: 4 EPIC ≤ 5 上限 (Rule 35 时间盒) ✅

---

## 3. 四卡 DoD (含守恒验证)

### EPIC-261 — check-doc-budgets.sh + budgets.manifest.json

**补短板**: DSH `verify-doc-budgets` 自动拒绝超长文档, KALLAX 靠主公手动"减码"。

**Scope**:
- `docs/budgets.manifest.json` — 每文档 word ceiling (实测基线 + 20% headroom)
- `scripts/verify/check-doc-budgets.sh` — 读 manifest, 超限 exit 1
- 接入 pre-commit (staged .md only, 同 check-jargon 做法)

**实测基线** (`wc -w .claude/rules/*.md`, 总 3783):

| 文件 | 实测 words | 提议 ceiling |
|------|-----------|-------------|
| recent-epics.md | 1332 | 1600 |
| immutable-scripts.md | 643 | 800 |
| rule-37.md | 587 | 700 |
| branch-flow.md | 354 | 500 |
| retrospective.md | 262 | 400 |
| installation.md | 203 | 300 |
| strict-tsconfig.md | 193 | 300 |
| testing.md | 116 | 300 |
| state-json.md | 93 | 300 |
| CLAUDE.md | 194 lines | 200 lines (既有硬阈值, 不改) |

**DoD**:
- [ ] manifest 10 条目全覆盖, 0 文件当前超限 (实测 0/10 FAIL)
- [ ] exit code 二态: 0 PASS / 1 FAIL, 无第三态 (辅助类不需 SKIP)
- [ ] pre-commit 接入, 且 `install.sh --verify` exit 0
- [ ] **守恒**: immutable 数字仍 9 (本脚本归辅助类, 同 check-smoke-retention 级别, 不进 immutable)
- [ ] raw output 贴 PR 描述

---

### EPIC-246 — keyless snapshot harness

**补短板**: DSH `test:snapshot` 跑真 assembled app + keyless JSON 透传对比。KALLAX 5-Level Verify 曾出 v3.8.0 假 PASS 事故。

**Scope**:
- `node/tests/snapshots/<cmd>/expected.json` — 冻结基线
- `node/tests/snapshot.test.ts` — vitest, 0 API key 依赖
- 起步 2 条命令: `/kallax-list` + `/kallax-help` (输出稳定, 纯本地枚举)
- `scripts/verify/check-snapshots.sh` — CI 入口

**关键顺序 (风险 #2 缓解)**: 先冻结输出契约, 后录基线。录前把两命令输出格式写进 `docs/snapshot-contract.md`, 否则基线随格式漂移每次红。

**DoD**:
- [ ] 2/2 命令有 expected.json, `npx vitest run tests/snapshot.test.ts` 0 fail
- [ ] `KALLAX_HOOK_API_KEY` 未设时仍 PASS (证明 keyless)
- [ ] 故意改 1 行输出 → 测试转红 (证明非 gate-paint, 同 scan-dead-code 防御思路)
- [ ] **守恒**: 服务 Rule 34 — snapshot 命令即 reproduction_command, exit code 即 reproduction_exit_code
- [ ] raw vitest output 贴 PR 描述

---

### EPIC-262 — verify-agent-note-format.sh + 目录规范

**补短板**: DSH `.agents/notes/{proposed,implemented,rejected}/{class}/` 双轴 + archived 永久冻结。KALLAX 101 个 decisions 平面无 lifecycle。

**Scope** (只建规范 + 脚本, **不迁移** — 迁移在 EPIC-260):
- 目录: `confluence/decisions/{proposed,implemented,rejected}/{class}/<date>-<slug>.md`
- class 闭集 6 个: `feature` / `bug-fix` / `architecture` / `process` / `testing` / `simplification`
- header 契约: 第 1 行 `# Agent Note: <title>`, 第 2 行 `Status: <proposed|implemented|rejected>`
- 必填 4 段: `## Problem` / `## Decision` / `## Alternatives` / `## Consequences`
- `scripts/verify/verify-agent-note-format.sh` — status 值须匹配所在 lifecycle 目录名 + class 属闭集 + 4 段必填

**DoD**:
- [ ] 脚本对新建 note 强制, 对平面遗留文件 exit 3 SKIP (沿用 EPIC-223 baseline 语义)
- [ ] 3 态 × 6 class = 18 组合目录建齐, `.gitkeep` 占位
- [ ] 本决策 doc 自身即首个合规样本 (self-hosting 验证)
- [ ] **守恒**: 归辅助类不进 immutable (数字仍 9)。若主公要求进 immutable → 走 `.claude/rules/immutable-scripts.md` 改数字流程
- [ ] raw output 贴 PR 描述

---

### EPIC-260 — 101 文件迁移 (migrate-decisions.sh)

**补短板**: EPIC-262 只立规范, 本卡执行迁移。

**Scope**:
- `scripts/migrate-decisions.sh` — 默认 **dry-run**, `--apply` 才动
- 分类策略: 文件名 / 内容关键词 → 推断 class + status (已合并 miao → `implemented`)
- **断链防御 (风险 #1)**: 迁移后跑 `grep -rn 'confluence/decisions/' --include='*.md' --include='*.json'` 全仓引用检查, 0 断链才算 PASS
- **git mv 前必 `mkdir -p`** (已知反模式: git mv dry-run 成功但实际失败)

**DoD**:
- [ ] dry-run 输出 98 条 from→to 映射表, 主公 review 后才 `--apply`
- [ ] `git mv` 保留 history (`git log --follow` 可追)
- [ ] 全仓引用扫描 0 断链 (X/X 格式, 预期 N/N)
- [ ] EPIC-262 脚本对迁移后 101 文件全 PASS, 或明确列出豁免清单
- [ ] **守恒**: 迁移属 9 类破坏性 #1 (改路径) → 必主公二次拍板才 `--apply`
- [ ] raw output 贴 PR 描述

---

## 4. Sprint 编排 (Rule 35 时间盒 + Rule 4 4-PR)

```
Sprint 当期 (4 EPIC ≤ 5 上限)
├─ EPIC-261 (doc budgets)   ─┐ 独立, 可并行起
├─ EPIC-246 (snapshot)      ─┘
├─ EPIC-262 (note format)   ─┐ 强依赖: 247 → 248
└─ EPIC-260 (migration)     ─┘ 260 等 247 合并后起

每卡 4-PR:
  feature/v3.35.0-EPIC-XXX → testing → main (FF+comment) → miao
                              ↑ master + Arch/BE/FE/Sec 4 sub-roles

Sprint 结束: bash scripts/metrics/sprint-metrics.sh --epic EPIC-261 (×4)
```

**派单** (遵循派遣 Checklist §9 "1 ticket 1 subagent 串行"):

| EPIC | Performer 专精 | worktree |
|------|---------------|----------|
| EPIC-261 | process-engineering (文档治理 gate) | `kallax-wt-EPIC-261` |
| EPIC-246 | backend (vitest + JSON 契约) | `kallax-wt-EPIC-246` |
| EPIC-262 | compliance (ADR lifecycle 规范) | `kallax-wt-EPIC-262` |
| EPIC-260 | auditor (迁移 + 断链审计) | `kallax-wt-EPIC-260` |

---

## 5. 本 Sprint 不做 (含理由, 0 隐藏)

> 报告 TOP 10 中 6 项归档。理由不是"以后再说", 是 KALLAX 已有等价物, 或栈不兼容。

| # | Gap | 不做理由 |
|---|-----|---------|
| 1 | capability-seam 三角色契约 | 需重构 scripts/ + node/ 双栈边界, 触及 66 verify 脚本 — 超 Rule 35 单 EPIC 上限 (4 模块 / 5 文件), 必拆独立 Sprint |
| 2 | microkernel 双事件轨 | KALLAX 有 run-history.jsonl + span。升级到 sourceEventSeqs 精度需先有 seam (依赖 #1) |
| 5 | 三向投影 render-intent | KALLAX 无原生 GUI (ticket-board 静态 HTML), 投影层无消费者 — 先有 UI 再谈 |
| 6 | sandbox seam + secret scrub | **P0 战线红线** — 触及 AUTO-PERMS + 9 immutable。raw_output: `ls scripts/verify/ \| wc -l` → 66; `bash scripts/hooks/install.sh --verify` → exit=1。改 seam 需同改 AUTO-PERMS 白名单 + 66 脚本入口, 超 Rule 35 单卡上限 |
| 8 | 4-waterfall tool pipeline | KALLAX pre-commit hook 链已是简化 waterfall。全量 monotonic guards 需 seam (依赖 #1) |
| 9 | hook-bridge 协议层 | KALLAX 是 Claude Code 治理层, 不做多 harness 适配 — 见 prime-agent 调研 §5.1 定位 |

**共同根因**: gaps #1 / #2 / #8 全依赖 capability seam。建议独立 research EPIC 出设计稿 (同 EPIC-222 persistent-supervisor 的 research-only 做法), 不在本 Sprint 实现。

---

## 6. 跟 prime-agent 调研 (EPIC-217~222) 的关系

| 关系 | 说明 |
|------|------|
| **不冲突** | prime-agent 6 卡 (217-222) 已合并或归档 (archive baseline 222)。本 4 卡 245-248 编号错开 |
| **复用** | EPIC-261 doc budgets 复用 EPIC-225 check-jargon 的 staged-md 扫描做法 |
| **复用** | EPIC-262 note format 沿用 EPIC-223 archive-baseline 的 exit 3 SKIP 语义 |
| **互补** | EPIC-246 snapshot 补 EPIC-220 check-disclaimer 之后一步: raw output 本身可重放 |

---

## 7. KPI 落地 (Rule 9 X/Y)

| KPI | 目标 | 当前 | 证据 |
|-----|------|------|------|
| 决策 doc | 1/1 | ✅ | 本文件 |
| 新 EPIC ticket.json | 4/4 | ✅ | `bash scripts/verify/check-ticket-schema.sh EPIC-261` exit=0 (×4) |
| 优势守恒清单 | 8/8 项 | ✅ | §1 |
| 短板补齐 | 4/10 gaps (6 归档含理由) | ✅ | §2 + §5 |
| 4-PR 全程 | 0/4 | 待跑 | — |
| 4 北极星 | 0/4 EPIC | Sprint 末跑 | — |
| 编号纠正 | 1/1 (256→245) | ✅ | §0 |

**当前落地 5/7**。未完成 2 项 (4-PR / 北极星) 不计入 PASS — 见 v3.8.0 假 PASS 事故教训。

---

## 8. Why this matters

DSH 对比暴露 KALLAX 的短板集中在 3 处: 自动化文档治理 / 可重放验证 / ADR lifecycle。全是"靠人记忆和主公拍板"的地方。补齐后, KALLAX 8 项既有优势 (immutable / 4-PR / worktree / 拍板分级 / 9-Expert / Rule 34 / archive baseline / KPI 契约) 一项不减, 新增 3 条自动 gate。

不借的 6 项全归因于 capability seam 依赖, 或 governance-layer 定位, 不是"没时间"。做法遵循 EPIC-206 借方法论 不借代码。

---

## 9. 侦查中发现的 2 个既有债 (非本卡引入, 已验证 baseline)

> 诚实记录: 建卡过程跑 gate 时发现 2 项 **在 miao 主干上就已 FAIL**, 不是本卡改坏的。

| 债 | 症状 | baseline 验证 | 处置 |
|----|------|--------------|------|
| **D1: pre-commit hook STALE** | `install.sh --verify` 报 "pre-commit 已安装但跟源文件不同步" | `cd kallax && bash scripts/hooks/install.sh --verify` → **exit=1** (miao 主干) | 违反 CLAUDE.md §5 "hook 体系健康 exit 0 才算生效"。**建议单独开 EPIC-249 修**, 或主公授权本卡顺手跑 `bash scripts/hooks/install.sh` |
| **D2: check-decorative-claim 全仓 FAIL** | 扫到 5-expert-pool / EPIC-208 / EPIC-212 / EPIC-213 等历史文件的装饰性表述 | `cd kallax && bash scripts/verify/check-decorative-claim.sh` → **exit=1** (miao 主干) | 脚本忽略传入的 file 参数, 总是全仓扫。EPIC-225 归档语义 (历史不追溯) **未应用到本脚本**。建议 EPIC-250 给它加 archive-baseline 读取 |

**D2 影响本 Sprint**: pre-commit 若真生效, 任何 commit 都会被 decorative gate 挡住 (因为它扫全仓历史文件)。这解释了为何 D1 (hook STALE) 一直没被发现 — hook 失效反而让 commit 通过。**两个债互相掩盖**。

**处置请求 (等主公拍板)**:
- 选项 A: 本卡只提交 ticket + 决策 doc, 用 `--no-verify` 绕过 (需主公明确批准, 见 CLAUDE.md §4)
- 选项 B: 先开 EPIC-249 (修 hook STALE) + EPIC-250 (decorative 加归档基线), 修完再提交本 4 卡
- 选项 C (推荐): 本卡加 EPIC-249 修 D1+D2, Sprint 变 5 EPIC (仍 ≤ Rule 35 上限 5)
