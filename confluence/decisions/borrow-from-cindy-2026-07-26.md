# 借鉴 makecindy/cindy 工程治理链条 — 决策记录 2026-07-26

**触发**: 主公 `/kallax 召唤团队深入研究一下 https://github.com/makecindy/cindy.git，对比和思考一下哪些我们做得好哪些它做得好`

**Phase 1-3 治理执行**: Conductor 全局扫描 (GH MCP + WebFetch) + 4 专家并行 (Explore agent: Architect / Product-Growth / Frontend-UX / Governance-Security) + Master 仲裁本文档.

---

## 定位对齐 (先挡"苹果对橙子"错觉)

| 维度 | Cindy (makecindy/cindy) | KALLAX |
|---|---|---|
| **交付形态** | Electron 41 + Expo 56 桌面/移动 App | CLI + Skills framework (Rust+Node monorepo) |
| **面向** | 终端用户 (BYO model / hosted / Coding Plan) | AI 团队成员 (conductor / performer / master) |
| **交付物** | .exe / .dmg / .apk / .ipa | Cargo crate + npm package + 26 slash commands |
| **背后组织** | 心动网络 (X.D. Network, TapTap 母公司), v1.0.0 (2026-07-25) 刚开源, 291 commits | 单人主公, v3.28.0 (52 tags), discipline-driven |
| **License** | Apache-2.0 + DCO 无 CLA + NOTICE 明确 X.D. | 当前 LICENSE 存在(内容未验证), 无 DCO 无 NOTICE |
| **CI workflows** | 3 (ci + pr-design-basis + pr-template-rules), ubuntu-only Electron stub | 13 (rust-test / cli-rule-ci / coverage-gate / perf-baseline / pr-body/reviewer/size-check / release) |

**结论**: 代码架构层几乎无交集 (Cindy 是 Electron App; KALLAX 是 framework). **能借的只在"OSS 工程治理 + 供应链硬化 + 治理文档链条"这一薄层**.

---

## KALLAX 已经比 Cindy 强的地方 (立住, 不倒退)

| 维度 | KALLAX 状态 | Cindy 状态 |
|---|---|---|
| **假 PASS 治理** | 5-Level Verify + check-claim-evidence.sh + Fact-Forcing raw output + 4 immutable scripts | AGENTS.md 只写"如实报告", 无脚本兜底 |
| **AI 团队角色分工** | Master + Conductor + Performer + 4 sub-role + 9 experts 3 阶段治理 | 单一 agent 心智, AGENTS.md 是 checklist |
| **记忆分层** | L0-L4 + memory-promote.sh + 5 反模式检测 | 无 |
| **CI workflow 数** | 13 (跨 rust + node + release) | 3 (Electron 二进制全 stub, 不做真实打包) |
| **branch flow 强制** | feature → testing → main → miao 4-branch + pre-commit hook | 无 (只有 PR-first + DCO) |
| **决策记录** | confluence/decisions/*.md 30+ 篇 | 无对应目录 |
| **Rust 侧工程** | 独立 workspace + `cargo test --workspace --release` 强制 | 有 cindy-updater 但只作为 electron-forge prePackage 黑盒 |
| **token economy 规则** | CLAUDE.md 第 10 章 5 类工具精简 + 5 类反例 | 无 |
| **CLI 执行规范** | 5 条强制 + exec-task.sh wrapper + nohup 逃逸路径识别 | 无 |
| **决策矩阵** | 5 levels × 4 roles = 25 cells 落地脚本 | 无 |

**读点**: Fact-Forcing / L0-L4 / Sub-Role / 决策矩阵 是 KALLAX 护城河, Cindy 抄不到.

---

## Cindy 更强的地方 — 借鉴清单

### P0 (立刻建 EPIC — 已建卡)

| # | 借鉴项 | Ticket | 大小 |
|---|---|---|---|
| **P0-1** | Supply-chain 硬化 (SHA 钉 actions + Node 三重锁 + cargo audit) | EPIC-136-A/B/C | 3 sub-ticket |
| **P0-2** | DCO + `.githooks/prepare-commit-msg` + `check-dco.sh` + NOTICE | EPIC-137-A/B/C | 3 sub-ticket |
| **P0-3** | PR 7-class 风险 checkbox + pr-body-check.yml 升级 | EPIC-138-A/B | 2 sub-ticket |
| **P0-4** | SECURITY.md (10-day / 90-day SLA) | EPIC-139 | 1 单卡 |

**总量**: 9 tickets (10 - EPIC-136-D 为 P1). 建卡完成 2026-07-26.

### P1 (下轮再做)

| 借鉴项 | 备注 |
|---|---|
| Node onlyBuiltDependencies 白名单 + Rust build.rs inventory | EPIC-136-D (已建卡, priority=P1) |
| AGENTS.md 升级: path pattern → 强制读的 decision 文件表 | 未建卡, 等 P0 落地后一起改 AGENTS.md |
| 堆叠"轻量 CI 门禁" (3 个新 check-*.sh) | 未建卡, 候选: check-eket-copy / check-worktree-cleanup / check-workspace-boundary |

### P2 (战略级, 暂缓)

| 借鉴项 | 何时启动 |
|---|---|
| 双语 governance 文档 (中英对偶) | 若 KALLAX v4.x 决定国际开源 |
| i18n glossary JSON schema + baseline drift CI | 若术语库出现漂移 (Master/Conductor/Performer/EPIC 等在 26 命令 / SKILL.md 间不一致时) |
| dependency-patches/ 系统治理 | 需要 patch upstream crate 时 |

---

## 反过来 — Cindy **不该抄** 的东西 (KALLAX 已有护城河)

| Cindy 做法 | 别抄的原因 |
|---|---|
| CI 单平台 ubuntu-only + Electron 二进制全 stub | KALLAX rust-build + cross-platform 已比它硬 |
| 无 release workflow (明说"不做") | KALLAX 已有 release.yml + 52 个 tag, 别倒退 |
| CODEOWNERS 只有 `* @team` 一行 | KALLAX 用 confluence/decisions/ 精细记录, 别退化 |
| React / TS 版本 desktop 与 mobile 漂移 | KALLAX rust workspace 已 --workspace 强制一致 |
| 20 commits 全在开源当天两天内 push (说明内部单仓一次性 push) | KALLAX 历史真实分布, 别抄这种 pattern |
| `cindy-protocol` submodule 是隐性 workspace 强依赖 | KALLAX 不该走 submodule-hoist-workspace 这种 clever 路 |

---

## 关键证据引用 (专家 4 报告 file:line 佐证)

### Architect 专家 (Cindy monorepo 架构)

- **Harness 抽象**: `packages/maker-core/src/index.ts:L3-5` 硬规 "零 Electron 依赖. 所有 IO 由 host 层依赖注入传入" — pure logic core.
- **Codex transport 契约**: `maker-core/src/index.ts:L18-25` 导出 `CodexAppServerTransport / LineHandler / StderrHandler / CloseHandler / TransportCloseInfo`.
- **Out-of-process harness manager**: `packages/maker-cc-manager/src/{protocol.ts,codec.ts,server.ts,client.ts,session-registry.ts,bin/}` (13KB protocol + 25KB session registry).
- **Vendor binary supply chain**: `scripts/ensure-agent-binaries.mjs` + `scripts/agent-binary-cdn-fallback.mjs` + sha256 verify + multi-CDN fallback + CI 单测.

### Product/Growth 专家 (GTM + community)

- **Coding Plan 直吃**: README 原文 "authorize the Claude Code / Codex Coding Plan you already pay for and keep using it inside Cindy — no duplicate bill" — 极其罕见的商业清算.
- **DCO 端到端**: `.githooks/prepare-commit-msg` (3012 bytes) + `.github/dco.yml` (806 bytes) + `pnpm check:dco` + PR checklist + AGENTS.md 描述.
- **PR 模板 7 类风险**: `.github/PULL_REQUEST_TEMPLATE.md` (3212 bytes) — 结构化 8 段含 "自动验证含命令与结果" + "7 类风险分类".
- **SECURITY SLA**: SECURITY.md 明写 "5 工作日确认 + 90 天协调披露窗口 + 7 天无响应可换渠道催".
- **20 commits 全在开源日**: 291 commits 但 20 recent commits 全在 2026-07-25/26 两天 → 内部单仓一次性 push 到开源仓的模式.

### Frontend/UX 专家 (Electron + RN 跨端)

- **Zero-dep pure-TS 共享**: `@cindy/maker-shared` 声明 "Zero React/Electron/Expo runtime dependencies", `main`/`types` 直接指 `./src/index.ts` (no build), 50+ subpath exports.
- **`.easignore` 白名单模式**: 精确保留 apps/mobile + 5 packages + cindy-protocol submodule, 其他全 filter, 保 EAS archive 小.
- **`.npmrc` 3 行硬 lock**: `node-linker=hoisted` / `frozen-lockfile=true` / `engine-strict=true`.
- **i18n glossary drift baseline**: `i18n/glossary.json` (34KB) + `glossary.schema.json` + `glossary-baseline.json` + `GLOSSARY.md` (29KB) — CI 强制术语一致.
- **风险: React/TS 版本漂移**: desktop `react@^19.0.0` + `typescript@^5.7.0`; mobile `react@19.2.3` + `typescript@~6.0.3` — 共享包被两个 TS 主版本 typecheck.

### Governance/Security 专家 (治理链条)

- **DCO hook 细节**: 用 COMMITTER ident 而非 AUTHOR (防代签); 显式 `--if-exists addIfDifferent --if-missing add` (防本地 config 绕过); merge commit 豁免; `allowRemediationCommits` 让 review 评论不因 force-push 失效.
- **CI actions SHA 钉版**: `actions/checkout@3d3c42e5…v7.0.1` (SHA + 注释) — 供应链硬化.
- **CI submodule 源校验**: 显式检查 `.gitmodules` 中 `cindy-protocol.url == https://github.com/makecindy/cindy-protocol.git` — 防 fork PR 换源.
- **`pnpm.overrides` CVE 治理**: `protobufjs 7.6.5` / `tar ^7.5.21` / `brace-expansion ^5.0.8` / `tmp ^0.2.7` / `fast-uri ^3.1.4` / `sharp ^0.35.0` — 系统性响应 CVE.
- **`pnpm.onlyBuiltDependencies` 白名单**: better-sqlite3, electron, node-pty, sharp 等 — 收窄 postinstall 面.
- **dependency-patches/** 5 个补丁: `react-native@0.85.3.patch` / `expo-paste-input@0.2.2.patch` / `harmonyos-sans-sc-webfont-splitted.patch` / `react-native-uitextview@2.2.0.patch` / `react-native-webview@13.16.1.patch` — 每个附上游 issue/PR 链接.
- **`GITHUB_TOKEN permissions: contents: read`**: 最小化 token, design-basis 才加 `pull-requests: read`.
- **CI 覆盖面单薄 (Cindy 缺口)**: ubuntu-only + Node 22 单版本 + Electron 二进制全 stub + 无 CodeQL/SAST + 无 SBOM CI + 无 release workflow.

---

## 落地追踪 (Post-Process 11 步骤对齐)

- [x] **1. 回归验证** — 4 专家 report + 综合报告
- [x] **2. 建卡** — EPIC-136-A/B/C/D + EPIC-137-A/B/C + EPIC-138-A/B + EPIC-139 = 10 tickets
- [ ] **3. 经验沉淀** — 本文档 (`borrow-from-cindy-2026-07-26.md`) 是 L1 → L2 升级候选
- [ ] **4. 技术债登记** — Cindy CI 覆盖面单薄给 KALLAX 提醒: 保持 13 workflows 不倒退
- [ ] **5-11.** — 等 EPIC 完成后跑 `scripts/post-process.sh --apply`

**联动 ticket**: EPIC-136 / 137 / 138 / 139 (本记录派生 10 sub-ticket)
**联动决策**: `confluence/research/eket-borrow-methodology-2026-06-07.md` (借方法论 不借代码原则, 本次 100% 遵循)
**联动战略**: "翻篇 & 精进" + "反哺框架" + "借方法论 不借代码" 三大战略一致

---

## 一句话总结

Cindy 的**代码架构** (Electron+Expo, harness 抽象, cindy-protocol submodule) 跟 KALLAX 无交集; 但 Cindy 的**工程治理链条** (供应链硬化 + DCO hook + PR 风险分类 + SECURITY SLA + 轻量门禁堆叠) 是**心动网络内部规范外化**, 工艺水平接近 CNCF baseline. KALLAX 抄这 9 个 P0 tickets, 工程 discipline 上一个台阶, 0 破坏现有 Fact-Forcing / L0-L4 / branch-flow 纪律.

**KALLAX 护城河不可倒退**: Fact-Forcing / L0-L4 / Sub-Role / 决策矩阵 25 cells / branch-flow governance — 这些 Cindy 都没有.
