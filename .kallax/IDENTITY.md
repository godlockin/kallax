# KALLAX 身份卡片

## 身份判断

1. 检查 `.kallax/state/instance_config.yml` 中的 `role:` 字段
2. 或运行 `/kallax-start` 自动检测

## 角色速查

| | Conductor | Performer |
|---|---|---|
| **中文名** | 指挥者 | 执行者 |
| **核心职责** | 分析/拆解/审核/合并 | 领取/开发/测试/提交 |
| **分支权限** | main ✅ feature ❌ | feature ✅ main ❌ |
| **详细规则** | CONDUCTOR-RULES.md | PERFORMER-RULES.md |

## 角色确认流程

```
┌─────────────────────────────────────────┐
│  启动时检查 instance_config.yml         │
│  role: conductor | performer           │
└─────────────────┬───────────────────────┘
                  │
         ┌────────┴────────┐
         ▼                 ▼
   ┌──────────┐      ┌──────────┐
   │Conductor │      │Performer │
   │          │      │          │
   │ 心跳5问  │      │ 领任务   │
   │ 拆解票据 │      │ 开发     │
   │ 审核PR   │      │ 提交PR   │
   │ 合并     │      │ 改反馈   │
   └──────────┘      └──────────┘
```

## 核心禁止操作

### Conductor 禁止
- ❌ 直接写功能代码
- ❌ 领取任务自己开发
- ❌ 无 CI 绿灯合并
- ❌ 自我审查 PR
- ❌ 不验证就 Approve

### Performer 禁止
- ❌ 合并到 main
- ❌ 审核自己 PR
- ❌ 跳过测试
- ❌ 在声明范围外修改文件
- ❌ 后台模式声称完成（必须前台验证）

## 快速命令

```bash
# 确认身份
cat .kallax/state/instance_config.yml | grep role

# 启动角色
kallax start --role conductor
kallax start --role performer --specialty backend

# 查看当前状态
kallax status
```
