# KALLAX 项目结构 (v2.0.0, 跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)

> 跟主公 §1 拍板 联合, 跟"诚实修正" 联合, 跟"翻篇&精进" 战略 一致.

## 3 库分离 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合)

| 库 | 路径 | 职责 |
|---|---|---|
| **文档库** | `docs/` | 设计文档 / 决策记录 / 经验教训 / 索引 |
| **Ticket 库** | `jira/` | EPIC / Ticket / Sub-task |
| **代码库** | `scripts/` + `node/` + `rust/` | 实现代码 + 工具脚本 + 引擎 |

## 边界规则 (跟"反讽" 联合, 跟"流程逻辑" 战略 一致)

- ❌ 文档 不可 引用 代码具体行号 (跨 release 失效) — 引用 文件名 + 路径
- ❌ Ticket 不可 改 文档 (跟 1 文件 1 改 联合)
- ❌ 代码 不可 写 决策 (跟"独立" 拍 explicit 约束 联合, 决策归 `confluence/decisions/`)
- ✅ **任何库** 都可引用 **其他库** (单向引用, 不双向写)

## 消息队列 (跟"反讽" 联合, 跟"独立" 拍 explicit 约束 联合, 跟 Rule 17 联合)

| 路径 | 用途 | 协议 |
|---|---|---|
| `.kallax/queue/inbox/<role>_<id>/` | Conductor 收 Performer 报 PASS | JSON + atomic write |
| `.kallax/queue/outbox/<role>_<id>/` | Performer 报 Conductor 派单 | JSON + atomic write |
| `.kallax/inbox/human_feedback/` | 主公 反馈 | Markdown |
| `.kallax/queue/dispatch/` | Conductor 派单 | JSON ticket manifest |
| `.kallax/queue/results/` | Performer 报 结果 | JSON {pass/fail, output, evidence} |

## 协议 (跟"反讽" 联合, 跟 Rule 17 联合)

- **写**: atomic write (写 `<file>.tmp.<pid>` → 校验 → `mv` 替换)
- **读**: 走 0 副作用 (read-only, 不 lock)
- **轮转**: `scripts/kallax-queue-rotate.sh` 每日轮转 (7 天前)
- **失败**: 失败重试 3 次 + 报错 + ticket status 同步 (跟 Rule 16 联合)

## 跟"反讽" 闭环 (跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟"翻篇&精进" 战略 一致)

- ✅ 23 Rule 累计 0 增 (跟 Rule 32 软约束升级阈值 联合, 跟"流程逻辑" 战略 一致)
- ✅ 0 重构 (跟 Rule 5 DRY 联合, 跟"翻篇&精进" 战略 一致)
- ✅ 边界明文化 (跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合)

---

**跟主公 §1 explicit 拍板 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合, 跟 Rule 17 联合, 跟"流程逻辑 > 扩充配置" 战略 一致**