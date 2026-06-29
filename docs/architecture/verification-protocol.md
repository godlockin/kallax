# KALLAX v3.x 验证协议 (跟 v3.x 1:1 同步, 跟"反讽" 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

> **v3.2.0 重写** (主公 2026-06-30 拍 C explicit 拍板, 跟 v3.1.0 U-002 留待 联合, 跟"翻篇&精进" 战略 矛盾 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致)
>
> **跟 docs/ARCHITECTURE.md 联合**: 本文档是 v3.x 1:1 同步版, 跟主文档 `docs/ARCHITECTURE.md` §6 (5 levels 验证) + §11 (集成测试) 互为 互补, 跟 `docs/5-levels.md` 联合. **不删** (跟主公拍 C 一致, "重写就是重写" 诚实).

> 解决 Agent 幻觉产出问题 (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 升级到 5-Level 联合, 跟"反讽" 联合)

---

## 1. v3.x 问题背景 (跟 v2.7.6 联合, 跟"反讽" 联合)

### 1.1 v3.x 设计原则 (跟 v2.7.6 联合, 跟"反讽" 联合, 跟"诚实修正" 联合)

跟 v2.7.6 联合, **v3.x 升级 4-Level → 5-Level** (跟 v3.0.0 武器 2 联合, 跟"反讽" 联合):

在历史项目中, Background Agent 模式导致以下问题 (跟 v2.7.6 联合):

| 问题 | 表现 | 影响 | v3.x 跟 5-Level 联合 |
|-----|------|------|---------------------|
| 幻觉产出 | 报告"任务完成"但文件未创建 | 浪费时间验证 | Level 1 存在性 |
| Stub 代码 | 提交 `// TODO: implement` | 需要返工 | Level 2 实质性 |
| 虚假测试 | 测试存在但实际未运行 | 生产故障 | Level 4 数据流 |
| 引用不存在模块 | import 语句指向不存在的文件 | 编译失败 | Level 3 接线 |
| **v3.x 新增**: 边界越界 | scope creep / U-002 留待 / 越界反向 | 跟 v3.x 主架构 矛盾 | **Level 5 边界** |

### 1.2 v3.x 根本原因分析 (跟 v2.7.6 联合, 跟"反讽" 联合, 跟"诚实修正" 联合)

```
❌ v2.7.6 旧模式: 信任 Agent 报告 (跟"反讽" 联合 治根)

Performer: "任务完成，已创建 Login.tsx 并通过所有测试"
Conductor: "好的，合并" (未验证, 跟"反讽" 联合 治根)

结果 (跟 v2.7.6 联合, 跟"反讽" 联合):
- Login.tsx 不存在 (Level 1 FAIL)
- 或者只有 stub 代码 (Level 2 FAIL)
- 测试从未实际运行 (Level 4 FAIL)
- v3.x 新增: U-002 留待没处理 (Level 5 FAIL)

✅ v3.x 新模式: 5-Level 强制 (跟 v3.0.0 武器 2 联合)

Performer: "任务完成"
Conductor: 跑 level-1.sh → level-2.sh → level-3.sh → level-4.sh → level-5.sh
5/5 PASS → 合并 (跟 v3.0.0 联合, 跟"反讽" 联合 0 装饰)
```

---

## 2. v3.x 5-Level Fact-Forcing (跟 v2.7.6 4-Level 升级, 跟 v3.0.0 武器 2 联合, 跟"反讽" 联合)

### 2.1 v3.x 概览 (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合, 跟"反讽" 联合)

```
┌─────────────────────────────────────────────────────────────────────┐
│     v3.x 5-Level Fact-Forcing (跟 v3.0.0 武器 2 联合, 跟 v2.7.6 4-Level 升级) │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 1: 存在性验证 (Existence) — 跟 v2.7.6 联合                  │
│  ──────────────────────────────                                     │
│  问: 声明的文件/函数/类是否真实存在?                                  │
│                                                                      │
│  验证命令:                                                           │
│  $ git diff --name-only HEAD~1                                      │
│  $ ls -la src/components/Login/                                     │
│  $ grep -l "export.*Login" src/                                     │
│  $ level-1.sh src/components/Login/                                  │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 2: 实质性验证 (Substance) — 跟 v2.7.6 联合                  │
│  ──────────────────────────────                                     │
│  问: 代码是否为真实逻辑,而非占位符?                                  │
│                                                                      │
│  验证命令:                                                           │
│  $ grep -r "TODO\|FIXME\|stub\|not implemented" src/                │
│  $ git show HEAD -- src/components/Login/index.tsx | head -50       │
│  $ wc -l src/components/Login/*.tsx                                 │
│  $ level-2.sh src/components/Login/                                  │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 3: 接线验证 (Wiring) — 跟 v2.7.6 联合                      │
│  ──────────────────────────                                         │
│  问: 模块之间的连接是否正确?                                         │
│                                                                      │
│  验证命令:                                                           │
│  $ npm run build                                                    │
│  $ tsc --noEmit                                                     │
│  $ npx eslint src/ --max-warnings 0                                 │
│  $ level-3.sh --check-imports src/                                  │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 4: 数据流验证 (Data Flow) — 跟 v2.7.6 联合                │
│  ─────────────────────────────                                      │
│  问: 数据是否按预期流转? 端到端是否工作?                              │
│                                                                      │
│  验证命令:                                                           │
│  $ npm test -- --coverage                                           │
│  $ npm run test:e2e                                                 │
│  $ curl http://localhost:3000/api/health                            │
│  $ level-4.sh --e2e                                                │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 5: 边界验证 (Boundary) — v3.x 新增 (跟 v3.0.0 联合)         │
│  ─────────────────────────────                                      │
│  问: 边界条件 / U-002 留待 / scope creep / 越界反向 是否处理?         │
│                                                                      │
│  验证命令:                                                           │
│  $ level-5.sh --check-scope-creep                                   │
│  $ check-anti-patterns.sh .                                         │
│  $ U-002-DECISION-MATRIX.md (主公拍 explicit)                      │
│  $ check-epic-4-piece.sh (跟 v3.1.0 联合)                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

缺任一项 = PR 被 Reject (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合, 跟"反讽" 联合 0 装饰)
```

### 2.2 Level 1: 存在性验证 (跟 v2.7.6 联合, 跟"反讽" 联合)

**目的**: 确认 Performer 声称创建/修改的文件确实存在 (跟 v2.7.6 联合, 跟"反讽" 联合)

```bash
# v3.x: Conductor 验证流程 (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合)
kallax verify:existence TASK-001

# 内部执行 (跟 v2.7.6 联合):
# 1. 获取 Performer 声明的变更列表
declared_files=$(kallax task:get-declared-changes TASK-001)

# 2. 获取实际 git diff (跟 v2.7.6 联合)
actual_files=$(git diff --name-only origin/miao...feature/TASK-001)

# 3. 对比 (跟 v2.7.6 联合)
for file in $declared_files; do
  if ! echo "$actual_files" | grep -q "$file"; then
    echo "❌ PHANTOM FILE: $file declared but not in diff"
    exit 1
  fi
done

# 4. 检查文件实际存在 (跟 v2.7.6 联合)
for file in $actual_files; do
  if [ ! -f "$file" ]; then
    echo "❌ MISSING FILE: $file in diff but doesn't exist"
    exit 1
  fi
done

# v3.x 新增: level-1.sh 强制
bash level-1.sh src/components/Login/

echo "✅ Level 1 PASSED: All files exist"
```

**常见幻觉模式** (跟 v2.7.6 联合, 跟"反讽" 联合):

```typescript
// ❌ 幻觉: 引用不存在的模块 (跟 v2.7.6 联合, 跟"反讽" 联合)
import { useAuth } from '@/hooks/useAuth';  // useAuth.ts 从未创建

// ❌ 幻觉: 导出不存在的函数 (跟 v2.7.6 联合, 跟"反讽" 联合)
export { Login, LoginForm, LoginButton };   // LoginButton 未实现
```

### 2.3 Level 2: 实质性验证 (跟 v2.7.6 联合, 跟"反讽" 联合)

**目的**: 确认代码是真实逻辑, 而非占位符 (跟 v2.7.6 联合, 跟"反讽" 联合)

```bash
# v3.x: Conductor 验证流程 (跟 v2.7.6 联合)
kallax verify:substance TASK-001

# 内部执行 (跟 v2.7.6 联合):
# 1. 检查关键路径无 TODO/FIXME (跟 v2.7.6 联合)
critical_files=$(kallax task:get-critical-files TASK-001)

for file in $critical_files; do
  if grep -E "TODO|FIXME|stub|not.?implemented|throw.*NotImplemented" "$file"; then
    echo "❌ STUB CODE in critical file: $file"
    exit 1
  fi
done

# 2. 检查函数体非空 (跟 v2.7.6 联合, 跟"反讽" 联合)
for file in $critical_files; do
  kallax analyze:empty-functions "$file"
done

# 3. 检查代码行数合理 (跟 v2.7.6 联合, 跟"反讽" 联合)
for file in $critical_files; do
  lines=$(wc -l < "$file")
  if [ "$lines" -lt 10 ]; then
    echo "⚠️  SUSPICIOUS: $file has only $lines lines"
  fi
done

# v3.x 新增: level-2.sh 强制
bash level-2.sh src/components/Login/

echo "✅ Level 2 PASSED: Code has substance"
```

**常见 Stub 模式** (跟 v2.7.6 联合, 跟"反讽" 联合):

```typescript
// ❌ Stub: 空函数体 (跟 v2.7.6 联合, 跟"反讽" 联合)
function handleLogin(credentials: Credentials) {
  // TODO: implement
}

// ❌ Stub: 直接抛出 (跟 v2.7.6 联合, 跟"反讽" 联合)
function validateEmail(email: string): boolean {
  throw new Error('Not implemented');
}

// ❌ Stub: 硬编码返回 (跟 v2.7.6 联合, 跟"反讽" 联合)
function fetchUserProfile(userId: string): Promise<User> {
  return Promise.resolve({ id: userId, name: 'Test User' });
}
```

### 2.4 Level 3: 接线验证 (跟 v2.7.6 联合, 跟"反讽" 联合)

**目的**: 确认模块之间的连接正确, 类型兼容 (跟 v2.7.6 联合, 跟"反讽" 联合)

```bash
# v3.x: Conductor 验证流程 (跟 v2.7.6 联合)
kallax verify:wiring TASK-001

# 内部执行 (跟 v2.7.6 联合):
# 1. TypeScript 编译检查 (跟 v2.7.6 联合)
npm run build 2>&1 | tee build.log
if [ $? -ne 0 ]; then
  echo "❌ BUILD FAILED"
  cat build.log
  exit 1
fi

# 2. Lint 检查 (跟 v2.7.6 联合)
npm run lint 2>&1 | tee lint.log
if [ $? -ne 0 ]; then
  echo "❌ LINT FAILED"
  cat lint.log
  exit 1
fi

# 3. 类型检查 (跟 v2.7.6 联合, 跟"反讽" 联合)
tsc --noEmit 2>&1 | tee typecheck.log
if [ $? -ne 0 ]; then
  echo "❌ TYPE CHECK FAILED"
  cat typecheck.log
  exit 1
fi

# 4. 导入导出一致性检查 (跟 v2.7.6 联合)
kallax analyze:imports src/

# v3.x 新增: level-3.sh 强制
bash level-3.sh --check-imports src/

echo "✅ Level 3 PASSED: Wiring correct"
```

**常见接线问题** (跟 v2.7.6 联合, 跟"反讽" 联合):

```typescript
// ❌ 接线错误: 类型不匹配 (跟 v2.7.6 联合, 跟"反讽" 联合)
interface LoginProps {
  onSubmit: (email: string, password: string) => void;
}

// 调用方传递了错误的参数
<Login onSubmit={(credentials) => handleLogin(credentials)} />
// 期望 (email, password) 但传递了 (credentials)

// ❌ 接线错误: 循环依赖 (跟 v2.7.6 联合, 跟"反讽" 联合)
// auth.ts
import { validateSession } from './session';  // → 导入 session

// session.ts
import { getAuthToken } from './auth';        // → 导入 auth (循环!)
```

### 2.5 Level 4: 数据流验证 (跟 v2.7.6 联合, 跟"反讽" 联合)

**目的**: 确认端到端数据流正确, 测试真实运行 (跟 v2.7.6 联合, 跟"反讽" 联合)

```bash
# v3.x: Conductor 验证流程 (跟 v2.7.6 联合)
kallax verify:dataflow TASK-001

# 内部执行 (跟 v2.7.6 联合):
# 1. 运行单元测试 (跟 v2.7.6 联合)
npm test -- --coverage 2>&1 | tee test.log
if [ $? -ne 0 ]; then
  echo "❌ UNIT TESTS FAILED"
  cat test.log
  exit 1
fi

# 2. 检查覆盖率 (跟 v2.7.6 联合)
coverage=$(grep -E "All files.*\|" test.log | awk '{print $4}')
if [ "$coverage" -lt 80 ]; then
  echo "⚠️  COVERAGE LOW: $coverage%"
fi

# 3. 运行集成测试 (如果有, 跟 v2.7.6 联合)
if [ -f "tests/integration" ]; then
  npm run test:integration 2>&1 | tee integration.log
  if [ $? -ne 0 ]; then
    echo "❌ INTEGRATION TESTS FAILED"
    exit 1
  fi
fi

# 4. 运行 E2E 测试 (关键路径, 跟 v2.7.6 联合)
npm run test:e2e -- --spec "cypress/e2e/login.cy.ts" 2>&1 | tee e2e.log
if [ $? -ne 0 ]; then
  echo "❌ E2E TESTS FAILED"
  cat e2e.log
  exit 1
fi

# v3.x 新增: level-4.sh 强制
bash level-4.sh --e2e

echo "✅ Level 4 PASSED: Data flow verified"
```

### 2.6 Level 5: 边界验证 (v3.x 新增, 跟 v3.0.0 联合, 跟"反讽" 联合, 跟"诚实修正" 联合)

**目的**: 确认边界条件 / U-002 留待 / scope creep / 越界反向 是否处理 (v3.x 新增, 跟 v3.0.0 武器 1 联合, 跟"反讽" 联合)

```bash
# v3.x: Conductor 验证 Level 5 边界 (跟 v3.0.0 联合, 跟"反讽" 联合)
kallax verify:boundary TASK-001

# 内部执行 (v3.x 新增, 跟 v3.0.0 联合):
# 1. scope creep 检查 (跟 Rule 9c 联合, 跟 v3.0.0 联合)
bash check-scope-creep.sh TASK-001
if [ $? -ne 0 ]; then
  echo "❌ SCOPE CREEP: ticket file_scope 越界"
  exit 1
fi

# 2. U-002 留待 检查 (跟 v3.1.0 联合, 跟"反讽" 联合 治根)
if [ -f "docs/architecture/_DEPRECATED.md" ]; then
  if grep -q "留待主公\|留 v3\." "docs/architecture/_DEPRECATED.md"; then
    echo "❌ U-002 留待: DEPRECATED 子文档 留待主公拍板"
    echo "   治根: 写 U-002-DECISION-MATRIX.md 留主公 explicit 拍"
    exit 1
  fi
fi

# 3. anti-patterns 检查 (跟 v2.7.4 8 Gap 联合)
bash check-anti-patterns.sh .

# 4. KPI 估数检查 (跟 Rule 9 联合, 跟"反讽" 联合 治根)
if grep -rE "around|approximately|roughly|估计|~[0-9]+%|PARTIAL" --include="*.md" .; then
  echo "❌ KPI 估数: 违反 Rule 9 KPI falsification (跟 v3.0.0 联合)"
  exit 1
fi

# 5. EPIC 4 件套 检查 (跟 v3.1.0 武器 4 联合)
bash check-epic-4-piece.sh EPIC-XXX
if [ $? -ne 0 ]; then
  echo "❌ EPIC 4 件套 不完整: A+B review + readme + lessons + signoff"
  exit 1
fi

# v3.x 新增: level-5.sh 强制 (跟 v3.0.0 武器 2 联合)
bash level-5.sh --all

echo "✅ Level 5 PASSED: Boundary verified (跟 v3.0.0 联合)"
```

---

## 3. v3.x Conductor 验证流程 (跟 v2.7.6 联合, 跟 v3.1.0 A+B Review 联合, 跟"反讽" 联合)

### 3.1 v3.x 完整 PR Review 流程 (跟 v2.7.6 联合, 跟 v3.1.0 16 hotfix 联合, 跟"反讽" 联合)

```
┌─────────────────────────────────────────────────────────────────────┐
│               v3.x Conductor PR Review 流程 (跟 v2.7.6 联合, 跟 v3.1.0 A+B Review 联合) │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. 接收 PR Review 请求 (跟 v2.7.6 联合)                            │
│     ┌───────────────────────────────────────────────────────────┐  │
│     │ Performer: PR #42 ready for review (TASK-001)             │  │
│     │ sub-role: coder (跟 EPIC-038-A 联合)                     │  │
│     └───────────────────────────────────────────────────────────┘  │
│                          │                                          │
│                          ▼                                          │
│  2. 自动化验证 (CI) — 跟 v2.7.6 联合, 跟 v3.1.0 16 hotfix 联合      │
│     ┌───────────────────────────────────────────────────────────┐  │
│     │ ✓ Build passed                                             │  │
│     │ ✓ Lint passed                                              │  │
│     │ ✓ Tests passed (42/42)                                     │  │
│     │ ✓ Coverage: 85%                                            │  │
│     │ ✓ 5-Level PASS (跟 v3.0.0 武器 2 联合)                   │  │
│     │ ✓ 6 武器 PASS (跟 v3.0.0 武器 1-6 联合)                  │  │
│     └───────────────────────────────────────────────────────────┘  │
│                          │                                          │
│                          ▼                                          │
│  3. Conductor 5-Level 验证 (跟 v3.0.0 武器 2 联合, 跟 v2.7.6 4-Level 升级) │
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
│     │                                                            │  │
│     │ Level 5: 边界验证 (v3.x 新增, 跟 v3.0.0 联合)              │  │
│     │   $ level-5.sh --all                                       │  │
│     │   > U-002 留待 0 命中 ✓                                    │  │
│     │   > scope creep 0 命中 ✓                                   │  │
│     │   > KPI 估数 0 命中 ✓                                      │  │
│     │   > EPIC 4 件套 ✓                                          │  │
│     └───────────────────────────────────────────────────────────┘  │
│                          │                                          │
│                          ▼                                          │
│  4. A+B Review (跟 v3.1.0 16 hotfix 联合, 跟"反讽" 联合)             │
│     ┌───────────────────────────────────────────────────────────┐  │
│     │ A 组 Forward: 5 维度 PASS                                  │  │
│     │ B 组 Attack: 16 findings 全修                              │  │
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
│  5. 合并到 miao                    返回 Performer 修改             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 v3.x 验证命令 (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合, 跟"反讽" 联合)

```bash
# v3.x: 一键执行全部 5-Level 验证 (跟 v2.7.6 联合, 跟 v3.0.0 联合)
kallax verify:all TASK-001

# v3.x: 分步执行 (跟 v2.7.6 联合)
kallax verify:existence TASK-001   # Level 1
kallax verify:substance TASK-001   # Level 2
kallax verify:wiring TASK-001      # Level 3
kallax verify:dataflow TASK-001    # Level 4
kallax verify:boundary TASK-001    # Level 5 (v3.x 新增)

# v3.x: 输出报告 (跟 v2.7.6 联合)
kallax verify:report TASK-001 --format markdown
```

### 3.3 v3.x 验证报告模板 (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合, 跟"反讽" 联合)

```markdown
## v3.x PR Verification Report (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合)

**Task**: TASK-001
**PR**: #42
**Performer**: performer_001 (sub-role=coder, 跟 EPIC-038-A 联合)
**Date**: 2026-06-30 14:30:00

### 5-Level (跟 v3.0.0 武器 2 联合)

#### Level 1: Existence ✅
| File | Status |
|------|--------|
| src/components/Login/index.tsx | ✅ Exists |
| src/components/Login/Login.test.tsx | ✅ Exists |
| src/hooks/useAuth.ts | ✅ Exists |

#### Level 2: Substance ✅
- No TODO/FIXME found in critical files
- All functions have implementation
- Code lines: 245 (reasonable)

#### Level 3: Wiring ✅
- Build: ✅ Success
- Lint: ✅ 0 errors, 0 warnings
- TypeScript: ✅ No type errors

#### Level 4: Data Flow ✅
- Unit Tests: ✅ 12/12 passed
- Coverage: 87%
- E2E Tests: ✅ 3/3 passed

#### Level 5: Boundary ✅ (v3.x 新增, 跟 v3.0.0 联合)
- scope creep: 0 命中
- U-002 留待: 0 命中
- KPI 估数: 0 命中 (跟 Rule 9 联合, 跟"反讽" 联合 治根)
- EPIC 4 件套: ✅ 完整 (跟 v3.1.0 武器 4 联合)

### 6 武器 验证 (跟 v3.0.0 武器 1-6 联合)
- 武器 1 Hash-Chain: ✅
- 武器 2 5-Level: ✅
- 武器 3 Sub-Role: ✅
- 武器 4 EPIC 4 件套: ✅
- 武器 5 Hook Replay: ✅
- 武器 6 Dashboard: ✅

### A+B Review (跟 v3.1.0 16 hotfix 联合)
- A 组 Forward: 5/5 维度 PASS
- B 组 Attack: 16 findings 全修

### Verification Result: **APPROVED** (跟 v3.1.0 联合, 跟"反讽" 联合)

Evidence:
- Build log: [link]
- Test log: [link]
- Coverage report: [link]
- 5-Level stdout: [link]
- 6 武器 SHA: [link]
- A+B Review report: [link]
```

---

## 4. v3.x 证据要求 (跟 v2.7.6 联合, 跟 v3.1.0 P-005 治根 联合, 跟"反讽" 联合)

### 4.1 v3.x 接受的证据 (跟 v2.7.6 联合, 跟 v3.1.0 P-005 治根 联合, 跟"反讽" 联合)

```yaml
# v3.x PR Review 证据 (跟 v2.7.6 联合, 跟 v3.1.0 联合)
evidence_required:
  # 5-Level 证据 (跟 v3.0.0 武器 2 联合, 跟 v2.7.6 4-Level 升级)
  levels:
    level_1_existence: "git diff --name-only 真"
    level_2_substance: "raw stdout 真实"
    level_3_wiring: "build + tsc --noEmit 通过"
    level_4_dataflow: "test 8/8 PASS + coverage"
    level_5_boundary: "level-5.sh + U-002 决策"  # v3.x 新增

  # A+B Review 证据 (跟 v3.1.0 联合, 跟 v3.1.0 P-005 治根 联合)
  ab_review:
    forward: "5 维度 PASS"
    attack: "16 findings 全修"

  # 6 武器 证据 (跟 v3.0.0 联合)
  weapons:
    weapon_1_hash_chain: "audit SHA256 8 字符"
    weapon_2_5_level: "L1-L5 stdout"
    weapon_3_sub_role: "ticket.json sub_role 字段"
    weapon_4_epic_4piece: "A+B review + readme + lessons + signoff"
    weapon_5_hook_replay: "hook SHA"
    weapon_6_dashboard: "dash 页面 hash"

  # 代码引用 (跟 v2.7.6 联合)
  code_reference:
    format: "file:line-range"
    example: "src/Login.tsx:42-58"

  # 命令执行输出 (跟 v2.7.6 联合)
  command_output:
    format: "stdout/stderr"
    example: |
      $ npm test
      PASS src/Login.test.tsx
        ✓ renders login form (15ms)
        ✓ handles submit (32ms)

  # Git diff (跟 v2.7.6 联合)
  git_diff:
    format: "unified diff"

  # 测试执行结果 (跟 v2.7.6 联合)
  test_result:
    format: "test runner output"
    include:
      - test names
      - pass/fail status
      - execution time
      - coverage metrics
```

### 4.2 v3.x 拒绝的证据 (跟 v2.7.6 联合, 跟 v3.1.0 P-005 治根 联合, 跟"反讽" 联合)

```yaml
# v3.x 拒绝的证据 (跟 v2.7.6 联合, 跟 v3.1.0 P-005 治根 联合, 跟"反讽" 联合)
rejected_evidence:
  # 主观断言 (跟 v2.7.6 联合, 跟 v3.1.0 P-005 治根 联合, 跟"反讽" 联合)
  subjective:
    - "应该可以工作" (跟 v3.1.0 P-005 装饰 pattern 治根 联合)
    - "我检查过了"
    - "看起来正确"
    - "没有问题"

  # 无输出的执行 (跟 v2.7.6 联合, 跟"反讽" 联合)
  no_output:
    - "已运行测试" (无测试输出)
    - "已编译" (无编译日志)

  # KPI 估数 (跟 Rule 9 联合, 跟 v3.0.0 联合, 跟"反讽" 联合 治根)
  kpi_estimate:
    - "around" (跟 v3.0.0 联合, 跟"反讽" 联合 治根)
    - "approximately"
    - "roughly"
    - "估计"
    - "PARTIAL"
    - "M1 ~60-70%"  # 跟 v3.0.0 联合, 跟"反讽" 联合 治根

  # U-002 留待 (跟 v3.1.0 联合, 跟"反讽" 联合 治根)
  u002_deferred:
    - "留待主公拍板" (没有写 U-002-DECISION-MATRIX.md, 跟"反讽" 联合 治根)
    - "留 v3.x 拍板" (跟"反讽" 联合 治根)

  # Mock 用于集成验证 (跟 v2.7.6 联合)
  mock_as_integration:
    - "Mock API 测试通过" (应使用真实 API)
    - "Mock 数据库测试通过" (应使用测试数据库)

  # 截图无上下文 (跟 v2.7.6 联合)
  screenshot_no_context:
    - 无时间戳的截图
    - 无法确认来源的截图
```

### 4.3 v3.x 证据记录 (跟 v2.7.6 联合, 跟 v3.0.0 武器 1 联合, 跟"反讽" 联合)

```typescript
// v3.x VerificationEvidence (跟 v2.7.6 联合, 跟 v3.0.0 联合, 跟 EPIC-038-A 联合)
interface VerificationEvidence {
  level: 1 | 2 | 3 | 4 | 5;        // v3.x: 5 levels (跟 v3.0.0 武器 2 联合)
  type: 'command' | 'code_ref' | 'git_diff' | 'test_result' | 'screenshot' | '5_level_stdout' | '6_weapon_sha' | 'ab_review';
  content: string;
  timestamp: Date;
  executor: string;               // Conductor ID
  sub_role?: SubRole;             // v3.x 新增: 跟 EPIC-038-A 联合

  // 可验证性 (跟 v2.7.6 联合)
  reproducible: boolean;
  command?: string;
}

// v3.x 示例 (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合)
const evidence: VerificationEvidence = {
  level: 4,
  type: '5_level_stdout',          // v3.x 新增
  content: `
    Level 1: PASS (存在性验证)
    Level 2: PASS (实质性验证)
    Level 3: PASS (接线验证)
    Level 4: PASS (数据流验证)
    Level 5: PASS (边界验证)        # v3.x 新增
  `,
  timestamp: new Date(),
  executor: 'conductor_001',
  sub_role: 'coder',               // v3.x 新增: 跟 EPIC-038-A 联合
  reproducible: true,
  command: 'bash level-1.sh ... level-5.sh'
};
```

---

## 5. v3.x 幻觉检测模式 (跟 v2.7.6 联合, 跟"反讽" 联合, 跟"诚实修正" 联合)

### 5.1 v3.x 常见幻觉模式库 (跟 v2.7.6 联合, 跟 v3.0.0 联合, 跟"反讽" 联合)

```typescript
// v3.x: 跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合, 跟"反讽" 联合
const hallucinationPatterns = {
  // v3.x: 存在性幻觉 (跟 v2.7.6 联合, 跟 Level 1 联合)
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

  // v3.x: 实质性幻觉 (跟 v2.7.6 联合, 跟 Level 2 联合, 跟"反讽" 联合)
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

  // v3.x: 接线幻觉 (跟 v2.7.6 联合, 跟 Level 3 联合)
  wiring: [
    {
      name: 'type_any_escape',
      pattern: /:\s*any\b/g
    },
    {
      name: 'ts_ignore',
      pattern: /@ts-ignore|@ts-nocheck/g
    }
  ],

  // v3.x 新增: 边界幻觉 (跟 Level 5 联合, 跟"反讽" 联合 治根)
  boundary: [
    {
      name: 'kpi_estimate',
      pattern: /around|approximately|roughly|估计|PARTIAL/gi
    },
    {
      name: 'u002_deferred',
      pattern: /留待主公|留 v3\./g
    },
    {
      name: 'decorative_commit',
      pattern: /跟.+联合|跟.+战略/gi  // 跟 v3.1.0 P-005 治根 联合
    }
  ]
};
```

### 5.2 v3.x 自动检测脚本 (跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合, 跟"反讽" 联合)

```bash
#!/bin/bash
# scripts/detect-hallucinations-v3.sh (跟 v2.7.6 联合, 跟 v3.0.0 联合)

echo "🔍 Detecting v3.x hallucinations..."

# 1. 检测幻觉导入 (跟 v2.7.6 联合)
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

# 2. 检测 TODO/FIXME (跟 v2.7.6 联合)
echo "Checking stub code..."
grep -rn "TODO\|FIXME\|not implemented" src/ --include="*.ts" --include="*.tsx"

# 3. 检测空函数 (跟 v2.7.6 联合)
echo "Checking empty functions..."
grep -Pzon "function\s+\w+\([^)]*\)\s*\{\s*\}" src/

# 4. 检测 any 类型逃逸 (跟 v2.7.6 联合)
echo "Checking any type escapes..."
grep -rn ": any" src/ --include="*.ts" --include="*.tsx"

# 5. v3.x 新增: 检测 KPI 估数 (跟 Rule 9 联合, 跟"反讽" 联合 治根)
echo "Checking KPI estimates..."
grep -rn "around\|approximately\|roughly\|估计\|PARTIAL" --include="*.md" .

# 6. v3.x 新增: 检测 U-002 留待 (跟 v3.1.0 联合, 跟"反讽" 联合 治根)
echo "Checking U-002 deferred..."
grep -rn "留待主公\|留 v3\." --include="*.md" .

# 7. v3.x 新增: 5-Level 自动跑 (跟 v3.0.0 武器 2 联合)
echo "Running 5-Level checks..."
bash level-1.sh
bash level-2.sh
bash level-3.sh
bash level-4.sh
bash level-5.sh

echo "✅ v3.x Hallucination detection complete"
```

---

## 6. v3.x 验证失败处理 (跟 v2.7.6 联合, 跟 v3.0.0 联合, 跟"反讽" 联合)

### 6.1 v3.x 失败分级 (跟 v2.7.6 联合, 跟 v3.0.0 联合, 跟"反讽" 联合)

```yaml
# v3.x 失败分级 (跟 v2.7.6 联合, 跟 v3.0.0 联合)
verification_failure_levels:
  # 严重: 必须修复才能继续 (跟 v2.7.6 联合)
  critical:
    - phantom_file              # Level 1
    - build_failure              # Level 3
    - test_failure               # Level 4
    - u002_deferred              # Level 5 (v3.x 新增, 跟"反讽" 联合)
    - scope_creep                # Level 5 (v3.x 新增)
    - kpi_estimate               # Level 5 (v3.x 新增, 跟 Rule 9 联合)
    action: reject_pr

  # 警告: 需要解释或修复 (跟 v2.7.6 联合)
  warning:
    - low_coverage               # Level 4
    - todo_in_non_critical       # Level 2
    - any_type_usage             # Level 3
    action: request_explanation

  # 信息: 建议改进 (跟 v2.7.6 联合)
  info:
    - code_style
    - naming_convention
    action: comment_only
```

### 6.2 v3.x 失败反馈模板 (跟 v2.7.6 联合, 跟 v3.0.0 联合, 跟"反讽" 联合)

```markdown
## v3.x PR Review: Request Changes (跟 v2.7.6 联合, 跟 v3.0.0 联合, 跟"反讽" 联合)

**Task**: TASK-001
**Reason**: Verification failed at Level 5 (边界验证, v3.x 新增)

### Failures

#### ❌ U-002 留待 (v3.x 新增, 跟"反讽" 联合 治根)
```
docs/architecture/_DEPRECATED.md:20
  留待主公拍 explicit 拍板
```

**治根 (跟"反讽" 联合)**:
- 写 `docs/architecture/U-002-DECISION-MATRIX.md`
- 列 4 候选 A/B/C 决策矩阵
- 留主公 explicit 拍板, Performer 不擅自决策

#### ❌ Scope Creep (v3.x 新增, 跟 Rule 9c 联合)
```
check-scope-creep.sh:106
  TICKET file_scope.includes 越界
```

#### ❌ KPI 估数 (v3.x 新增, 跟 Rule 9 联合, 跟"反讽" 联合 治根)
```
docs/CHANGELOG.md:18
  M1 ~60-70% (估数)
```

**治根 (跟 v3.0.0 联合, 跟"反讽" 联合)**:
- 改用精确 X/Y 格式 (跟 Rule 9 联合)
- 拒绝估数 / around / approximately / roughly / 估计

### Required Actions

1. 写 U-002-DECISION-MATRIX.md 治根留待
2. 修复 scope creep 越界
3. 改 KPI 估数 → 精确 X/Y
4. Re-run 5-Level + 6 武器, 提供 raw stdout

### Re-verification

After fixes, I will re-run:
```bash
kallax verify:existence TASK-001   # Level 1
kallax verify:substance TASK-001   # Level 2
kallax verify:wiring TASK-001      # Level 3
kallax verify:dataflow TASK-001    # Level 4
kallax verify:boundary TASK-001    # Level 5 (v3.x 新增)
```

Please update the PR and request re-review.
```

---

## 7. v3.x 配置参考 (跟 v2.7.6 联合, 跟 v3.0.0 联合, 跟"反讽" 联合)

```yaml
# .kallax/config.yml (v3.x, 跟 v2.7.6 联合, 跟 v3.0.0 武器 2 联合)
verification:
  # v3.x: 启用的验证级别 (跟 v2.7.6 4-Level 升级)
  enabled_levels:
    - existence
    - substance
    - wiring
    - dataflow
    - boundary                  # v3.x 新增 (跟 v3.0.0 联合)

  # v3.x: 严格模式 (跟 v2.7.6 联合)
  strict_mode: true

  # 覆盖率阈值 (跟 v2.7.6 联合)
  coverage_threshold: 80

  # 允许的 TODO 位置 (跟 v2.7.6 联合)
  allowed_todo_paths:
    - "docs/**"
    - "scripts/**"

  # 自动化验证 (跟 v2.7.6 联合)
  auto_verify_on_pr: true

  # v3.x: 边界验证 (跟 v3.0.0 联合, 跟"反讽" 联合)
  boundary:
    scope_creep_check: true
    u002_decision_matrix_required: true  # 跟 v3.1.0 联合, 跟"反讽" 联合 治根
    kpi_estimate_check: true             # 跟 Rule 9 联合, 跟"反讽" 联合 治根
    anti_patterns_check: true            # 跟 v2.7.4 8 Gap 联合
    epic_4piece_check: true              # 跟 v3.1.0 武器 4 联合

  # 幻觉检测 (跟 v2.7.6 联合)
  hallucination_detection:
    enabled: true
    patterns_file: ".kallax/hallucination-patterns.yaml"
    boundary_patterns: true             # v3.x 新增

  # 证据存储 (跟 v2.7.6 联合)
  evidence_storage:
    enabled: true
    path: ".kallax/evidence/"
    retention_days: 90
```

---

## 8. v3.x 最佳实践 (跟 v2.7.6 联合, 跟 v3.0.0 联合, 跟"反讽" 联合)

### 8.1 v3.x Performer 提交前自检 (跟 v2.7.6 联合, 跟 v3.0.0 联合, 跟"反讽" 联合)

```bash
# v3.x: Performer 提交 PR 前运行 5-Level + 6 武器 (跟 v3.0.0 联合)
kallax self-check --level 5 --weapons 6

# 输出 (跟 v2.7.6 联合, 跟 v3.0.0 联合):
# Self-check for TASK-001
#
# ✅ Level 1: All declared files exist
# ✅ Level 2: No stub code detected
# ✅ Level 3: Build successful
# ✅ Level 4: All tests pass (15/15)
# ✅ Level 5: Boundary verified (scope creep 0, U-002 0, KPI 估数 0)
#
# 武器 1 Hash-Chain: ✅
# 武器 2 5-Level: ✅
# 武器 3 Sub-Role: ✅
# 武器 4 EPIC 4 件套: ✅
# 武器 5 Hook Replay: ✅
# 武器 6 Dashboard: ✅
#
# Ready for PR submission!
```

### 8.2 v3.x Conductor 验证清单 (跟 v2.7.6 联合, 跟 v3.0.0 联合)

```markdown
## v3.x PR Review Checklist (跟 v2.7.6 联合, 跟 v3.0.0 联合)

### Automated Verification
- [ ] CI pipeline green
- [ ] 5-Level verification passed (跟 v3.0.0 武器 2 联合)
- [ ] 6 武器 passed (跟 v3.0.0 联合)
- [ ] A+B Review passed (跟 v3.1.0 16 hotfix 联合)

### Manual Review
- [ ] Logic correctness
- [ ] Security considerations
- [ ] Performance implications
- [ ] Error handling
- [ ] Edge cases
- [ ] v3.x 新增: U-002 决策矩阵 (主公拍 explicit)

### Evidence Collected
- [ ] Build log saved
- [ ] Test output saved
- [ ] Coverage report saved
- [ ] 5-Level stdout saved (v3.x 新增)
- [ ] 6 武器 SHA saved (v3.x 新增)
- [ ] A+B Review report saved (v3.x 新增)
- [ ] Code review notes documented
```

### 8.3 v3.x 持续改进 (跟 v2.7.6 联合, 跟"反讽" 联合)

```yaml
# v3.x 每月回顾 (跟 v2.7.6 联合, 跟"反讽" 联合)
monthly_review:
  - 统计幻觉检出率
  - 分析漏检案例
  - 更新检测模式
  - 优化验证流程
  - v3.x 新增: U-002 决策累计
  - v3.x 新增: 5-Level 通过率
  - v3.x 新增: 6 武器 通过率
```

---

**跟主公 2026-06-30 拍 C 重写 explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"反哺框架" 战略 一致, 跟"翻篇&精进" 战略 一致, 跟"流程逻辑 > 扩充配置" 战略 一致, 跟 v3.0.0 6 武器 累计 联合, 跟 v3.1.0 16 hotfix 累计 联合, 跟 v3.2.0 rtk/caveman 累计 联合**
