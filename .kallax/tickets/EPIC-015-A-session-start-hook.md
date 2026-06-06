# EPIC-015-A: session_start.sh + Hook 注册

**Priority**: P0 | **Estimate**: 2d | **Status**: pending
**Assignee**: unassigned | **Branch**: feature/epic-015-a

## 背景
新 session 启动时缺乏自动化身份初始化。instance_config.yml 全 null，agent 不知道自己的角色、instance_id、工作目录。

## 交付物

### 1.1 session_start.sh (~80 行 Bash)
- 路径: `.kallax/hooks/session_start.sh`
- 功能:
  1. 检测/生成 instance_id (格式: `{role}_{hostname}_{pid}`)
  2. 创建 `.kallax/instances/<id>/state.json` 并写入初始状态
  3. 输出 ASCII Card 首屏 (role, instance, branch, team count, inbox, next action)
  4. 检测 role (从 git branch 或环境变量)
  5. 创建必要的目录结构 (.kallax/instances/<id>/, .kallax/queue/inbox/<id>/)
- 约束: 纯 Bash，无外部依赖，`bash -n` 语法检查通过
- 验收: dry-run 输出完整的 ASCII Card

### 1.2 settings.json Hook 注册
- 路径: `.claude/settings.json`
- 在 SessionStart hook 中注册 session_start.sh
- 配置 `not-blocking: true` (失败仅 stderr，不阻塞 session)
- 验收: 新 session 启动时自动触发

## 架构原则
- 治理层 (Shell): 身份注册、目录初始化、状态写入
- 智能层 (LLM): 读取状态、做决策、分配任务
- instance_id 唯一标识，心跳由后台脚本维护
- 不依赖大模型可用性

## 验收标准
- [ ] `bash -n .kallax/hooks/session_start.sh` 通过
- [ ] 新 session 启动自动触发 hook
- [ ] state.json 包含完整的 instance_id/role/status/heartbeat 字段
- [ ] ASCII Card 输出格式正确
- [ ] Hook 失败不阻塞 session 启动
