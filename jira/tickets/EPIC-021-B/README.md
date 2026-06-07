# EPIC-021-B: experts/INDEX.md 症状决策树 + 10 emoji

## 需求

创建症状决策树 INDEX, 解决 EKET 自己承认的 P0 共识 (UX + Product 都列为 P0). 表格用**症状语言**("接口慢") 而非 EKET 那种**解决方案语言**("系统实现视角"), 3 秒决策目标.

## 接受标准 (AC)

详见 `ticket.json`. 7 条 AC.

## INDEX 表格草图

```markdown
| 症状 | 角色 | 典型 Ticket | 2-Group 位置 | emoji |
|------|------|-------------|--------------|-------|
| 接口慢 / DB 撑不住 / 缓存击穿 | 💻 后端 | EPIC-016-B | A | 💻 |
| 页面卡 / 组件乱 / 构建报错 | 🎨 前端 | EPIC-016-C | B | 🎨 |
| 架构边界 / 选型争议 | 🏗️ 架构 | EPIC-016-D | A | 🏗️ |
| 功能优先级 / 砍哪个 / MVP 取舍 | 📋 产品 | EPIC-016-E | A | 📋 |
| 交互难用 / 流程不顺 / 认知负荷 | 🖌️ UX | EPIC-016-F | B | 🖌️ |
| 路径穿越 / 注入 / 认证绕过 / 竞态 | 🛡️ 安全 | EPIC-018-* | B | 🛡️ |
| 任务规划 / 跨 ticket 协调 / 风险确保 | 🧭 PM | EPIC-022-* | A | 🧭 |
| 部署失败 / CI 红 / 监控告警 | 🔧 DevOps | (预留) | A | 🔧 |
| 流水线慢 / 指标异常 / 数据漂移 | 📊 Data | (预留) | A | 📊 |
| 覆盖率不足 / e2e 漏场景 | 🧪 Test | (预留) | A | 🧪 |

**场景示例** (per row):
- 💻 Backend: "用户列表接口 P99 2s+, 看 psql slow log 是 N+1"
- 🎨 Frontend: "首屏 LCP > 4s, Chrome DevTools 看 LCP element 是大图"
- 🏗️ Architect: "新加 feature flag 库选 LaunchDarkly vs 自研"
- ...
```

## 顶部说明 (3 行)

```markdown
## How to Use This Index

1. 找最像的**症状** (不是关键词) — 不知道"接口"是不是"系统实现"不用纠结
2. 看 **2-Group 位置** 决定 review 优先级 (A=可行性, B=攻击)
3. 实在不像任何行 → 走 master 仲裁 (out of scope for this index)
```

## 底部 Fallback

```markdown
## When Not Sure

症状对不上 10 行中的任意一行? 三种处理:
1. **症状模糊**: 从 7 个核心里选最像的, 错比漏好
2. **症状多维度**: 走 master 仲裁 (e.g. "接口慢 + 部署失败" = Backend + DevOps)
3. **新症状**: 创建 `jira/tickets/EPIC-XXX/` 时, 在 `expert.yaml` 的 `assigned_expert` 字段标注
```

## 10 emoji 含义

**7 核心** (必填, EPIC-021-A 创建对应 persona 文件):
- 🏗️ Architect — 架构边界, 选型
- 💻 Backend — API/DB/性能
- 🎨 Frontend — 组件/性能/可访问
- 🖌️ UX — 体验/旅程/认知
- 📋 Product — 优先级/MVP/北极星
- 🛡️ Security — 系统风险 (合规/法律走外部)
- 🧭 PM — 跨 ticket 规划+ensuring

**3 治理** (预留, EPIC-022/023/024 扩展位):
- 🔧 DevOps — CI/CD/部署/监控
- 📊 Data — 指标/分析/数据流水线
- 🧪 Test — 覆盖率/e2e/集成

## 文件范围

1 个 NEW 文件:
- `.kallax/experts/INDEX.md`

## ⚠️ 阻塞说明

**blocked_by EPIC-021-A**: A 创建 7 个 persona 文件, B 才能在 INDEX 引用它们. 7 行核心必有, 3 行治理是预留.

## 预估工时

0.5 小时 (1 个表格 + 顶部说明 + 底部 fallback + emoji 兼容性测试)

## 2-Group review 期望

- **A 组 (Forward)**: 校验 10 行齐全, 症状描述是否用户语言 (不掺技术 jargon)
- **B 组 (Attack)**: 找 emoji 在 macOS Terminal.app 渲染是否正常, 找症状覆盖是否漏 80% 常见场景, 找 fallback 是否真能用

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 17:00 UTC | ready | master_main | 创建 |
