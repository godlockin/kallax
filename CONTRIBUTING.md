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

## 加入社区

| 渠道 | 联系方式 | 说明 |
|------|----------|------|
| **GitHub Issues** | [godlockin/kallax/issues](https://github.com/godlockin/kallax/issues) | Bug 报告、功能请求 |
| **GitHub Discussions** | [godlockin/kallax/discussions](https://github.com/godlockin/kallax/discussions) | Q&A、讨论 |
| **Lark 群** | 见 [docs/community/README.md](docs/community/README.md) | Lark 群二维码占位 |
| **WeChat** | huangrt00 | 添加时备注 "KALLAX" |

### Lark 群二维码

> TODO: 扫描下方二维码加入 KALLAX Lark 交流群

```
┌─────────────────────────────┐
│                             │
│    [LARK QR CODE PLACEHOLDER] │
│                             │
│    扫码加入 KALLAX Lark 群   │
│                             │
└─────────────────────────────┘
```

### WeChat 群

添加微信号 `huangrt00`，备注 "KALLAX" 申请加入。

---

## 贡献前检查清单

在提交 PR 之前，请确认：

- [ ] 代码符合 TypeScript/Rust 规范（无 `any`、无 `@ts-ignore`）
- [ ] 已运行 `npm test` 和 `cargo test`（全部通过）
- [ ] 已运行 `bash scripts/scan-dead-code.sh`（退出码 0）
- [ ] 新功能已添加文档
- [ ] API 变更已更新 [docs/reference/](docs/reference/)
- [ ] README 或 CHANGELOG 需要更新（如适用）

---

## 5-Level Verify 贡献者责任

KALLAX 使用 5-Level Verify 确保代码质量。贡献者必须：

1. **L1**: Commit message 包含真实变更（不空提交）
2. **L2**: 测试输出是 raw stdout（非装饰性 "PASS"）
3. **L3**: 4-expert 接线（coder/reviewer/tester/docs）
4. **L4**: 独立验证（跨 subagent）
5. **L5**: check-claim-evidence.sh 扫描

详见 [docs/5-levels.md](docs/5-levels.md)。

---

## Code of Conduct

本项目遵守 [Contributor Covenant](https://www.contributor-covenant.org/) 行为准则。

### 我们的承诺

我们承诺为所有参与者提供友好、安全的环境，无论年龄、体型、肤色、能力、学历、性别认同、经验水平、国籍、个人形象、种族、宗教或性认同和取向。

### 我们的标准

**鼓励的行为**:
- 使用欢迎和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情
- 对其他社区成员表示同理心

**不可接受的行为**:
- 仇恨言论和歧视
- 人身攻击
- 公开或隐性的骚扰
- 未经同意发布他人私人信息
- 其他不道德或不专业的行为

---

## 扫描 Private Context

贡献前请运行：

```bash
bash scripts/check-private-context.sh
```

确保没有以下内容被 staged:
- 凭证（API keys, passwords, tokens）
- 私有路径（`~/.aws/`, `/var/secrets/`）
- Raw logs（完整 stack trace）
- Sub-agent prompts

详见 [docs/public-private-boundary.md](docs/public-private-boundary.md)。

---

## 获取帮助

- 查看 [文档](./docs/)
- 搜索 [Issues](https://github.com/godlockin/kallax/issues)
- 提问 [Discussions](https://github.com/godlockin/kallax/discussions)
- 加入 [Lark 群](docs/community/README.md)
- 添加 WeChat: huangrt00

---

## 社区

加入我们的开发者社区:

- **Lark 群 (飞书)**: [docs/community/lark-qr-placeholder.md](docs/community/lark-qr-placeholder.md)
- **WeChat 群**: [docs/community/wechat-qr-placeholder.md](docs/community/wechat-qr-placeholder.md)
- **社区首页**: [docs/community/README.md](docs/community/README.md)

### 社区准则

- 保持友善和尊重
- 提问前先搜索已有讨论
- 使用问题模板获得更快响应
- 分享你的使用经验，帮助他人

---

感谢你的贡献！
