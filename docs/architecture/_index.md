# docs/architecture/ 索引 (KALLAX v3.0.0)

> **主文档**: [../ARCHITECTURE.md](../ARCHITECTURE.md) (12 章节, 5W2H 模式)
> **本文档**: 子文档 索引 + 状态 (DEPRECATED / 引用 / 主文档章节)

---

## 主文档

| 文档 | 行数 | 用途 | 链接 |
|------|------|------|------|
| `docs/ARCHITECTURE.md` | ~470 | 主架构文档 (5W2H, 跟 eket 对比 + 6 武器 + 5 levels + 4 roles + Q18) | [link](../ARCHITECTURE.md) |

---

## 子文档 (14 个, v2.7.6 → v3.0.0 整合)

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

## DEPRECATED 清理时间表 (V310 hotfix U-002)

> **来源**: B 组 review `confluence/decisions/V310-B-REVIEW-2026-06-29.md` U-002 (P-003) P1
> **当前状态**: 4 个 DEPRECATED 子文档 仍 tracked, 内容已 100% 整合到主文档, 子文档本身 是 0 信息增量的 reference 副本.

### 计划

| 版本 | 动作 | 详情 |
|------|------|------|
| **v3.1.0 (当前)** | ✅ 标记 DEPRECATED + 加清理时间表 | 本文档 + `_DEPRECATED.md` |
| **v3.2.0** | 🟡 评估期 (主公拍) | 主公审查 4 个 DEPRECATED 内容, 决定留 / 删 |
| **v3.3.0** | 🟢 删 4 个 DEPRECATED 子文档 (跟主公拍板 联合) | framework.md / three-repo-architecture.md / workflow-engine.md / verification-protocol.md |

### 删除前 1:1 验证

```bash
# 1. 4 个待删文档 content 跟主文档对应章节 diff (期望 = 0 实质 增量)
diff <(grep -E '^##' docs/architecture/framework.md) <(grep -E '^##' docs/ARCHITECTURE.md)

# 2. 4 个待删文档 0 active 引用 (除 _index.md 自己)
grep -rln "architecture/framework\|architecture/three-repo\|architecture/workflow\|architecture/verification" docs/ confluence/ scripts/

# 3. 主公拍板 (confluence/decisions/) 跟踪
```

### 主公拍 决策

**v3.1.0 阶段**: 保留 4 个 DEPRECATED 子文档 (跟 Iter 12 "不删" 决定 一致), 加 时间表 + `_DEPRECATED.md` 说明.
**v3.2.0 阶段**: 主公 拍 "是 删 4 DEPRECATED 还是 留做 reference history".