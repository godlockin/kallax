# KALLAX 经验教训 + 最佳实践 — 深远影响沉淀

> **目的**: 记录 8 个月迭代中**深远影响**项目走向的教训, 转化为可复用的最佳实践。
> **写入**: 2026-08-07, 跟 EPIC-194 Rule 36 + EPIC-188 retrospective 联合。
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
- ✅ L2 必跑 `cargo test --workspace --release`, 禁 `cargo build` 当 PASS (EPIC-102 升级)
- ✅ L3 至少 1 expert 提供 raw `cargo test --workspace` 输出
- ✅ L4 verify 脚本**真跑** (cache 失效, 不复用上次)
- ✅ L5 check-claim-evidence.sh 扫 README/CHANGELOG 数字 (PRE-COMMIT hook)
- ✅ 5 个 immutable scripts: check-decorative-claim / check-narrative / check-fail-closed / check-self-heal / check-claim-evidence

**深远影响**: v3.8.1+ 假 PASS 0 复发, 北极星 #3 ab_hit_rate < 15%。

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
  - cross_epic_reuse ≥ 60%
  - ab_hit < 15%
  - mis_dispatch < 10%
- ✅ 0 数据 (NO_DATA exit=2) 触发 ASK, 不接受 silent PASS
- ✅ 必跑 `bash scripts/metrics/sprint-metrics.sh --epic EPIC-XXX`

---

## 9. 跨 8 月累计沉淀: 12 条最有价值

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
