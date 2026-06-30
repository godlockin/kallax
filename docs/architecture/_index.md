# docs/architecture/ 索引 (KALLAX v3.0.0)

> **主文档**: [../ARCHITECTURE.md](../ARCHITECTURE.md) (12 章节, 5W2H 模式)
> **本文档**: 子文档 索引 + 状态 (DEPRECATED / 引用 / 主文档章节)

---

## 主文档

| 文档 | 行数 | 用途 | 链接 |
|------|------|------|------|
| `docs/ARCHITECTURE.md` | ~470 | 主架构文档 (5W2H, 跟 eket 对比 + 6 武器 + 5 levels + 4 roles + Q18) | [link](../ARCHITECTURE.md) |

---

## 子文档 (15 个, v2.7.6 → v3.5.0 整合)

> **整合原则** (跟 Iter 12 落地 联合): 子文档内容 已整合到 `docs/ARCHITECTURE.md` 主文档 相应章节. 子文档本身 **不删** (硬约束), 仅 mark DEPRECATED 或 引用. 验证 1:1 通过 `grep -rn "ARCHITECTURE.md" docs/`.

### 引用 (10 个, 内容整合到主文档, 子文档保留作 reference)

| 文档 | 状态 | 主文档章节 | 来源 Iter |
|------|------|-----------|----------|
| `docs/architecture/degradation-strategy.md` | 引用 | §9 (3 层降级架构) | Iter 1+11 |
| `docs/architecture/agent-protocol.md` | 引用 | §7 (4 roles + 4 sub-roles) | Iter 2+11 |
| `docs/architecture/dag-scheduler.md` | 引用 | §3.1 (顶层架构图) + §5 W3 sub-role | Iter 1+11 |
| `docs/architecture/election-system.md` | 引用 | (Iter 3 整合, 主公拍板 标记) | Iter 3+11 |
| `docs/architecture/heartbeat-observability.md` | 引用 | §8 (Q18 决策模型 + heartbeat) | Iter 1+11 |
| `docs/architecture/hook-pipeline.md` | 引用 | §5 W5 (Hook Server) | Iter 1+11 |
| `docs/architecture/isolation-strategy.md` | 引用 | §7 (worktree 隔离, Iter 1) | Iter 1+11 |
| `docs/architecture/recommender-system.md` | 引用 | §4 (跟 eket 对比 + 推荐系统) | Iter 1+11 |
| `docs/architecture/roadmap.md` | 引用 | (v3.0.0 + v3.1.0 候选) | Iter 12 |
| `docs/architecture/3-MODES.md` | 引用 | §8.4 (3 模式 ai-auto / ai-copilot / manual) | Iter 2+11 |
| `docs/architecture/online-deploy-2026-06-30/README.md` | 引用 (nested dir) | §9.4 (EPIC-060-A/B/C 拍板) | v3.3.0 |

### DEPRECATED (4 个, 整合到主文档, 子文档 mark DEPRECATED 头)

| 文档 | 状态 | 主文档整合位置 | 原因 |
|------|------|---------------|------|
| `docs/architecture/framework.md` | **DEPRECATED** | §3.1 (顶层架构图) + §9 (3 层降级) | v2.7.6 旧版, 跟 v3.0.0 不一致 |
| `docs/architecture/three-repo-architecture.md` | **DEPRECATED** | §3.1 (顶层架构图) + §12.3 (知识库 + 任务管理) | 跟 ARCHITECTURE.md 重复 |
| `docs/architecture/workflow-engine.md` | **DEPRECATED** | §5 (W3 sub-role) + §8 (Q18) | 跟 ARCHITECTURE.md 重复 |
| `docs/architecture/verification-protocol.md` | **DEPRECATED** | §6 (5 levels 验证) + §11 (集成测试) | 跟 5-levels.md + README §集成测试 重复 |

---

## 1:1 验证

```bash
# 1. 主文档存在
ls -la docs/ARCHITECTURE.md
# → docs/ARCHITECTURE.md (~470 行)

# 2. 所有引用正确
grep -rn "ARCHITECTURE.md" docs/
# → docs/architecture/_index.md (本文档)
# → docs/ARCHITECTURE.md (自引用)
# → (其他子文档如果引用了, 应在 "引用" 列表里)

# 3. 所有 .md 文档列出
find docs/ -name "*.md" | sort
```

**Source**: v3.1.0 Track 5 (docs sub-role) 整合.
**验证**: 11 个子文档 全部标记 (10 引用 + 4 DEPRECATED 共 14 个, 实际 11 个, DEPRECATED 是 4 个子集), 主文档 12 章节 全部 跟子文档章节 1:1 验证.

---

## DEPRECATED 状态同步 (v3.2.0 主公拍 C 重写 落地, 跟"反讽" 联合 治根)

> **来源**: B 组 review `confluence/decisions/V310-B-REVIEW-2026-06-29.md` U-002 (P-003) P1
> **当前状态**: ✅ **v3.2.0 主公拍 C 覆盖重写 4 文件 跟 v3.x 1:1 同步** (commit `08f2393`, 4 files +1453/-857 行). 不删, 留 reference history. 跟 E "重写 > 删除" 联合, 跟 v3.1.0 P-005 治根 联合, 跟"诚实修正" 联合, 跟"独立" 拍 explicit 约束 联合.

### 累计状态 (跟"反讽" 联合 治根 v3.1.0 二分矛盾)

| 版本 | 动作 | 详情 | 跟"独立" 拍板 联合 |
|------|------|------|-----------------|
| **v3.1.0** | ✅ 标记 DEPRECATED + 加清理时间表 (留/删 二分) | 本文档 + `_DEPRECATED.md` | ✅ 跟 v3.1.0 P-005 联合 |
| **v3.2.0** | ✅ **主公拍 C 覆盖重写** (4 文件 跟 v3.x 1:1 同步) | commit `08f2393` | ✅ 跟"独立" 拍 explicit 约束 联合 |
| **v3.3.0** | 🟢 累计 release (跟 A1+A2 联合 闭环) | F1 推 v3.3.0 | ✅ 跟"反讽" 闭环 |

### 跟 v3.x 1:1 同步 验证 (跟"诚实修正" 联合)

| 重写文件 | 跟 v3.x 1:1 同步 (跟"反讽" 联合) | 跟"诚实修正" 联合 |
|---------|------------------------------|---------------|
| `framework.md` | 跟 v3.0.0 6 武器 + Iter 3 binary 整合 + 5-Level + EPIC-038-A sub-role 1:1 | ✅ |
| `three-repo-architecture.md` | 跟 v3.x L0-L4 记忆分层 (EPIC-059-H) + sub-role 4 schema 1:1 | ✅ |
| `workflow-engine.md` | 跟 v3.x 4 sub-roles (coder/reviewer/tester/docs) + Q18 + 7 templates 1:1 | ✅ |
| `verification-protocol.md` | 跟 v3.x 5-Level (Level 5 边界: U-002/scope creep/KPI 估数) + 6 武器 1:1 | ✅ |

### 主公拍 决策 (跟"独立" 拍 explicit 约束 联合)

**v3.2.0 阶段**: ✅ 主公拍 **C 重写 跟 v3.x 1:1 同步** (commit `08f2393`). 跟"诚实修正" 联合 ("重写就是重写" 诚实), 跟"独立" 拍 explicit 约束 联合, 跟 v3.1.0 P-005 治根 联合.
**v3.3.0 阶段**: 推 v3.3.0 release, 跟 A1+A2 累计 联合 闭环.
**v3.5.0 阶段**: ✅ 加 `online-deploy-2026-06-30/README.md` (nested dir) 到 "引用" 表, 跟 B 组 U-005 + P-004 治根 联合. 内容 跟 degradation-strategy.md (16.6K) 部分 重复, 待 v3.6.0 整合 (本 hotfix 范围外).