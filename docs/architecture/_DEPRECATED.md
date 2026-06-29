# docs/architecture/ DEPRECATED 子文档说明 (V310 hotfix U-002)

> **来源**: B 组 review `confluence/decisions/V310-B-REVIEW-2026-06-29.md` U-002 (P-003) P1
> **跟踪**: `_index.md` §"DEPRECATED 清理时间表"
> **目的**: 一句话说明 4 个 DEPRECATED 子文档 状态 + 替代主文档位置

---

## 4 个 DEPRECATED 子文档

| 子文档 | 替代主文档章节 | 整合时间 | 原因 |
|--------|----------------|----------|------|
| `framework.md` | `docs/ARCHITECTURE.md` §3.1 (顶层架构图) + §9 (3 层降级) | Iter 11 (v2.7.6 → v3.0.0 整合) | v2.7.6 旧版, 跟 v3.0.0 不一致 |
| `three-repo-architecture.md` | `docs/ARCHITECTURE.md` §3.1 (顶层架构图) + §12.3 (知识库 + 任务管理) | Iter 11 | 跟 ARCHITECTURE.md 重复 |
| `workflow-engine.md` | `docs/ARCHITECTURE.md` §5 (W3 sub-role) + §8 (Q18 决策模型) | Iter 11 | 跟 ARCHITECTURE.md 重复 |
| `verification-protocol.md` | `docs/ARCHITECTURE.md` §6 (5 levels 验证) + §11 (集成测试) | Iter 11 | 跟 `docs/5-levels.md` + `README.md` §集成测试 重复 |

---

## 当前状态

- **tracked**: 仍 保留 在 git (`git ls-files docs/architecture/`), 4 个文件 共 ~2KB
- **DEPRECATED 标记**: 每个子文档 头部加 "DEPRECATED" 警告
- **替代**: 内容 100% 整合到 `docs/ARCHITECTURE.md` 跟 `docs/5-levels.md`
- **引用**: 0 active 引用 (除 `_index.md` 自己)

## 删除前 验证

主公 拍板 删除前, 需跑 `_index.md` §"DEPRECATED 清理时间表" 中 1:1 验证 命令.

## 主公拍 决策

**v3.1.0 (当前)**: 保留 (跟 Iter 12 "不删" 决定 一致).
**v3.2.0**: 主公审查 + 拍 "留 / 删".