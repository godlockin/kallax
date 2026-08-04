# KALLAX 贡献指南

感谢你对 KALLAX 项目的兴趣！本文档将帮助你了解如何为项目做出贡献。

---

## 行为准则

- 保持友善和尊重
- 建设性地提出反馈
- 接受建设性批评
- 关注最佳实践而非个人偏好

---

## 开发环境

### 前置要求

- Node.js >= 20.0.0
- Rust >= 1.75.0
- Git >= 2.30.0
- (可选) Redis >= 7.0

### 安装

```bash
# 克隆仓库
git clone https://github.com/godlockin/kallax.git
cd kallax

# 安装依赖
npm install
cd rust && cargo build

# 运行测试
npm test
cargo test
```

---

## 分支策略

```
feature/* → testing → main → miao
```

- **feature/***: 功能开发分支
- **testing**: 集成测试分支
- **main**: 稳定版本
- **miao**: 生产发布

### 创建分支

```bash
# 从 main 创建功能分支
git checkout main
git pull origin main
git checkout -b feature/TASK-XXX-short-description
```

---

## Commit 规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
type(scope): subject [TASK-XXX]

body (optional)

footer (optional)
```

### 类型

| 类型 | 说明 |
|------|------|
| feat | 新功能 |
| fix | 缺陷修复 |
| docs | 文档更新 |
| style | 代码格式 |
| refactor | 重构 |
| perf | 性能优化 |
| test | 测试 |
| chore | 杂项 |

### 示例

```
feat(auth): implement login form [TASK-001]

- Add LoginForm component
- Add useAuth hook
- Add auth service

Closes #1
```

---

## Pull Request 流程

### 1. 创建 PR

- 填写 PR 模板
- 关联 Ticket
- 添加测试输出

### 2. 代码审查

- 等待 Conductor 审查
- 响应审查意见
- 推送修改

### 3. 合并

- CI 必须通过
- 至少 1 个 Approval
- 所有讨论已解决

---

## 代码规范

### TypeScript

```typescript
// ✅ 正确
function process(data: unknown): Result<Data, Error> {
  if (!isValid(data)) {
    return err(new ValidationError());
  }
  return ok(transform(data));
}

// ❌ 错误
function process(data: any): any {
  // @ts-ignore
  return data.foo;
}
```

### Rust

```rust
// ✅ 正确
fn process(data: &str) -> Result<Data, KallaxError> {
    let parsed = parse(data)
        .map_err(|e| KallaxError::Parse { source: e })?;
    Ok(parsed)
}

// ❌ 错误
fn process(data: &str) -> Data {
    parse(data).expect("should not fail")
}
```

### 禁止清单

- [ ] 禁止 `any` 类型
- [ ] 禁止 `@ts-ignore`
- [ ] 禁止 `expect()`/`unwrap()`
- [ ] 禁止 `console.log`
- [ ] 禁止空 catch 块
- [ ] 禁止 magic number

---

## 测试要求

### 单元测试

```bash
# Node.js
npm test

# Rust
cargo test
```

### 测试覆盖率

- 新代码必须有测试
- 核心逻辑覆盖率 > 80%

### 测试质量

- 测试必须导入源码（不可内联实现）
- 测试必须验证真实行为

---

## 文档

### 代码注释

- 仅在必要时添加
- 解释"为什么"而非"是什么"

### 文档更新

- 新功能需要文档
- API 变更需要更新文档

---

## 报告问题

### Bug 报告

请包含：
- 复现步骤
- 预期行为
- 实际行为
- 环境信息

### 功能请求

请包含：
- 问题描述
- 建议方案
- 备选方案

---

## Security Rules

### Private Context

Before committing, run the private context scanner:

```bash
bash scripts/check-private-context.sh
```

This checks for:
- Credentials (api_key, token, password, secret)
- Private paths (/Users/*/, ~/.local/, /tmp/claude-tasks/)
- Raw logs (>1MB .log/.jsonl files)
- Sub-agent prompts

**Never commit**: credentials, tokens, local paths, raw logs, or agent prompts.

---

## 获取帮助

- 查看 [文档](./docs/)
- 搜索 [Issues](https://github.com/godlockin/kallax/issues)
- 提问 [Discussions](https://github.com/godlockin/kallax/discussions)

---

感谢你的贡献！
