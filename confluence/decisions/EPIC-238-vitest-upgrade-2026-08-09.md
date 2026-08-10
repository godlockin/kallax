# EPIC-238 — vitest 1.5 → 4.1 大版本升级 (Security Audit Phase 2)

- **日期**: 2026-08-09
- **拍板**: 主公 ("A" — 接 Phase 2, 独立 EPIC)
- **前置**: EPIC-237 Security Audit Phase 1 (decision doc 评估了此 EPIC)
- **版本目标**: v3.34.12

## 1. 为什么

CI Security Audit 仍 fail (5 漏洞, 全在 vitest<=3.2.5 依赖链):
- esbuild (GHSA-67mh-4wv8-2f99, GHSA-g7r4-m6w7-qqqr) — dev server 任意文件读
- vitest<=3.2.5 — 含 esbuild 传递漏洞
- vite<=6.4.2 — 含 esbuild
- vite-node<=2.2.0-beta.2 — 含 vite
- @vitest/coverage-v8<=3.2.5 — 含 vitest

EPIC-237 §3 评估: 跨 3 大版本, 79 个测试文件需要验证 (实际77 个用vitest), 预计 1-3 天工作.

## 2. 当前状态

| 包 | 当前版本 | 目标 | 备注 |
|---|---|---|---|
| vitest | 1.6.1 | 4.1.10 | 跨 3 major |
| @vitest/coverage-v8 | 1.5.0 | 4.1.10 | 同步 |
| vite | 5.x | 6.4.x | vitest 4 需要 |
| vite-node | 1.6.1 | 2.x | 同步 |
| esbuild | 0.28.x | 0.25.x | vite 6 转 SWC, esbuild 降级 |

## 3. 阶段计划

### 3.1 Phase A: 升级 + 跑测试 (本 EPIC)

**Step 1**: 装新版本
```bash
cd node
npm install --save-dev vitest@^4.1.10 @vitest/coverage-v8@^4.1.10 vite@^6.4.0 vite-node@^2.2.0
```

**Step 2**: 跑测试
```bash
KALLAX_HOOK_API_KEY=test-key npx vitest run --reporter=basic
```

**Step 3**: 分类 fail
- API 改 (vi.mock / spyOn / expect.soft)
- 配置改 (vite.config.ts)
- 测自身 bug (罕见, 但要看)

**Step 4**: 修 fail (最多 79 个文件)

**Step 5**: 跑 cargo test + vitest 一起验证

**Step 6**: 4-PR 全流程
- feature → testing (master + 4 sub-roles)
- testing → main (FF)
- main → miao (master + 4 sub-roles)

### 3.2 Phase B: 完整测试覆盖 (主公独立拍板, 不在本 EPIC)

- 跑完 `cargo test --workspace --release` 确认 0 errors
- 跑 `npx vitest --coverage` 验证覆盖率没降
- 跑 `bash scripts/verify/check-ticket-schema.sh` 验证新 vitest 兼容 hook

## 4. 已知风险 + 缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| `vi.mock` API 变化 | 中 | sentinel 测试 (79 个) 多用 `import + describe + it`, 影响小 |
| `vite.config.ts` 配置格式 | 中 | vitest 4 文档: config 可独立于 vite.config, 不强制要求 vite 6 |
| `expect.soft` 不存在 4.x | 低 | 扫代码, 没用到 (推测) |
| coverage-v8 接口 | 中 | reporter 选项可能变 |
| Node ESM compatibility | 中 | 仓库用 Node 20+, vitest 4 要求 Node 18+ |
| pnpm vs npm | 中 | `packageManager: pnpm@10.13.1` 但 lockfile 是 npm 格式 — 装包时需注意 |

## 5. 实施

### 5.1 检查 vitest 4 升级指引

按 [vitest 4 migration guide](https://vitest.dev/guide/migration) (从网络查, 跟据 EPIC-069-D 标注):
- 2.0: `test` 已分化为 `describe`/`it` 外的 fixture API, 但旧 import 仍兼容
- 3.0: Node 16 移除, 需 Node 18+, 默认 Node ESM
- 4.0: 默认 vite 6, 移除 Node CJS 实验性支持

### 5.2 已识别可能 fail 的模式

```
import { vi } from 'vitest'      # 仍在
vi.fn() / vi.spyOn() / vi.mock()  # 大部分兼容
expect.soft()                     # 2.1+ 引入
vi.hoisted()                      # 4.x 新增 (我们的代码无影响)
test.extend()                     # 2+ 新增
```

## 6. 测试策略

1. **最小测试**: 装包后, 跑 vitest run --reporter=basic 5 min timeout
2. **fail 分类**: 用 `npx vitest --reporter=json` 收集 fail, grep 错误类型
3. **修**: 按类型批改 (sed / 单文件手动)
4. **回归**: 修一个跑一次, 不要一次性改完再跑

## 7. 验证 Checklist

- [x] Phase 1 完成 (10→5 漏洞)
- [ ] vitest 1.5 → 4.1 安装完成
- [ ] `npx vitest run` 0 fail
- [ ] `cargo test --workspace` 0 errors
- [ ] coverage 报告无退化
- [ ] PR #X 通过 Phase 2 gate (master + 4 sub-roles)
- [ ] `npm audit --audit-level=high` 0 漏洞

## 8. 0 增 Rule, 0 改 Immutable, 0 改 CLAUDE.md

跟 EPIC-237 同样模式, 仅依赖升级 + 测试代码修复.

## 9. 风险预案

如果 vitest 4.1 升级大面积 fail (≥ 30%), 主公需拍板:
- **A. 接受 vitest 1.5 现状** + 关 CI Security Audit check (标记已知债)
- **B. 逐个 fail 修** (延长本 EPIC 到 1-2 周)
- **C. 换 jest** (高风险, 跟 EPIC-237 §3.3 C 同样不推荐)
- **D. 跳 vitest, 删测试** (不可接受)

## 10. 联动

- **EPIC-237**: Phase 1 完成, Phase 2 (本 EPIC) 跟 §3 评估相同
- **PR #342 (EPIC-237)**: 已 merge, 含本 EPIC 评估
- **EPIC-231**: 跨主干 PR gate 工作, 本 EPIC 4 阶段均走 4-PR
- **Rule 9 (X/Y 格式)**: "X fail / Y total" 显式标
- **Rule 8 (≤500 行)**: 单 commit 控制在 500 行内 (依赖 bump 极小, 主要是测试修复)

## 11. 累积会话状态

| EPIC | 内容 | 状态 |
|---|---|---|
| 231 | PR flow gate | ✅ merged (9dbeeca4) |
| 232 | authz 5 bug | ✅ merged (30a161bd) |
| 217 | README 30s | ✅ merged (eb7e60fc) |
| 235 | amend 备案 | ✅ merged (a2040afa) |
| 236 | lib 迁移 | ✅ merged (16b2da74) |
| 237 | security audit Phase 1 | ✅ merged (5774a90e) |
| **238** | **vitest 升级 Phase 2** | **⏳ 本 EPIC, 进行中** |

主公下一步:
- 步骤 1: 装 vitest 4.1.10
- 步骤 2: 跑测试, 报告 fail 数
- 步骤 3: 主公根据 fail 数决定修法 (A/B/C/D)