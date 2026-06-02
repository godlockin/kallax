# Gate Review 协议

> KALLAX 执行前关卡审查协议 v1.0

---

## 1. 概述

Gate Review 是 KALLAX 的质量关卡机制，确保任务在进入下一阶段前满足所有条件。

### 1.1 设计原则

1. **Fail Fast**: 问题越早发现，修复成本越低
2. **强制执行**: 关卡不可跳过
3. **可追溯**: 所有检查结果记录
4. **自动化**: 尽可能自动化检查

### 1.2 KALLAX 教训

| 问题 | KALLAX | KALLAX 改进 |
|-----|------|------------|
| 票据质量 | 低质量票据流入开发 | 强制 Gate 检查 |
| PR 合并 | 无验证直接合并 | 4-Level 验证 |
| 范围蔓延 | 无边界控制 | file_scope 强制声明 |

---

## 2. 关卡定义

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Gate Review 流程                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  需求输入                                                            │
│      │                                                              │
│      ▼                                                              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Gate 0: 需求质量关卡                                        │   │
│  │  • 需求描述完整                                              │   │
│  │  • 验收标准清晰                                              │   │
│  │  • 优先级已确定                                              │   │
│  └n│      │ 通过                                                        │
│      ▼                                                              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Gate 1: 任务就绪关卡                                        │   │
│  │  • Ticket 信息完整                                           │   │
│  │  • file_scope 已声明                                         │   │
│  │  • 依赖已就绪                                                │   │
│  │  • 无范围重叠                                                │   │
│  └─────────────────────────────────────────────────────────────┘   │
│      │ 通过                                                        │
│      ▼                                                              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Gate 2: 开发完成关卡                                        │   │
│  │  • 代码实现完成                                              │   │
│  │  • 本地测试通过                                              │   │
│  │  • Lint 检查通过                                             │   │
│  │  • 类型检查通过                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│      │ 通过                                                        │
│      ▼                                                              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Gate 3: PR 合并关卡                                         │   │
│  │  • CI 全部通过                                               │   │
│  │  • 4-Level 验证通过                                          │   │
│  │  • Code Review 通过                                          │   │
│  │  • 无未解决讨论                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│      │ 通过                                                        │
│      ▼                                                              │
│  合并到 main                                                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Gate 0: 需求质量关卡

### 3.1 检查项

```yaml
gate0_checks:
  # 必填项检查
  required_fields:
    - title: "需求标题"
    - description: "详细描述"
    - acceptance_criteria: "验收标准"
    - priority: "优先级 (P0-P3)"
    
  # 描述质量
  description_quality:
    - min_length: 100        # 最少 100 字符
    - no_vague_terms: true   # 无模糊用语
    
  # 验收标准质量
  ac_quality:
    - min_items: 2           # 至少 2 条
    - measurable: true       # 可度量
```

### 3.2 验证命令

```bash
# 检查需求质量
kallax gate:check 0 --input inbox/human_input.md

# 输出示例
# Gate 0: 需求质量关卡
# ─────────────────────
# ✅ title: 存在
# ✅ description: 存在 (234 字符)
# ✅ acceptance_criteria: 3 条
# ✅ priority: P1
# 
# Result: PASSED
```

### 3.3 失败处理

```bash
# 失败示例
# Gate 0: 需求质量关卡
# ─────────────────────
# ✅ title: 存在
# ❌ description: 太短 (45 字符 < 100)
# ❌ acceptance_criteria: 缺失
# ✅ priority: P1
# 
# Result: FAILED
# 
# 请补充:
# 1. 完善需求描述 (至少 100 字符)
# 2. 添加验收标准
```

---

## 4. Gate 1: 任务就绪关卡

### 4.1 检查项

```yaml
gate1_checks:
  # Ticket 完整性
  ticket_completeness:
    required:
      - id
      - title
      - description
      - acceptance_criteria
      - priority
      - estimate
      - file_scope
      
  # file_scope 验证
  file_scope_check:
    - includes_not_empty: true
    - valid_glob_patterns: true
    - no_overlap_with_active: true
    
  # 依赖检查
  dependency_check:
    - all_deps_resolved: true    # 依赖已完成
    - no_circular_deps: true     # 无循环依赖
```

### 4.2 验证命令

```bash
# 检查任务就绪状态
kallax gate:check 1 --ticket TASK-001

# 输出示例
# Gate 1: 任务就绪关卡
# ─────────────────────
# ✅ Ticket 完整性: 所有字段已填
# ✅ file_scope: 声明有效
#    - includes: src/components/Login/**
#    - excludes: src/components/shared/**
# ✅ 依赖检查: 无依赖
# ✅ 隔离检查: 无活动任务重叠
# 
# Result: PASSED
```

### 4.3 隔离检查详情

```bash
# 检查与现有任务的文件范围重叠
kallax isolation:check TASK-001

# 输出示例 (无冲突)
# 隔离检查: TASK-001
# ──────────────────
# TASK-001 scope: src/components/Login/**
# 
# Active tasks:
#   TASK-002: src/components/Dashboard/** - No overlap ✅
#   TASK-003: src/hooks/useData.ts - No overlap ✅
# 
# Result: No conflicts

# 输出示例 (有冲突)
# ⚠️  Conflict detected!
# 
# TASK-001 scope: src/components/Login/**
# TASK-004 scope: src/components/Login/LoginButton.tsx
# 
# Overlapping files:
#   - src/components/Login/LoginButton.tsx
# 
# Suggested resolution:
#   Option 1: Wait for TASK-004 to complete
#   Option 2: Remove overlap from TASK-001 scope
```

---

## 5. Gate 2: 开发完成关卡

### 5.1 检查项

```yaml
gate2_checks:
  # 代码检查
  code_quality:
    - no_any_types: true
    - no_ts_ignore: true
    - no_console_log: true
    - no_todo_in_critical: true
    
  # 测试检查
  test_quality:
    - tests_exist: true
    - tests_pass: true
    - coverage_threshold: 80
    
  # 静态分析
  static_analysis:
    - lint_pass: true
    - type_check_pass: true
    - build_pass: true
    
  # 范围检查
  scope_compliance:
    - only_declared_files: true   # 只修改声明范围的文件
```

### 5.2 验证命令

```bash
# 在 worktree 中运行
cd .worktrees/TASK-001

# 检查开发完成状态
kallax gate:check 2

# 输出示例
# Gate 2: 开发完成关卡
# ─────────────────────
# 
# Code Quality:
#   ✅ No any types
#   ✅ No @ts-ignore
#   ✅ No console.log
#   ✅ No TODO in critical paths
# 
# Tests:
#   ✅ Tests exist: 12 test files
#   ✅ Tests pass: 45/45
#   ✅ Coverage: 87% (> 80%)
# 
# Static Analysis:
#   ✅ Lint: 0 errors, 0 warnings
#   ✅ Type check: pass
#   ✅ Build: success
# 
# Scope Compliance:
#   ✅ All modified files in declared scope
# 
# Result: PASSED
```

### 5.3 范围合规检查

```bash
# 检查修改的文件是否在声明范围内
kallax scope:verify

# 输出示例 (合规)
# Scope Verification
# ──────────────────
# Declared scope:
#   includes: src/components/Login/**
#   excludes: src/components/shared/**
# 
# Modified files:
#   ✅ src/components/Login/index.tsx
#   ✅ src/components/Login/LoginForm.tsx
#   ✅ src/components/Login/Login.test.tsx
# 
# Result: COMPLIANT

# 输出示例 (违规)
# ⚠️  Scope Violation!
# 
# Modified files outside scope:
#   ❌ src/utils/validation.ts (not in includes)
#   ❌ src/components/shared/Button.tsx (in excludes)
# 
# Please:
#   1. Revert changes to files outside scope, OR
#   2. Request scope modification from Conductor
```

---

## 6. Gate 3: PR 合并关卡

### 6.1 检查项

```yaml
gate3_checks:
  # CI 状态
  ci_status:
    - all_checks_pass: true
    - no_required_check_pending: true
    
  # 4-Level 验证
  verification:
    - level1_existence: true
    - level2_substance: true
    - level3_wiring: true
    - level4_dataflow: true
    
  # Review 状态
  review_status:
    - has_approval: true
    - no_changes_requested: true
    - all_threads_resolved: true
    
  # 合并冲突
  merge_status:
    - no_conflicts: true
    - up_to_date_with_base: true
```

### 6.2 验证命令

```bash
# Conductor 执行合并前检查
kallax gate:check 3 --pr 42

# 输出示例
# Gate 3: PR 合并关卡
# ─────────────────────
# 
# CI Status:
#   ✅ build: pass
#   ✅ test: pass
#   ✅ lint: pass
#   ✅ type-check: pass
# 
# 4-Level Verification:
#   ✅ Level 1: Existence - all files present
#   ✅ Level 2: Substance - no stubs detected
#   ✅ Level 3: Wiring - build successful
#   ✅ Level 4: Data Flow - tests pass
# 
# Review Status:
#   ✅ Approvals: 1 (conductor)
#   ✅ No changes requested
#   ✅ All 3 threads resolved
# 
# Merge Status:
#   ✅ No conflicts
#   ✅ Up to date with main
# 
# Result: READY TO MERGE
```

---

## 7. 自动化配置

### 7.1 CI/CD 集成

```yaml
# .github/workflows/gate-check.yml
name: Gate Checks

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  gate2:
    name: Gate 2 - Development Complete
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup
        run: npm ci
        
      - name: Code Quality Check
        run: |
          # No any types
          ! grep -r ": any" src/ || exit 1
          # No console.log
          ! grep -r "console.log" src/ || exit 1
          # No @ts-ignore
          ! grep -r "@ts-ignore" src/ || exit 1
          
      - name: Lint
        run: npm run lint
        
      - name: Type Check
        run: npm run type-check
        
      - name: Build
        run: npm run build
        
      - name: Test
        run: npm test -- --coverage
        
      - name: Coverage Check
        run: |
          COVERAGE=$(jq '.total.lines.pct' coverage/coverage-summary.json)
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80%"
            exit 1
          fi
```

### 7.2 Git Hooks

```bash
# .husky/pre-commit
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

# 快速 Gate 2 检查
npm run lint-staged

# 范围合规检查
kallax scope:verify --staged
```

### 7.3 PR 模板

```markdown
<!-- .github/pull_request_template.md -->
- [ ] 无 @ts-ignore
- [ ] 无 console.log
- [ ] 测试通过
- [ ] 覆盖率 ≥ 80%
- [ ] Lint 通过
- [ ] 类型检查通过
- [ ] 只修改了声明范围内的文件

### 测试输出
```
[粘贴 npm test 输出]
```

### 截图 (如适用)
[UI 变更截图]
```

---

## 8. 手动覆盖

### 8.1 覆盖流程

某些情况下可能需要跳过 Gate 检查:

```bash
# 紧急修复场景
kallax gate:override --gate 3 --pr 42 --reason "P0 hotfix" --approver conductor_001

# 记录覆盖
# Gate Override Log
# ─────────────────
# Gate: 3
# PR: 42
# Reason: P0 hotfix
# Approver: conductor_001
# Time: 2024-01-15T14:30:00Z
# 
# Skipped checks:
#   - coverage_threshold (actual: 65%, required: 80%)
# 
# ⚠️  Manual override applied. Ensure follow-up ticket created.
```

### 8.2 覆盖限制

```yaml
override_policy:
  # 只有 Conductor 可以覆盖
  allowed_roles:
    - conductor
    
  # 必须提供理由
  require_reason: true
  
  # 必须记录
  audit_log: true
  
  # 不可覆盖的检查
  non_overridable:
    - ci_build_pass      # 构建必须通过
    - no_security_vulns  # 安全漏洞不可跳过
```

---

## 9. 报告与统计

### 9.1 Gate 通过率报告

```bash
# 查看 Gate 统计
kallax gate:stats --last 30d

# Gate Statistics (Last 30 Days)
# ───────────────────────────────
# 
# Gate 0 (需求质量):
#   Total: 45
#   Passed: 42 (93.3%)
#   Failed: 3 (6.7%)
#   Common failures:
#     - Missing AC: 2
#     - Description too short: 1
# 
# Gate 1 (任务就绪):
#   Total: 42
#   Passed: 40 (95.2%)
#   Failed: 2 (4.8%)
#   Common failures:
#     - Scope overlap: 2
# 
# Gate 2 (开发完成):
#   Total: 40
#   Passed: 35 (87.5%)
#   Failed: 5 (12.5%)
#   Common failures:
#     - Low coverage: 3
#     - Lint errors: 2
# 
# Gate 3 (PR 合并):
#   Total: 35
#   Passed: 34 (97.1%)
#   Failed: 1 (2.9%)
#   Common failures:
#     - Pending review: 1
```

### 9.2 趋势分析

```bash
# 查看趋势
kallax gate:trend --gate 2 --period weekly

# Gate 2 Pass Rate Trend
# ─────────────────────────
# Week 1: ████████████████░░░░ 80%
# Week 2: █████████████████░░░ 85%
# Week 3: ██████████████████░░ 90%
# Week 4: ██████████████████░░ 90%
# 
# Trend: Improving (+10% over 4 weeks)
```

---

## 参考

- [Conductor 规则](CONDUCTOR-RULES.md)
- [Performer 规则](PERFORMER-RULES.md)
- [验证协议](../../docs/architecture/VERIFICATION-PROTOCOL.md)
