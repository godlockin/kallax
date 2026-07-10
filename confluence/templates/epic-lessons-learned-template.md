# EPIC-XXX — Lessons Learned

> **何时填**: EPIC 全部 ticket close 后 24h 内 (跟最后 PR 一起提交).
> **必填**: ✅ 全部 6 节. 不可省略, 不可 "TBD".
> **谁填**: master 主导, 可派 Performer 收集, 但 master 终审.
> **路径**: `jira/epics/EPIC-XXX/LESSONS-LEARNED.md`

**Date**: YYYY-MM-DD
**Status**: COMPLETE (X/Y tickets done)
**Author**: master_xxx (post-completion review)
**Reviewers**: [列出 A+B 2-Group reviewer 名字]

---

## 1. 结果摘要 (量化)

| 指标 | Baseline (v0) | 最终 (vN) | 节省 / 改进 | 目标 | 达成 |
|---|---:|---:|---:|---|---|
| [指标 1] | X | Y | Z% | [目标] | ✅/❌ |
| [指标 2] | X | Y | Z% | [目标] | ✅/❌ |
| [指标 3] | X | Y | Z% | [目标] | ✅/❌ |

**目标达成情况**: X/Y 指标达标 (Z%)

## 2. 交付物清单 (X tickets, Y commits to miao)

| ID | Ticket | Status | Notes |
|---|---|---|---|
| A | [title] | done | [备注] |
| B | [title] | done | [备注] |
| ... | | | |

## 3. 关键事件时间线

| Date | Event |
|---|---|
| YYYY-MM-DD | EPIC 启动, baseline 测量 |
| YYYY-MM-DD | [关键里程碑 1] |
| YYYY-MM-DD | [事故 / 修复 / 重新派发] |
| YYYY-MM-DD | [关键里程碑 2] |
| YYYY-MM-DD | 全部 ticket 完成 |

## 4. 关键经验教训 (按类别, 不可漏)

### 4.1 技术 (Tech)

- [教训 1]: [现象, 根因, 修复, 防范]
- [教训 2]: [同上]

### 4.2 流程 (Process)

- [教训 1]: [现象, 根因, 修复, 防范]

### 4.3 治理 (Governance)

- [教训 1]: [现象, 根因, 修复, 防范]

### 4.4 人员 (People)

- [教训 1]: [Performer 误路由, 沟通失误, 角色越界, etc]

### 4.5 工具 (Tooling)

- [教训 1]: [check 脚本漏, 自动化不到位, etc]

## 5. A+B 2-Group Review 总结

### 5.1 A 组 (Forward) 发现

[列出 A 组找到的 issue, 按 P0/P1/P2 分级]

### 5.2 B 组 (Attack) 发现

[列出 B 组找到的 issue, 按 CRITICAL/HIGH/MEDIUM/LOW 分级]

### 5.3 互补性观察

[A 组漏了 B 组找到的, 或反之. 哪些角度只有 A/B 单一能找到]

### 5.4 修复记录

- [issue]: [修复 commit, 解决方式]

## 6. EPIC 评估

### 6.1 成功之处

- ✅ [做得好的]
- ✅ [比预期好的]

### 6.2 未达预期

- ❌ [没做到的, 为什么]
- ❌ [质量 / 进度 / 范围的偏差]

### 6.3 流程改进建议

- [建议 1]: [给下个 EPIC / 给 master / 给 Performer]
- [建议 2]: [具体可执行]

## 7. 跟其他 EPIC 的关联

- [配合 EPIC-YYY 的依赖 / 阻塞 / 互补关系]
- [复用 / 借鉴 / 跟冲突的内容]

## 8. 下一步建议

1. **EPIC-ZZZ** 启动前需要先做: [具体]
2. **回填**: [本 EPIC 没覆盖的, 下个 EPIC 补]
3. **升级**: [哪些经验教训值得升级到 CLAUDE.md]

---

**Reviewer(s)**: [名字列表]
**Last updated**: YYYY-MM-DD
**Status**: ✅ COMPLETE — 6 节全填, A+B review 整合, 配合 EPIC-XXX 实施 commit 同一 PR 提交
