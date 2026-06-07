# KALLAX Expert Index — 症状决策树

> 决策目标: 3 秒从症状定位到 expert.
> 设计哲学: 用户语言优先 (不掺技术 jargon).

## How to Use This Index

1. 找最像的**症状** (不是关键词) — 不知道"接口"是不是"系统实现"不用纠结
2. 看 **2-Group 位置** 决定 review 优先级 (A=可行性, B=攻击)
3. 实在不像任何行 → 走 master 仲裁 (out of scope for this index)

## Decision Tree (10 行)

| 症状 | 角色 | 典型 Ticket | 2-Group 位置 | emoji |
|------|------|-------------|--------------|-------|
| 接口慢 / DB 撑不住 / 缓存击穿 / N+1 查询 | 💻 后端 | EPIC-016-B | A | 💻 |
| 页面卡 / 组件乱 / 构建报错 / LCP > 4s | 🎨 前端 | EPIC-016-C | B | 🎨 |
| 架构边界模糊 / 选型争议 / 模块拆分 | 🏗️ 架构 | EPIC-016-D | A | 🏗️ |
| 功能优先级 / 砍哪个 / MVP 取舍 / ROI 评估 | 📋 产品 | EPIC-016-E | A | 📋 |
| 交互难用 / 流程不顺 / 认知负荷 / 文案不清 | 🖌️ UX | EPIC-016-F | B | 🖌️ |
| 路径穿越 / 注入 / 认证绕过 / 竞态 / fd 泄漏 | 🛡️ 安全 | EPIC-018-* | B | 🛡️ |
| 任务规划 / 跨 ticket 协调 / 风险确保 | 🧭 PM | EPIC-022-* | A | 🧭 |
| 部署失败 / CI 红 / 监控告警 / 镜像问题 | 🔧 DevOps | (预留) | A | 🔧 |
| 流水线慢 / 指标异常 / 数据漂移 / 报表错 | 📊 Data | (预留) | A | 📊 |
| 覆盖率不足 / e2e 漏场景 / 边界用例 | 🧪 Test | (预留) | A | 🧪 |

### 场景示例

- 💻 Backend: "用户列表接口 P99 2s+, 看 psql slow log 是 N+1"
- 🎨 Frontend: "首屏 LCP > 4s, Chrome DevTools 看 LCP element 是大图"
- 🏗️ Architect: "新加 feature flag 库选 LaunchDarkly vs 自研"
- 📋 Product: "v2.0 砍监控还是砍导出? 用户调研显示监控留存率 80% vs 导出 60%"
- 🖌️ UX: "新用户 onboarding 第 3 步流失率 60%, Hotjar 看是文案不清"
- 🛡️ Security: "`rm -rf /tmp/$instance` 没 sanitization, 跨实例误杀"
- 🧭 PM: "EPIC-022 跨 5 个 ticket, 谁先谁后? 哪个阻塞哪个?"
- 🔧 DevOps: "k8s pod 启动失败, image pull backoff"
- 📊 Data: "ClickHouse 慢查询, 看 EXPLAIN 是全表扫"
- 🧪 Test: "支付链路 e2e 漏了退款场景, 生产事故"

## When Not Sure

症状对不上 10 行中的任意一行? 三种处理:

1. **症状模糊**: 从 7 个核心里选最像的, 错比漏好
2. **症状多维度**: 走 master 仲裁 (e.g. "接口慢 + 部署失败" = Backend + DevOps)
3. **新症状**: 创建 `jira/tickets/EPIC-XXX/` 时, 在 `expert.yaml` 的 `assigned_expert` 字段标注