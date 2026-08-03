---
paths:
  - node/**/tsconfig.json
  - node/**/*.ts
  - "**/tsconfig*.json"
---

# TypeScript Strict Mode + Scan-Dead-Code Gate-Paint 防御 (EPIC-131/132)

> **Path-scoped rule**: 只在 tsconfig 或 TS 源码被操作时加载.

## tsconfig 必含 (跟 EPIC-131 教训)

```json
{
  "strict": true,
  "noUncheckedIndexedAccess": true,
  "noPropertyAccessFromIndexSignature": true,
  "noImplicitOverride": true,
  "noUnusedLocals": true,
  "noUnusedParameters": true,
  "noFallthroughCasesInSwitch": true
}
```

## 禁止

- ❌ `npx tsc --noEmit` alone (跳过 emit 不算 build) → 必须 `npm run build` (= `npx tsc`)
- ❌ `--strict false` 任何 flag override
- ❌ 改 `scripts/scan-dead-code.sh` 让 sentinel 永远 exit 0 (gate-paint)
- ❌ try/catch tolerant 验业务逻辑 (sentinel 仅验"module 加载不抛")

## L2 / L4 必跑

```bash
cd node && npm run build  # L2 = tsc, exit 0
bash scripts/scan-dead-code.sh  # L4 sentinel, exit 0
```

## Stage 1 regex false-positive 沉淀 (主公 Phase F 教训 + EPIC-158 修复)

- ❌ `grep -rnE '@ts-ignore'` 抓 JSDoc prose → 排除 `^\s*\*\s` 模式
- ❌ `grep -rnE ':\s*any'` 抓 JSDoc prose `"fail-closed: any error"` → 排除 JSDoc 行 (`grep -v -E '^[^:]+:[0-9]+:\s*\*'`)
- ❌ `grep -rnE '\bTODO\b'` 抓 enum literal `TicketStatus.TODO` → 排除
- ❌ `grep -rnE 'catch\s*\('` 抓 `.catch((err: unknown) => ...)` Promise → 排除 `\.catch(`