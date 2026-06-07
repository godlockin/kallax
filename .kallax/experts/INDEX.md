# KALLAX Expert Index — 症状决策树

> 决策目标: 3 秒从症状定位到 expert.
> 设计哲学: **用户语言优先** (不掺技术 jargon, 不引用排查工具, 不引用具体 SLO 数字).
> 修复 (A+B review): 去掉 jargon / 移除"错比漏好" / 解决接口歧义 / 补 Data 行 / 消除 UX/PM 流程重叠 / 多维度兜底 / 预留标记.

## How to Use This Index

1. 找最像的**症状** (用户能感知的结果, 不是技术根因)
2. 看 **2-Group 位置** 决定 review 优先级 (A=可行性, B=攻击)
3. 实在不像任何行 → 走 master 仲裁 (out of scope for this index)
4. 症状模糊 → 在 `tickets/<EPIC>/expert.yaml` 标 `[待确认]`, master 复核

## Decision Tree (10 行)

| 症状 | 角色 | 典型 Ticket | 2-Group | emoji |
|------|------|-------------|---------|-------|
| 接口响应慢 / 列表加载要等好几秒 / 一查就卡 | 💻 后端 | EPIC-016-B | A | 💻 |
| 页面卡顿 / 打开要等很久 / 组件错位 | 🎨 前端 | EPIC-016-C | B | 🎨 |
| 架构选型争议 / 模块边界不清 / 抽象层缺失 | 🏗️ 架构 | EPIC-016-D | A | 🏗️ |
| 功能该不该做 / 砍哪个 / 优先级分歧 | 📋 产品 | EPIC-016-E | A | 📋 |
| 界面操作不顺 / 文案看不懂 / 按钮找不到 | 🖌️ UX | EPIC-016-F | B | 🖌️ |
| 能看别人数据 / 没登录却能操作 / 突然被登出 | 🛡️ 安全 | EPIC-018-* | B | 🛡️ |
| 跨 ticket 协调 / 谁先谁后 / 阻塞链路 | 🧭 PM | EPIC-022-* | A | 🧭 |
| 部署失败 / CI 红 / 监控告警 * | 🔧 DevOps* | (预留) | A | 🔧 |
| 数据不一致 / 报表错 / 指标异常 / 流水线慢 * | 📊 Data* | (预留) | A | 📊 |
| 测试漏场景 / e2e 漏检 / 边界用例没覆盖 * | 🧪 Test* | (预留) | A | 🧪 |

`*` = 治理预留, 暂不可选 (走 master 仲裁或新建 EPIC-023/024/025)

### 场景示例 (避开具体生产数字)

- 💻 Backend: "用户列表打开要等好几秒, 客户投诉"
- 🎨 Frontend: "首屏打开要等很久, 客户反馈图片加载慢"
- 🏗️ Architect: "新加 feature flag 库选哪个, 团队没共识"
- 📋 Product: "v2.0 砍监控还是砍导出? 调研显示监控留存更高"
- 🖌️ UX: "新用户 onboarding 第 3 步流失率高, 用户反馈看不懂"
- 🛡️ 安全: "一个实例误操作导致其他实例也崩了"
- 🧭 PM: "EPIC-022 跨 5 个 ticket, 谁先谁后?"
- 🔧 DevOps*: "服务起不来, 拉镜像一直失败"
- 📊 Data*: "报表数字跟实际对不上"
- 🧪 Test*: "支付链路漏了退款场景, 生产出事故"

## When Not Sure

症状对不上 10 行中的任意一行? **四种处理**:

1. **症状模糊** (匹配 1 行但不确定): 不要猜. 在 `tickets/<EPIC>/expert.yaml` 的 `assigned_expert` 字段标 `[待确认]`, 让 master 复核. master 看完后, 在 `expert.md` 文件加 `tickets_served` 记录
2. **症状多维度** (匹配 2+ 行): 在多行后都标 `[并行]`, master 按维度分派. e.g. "接口慢 + 部署失败" = Backend + DevOps 并行评审
3. **新症状** (10 行无任何匹配): 创建 `jira/tickets/EPIC-XXX/`, 在 `expert.yaml` 的 `assigned_expert` 字段标注新角色. master 会创建对应 persona 文件
4. **预留角色** (用户想选 DevOps/Data/Test): 这些是治理预留, **暂不可选**. 走 master 仲裁, 或纳入 EPIC-023/024/025 后再启用

## 边界规则 (避免误派)

- **接口性能问题** → 💻 Backend (运行时慢). **接口设计问题** → 🏗️ Architect (抽象层)
- **界面交互流程** → 🖌️ UX (UI 步骤). **跨团队协作流程** → 🧭 PM (依赖协调)
- **数据不一致** → 📊 Data (留待 EPIC-024). 当前可先标 `[待确认]` 给 master
- **"PM 一下"** 通常指产品决策 → 📋 Product, 不是 🧭 PM (PM 是协调, 不是产品)

## 维护

- Symptom 关键词每 2 周 review (master 主导, 增删症状)
- "预留" 角色启用条件: 激活率 > 5% (用 EPIC-021-F expert_invocations 数据)
- 新角色加入: 更新此 INDEX + 建对应 `experts/default/<role>.md`
