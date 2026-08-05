# Smoke Retention Policy (EPIC-174, v3.32.20)

> **来源**: loopx AGENTS.md Smoke Retention Policy (借鉴)
> **拍板**: 主公 2026-08-05 Phase 5 D
> **目的**: 治理 KALLAX smoke 测试膨胀，保持测试套件的健康度

## 背景

Smoke 测试 (冒烟测试) 目的是在 CI 时间预算内快速验证核心功能。
当 smoke 测试膨胀到 5xx+ 行时，它失去了"快速"特性，变成了另一个 integration test。

本 policy 定义 5 条保留规则：只有满足这些条件的测试才应该保留在 smoke 目录。
其他测试应移到 integration 或拆分成更小的单元。

---

## 5 条保留规则

### Rule 1: 保留 shipped CLI/runtime behavior

**定义**: 验证用户直接调用的 CLI 命令或运行时行为的测试。

**示例**:
- `kallax install --dry-run` 输出正确
- `kallax status` 返回有效 JSON
- `./scripts/install.sh` 安装流程正确

**排除**:
- 内部 helper function 测试 (应该单元测试)
- 间接调用多个内部模块的测试

**判定标准**:
```bash
# ✅ 保留: CLI 直接调用
kallax --version
kallax init --force

# ❌ 排除: 间接调用
source ~/.claude/kallax-env.sh && run_internal_func
```

---

### Rule 2: 保留 reusable control-plane contract

**定义**: 验证跨 EPIC 重用的控制平面契约 (API/配置/状态)。

**示例**:
- state.json schema 验证
- ticket.json 4 expert binding 字段存在
- hook 配置格式正确

**排除**:
- 单次 EPIC 使用的临时数据验证
- 业务逻辑的细粒度测试

**判定标准**:
```bash
# ✅ 保留: 跨 EPIC 重用
jq '.expert_binding' ticket.json
test -f ~/.claude/kallax/state.json

# ❌ 排除: 单次使用
grep "EPIC-174" ticket.json | grep "2026-08-05"
```

---

### Rule 3: 保留 public/private boundary enforcement

**定义**: 验证公开 API 和内部实现边界的测试。

**示例**:
- 验证 `--help` 输出格式不变 (公开接口稳定性)
- 验证环境变量前缀 `KALLAX_` 生效
- 验证公开错误码格式

**排除**:
- 内部函数调用的副作用验证
- 私有变量状态的测试

**判定标准**:
```bash
# ✅ 保留: public boundary
kallax --help | grep -q "Usage:"
KALLAX_DEBUG=1 kallax status 2>&1 | grep -q "debug"

# ❌ 排除: private implementation
grep "_internal_cache" src/*.ts
```

---

### Rule 4: 保留 regression that stranded automation

**定义**: 修复了阻止自动化运行问题的回归测试。

**来源**: 真实 CI 失败 / 人工验证失败后创建的测试

**示例**:
- EPIC-158: sqlite skipIf 缺失导致 CI 失败
- EPIC-168-F: daemon 真跑验证

**判定标准**:
```bash
# ✅ 保留: 有 CI failure ticket 背景
# 必有: verification.reproduction_command
# 必有: verification.reproduction_exit_code
# 必有: verification.reproduction_raw_output

# ❌ 排除: 无 regression 背景的测试
# 无 ticket 关联
```

---

### Rule 5: 5xx+ 行 smoke 拆 / aggregate 替代

**定义**: 超过 500 行的 smoke 测试必须拆分或替换为 aggregate 测试。

**阈值**: 500 行硬限制

**处理方式**:
1. **拆分** (优先): 按功能领域拆成多个 <500 行测试
2. **Aggregate**: 用一个汇总测试覆盖多个小场景
3. **迁移**: 移到 `tests/integration/` 目录

**判定标准**:
```bash
# 检测命令 (见 scripts/check-smoke-retention.sh)
find tests/integration/ -name "*-smoke.test.sh" -exec wc -l {} \;

# 告警: 行数 >= 500
```

---

## Pre-existing CI debt 处理

**来源**: loopx AGENTS.md "Pre-existing CI debt" 条款

对于已存在的 >500 行 smoke 测试 (如 CI debt)，处理方式:

1. **登记**: 记录到 `scripts/audit/smoke-size-report.sh` 报告
2. **不阻塞**: 不强制拆分 (避免破坏现有 CI)
3. **逐步治理**: 后续 EPIC 逐步拆分

---

## 目录结构

```
tests/integration/
├── *-smoke.test.sh        # 冒烟测试 (<500 行)
└── *-integration.test.sh  # 集成测试 (无限制)
```

**命名约定**:
- `-smoke.test.sh`: 必须 <500 行
- `-integration.test.sh`: 无限制
- `-regression.test.sh`: 回归测试 (有 ticket 背景)

---

## Scanner 工具

| 工具 | 路径 | 职责 |
|------|------|------|
| `check-smoke-retention.sh` | `scripts/` | 检测 >=500 行 smoke |
| `smoke-size-report.sh` | `scripts/audit/` | 报告当前所有 smoke 状态 |

---

## 引用

- EPIC-174 ticket: `jira/tickets/EPIC-174/ticket.json`
- loopx AGENTS.md Smoke Retention Policy
- EPIC-131/132: scan-dead-code sentinel (exit code 2 = BLOCKED-env)
