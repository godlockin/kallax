# 5-Level Verify 硬化细节 (扩展)

> 主 CLAUDE.md 5-Level Verify 段 + immutable scripts 之外的所有 hardened 检查

**主 CLAUDE.md**: `/Users/chenchen/.claude/CLAUDE.md` → `### 5-Level Verify`
**本文件加载场景**: 新 EPIC 涉及 tsconfig / dead-code / cargo build 改动时; 还有 staging regex false-positive 沉淀 reference

---

## 起源

EPIC-131 抓到 "死代码/类型错误不被调用就不暴露" 治根. EPIC-132-A→G 跑了 `scripts/scan-dead-code.sh` 抓死债并 enabled strict.

---

## L2 / L4 必跑扩展规则

| 检查 | 必须 | 禁止 |
|------|------|------|
| L2 stdout | `cd node && npm run build` (= `npx tsc`) | ❌ `npx tsc --noEmit` alone (跳过 emit 不算 build) |
| L2 strict | tsconfig 含 `strict: true` (含 noUncheckedIndexedAccess + noPropertyAccessFromIndexSignature + noImplicitOverride + noUnusedLocals + noUnusedParameters) | ❌ `--strict false` 任何 flag override |
| L4 sentinel | `bash scripts/scan-dead-code.sh` exit 0 | ❌ 改 scan 脚本让 sentinel 永远 exit 0 (gate-paint) |
| L4 coverage | `vitest tests/dead-code-sentinel-coverage*.test.ts` 100% pass | ❌ try/catch tolerant 验业务逻辑 (sentinel 仅验"module 加载不抛") |

---

## tsconfig 跟 5-Level 必须对齐 (跟 EPIC-131 教训)

```json
{
  "compilerOptions": {
    "strict": true,                            // 含 noImplicit* 全套
    "noUncheckedIndexedAccess": true,          // index access 后 必须 narrow
    "noPropertyAccessFromIndexSignature": true,
    "noUnusedLocals": true,                    // EPIC-132-G 启用
    "noUnusedParameters": true,                // EPIC-132-G 启用
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
  }
}
```

---

## Stage 1 regex false-positive 沉淀 (历史教训)

> 这些 false positives 已经经累积测试 + postmortem 沉淀. **不要改 regex 改回去** (会让 sentinel 永久 noise)

- ❌ `grep -rnE '@ts-ignore'` 抓 JSDoc prose `"no @ts-ignore"` → 排除 `^\s*\*\s` 模式
- ❌ `grep -rnE ':\s*any'` 抓 JSDoc prose `"fail-closed: any error"` → 排除 JSDoc 行 (EPIC-151 收)
- ❌ `grep -rnE '\bTODO\b'` 抓 enum literal `TicketStatus.TODO` + regex pattern `/TODO/` → 排除
- ❌ `grep -rnE 'catch\s*\('` 抓 `.catch((err: unknown) => ...)` Promise → 排除 `\.catch(`

EPIC-151 修 Forbidden Patterns CI 加 `grep -v -E '^\s*\*\s?'` 排除 JSDoc 行 (v3.30.1).

---

## 新 EPIC 必跑 sentinel

```bash
# Confirm 0 dead code (新 EPIC 加新 .ts 必须 keep 0)
bash scripts/scan-dead-code.sh  # exit 0 = pass

# Confirm dead-code coverage sentinel 4 个测试 100% pass (sentinel 自身)
cd node && KALLAX_HOOK_API_KEY=test-key npx vitest run \
  tests/dead-code-sentinel-coverage.test.ts \
  tests/dead-code-sentinel-coverage-d.test.ts \
  tests/dead-code-sentinel-coverage-e.test.ts \
  tests/dead-code-master-verify.test.ts
```

---

## Pre-commit hook 配置

`.githooks/pre-commit` 强制跑 `scripts/scan-dead-code.sh`. Stage 1 false positives 通过精确 regex 排除 (不退).

如果 scan-dead-code 报 failure, **fix source**, 不要禁用 sentinel 或改 scan script.

---

## 起源: EPIC-069-D check-claim-evidence

`scripts/check-claim-evidence.sh` 是 5th immutable script (v3.8.1 EPIC-069-D 新加). 扫 README/CHANGELOG 出现 `X/Y PASS` 数字但无 `raw_output` 引用 → fail.

详细: `confluence/decisions/EPIC-069-D-fact-forcing-examples.md`.

---

## Cargo test strict (类似 Node tsconfig)

| 检查 | 必须 | 禁止 |
|------|------|------|
| L2 strict (rust) | `cargo test --workspace --release --no-fail-fast` 0 fail | ❌ `cargo build` alone |
| L4 strict (rust) | `cargo clippy --workspace --all-targets -- -D warnings` 0 warn | ❌ `cargo clippy` alone 不带 -D warnings |
| L4 strict (rust) | `cargo fmt --check --all` 0 diff | ❌ `cargo fmt --check` 不带 --all |

`rustfmt.toml` project-level config 用 rustc default (无 override).
