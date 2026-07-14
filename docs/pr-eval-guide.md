# PR Eval Guide — OpenAI Evals Framework 借鉴

> EPIC-120-B | v3.26.0 | OpenAI Evals 原文: "creating high-quality evals is among the most impactful activities"

## OpenAI Eval 设计原则

> **"Good eval criteria: thematically consistent, challenging, directionally clear, carefully crafted."**

| 原则 | 含义 | KALLAX 应用 |
|------|------|------------|
| Thematically consistent | 同 domain/use-case | PR eval 按 changed files 分类 |
| Challenging | 人类专家能做但不完美 | lint/tsc 是客观标准 |
| Directionally clear | 有明确参考答案或评分标准 | eslint exit 0 / tsc exit 0 / vitest exit 0 |
| Carefully crafted | 工程师写 prompt + spot-check | pr-eval.sh 由 master review |

## KALLAX PR Eval 架构

### 3 项自动化检查

| # | Eval | 命令 | 通过标准 |
|---|------|------|---------|
| 1 | **Lint** | `cd node && npx eslint . --max-warnings 0` | exit 0 |
| 2 | **TypeScript** | `cd node && npx tsc --noEmit` | exit 0 |
| 3 | **Vitest** | `cd node && npx vitest run --reporter=json` | failures=0 |

### pr-eval.sh 用法

```bash
# Eval PR by number
bash scripts/verify/pr-eval.sh --pr 129

# Eval by commit SHA
bash scripts/verify/pr-eval.sh --sha abc1234

# Eval local uncommitted changes
bash scripts/verify/pr-eval.sh --local
```

### 输出格式

```json
{
  "lint":   {"errors": 0, "exit": 0, "passed": true},
  "tsc":    {"errors": 0, "exit": 0, "passed": true},
  "vitest": {"failures": 0, "exit": 0, "passed": true},
  "all_pass": true,
  "overall_exit": 0
}
```

### Exit code

| Code | 含义 |
|------|------|
| **0** | 全部 PASS (lint 0 errors + tsc 0 errors + vitest 0 failures) |
| **1** | 至少一项 FAIL |
| **2** | 环境错误 (gh CLI 缺失, node_modules 不存在) |

## 设计理由

### 为什么 eslint + tsc + vitest?

OpenAI Eval 4 原则映射到 KALLAX:

- **lint** → 代码风格一致性 (thematically consistent)
- **tsc** → 类型安全 (directionally clear: 0 type errors = 明确标准)
- **vitest** → 功能正确性 (challenging: 人类 reviewer 无法枚举所有测试用例)

### 为什么 exit 0 才算 pass?

OpenAI Eval 强调 **ground truth from environment** — lint/tsc/vitest 的 exit code 是客观事实，不是主观评分。没有 raw_output 就 FAIL。

## CI 集成

`pr-eval.sh` 可在以下时机跑:

1. **PR open** (CI check) — 自动化 gate, 0 errors 才能 merge
2. **Pre-commit** (可选) — 本地提前 catch
3. **Release tag** — 最终 gate

## OpenAI 原文

```
Good eval criteria:
1. Thematically consistent (same use case/domain)
2. Challenging (human expert could do well)
3. Directionally clear (high quality reference answers or exhaustive rubrics)
4. Carefully crafted (engineer prompts, spot-check results)
```

Source: [OpenAI Evals README](https://github.com/wd0517/openai-evals/blob/main/README.md)
