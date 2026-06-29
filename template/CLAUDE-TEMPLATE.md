# [项目名称] - CLAUDE.md

> 基于 KALLAX 框架的 AI Agent 协作配置
> 
> 生成日期: YYYY-MM-DD

---

## 身份确认

**进入项目后首先确认角色:**

```bash
# 检查当前角色
kallax whoami

# 或手动启动
/kallax-start
```

| 角色 | Conductor | Performer |
|-----|-----------|-----------|
| 职责 | 分析/拆解/审核/合并 | 领取/开发/测试/提交 |
| 分支权限 | main ✅ feature ❌ | feature ✅ main ❌ |
| 规则文档 | CONDUCTOR-RULES.md | PERFORMER-RULES.md |

---

## 项目概述

<!-- TODO: 填写项目信息 -->

**项目名称**: [项目名称]

**项目描述**: [简要描述项目目的和功能]

**技术栈**:
- 语言: [TypeScript/Rust/Python/...]
- 框架: [React/Express/Axum/...]
- 数据库: [PostgreSQL/SQLite/...]
- 其他: [Redis/...]

---

## 目录结构

```
[项目根目录]/
├── confluence/          # 知识库
│   ├── memory/          # 长期记忆
│   └── decisions/       # 架构决策
├── jira/                # 任务管理
│   ├── epics/           # 史诗需求
│   ├── tickets/         # 可执行票据
│   └── inbox/           # 输入队列
├── src/                 # 源代码
├── tests/               # 测试代码
├── docs/                # 文档
│   └── CONDUCTOR-RULES.md
│   └── PERFORMER-RULES.md
│   └── ANTI-PATTERNS.md
└── .kallax/             # KALLAX 配置
    └── config.yml
```

---

## 核心原则 (P0)

### 1. 并行隔离强制

```bash
# ✅ 领取任务时自动创建 worktree
kallax task:claim TASK-001

# ✅ 派发前检查文件范围
kallax isolation:check TASK-001 TASK-002
```

**红线**:
- 每个 Performer 必须在独立 worktree 工作
- 文件范围不得重叠

### 2. 错误处理严格

```typescript
// ❌ 禁止
let result = operation().expect("should work");
function process(data: any): any { }

// ✅ 强制
let result = operation().map_err(|e| Error::from(e))?;
function process(data: unknown): Result<Data, Error> { }
```

**红线**:
- 生产代码禁用 `expect()`/`unwrap()`/`panic!()`
- 禁用 `any` 类型和 `@ts-ignore`

### 3. 产出验证机制

```bash
# Conductor 验证 Performer 产出
kallax verify:all TASK-001
```

**5 levels 验证**:
1. 存在性: 文件确实存在
2. 实质性: 非 stub 代码
3. 接线: 编译/lint 通过
4. 数据流: 测试通过

---

## 命令速查

### 斜杠命令
```bash
/kallax-start           # 启动角色选择
/kallax-claim           # 领取任务
/kallax-status          # 当前状态
/kallax-submit-pr       # 提交 PR
/kallax-review-pr       # 审核 PR
/kallax-help            # 帮助
```

### CLI 命令
```bash
kallax task:claim TASK-NNN      # 领取任务
kallax task:complete TASK-NNN   # 完成任务
kallax conductor:heartbeat      # 心跳检查
kallax system:doctor            # 系统诊断
```

---

## 禁止操作

### Conductor 禁止
- ❌ 编写生产代码
- ❌ 领取任务自己开发
- ❌ 无 CI 绿灯合并
- ❌ 自我审查 PR

### Performer 禁止 (9 条硬规则)
1. ❌ 合并到 main
2. ❌ 审核自己 PR
3. ❌ 跳过测试
4. ❌ magic number
5. ❌ console.log (用 logger)
6. ❌ 忽略 lint 错误
7. ❌ 注释掉代码
8. ❌ 复制粘贴代码
9. ❌ 交叉变更

---

## 详细规则

- [Conductor 规则](docs/CONDUCTOR-RULES.md)
- [Performer 规则](docs/PERFORMER-RULES.md)
- [反模式集合](docs/ANTI-PATTERNS.md)

---

## 项目特定规则

<!-- TODO: 添加项目特定规则 -->

### 代码风格

```typescript
// 示例: 项目特定的代码规范
```

### 测试要求

- 覆盖率要求: [80%]
- E2E 测试: [必须/可选]

### 部署流程

1. [部署步骤]

---

## 联系方式

- Tech Lead: [邮箱/Slack]
- Code Review: @conductor
