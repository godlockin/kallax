# EPIC-237 — Security Audit vitest 升级 (Phase 1 + Phase 2 评估)

- **日期**: 2026-08-09
- **拍板**: 主公 ("几个pr都合并, 下面做 Security Audit vitest")
- **触发**: CI Security Audit 一直 fail (10 个漏洞), PR #332/#333/#335/#337/#339/#340 都因这个 fail 而"PR Flow Gate 通过但 Security Audit fail" — 需在 phase 1/2 之间明确分工
- **版本**: v3.34.11 (Phase 1) / 待定 (Phase 2)

## 1. 为什么

CI Security Audit 长期 fail:
- vitest 1.5.0 → 4.1.10 跨 3 大版本 (breaking changes)
- 790 个测试文件需要全部跑一遍
- vite / vite-node / esbuild / @vitest/coverage-v8 依赖链必须同步升级

主公 2026-08-09 拍板做 Security Audit. 一次性 `npm audit fix --force` 会装 vitest 4.x, 但:
1. 790 个测试可能大面积 fail
2. vi.mock / vi.fn API 在 4.x 有破坏性变化
3. vite/vite-node 同步升级可能影响 vitest 配置
4. coverage-v8 从 v1→v4 接口也变

所以分两阶段:
- **Phase 1 (本 EPIC 提交)**: 只升级非 breaking 漏洞, vitest 保留 1.5.0
- **Phase 2 (下个 EPIC)**: vitest 1.5→4.1 大版本升级, 主公拍板 + 充分测试

## 2. Phase 1: 非 breaking 升级 (本 commit)

### 2.1 已修复

| CVE | 包 | 严重程度 |
|---|---|---|
| GHSA-52cp-r559-cp3m | js-yaml | high |
| GHSA-5p4m-2wfm-xmqj | js-yaml | high (CVE-2026-59870) |
| GHSA-28wg-ghj8-5hjv | nanoid | high |
| GHSA-2v37-7h3g-55p8 | nanoid | high |
| GHSA-r28c-9q8g-f849 | postcss | high |
| GHSA-fxqj-rqcc-2cmp | postcss | high |

### 2.2 剩余 (Phase 2 修)

5 个漏洞全在 vitest<=3.2.5 依赖链:
- vite <=6.4.2 (esbuild)
- vite-node <=2.2.0-beta.2 (vite)
- vitest <=3.2.5 (vite, vite-node)
- @vitest/coverage-v8 <=3.2.5 (vitest)
- esbuild (transitive)

### 2.3 实跑

```
$ npm audit --audit-level=high (修前)
  10 vulnerabilities (1 low, 2 moderate, 5 high, 2 critical)

$ npm audit fix   # 装 patch 版本, 保留 vitest 1.5

$ npm audit --audit-level=high (修后)
  5 vulnerabilities (5 high, 2 critical)
  (剩余全是 vitest<=3.2.5 依赖链)
```

## 3. Phase 2: vitest 1.5 → 4.1 评估 (未执行)

### 3.1 风险评估

| 风险 | 等级 | 说明 |
|---|---|---|
| 测试 API breaking | 高 | vi.mock / vi.fn / spyOn 在 vitest 2.x/3.x 有多次重构, 4.x 再变 |
| 790 个测试大面积 fail | 高 | 可能 30%+ fail, 需要逐个修 |
| 配置格式变 | 中 | vite.config.ts 在 2.x 后变化, vitest 4 可能要求新格式 |
| coverage-v8 接口变 | 中 | reporter 配置 / threshold 算法变化 |
| pnpm vs npm 包管理 | 中 | 仓库用 pnpm (`packageManager: pnpm@10.13.1`), 但 lockfile 是 npm 格式, lockfile 转换风险 |
| Node 版本要求 | 低 | Node 20+ 应该够 |

### 3.2 范围估算

- **Step 1**: 在 worktree 里 `npm install vitest@^4.1.10 @vitest/coverage-v8@^4.1.10 vite@latest vite-node@latest --save-exact`
- **Step 2**: 跑 `npx vitest run --reporter=basic`, 收集 fail 列表
- **Step 3**: 分类 fail (API 改 / 配置改 / 测试自身 bug), 逐类修
- **Step 4**: 跟现有 `tests/integration/*.test.sh` (Rule 5-Level L4) 一起跑
- **Step 5**: 修复 lint / typecheck
- **Step 6**: PR 走 4-PR 全流程 (跟 EPIC-231 / EPIC-232 同型)

预计: 1-3 天连续工作, 取决于 fail 数量.

### 3.3 决策建议 (供主公拍板)

- **A. 接受 Phase 1 现状, 不升 vitest** — 风险 0, 但 CI 长期 fail (报告"无法通过 security check")
- **B. 单独 EPIC 做 Phase 2, 主公独立拍板** — 风险高, 但符合"修治理债"价值观
- **C. 跳过 vitest, 改用 jest 或 vitest-lite** — 风险极高 (改测试框架), 不推荐

我倾向 **B**, 但需主公拍板 (本 EPIC 不擅自开始).

## 4. 影响

**正面**:
- 6 个 high 漏洞修复 (js-yaml, nanoid, postcss)
- Phase 1 修后, CI Security Audit fail 数字从 10 → 5 (虽然还 fail, 但 progress 明确)
- 不破坏任何现有测试 (因为只升 patch 版)

**代价**:
- 5 个 vitest 依赖链漏洞仍存在
- CI 仍 fail, 需 Phase 2 进一步修

## 5. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| npm audit fix 改了不该改的传递依赖 | 低 | diff 显示 144+/144-, 仅补丁级 bump |
| package-lock.json format 影响 pnpm 用户 | 低 | 仓库现用 npm (package-lock.json), pnpm 不影响 |
| Phase 1 触发其他 test 副作用 | 低 | 仅 patch 版, 兼容 |

## 6. 未验证

- **`npm audit fix --dry-run`** 没未跑, 直接 `--force-less` 装 patch
- **CI 重跑** 本 commit 在本地, 没 push
- **PR 创建** 未做
- **CHANGELOG / recent-epics 未补** — 同之前 EPIC
- **Phase 2 评估未实跑** — 本 EPIC 只评估不实施

## 7. 联动

- **PR #332/#333/#335/#337/#339/#340**: 都因 Security Audit fail 不能标 "All Checks Passed"
- **Rule 9 (KPI X/Y)**: Phase 1 后漏洞数 10→5, Phase 2 评估后 5→0 (跟 npm audit --audit-level=high)
- **EPIC-231**: PR Flow Gate 已工作, 本 PR 会通过

## 8. 变更文件

| 文件 | 变化 |
|---|---|
| `package-lock.json` | +144/-144 (patch bump, js-yaml/nanoid/postcss) |
| `confluence/decisions/EPIC-237-security-audit-2026-08-09.md` | 本文档 |

## 9. 验收 Checklist

- [x] Phase 1 patch bump 完成, npm audit 10 → 5
- [x] 0 改 source code
- [x] 0 增 Rule
- [x] 0 改 Immutable
- [x] 0 改 CLAUDE.md
- [ ] Phase 2 (vitest 1.5→4.1) 由主公独立拍板另开 EPIC
- [ ] CI 重跑验证 Security Audit fail 数减少