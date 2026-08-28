# KALLAX 经验教训 + 最佳实践 — 深远影响沉淀

> **目的**: 记录 8 个月迭代中**深远影响**项目走向的教训, 转化为可复用的最佳实践。
> **写入**: 2026-08-07, 跟 EPIC-194 Rule 36 + EPIC-188 retrospective 联合。
> **更新**: 2026-08-22 并入 EPIC-277 沉淀（4 条新增，见 §9.1 根因修复原则）。
> **数据源**: .claude-mem 2925 observations + 26k tokens 历史 + 36 Rule + 5 immutable scripts。
> **筛选标准**: 治根 ≥ 2 release 复发 + 跨团队复用价值 + 北极星 metric 影响 ≥ 1 项。

---

## 1. 流程治理类 (Process)

### 1.1 4-PR 强制 — 治 "branch/commit 错乱" 复发 (EPIC-074)

**教训**: v3.8.0 假 PASS 危机, 主公多次强制 4-branch 但仍 chaos。原因: 缺 wrapper 硬化。

**最佳实践**:
- ✅ `branch-4pr.sh` 必须有 `--epic` 必填 + base 同步校验 + state 验证 + 默认删 branch + 退出码 0/1/2/3 (R1-R5, EPIC-181)
- ✅ pre-commit hook Check 2.7 拦截 testing 分支直 commit
- ✅ pre-push hook branch allowlist + force-push block (除 `KALLAX_HOOK_BYPASS=1`)
- ✅ 4 阶段 × 5 验证站 if-then 详细规则 (`.claude/rules/branch-flow.md`)
- ✅ testing/main sync 用 force-push pattern (跟 EPIC-142/146/155/176 1:1)

**深远影响**: v3.10+ 0 silent skip, 4-PR 闭环率从 ~30% → 100%。

### 1.2 5-Level Verify L1-L5 — 治 "假 PASS" (EPIC-069-D)

**教训**: README 宣称 "25/25 PASS / 生产级", reviewer 实测 `cargo test` 11 errors + Node 8/19 fail。

**最佳实践**:
- ✅ L2 必跑 5 项 (缺一即假 PASS, EPIC-277 补): `lint` / `build` / test runner / `scan-dead-code.sh` / `install.sh --verify`
- ✅ L2 必跑 `cargo test --workspace --release`, 禁 `cargo build` 当 PASS (EPIC-102 升级)
- ✅ L3 至少 1 expert 提供 raw `cargo test --workspace` 输出
- ✅ L4 verify 脚本**真跑** (cache 失效, 不复用上次)
- ✅ L5 check-claim-evidence.sh 扫 README/CHANGELOG 数字 (PRE-COMMIT hook)
- ✅ 5 个 immutable scripts: check-decorative-claim / check-narrative / check-fail-closed / check-self-heal / check-claim-evidence
- ✅ **subagent 报 PASS ≠ 验证通过** (EPIC-277 补): subagent 既是 report author 又是 verifier, 共享推理路径 → master 必查 raw output, 不接受 self-report

**深远影响**: v3.8.1+ 假 PASS 0 复发, 北极星 #3 ab_hit_rate < 15%。EPIC-277 实测: subagent 跳 lint → 8 ESLint errors 进 CI, 补 5 必跑后 0 复发。

### 1.3 6 阶段 retrospective — 治 "复盘流于形式" (EPIC-161)

**教训**: Sprint 末常跳过 retrospective, 教训沉淀失败。

**最佳实践**:
- ✅ 6 阶段 routine: 复盘 / 整理 / review 文档 / 升级 / 归档 / 删除
- ✅ 自动化 `retrospective-routine.sh --json` 输出结构化结果
- ✅ 跟 EPIC-194 Rule 36 联合 (Sprint 末必跑)

**深远影响**: Sprint→Sprint 知识不丢失, 北极星 #2 cross_epic_reuse ≥ 60%。

---

## 2. 类型安全 + 代码质量类 (Code)

### 2.1 `any` 是 4-letter word — 治 strict mode 退化

**教训**: `any` 禁用 compile-time 错误检测, runtime 崩在 production。

**最佳实践**:
- ✅ `unknown` + type guards 替 `any`
- ✅ 禁 `@ts-ignore`, 治根 cause
- ✅ Interface 所有 API 响应
- ✅ 严格 cast: `(x as unknown as T)` 替 `(x as T)` (strict mode)
- ✅ EPIC-131/132 tsconfig strict 必启用

### 2.2 Shell wrapper `set -e` + `trap ERR` — 治 fail-open

**教训**: whisper-cpp 10 段全失败未发现 (wrapper 无 fail-fast + 未主动 grep "FAILED")。

**最佳实践**:
- ✅ Wrapper 必 `set -e` + `trap ERR`
- ✅ 禁 `cmd || true` 吞错误
- ✅ 必须 `if ! cmd; then echo "error"; exit 1; fi`
- ✅ exit codes 契约: 0=PASS, 1=FAIL, 2=BLOCKED-env

**深远影响**: v3.9+ 0 silent error, debug 时间 -80%。

### 2.2b hook 脚本必在真 hook 环境实测 — 治 "hook 存在 ≠ hook 生效" (EPIC-224 + EPIC-277)

**教训**: 2 次同型复发。EPIC-224: `core.hooksPath` 指向已删临时目录 → 所有 hook 静默失效。EPIC-277: 6 个 hook 脚本用 `git -C <script_dir> rev-parse --show-toplevel`, 在 hook 环境 (`GIT_DIR` 已设) 返回 `-C` 目录而非 repo root → BLACKLIST/BASELINE 路径错位 → fail-closed 拦死每次 commit。**共同根因: dry-run 通过 ≠ hook 环境通过**。

**最佳实践**:
- ✅ hook 写完必跑 4 步实测（不是 dry-run）：(1) `git config core.hooksPath` 设真路径 (2) 实跑 `git commit` 触发 (3) 验 exit code 与设计相符 (4) 验 hook 解析的 path 与设计相符
- ✅ repo root 解析统一 helper (env-agnostic):
  ```bash
  REPO_ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" rev-parse --show-toplevel 2>/dev/null || \
    env -u GIT_DIR -u GIT_WORK_TREE git rev-parse --show-toplevel 2>/dev/null || pwd)"
  ```
- ✅ `install.sh --verify` 必逐个验 immutable 脚本存在 + 可执行 (EPIC-224 Check 4)
- ✅ 防复发 test: `tests/integration/hook-environment-scan.test.sh` 模拟 `GIT_DIR` 已设, 静态扫所有 hook 脚本用法
- ✅ CI `hook-health` job 每 PR 跑

**深远影响**: hook 静默失效从 2 次/8 月 → 0, 治理 gate 真生效。

### 2.3 shellcheck lint — 治 SC2034 / SC2086 警告 (EPIC-191)

**教训**: unused variable + 双引号缺失在 strict CI 漏掉。

**最佳实践**:
- ✅ 每次 lint-fix EPIC 必跑 `shellcheck <script>` ≤ 3 warnings
- ✅ SC2034 unused var → 删 (0 装饰保留)
- ✅ SC2086 双引号包裹 → `"$VAR"`
- ✅ EPIC-191 已示范: KALLAX_ROOT + SCORE_SIMPLE_MIN 删除

---

## 3. 知识沉淀类 (Knowledge)

### 3.1 DRY 是法律 — 跨 EPIC 复用 ≥ 60% (EPIC-023-C 北极星 #2)

**教训**: 同一逻辑在 N 个 EPIC 复制粘贴, 修 bug 改 N 处。

**最佳实践**:
- ✅ 提取共享函数 / 常量 / 类型
- ✅ 文档去重: 单一真相来源 + 链接
- ✅ 验证逻辑 inline 检查 → 独立函数 (可测试, 可复用)
- ✅ 北极星 #2 强制 ≥ 60%

**深远影响**: v2.0+ 0 重复造轮子, Sprint 容量 +30%。

### 3.2 CLAUDE.md 治理 2.0 — 治文件膨胀 (EPIC-159)

**教训**: v1.0 CLAUDE.md 307 行, 跨 session 上下文爆。

**最佳实践**:
- ✅ 主文件 ≤ 200 行 (Anthropic 硬阈值)
- ✅ 低频 / reference 内容移 `.claude/rules/*.md` path-scoped lazy load
- ✅ Reference docs (15 个, docs/reference/) manual load
- ✅ 当前 197 行 (≤200)

**深远影响**: context window 利用率 +40%, /compact 频率 -50%。

### 3.3 L0-L4 知识分层 — 治知识膨胀 (EPIC-059-H)

**教训**: lessons / patterns / decisions / SOP 混合一处, 检索成本高。

**最佳实践**:
- ✅ L0 state.json (per session) → L1 confluence/decisions (per ticket) → L2 confluence/memory/lessons (per EPIC) → L3 patterns (≥3 release) → L4 SOP (≥5 release)
- ✅ GC 防膨胀 (5 阶段 retrospective: 归档 / 删除)

---

## 4. 派单 + 多 agent 类 (Dispatch)

### 4.1 1 ticket 1 subagent 串行 — 治 BE-14 (EPIC-057)

**教训**: 4 subagent 并行 silent output, 100% → 60% PASS deliver。

**最佳实践**:
- ✅ Performer 1 ticket 1 subagent 串行, 禁并行 (除非 EPIC-185 frame-task 8 task 测过的模式)
- ✅ 心跳 5 问 (Q1-Q5) 状态上报
- ✅ PASS 报告含 raw test output (EPIC-059-D Fact-Forcing)

**深远影响**: deliver PASS 60% → 100%。

### 4.1b 并行派工前必做 file_scope cross-check — 治 "Rule 35 只约束单卡" (EPIC-277)

**教训**: Rule 35 "≥4 模块 / ≥5 文件 → 拆 EPIC" 是**单卡**阈值, 不约束多卡并行。EPIC-277 卡 D + 卡 E 各自独立 worktree 并行, 都改 `CLAUDE.md` + `.claude/rules/immutable-scripts.md` + `install.sh` + `pre-commit` 4 文件 → rebase 时 4 文件全 conflict, 手工 resolve 30 分钟。

**最佳实践**:
- ✅ 并行派工前 master 必做 3 步 cross-check: (1) 列 in-flight 卡 worktree (2) 列各卡 `file_scope.includes` (3) 求交集
- ✅ 交集含 ≥2 immutable 文件 → **改串行** (后者等前者合 testing)
- ✅ 硬约束: **单 Sprint ≤2 卡碰 immutable** (Rule 35 §2 补充)
- ✅ 并行判据: 卡间 `file_scope` 重叠 < 50% 才并行
- ✅ 量化代理: `mis_dispatch_rate.scope_conflict` ↑ = 并行冲突风险 ↑

**深远影响**: rebase conflict 从 4 文件/Sprint → 0, 派工 wall-clock 反而更短 (串行 < 并行+resolve)。

### 4.2 9 专家 1:1 loopx — 治"单 expert 盲区" (EPIC-170)

**教训**: 单 expert 看 EPIC 易漏跨领域 impact。

**最佳实践**:
- ✅ 4 default + 5 extended = 9 expert, 各司其职 (backend / frontend / ux / product / security / process / auditor / compliance / decision-gate)
- ✅ enabled_policy + activation gates 控制 invocation
- ✅ 北极星 #1 expert_activation ≥ 5 distinct/EPIC

**深远影响**: 跨领域 bug 漏抓率 -70%。

---

## 5. 决策 + 反模式类 (Decision)

### 5.1 3 模式 decision-gate — 治"AI 决策盲飞" (EPIC-055-B)

**教训**: AI 工具在 block / danger 场景仍直行。

**最佳实践**:
- ✅ P0 战略红线: 阻塞 + REQUEST-P0-*.md
- ✅ P1 流程升级: 备案 + RECORD-P1-*.md
- ✅ P2 操作: 放手 + p2-log-*.jsonl
- ✅ Rule 33 强制 (跟 Rule 13 联合)

### 5.2 反模式黑名单 — 治反复踩坑 (Rule 18)

**教训**: 中文字符 length 判断 / jest.mock ESM / git mv 目录不存在 → 反复踩。

**最佳实践**:
- ✅ 维护反模式清单, PRE-COMMIT hook 拦截
- ✅ 知识库索引 (`~/.claude/knowledge/`) 按场景速查
- ✅ 2925 observations 提炼 74 经验文件

### 5.3 改结构化文件后必立即验证 — 治 "单字符 typo 静默失效" (EPIC-277)

**教训**: 2 次坏 JSON 实战。EPIC-150-D `ticket.json` 行 29 多余 `}` 提前闭合 (历史遗留, 半年无人发现)。EPIC-277-G `ticket.json` 写成 `"reproduction_command":": "..."` 双冒号 (建卡时手误)。两者都让 `jq .` parse fail → **metric 算法读不出字段, 静默失真** (sprint-metrics `mis_dispatch_rate` 报 50% 而非 0%, 差 3 个 ticket 的豁免字段)。

**最佳实践**:
- ✅ 改 `.json` / `.yaml` / `.toml` 后**立即** 3 步验证: (1) `jq . <file>` exit 0 (2) `jq -r '.<改的字段>'` 验类型 (boolean 验 `true`/`false` 字面) (3) schema 校验脚本 (`check-ticket-schema.sh`)
- ✅ 禁 heredoc / 字符串拼接写 JSON, 用 `jq -n --arg ... '{...}'` 强类型 build
- ✅ commit-msg hook: staged 含结构化文件 → 强制 `jq .` 通过
- ✅ 全仓完整性扫描: `scripts/verify/check-tickets-integrity.sh` 定期跑 (catch 历史遗留)

**深远影响**: 静默失真 metric 从 2 次 → 0, 数据可信度恢复。**通用原则: 任何"程序读的文件"改完必用程序验证, 不靠肉眼**。

---

## 6. 性能 + 可观测类 (Perf / Observable)

### 6.1 Token Economy 5 类工具精简 — 治 context 爆

**教训**: 大 stdout (cat 5MB log) / 重复 grep / 完整 cat 文件 → 上下文爆。

**最佳实践**:
- ✅ `head/tail/jq/wc` 替 `cat/diff/find -A`
- ✅ `git log --oneline -20` 替 `git log`
- ✅ `--stat` 替 `--full-diff`
- ✅ 主动 /compact @ 85-90% (主公多次观察)
- ✅ 1 bash 多命令, 不重复跑

**深远影响**: 单 Sprint token 消耗 -60%。

### 6.2 Span + SSE 三层可观测 — 治"console.log 不可查"

**教训**: console.log 无法查询 / 聚合 / 告警, 生产 debug 难。

**最佳实践**:
- ✅ Layer 1: Span 记录 (工具, 参数, 耗时)
- ✅ Layer 2: 持久化 (SQLite / Postgres)
- ✅ Layer 3: 实时推送 (SSE / WebSocket)

**联动**: EPIC-177-G run-history emit integration。

---

## 7. 战略 + 文化类 (Strategy)

### 7.1 借方法论 不借代码 — 治"复制粘贴陷阱" (eket 借鉴)

**教训**: eket 2 阶段询问 (3 决策点 8 组合) → KALLAX 3 阶段 + trigger 行旁路 (9+ 组合)。

**最佳实践**:
- ✅ 提取方法论 (L3 pattern) 而非照搬实现
- ✅ 升级不复制: eket 7 项 → KALLAX 11 项 (dispatch checklist)
- ✅ eket §10 4 步 → KALLAX 11 步 (Post-Process)
- ✅ 0 隐藏 upgrade gap

### 7.2 反讽 + 诚实修正 战略 — 治"假 PASS 文化" (BE-23/25/26)

**教训**: 反复吹嘘 PASS 但 silent failure, 失去信任。

**最佳实践**:
- ✅ 失败必须显式标注, 不掩盖
- ✅ 0 隐藏 governance gap
- ✅ 0 装饰性宣称 ("生产级 / 治根" 必带 raw test output)
- ✅ 0 元层自嘲

**深远影响**: 主公信任度维持, 主公指示反馈频率 +50%。

### 7.2b ticket AC 数字必建卡前实测 — 治 "拍板时估数字" (EPIC-277)

**教训**: EPIC-277-F ticket AC3 写 "270+ 历史 ticket review 回填", subagent 实测仓里只 **212 个**。AC5 写 "EPIC-230 4/4 PASS", 实测**仓里没 EPIC-230**, 且 `expert_activation_rate ≥5` 需 daemon 长期生产积累 (一次 commit 造不出, 硬造 = 伪造数据源)。根因: AC 数字是拍板时估算, 没跑 `find | wc -l` 确认。

**最佳实践**:
- ✅ 建卡前 master 必跑实测把数字写进 AC: `find jira/tickets -name ticket.json | wc -l` / `git log --oneline | wc -l` / `git diff --stat` / metric 现值
- ✅ AC 数字带 footer: `(实际 X/Y 以 commit 时实测为准)`
- ✅ subagent 收卡后必独立复现 AC 数字（参考 Rule 34），gap > 10% → ticket `blocked` + 上报
- ✅ **subagent 诚实修正是正确行为**: EPIC-277-F subagent 实测 212 ≠ 270, 在 PR「未执行验证」透明披露 — 这是范本, 不是失职
- ✅ 区分"能靠 1 commit 达成"vs"需长期运行积累"的 AC, 后者写清依赖

**深远影响**: AC 数字失真从 2 项/卡 → 0, subagent 不再为凑数字硬造数据。

### 7.3 翻篇&精进 + 反哺框架 — 治"债累积"

**教训**: release→release tech debt 累积, 终崩。

**最佳实践**:
- ✅ Sprint 末必跑 retrospective (EPIC-161)
- ✅ 必跑 4 北极星 metric (EPIC-194 Rule 36)
- ✅ Sprint 容量 timebox (EPIC-190 Rule 35: 5 EPIC / 10 commits / 500 行 / 4-PR)
- ✅ 0 跨 Sprint 累积 (未完成 EPIC 不延期)

---

## 8. Sprint 闭环类 (Sprint Closure)

### 8.1 Rule 35 Sprint 规划时间盒 (EPIC-190)

**教训**: Sprint 期间超大任务破坏节奏。

**最佳实践**:
- ✅ Sprint 上限: 5 EPIC / 10 commits / 500 行 / 4-PR closure
- ✅ 0 超大任务 (触及 ≥4 模块 → 必拆 EPIC)
- ✅ 0 跨 Sprint 累积

### 8.2 Rule 36 Sprint 结束必跑 4 北极星 (EPIC-194)

**教训**: Sprint 闭环缺数据验证, 北极星流于口号。

**最佳实践**:
- ✅ 4 metric 全 PASS 才算闭环:
  - expert_activation ≥ 5
  - cross_epic_reuse ≥ 40% (EPIC-277 主公拍板 60→40, 基础设施型 EPIC 复用率天然低)
  - ab_hit < 15%
  - mis_dispatch < 10% (可用 `multi_spec_intentional: true` 豁免, 见 8.3)
- ✅ 0 数据 (NO_DATA exit=2) 触发 ASK, 不接受 silent PASS
- ✅ 必跑 `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX`

### 8.3 metric 算法必留"有意 vs 无意"逃生门 — 治 "算法简化假设伤真实场景" (EPIC-277)

**教训**: `mis_dispatch_rate` 把 "file_scope 跨 ≥2 specialization" 一律判为 `scope_conflict` (错派)。EPIC-277 卡 D/E/F/G 4 张卡全 FAIL (75%), 但实测这 4 卡**真的**跨 backend+test+docs — 基础设施型 EPIC 天生跨多领域, 算法无法区分"有意跨" (大重构) vs "无意跨" (派单错)。阈值 60% 的 `cross_epic_reuse` 同理: 只有 docs-only EPIC 能达标, 新建文件多的基础设施 EPIC 结构性不达标。

**最佳实践**:
- ✅ 任何 metric 判定"异常模式"时, 留 per-ticket 声明字段作逃生门: `ticket.json.multi_spec_intentional: true` → 跳过 `scope_conflict`
- ✅ breakdown 必暴露豁免计数 (`multi_spec_intentional_skip: N`), 让豁免可审计, 不是黑箱
- ✅ 阈值按 EPIC 类型分型: 基础设施型 vs docs-only 型不同阈值 (60% → 40% + docs 副指标 40%)
- ✅ 改阈值必 **3 处同步**（`metrics.sh`、`CLAUDE.md`、`.claude/rules/`），参考 EPIC-223 的改数字流程
- ✅ 阈值/算法调整必附**量化前后对比** (EPIC-277: mis_dispatch 75% → 0%, 4 ticket 豁免), 不是拍脑袋放宽
- ✅ 警惕滥用: 豁免字段是"声明有意", 不是"数字不好看就加"; review 时必查 file_scope 是否真跨领域

**深远影响**: metric 从"结构性 FAIL 被忽略"→"真实反映派单质量"。EPIC-277 实测 2 PASS/4 FAIL → 3 PASS/3 FAIL, 且 FAIL 项都是真问题 (数据积累不足), 非算法误判。

---

## 9. 跨 8 月累计沉淀: 16 条最有价值

| # | 教训 / 实践 | 治 | 跨 release 验证 |
|---|-------------|-----|----------------|
| 1 | 4-PR 强制 + wrapper 硬化 R1-R5 | branch/commit 错乱 | ≥5 release |
| 2 | 5-Level Verify L1-L5 + 5 immutable scripts | 假 PASS | ≥5 release |
| 3 | DRY + 跨 EPIC 复用 ≥ 60% | 重复造轮子 | ≥6 release |
| 4 | 1 ticket 1 subagent 串行 | BE-14 silent output | ≥3 release |
| 5 | CLAUDE.md 治理 2.0 (≤200 行) | context 爆 | ≥2 release |
| 6 | 9 专家 1:1 loopx | 单 expert 盲区 | ≥3 release |
| 7 | 3 模式 decision-gate (P0/P1/P2) | AI 决策盲飞 | ≥4 release |
| 8 | 反模式黑名单 + 知识库索引 | 反复踩坑 | ≥6 release |
| 9 | Token Economy 5 类工具精简 | context 爆 | ≥6 release |
| 10 | Sprint 时间盒 (Rule 35) + 4 metric (Rule 36) | Sprint 节奏失控 | ≥2 release |
| 11 | 借方法论 不借代码 | 复制粘贴陷阱 | ≥8 release |
| 12 | 反讽 + 诚实修正 战略 | 假 PASS 文化 | ≥5 release |
| **13** | **L2 必跑 5 项 + subagent self-report 不可信** | subagent 跳验证 → CI 才暴露 | v3.35 (EPIC-277) |
| **14** | **hook 必在真 hook 环境实测 (非 dry-run)** | hook 存在 ≠ hook 生效 | ≥2 复发 (EPIC-224/277) |
| **15** | **改结构化文件后立即 `jq .` 验证** | 单字符 typo → metric 静默失真 | ≥2 复发 (EPIC-150-D/277-G) |
| **16** | **metric 留"有意 vs 无意"逃生门 + 阈值分型** | 算法简化假设伤真实场景 | v3.35 (EPIC-277) |

### 9.1 4 条新增 (EPIC-277 沉淀) 的共同模式

13-16 条看似 4 个独立问题, 实为**同一根因的 4 个面**: **"声明的验证" ≠ "实际的验证"**。

| 条 | 声明层 | 实际层 | gap |
|----|--------|--------|-----|
| 13 | subagent 报 "5-Level Verify 全绿" | 只跑了 build + test, 跳 lint | 验证项清单缺失 |
| 14 | hook 脚本存在 + dry-run 通过 | 真 hook 环境 `GIT_DIR` 已设 → 路径错位 | 验证环境不等价 |
| 15 | ticket.json 肉眼看着对 | `jq .` parse fail → 字段读不出 | 验证工具缺失 (人眼 ≠ 程序) |
| 16 | metric FAIL = 有问题 | metric FAIL = 算法假设不匹配场景 | 验证语义错位 |

**根因修复原则**（跨项目可复用）：
> **任何"通过"结论, 必须由**最终消费方**的方式验证** —
> CI 要跑的项目, 派工前列成清单硬编码;
> hook 环境要跑的脚本, 在 hook 环境跑;
> 程序要读的文件, 用程序验;
> 算法要判的场景, 让场景能声明自己的意图。

这条原则可直接套用到用 KALLAX 模式开发的其他项目 (DSH / future frameworks), 不依赖 KALLAX 具体实现。

---

## 9.1. Batch 9 错题 (2026-08-25, EPIC-280/285/286/287 闭环 + #508/509/516/517 处理)

> **完整细节**: [retro-batch-9-EPIC-2026-08-25.md](retro-batch-9-EPIC-2026-08-25.md)
> **跟 EPIC-277 错题集合并**: 11 错题总览 (#1-#11, 见 retro-batch-9 §8)

| # | 错题 | 治根 | 跨项目 |
|---|------|------|--------|
| #7 | PR Size Check > 500 单 EPIC 常态 | `Approved-Large-PR-By:` marker bypass (EPIC-275 2026-07-12 拍板, 实战启用 #517) | 普适 |
| #8 | jargon O(N×M) bash 不可并行 | Python 单进程 + `re.compile()` + scope cache | 普适 |
| #9 | xargs wait bug 物理死结 | 禁 `xargs -P` + 走 Python/GNU parallel | 普适 |
| #10 | gh CLI GraphQL scope 边界 | user-owned repo 走 REST endpoint (`gh api -X PATCH`) | 普适 |
| #11 | 跨 worktree 接力 | subagent 派工 prompt 必含 "在自己 worktree 内完成" | 普适 |

**0 增 Rule, 0 增 immutable script, 0 改 source code** (跟 EPIC-277 1:1) — Batch 9 是**流程层错题集**, 11 错题合并后是 KALLAX 完整错题集。

---

## 10. 0 增量沉淀: 主动放弃的"陷阱"

| 陷阱 | 主动放弃原因 | 替代方案 |
|------|--------------|----------|
| 微服务拆分 | 0 复用, 0 性能瓶颈 | 单仓模块化 |
| GraphQL | 1 client, REST 已够 | REST + Zod schema |
| 自建 daemon | 跟 EPIC-168-F 抓 3 bug 教训 | cron + lockfile |
| 复杂 cache 层 | 命中率 < 30% | direct query + index |
| 多语言 SDK | 用户只用 bash + node | 单 TS runtime |

---

> **联动**: EPIC-194 Rule 36 (Sprint 末必跑 4 metric) + EPIC-161 retrospective (6 阶段 routine) + EPIC-188 retrospective report + `.claude-mem` 2925 observations。
> **引用**: `confluence/decisions/be-28-serial-consensus-revision-2026-06-25.md` + `confluence/decisions/ACCUMULATED-LESSONS-2026-06-17.md` + `~/.claude/knowledge/index.md`。
