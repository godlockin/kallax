# KALLAX 验证协议

> 解决 KALLAX Agent 幻觉产出问题

---

## 1. 问题背景

### 1.1 KALLAX 教训

在 KALLAX 项目中，Background Agent 模式导致以下问题:

| 问题 | 表现 | 影响 |
|-----|------|-----|
| 幻觉产出 | 报告"任务完成"但文件未创建 | 浪费时间验证 |
| Stub 代码 | 提交 `// TODO: implement` | 需要返工 |
| 虚假测试 | 测试存在但实际未运行 | 生产故障 |
| 引用不存在模块 | import 语句指向不存在的文件 | 编译失败 |

### 1.2 根本原因分析

```
❌ KALLAX 模式: 信任 Agent 报告

Performer: "任务完成，已创建 Login.tsx 并通过所有测试"
Conductor: "好的，合并" (未验证)

结果: 
- Login.tsx 不存在
- 或者只有 stub 代码
- 测试从未实际运行
```

---

## 2. KALLAX 4-Level Fact-Forcing

### 2.1 概览

     4-Level Fact-Forcing                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 1: 存在性验证 (Existence)                                    │
│  ──────────────────────────────                                     │
│  问: 声明的文件/函数/类是否真实存在?                                  │
│                                                                      │
│  验证命令:                                                           │
│  $ git diff --name-only HEAD~1                                      │
│  $ ls -la src/components/Login/                                     │
│  $ grep -l "export.*Login" src/                                     │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 2: 实质性验证 (Substance)                                    │
│  ──────────────────────────────                                     │
│  问: 代码是否为真实逻辑，而非占位符?                                  │
│                                                                      │
│  验证命令:                                                           │
│  $ grep -r "TODO\|FIXME\|stub\|not implemented" src/                │
│  $ git show HEAD -- src/components/Login/index.tsx | head -50       │
│  $ wc -l src/components/Login/*.tsx                                 │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 3: 接线验证 (Wiring)                                         │
│  ──────────────────────────                                         │
│  问: 模块之间的连接是否正确?                                         │
│                                                                      │
│  验证命令:                                                           │
│  $ npm run build                                                    │
│  $ tsc --noEmit                                                     │
│  $ npx eslint src/ --max-warnings 0                                 │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 4: 数据流验证 (Data Flow)                                    │
│  ─────────────────────────────                                      │
│  问: 数据是否按预期流转? 端到端是否工作?                              │
│                                                                      │
│  验证命令:                                                           │
│  $ npm test -- --coverage                                           │
│  $ npm run test:e2e                                                 │
│  $ curl http://localhost:3000/api/health                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

缺任一项 = PR 被 Reject
```

### 2.2 Level 1: 存在性验证

**目的**: 确认 Performer 声称创建/修改的文件确实存在

```bash
# Conductor 验证流程
kallax verify:existence TASK-001

# 内部执行:
# 1. 获取 Performer 声明的变更列表
declared_files=$(kallax task:get-declared-changes TASK-001)

# 2. 获取实际 git diff
actual_files=$(git diff --name-only origin/main...feature/TASK-001)

# 3. 对比
for file in $declared_files; do
  if ! echo "$actual_files" | grep -q "$file"; then
    echo "❌ PHANTOM FILE: $file declared but not in diff"
    exit 1
  fi
done

# 4. 检查文件实际存在
for file in $actual_files; do
  if [ ! -f "$file" ]; then
    echo "❌ MISSING FILE: $file in diff but doesn't exist"
    exit 1
  fi
done

echo "✅ Level 1 PASSED: All files exist"
```

**常见幻觉模式**:

```typescript
// ❌ 幻觉: 引用不存在的模块
import { useAuth } from '@/hooks/useAuth';  // useAuth.ts 从未创建

// ❌ 幻觉: 导出不存在的函数
export { Login, LoginForm, LoginButton };   // LoginButton 未实现
```

### 2.3 Level 2: 实质性验证

**目的**: 确认代码是真实逻辑，而非占位符

```bash
# Conductor 验证流程
kallax verify:substance TASK-001

# 内部执行:
# 1. 检查关键路径无 TODO/FIXME
critical_files=$(kallax task:get-critical-files TASK-001)

for file in $critical_files; do
  if grep -E "TODO|FIXME|stub|not.?implemented|throw.*NotImplemented" "$file"; then
    echo "❌ STUB CODE in critical file: $file"
    exit 1
  fi
done

# 2. 检查函数体非空
for file in $critical_files; do
  # 使用 AST 分析检查空函数
  kallax analyze:empty-functions "$file"
done

# 3. 检查代码行数合理
for file in $critical_files; do
  lines=$(wc -l < "$file")
  if [ "$lines" -lt 10 ]; then
    echo "⚠️  SUSPICIOUS: $file has only $lines lines"
  fi
done

echo "✅ Level 2 PASSED: Code has substance"
```

**常见 Stub 模式**:

```typescript
// ❌ Stub: 空函数体
function handleLogin(credentials: Credentials) {
  // TODO: implement
}

// ❌ Stub: 直接抛出
function validateEmail(email: string): boolean {
  throw new Error('Not implemented');
}

// ❌ Stub: 硬编码返回
function fetchUserProfile(userId: string): Promise<User> {
  return Promise.resolve({ id: userId, name: 'Test User' });
}
```

### 2.4 Level 3: 接线验证

**目的**: 确认模块之间的连接正确，类型兼容

```bash
# Conductor 验证流程
kallax verify:wiring TASK-001

# 内部执行:
# 1. TypeScript 编译检查
npm run build 2>&1 | tee build.log
if [ $? -ne 0 ]; then
  echo "❌ BUILD FAILED"
  cat build.log
  exit 1
fi

# 2. Lint 检查
npm run lint 2>&1 | tee lint.log
if [ $? -ne 0 ]; then
  echo "❌ LINT FAILED"
  cat lint.log
  exit 1
fi

# 3. 类型检查
tsc --noEmit 2>&1 | tee typecheck.log
if [ $? -ne 0 ]; then
  echo "❌ TYPE CHECK FAILED"
  cat typecheck.log
  exit 1
fi

# 4. 导入导出一致性检查
kallax analyze:imports src/

echo "✅ Level 3 PASSED: Wiring correct"
```

**常见接线问题**:

```typescript
// ❌ 接线错误: 类型不匹配
interface LoginProps {
  onSubmit: (email: string, password: string) => void;
}

// 调用方传递了错误的参数
<Login onSubmit={(credentials) => handleLogin(credentials)} />
// 期望 (email, password) 但传递了 (credentials)

// ❌ 接线错误: 循环依赖
// auth.ts
import { validateSession } from './session';  // → 导入 session

// session.ts
import { getAuthToken } from './auth';        // → 导入 auth (循环!)
```

### 2.5 Level 4: 数据流验证

**目的**: 确认端到端数据流正确，测试真实运行

```bash
# Conductor 验证流程
kallax verify:dataflow TASK-001

# 内部执行:
# 1. 运行单元测试
npm test -- --coverage 2>&1 | tee test.log
if [ $? -ne 0 ]; then
  echo "❌ UNIT TESTS FAILED"
  cat test.log
  exit 1
fi

# 2. 检查覆盖率
coverage=$(grep -E "All files.*\|" test.log | awk '{print $4}')
if [ "$coverage" -lt 80 ]; then
  echo "⚠️  COVERAGE LOW: $coverage%"
fi

# 3. 运行集成测试 (如果有)
if [ -f "tests/integration" ]; then
  npm run test:integration 2>&1 | tee integration.log
  if [ $? -ne 0 ]; then
    echo "❌ INTEGRATION TESTS FAILED"
    exit 1
  fi
fi

# 4. 运行 E2E 测试 (关键路径)
npm run test:e2e -- --spec "cypress/e2e/login.cy.ts" 2>&1 | tee e2e.log
if [ $? -ne 0 ]; then
  echo "❌ E2E TESTS FAILED"
  exit 1
fi

echo "✅ Level 4 PASSED: Data flow verified"
```

---

## 3. Conductor 验证流程

### 3.1 完整 PR Review 流程

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Conductor PR Review 流程                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. 接收 PR Review 请求                                             │
│     ┌───────────────────────────────────────────────────────────┐  │
│     │ Performer: PR #42 ready for review (TASK-001)             │  │
│     └───────────────────────────────────────────────────────────┘  │
│                          │                                          │
│                          ▼                                          │
│  2. 自动化验证 (CI)                                                 │
│     ┌───────────────────────────────────────────────────────────┐  │
│     │ ✓ Build passed                                             │  │
│     │ ✓ Lint passed                                              │  │
│     │ ✓ Tests passed (42/42)                                     │  │
│     │ ✓ Coverage: 85%                                            │  │
│     └───────────────────────────────────────────────────────────┘  │
│                          │                                          │
│                          ▼                                          │
│  3. Conductor 4-Level 验证                                         │
│     ┌───────────────────────────────────────────────────────────┐  │
│     │ Level 1: 存在性验证                                        │  │
│     │   $ git diff --name-only                                   │  │
│     │   > src/components/Login/index.tsx ✓                       │  │
│     │   > src/components/Login/Login.test.tsx ✓                  │  │
│     │   > src/hooks/useAuth.ts ✓                                 │  │
│     │                                                            │  │
│     │ Level 2: 实质性验证                                        │  │
│     │   $ grep -r "TODO\|FIXME" src/components/Login/            │  │
│     │   > (no results) ✓                                         │  │
│     │                                                            │  │
│     │ Level 3: 接线验证                                          │  │
│     │   $ npm run build                                          │  │
│     │   > Build successful ✓                                     │  │
│     │                                                            │  │
│     │ Level 4: 数据流验证                                        │  │
│     │   $ npm test -- src/components/Login/                      │  │
│     │   > PASS Login.test.tsx (5 tests) ✓                        │  │
│     └───────────────────────────────────────────────────────────┘  │
│                          │                                          │
│                          ▼                                          │
│  4. 代码审查                                                        │
│     ┌───────────────────────────────────────────────────────────┐  │
│     │ • 逻辑正确性检查                                           │  │
│     │ • 安全性检查                                               │  │
│     │ • 性能检查                                                 │  │
│     │ • 代码风格检查                                             │  │
│     └───────────────────────────────────────────────────────────┘  │
│                          │                                          │
│         ┌────────────────┴────────────────┐                        │
│         ▼                                 ▼                        │
│    ┌─────────┐                       ┌─────────┐                   │
│    │ APPROVE │                       │ REQUEST │                   │
│    │         │                       │ CHANGES │                   │
│    └────┬────┘                       └────┬────┘                   │
│         │                                 │                        │
│         ▼                                 ▼                        │
│  5. 合并到 main                    返回 Performer 修改             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 验证命令

```bash
# 一键执行全部验证
kallax verify:all TASK-001

# 或分步执行
kallax verify:existence TASK-001
kallax verify:substance TASK-001
kallax verify:wiring TASK-001
kallax verify:dataflow TASK-001

# 输出报告
kallax verify:report TASK-001 --format markdown
```

### 3.3 验证报告模板

```markdown
## PR Verification Report

**Task**: TASK-001
**PR**: #42
**Performer**: performer_frontend_001
**Date**: 2024-01-15 14:30:00

### Level 1: Existence ✅
| File | Status |
|------|--------|
| src/components/Login/index.tsx | ✅ Exists |
| src/components/Login/Login.test.tsx | ✅ Exists |
| src/hooks/useAuth.ts | ✅ Exists |

### Level 2: Substance ✅
- No TODO/FIXME found in critical files
- All functions have implementation
- Code lines: 245 (reasonable)

### Level 3: Wiring ✅
- Build: ✅ Success
- Lint: ✅ 0 errors, 0 warnings
- TypeScript: ✅ No type errors

### Level 4: Data Flow ✅
- Unit Tests: ✅ 12/12 passed
- Coverage: 87%
- E2E Tests: ✅ 3/3 passed

### Verification Result: **APPROVED**

Evidence:
- Build log: [link]
- Test log: [link]
- Coverage report: [link]
```

---

## 4. 证据要求

### 4.1 接受的证据

```yaml
accepted_evidence:
  # 具体代码引用
  code_reference:
    format: "file:line-range"
    example: "src/Login.tsx:42-58"
    
  # 命令执行输出
  command_output:
    format: "stdout/stderr"
    example: |
      $ npm test
      PASS src/Login.test.tsx
        ✓ renders login form (15ms)
        ✓ handles submit (32ms)
      
  # Git diff
  git_diff:
    format: "unified diff"
    example: |
      diff --git a/src/Login.tsx b/src/Login.tsx
      +export function Login() {
      +  return <form>...</form>
      +}
      
  # 测试执行结果
  test_result:
    format: "test runner output"
    include:
      - test names
      - pass/fail status
      - execution time
      - coverage metrics
```

### 4.2 拒绝的证据

```yaml
rejected_evidence:
  # 主观断言
  subjective:
    - "应该可以工作"
    - "我检查过了"
    - "看起来正确"
    - "没有问题"
    
  # 无输出的执行
  no_output:
    - "已运行测试" (无测试输出)
    - "已编译" (无编译日志)
    
  # Mock 用于集成验证
  mock_as_integration:
    - "Mock API 测试通过" (应使用真实 API)
    - "Mock 数据库测试通过" (应使用测试数据库)
    
  # 截图无上下文
  screenshot_no_context:
    - 无时间戳的截图
    - 无法确认来源的截图
```

### 4.3 证据记录

```typescript
interface VerificationEvidence {
  level: 1 | 2 | 3 | 4;
  type: 'command' | 'code_ref' | 'git_diff' | 'test_result' | 'screenshot';
  content: string;
  timestamp: Date;
  executor: string;  // Conductor ID
  
  // 可验证性
  reproducible: boolean;  // 是否可复现
  command?: string;       // 用于复现的命令
}

// 示例
const evidence: VerificationEvidence = {
  level: 4,
  type: 'test_result',
  content: `
    PASS src/components/Login/Login.test.tsx
      ✓ renders login form (15ms)
      ✓ submits credentials (32ms)
      ✓ shows error on failure (28ms)
    
    Test Suites: 1 passed, 1 total
    Tests:       3 passed, 3 total
  `,
  timestamp: new Date(),
  executor: 'conductor_001',
  reproducible: true,
  command: 'npm test -- src/components/Login/Login.test.tsx'
};
```

---

## 5. 幻觉检测模式

### 5.1 常见幻觉模式库

```typescript
const hallucinationPatterns = {
  // 存在性幻觉
  existence: [
    {
      name: 'phantom_import',
      pattern: /import.*from\s+['"](\.\/[^'"]+)['"]/g,
      check: (match: string) => !fs.existsSync(resolveImport(match))
    },
    {
      name: 'phantom_export',
      pattern: /export\s+\{([^}]+)\}/g,
      check: (match: string) => !symbolExists(match)
    }
  ],
  
  // 实质性幻觉
  substance: [
    {
      name: 'todo_placeholder',
      pattern: /\/\/\s*(TODO|FIXME|HACK|XXX):/gi
    },
    {
      name: 'empty_function',
      pattern: /function\s+\w+\([^)]*\)\s*\{\s*\}/g
    },
    {
      name: 'throw_not_implemented',
      pattern: /throw\s+new\s+Error\(['"]Not\s+implemented['"]\)/gi
    },
    {
      name: 'hardcoded_return',
      pattern: /return\s+['"]test['"]/gi
    }
  ],
  
  // 接线幻觉
  wiring: [
    {
      name: 'type_any_escape',
      pattern: /:\s*any\b/g
    },
    {
      name: 'ts_ignore',
      pattern: /@ts-ignore|@ts-nocheck/g
    }
  ]
};
```

### 5.2 自动检测脚本

```bash
#!/bin/bash
# scripts/detect-hallucinations.sh

echo "🔍 Detecting hallucinations..."

# 1. 检测幻觉导入
echo "Checking phantom imports..."
for file in $(find src -name "*.ts" -o -name "*.tsx"); do
  imports=$(grep -oP "from ['\"]\.\/[^'\"]+['\"]" "$file" | sed "s/from ['\"]\.\/\([^'\"]*\)['\"/\1/")
  dir=$(dirname "$file")
  for imp in $imports; do
    resolved="$dir/$imp"
    if [ ! -f "$resolved.ts" ] && [ ! -f "$resolved.tsx" ] && [ ! -f "$resolved/index.ts" ]; then
      echo "❌ PHANTOM IMPORT: $file imports non-existent $imp"
    fi
  done
done

# 2. 检测 TODO/FIXME
echo "Checking stub code..."
grep -rn "TODO\|FIXME\|not implemented" src/ --include="*.ts" --include="*.tsx"

# 3. 检测空函数
echo "Checking empty functions..."
grep -Pzon "function\s+\w+\([^)]*\)\s*\{\s*\}" src/

# 4. 检测 any 类型逃逸
echo "Checking any type escapes..."
grep -rn ": any" src/ --include="*.ts" --include="*.tsx"

echo "✅ Hallucination detection complete"
```

---

## 6. 验证失败处理

### 6.1 失败分级

```yaml
verification_failure_levels:
  # 严重: 必须修复才能继续
  critical:
    - phantom_file
    - build_failure
    - test_failure
    action: reject_pr
    
  # 警告: 需要解释或修复
  warning:
    - low_coverage
    - todo_in_non_critical
    - any_type_usage
    action: request_explanation
    
  # 信息: 建议改进
  info:
    - code_style
    - naming_convention
    action: comment_only
```

### 6.2 失败反馈模板

```markdown
## PR Review: Request Changes

**Task**: TASK-001
**Reason**: Verification failed at Level 2

### Failures

#### ❌ Stub Code Detected
```
src/hooks/useAuth.ts:42
  // TODO: implement token refresh
```

#### ❌ Empty Function
```typescript
// src/components/Login/validators.ts:15
function validatePassword(password: string): boolean {
  // Empty implementation
}
```

### Required Actions

1. Implement token refresh logic in `useAuth.ts:42`
2. Add password validation logic in `validators.ts:15`
3. Re-run tests and provide output

### Re-verification

After fixes, I will re-run:
```bash
kallax verify:substance TASK-001
kallax verify:dataflow TASK-001
```

Please update the PR and request re-review.
```

---

## 7. 配置参考

```yaml
# .kallax/config.yml
verification:
  # 启用的验证级别
  enabled_levels:
    - existence
    - substance
    - wiring
    - dataflow
    
  # 严格模式
  strict_mode: true
  
  # 覆盖率阈值
  coverage_threshold: 80
  
  # 允许的 TODO 位置
  allowed_todo_paths:
    - "docs/**"
    - "scripts/**"
    
  # 自动化验证
  auto_verify_on_pr: true
  
  # 幻觉检测
  hallucination_detection:
    enabled: true
    patterns_file: ".kallax/hallucination-patterns.yaml"
    
  # 证据存储
  evidence_storage:
    enabled: true
    path: ".kallax/evidence/"
    retention_days: 90
```

---

## 8. 最佳实践

### 8.1 Performer 提交前自检

```bash
# Performer 提交 PR 前运行
kallax self-check

# 输出:
# Self-check for TASK-001
# 
# ✅ Level 1: All declared files exist
# ✅ Level 2: No stub code detected
# ✅ Level 3: Build successful
# ✅ Level 4: All tests pass (15/15)
# 
# Ready for PR submission!
```

### 8.2 Conductor 验证清单

```markdown
## PR Review Checklist

### Automated Verification
- [ ] CI pipeline green
- [ ] 4-Level verification passed

### Manual Review
- [ ] Logic correctness
- [ ] Security considerations
- [ ] Performance implications
- [ ] Error handling
- [ ] Edge cases

### Evidence Collected
- [ ] Build log saved
- [ ] Test output saved
- [ ] Coverage report saved
- [ ] Code review notes documented
```

### 8.3 持续改进

```yaml
# 每月回顾
monthly_review:
  - 统计幻觉检出率
  - 分析漏检案例
  - 更新检测模式
  - 优化验证流程
```
