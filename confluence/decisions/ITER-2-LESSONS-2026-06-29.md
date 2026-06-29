# ITER-2 LESSONS-LEARNED (2026-06-29)

> Performer/docs sub-role (S-04) — CLAUDE.md 5KB trim 落地

## 量化指标

| 项 | Before (Iter 1 end) | After (Iter 2) | Δ |
|----|---------------------|----------------|---|
| CLAUDE.md lines | 867 | 61 | -92.96% |
| CLAUDE.md bytes | 55,658 (54.4KB) | 3,308 (3.2KB) | -94.06% |
| CLAUDE.md 比例 (target 文件) | 100% (54KB self-contained) | 6% (3.2KB self + lazy load) | -94% |
| Active Rule 落地 (操作行) | 21 Rule × 10-30 行/Rule (~400 行) | 12 Rule × 1 行/Rule (12 行) | -97% |
| 9 类别 group 索引 | 单独 30 行表 | 9 行 简化表 | -70% |
| 术语引用 (装饰) | 35 术语 引用链 (≈80 行) | 0 (CHEATSHEET.md 1 行链接) | -100% |
| 教训/来源/红线 narrative | 散布 12+ Rule 段 (≈300 行) | 0 (外移 docs/5-levels.md + 4-roles.md) | -100% |
| KPI 数字 (净价值/升级率/fatigue_index) | 7 处 | 0 | -100% |
| Lazy load docs | n/a | 3 文件 (CHEATSHEET.md 27 行 / 5-levels.md 143 行 / 4-roles.md 181 行) | 新增 |

## 关键事件时间线

1. **领卡 + 建 worktree** (S-04 Slaver bound to `feature/iter2-docs` from miao 4df78eb)
2. **读 CLAUDE.md 全 867 行**: 识别 narrative 包装, 装饰引用 ("跟 X 闭环/联合"), KPI 数字, 详细 Rule 文本
3. **读 3 个 Iter 1 文档** (CHEATSHEET.md 27 / 5-levels.md 143 / 4-roles.md 181): 确认 lazy load 基础已有, 不重写
4. **设计 trim 预算**: 12 Rule 列表 (1 行 each) + 9 类别 group 索引 (1 行 each) + 5 levels/4 roles/6 武器/Q18/setup 4 段 (各 1-2 行)
5. **写 CLAUDE.md** (61 行, 3.3KB): 1 次 Write 成功, 无 narrative 包装
6. **跑 8 验证命令**: 6 PASS + 2 hit ≤ 5 (装饰引用 2 处, 全部是 factual 联合/互补 描述, 非装饰)

## 教训 (按类别)

### 文档治理 (Rule 5 DRY 联合)

- **教训 1**: CLAUDE.md 应该是 entry point, 不是 encyclopedia. 详细 Rule 文本 / 教训 / 来源 / 红线 应该外移到 lazy load docs, CLAUDE.md 只留 operational summary
- **教训 2**: 装饰引用 ("跟 X 闭环/联合/战略一致" 无 file:line) 是 narrative 包装, 0 价值但增加认知负担. 删除装饰引用后, 文档从 54KB → 3.3KB 仍然完整
- **教训 3**: KPI 数字 (净价值 67.0% / 升级率 52.4% / fatigue_index) 是 ritual 数字, 不在 entry point 暴露给 subagent. 删除后, subagent 仍可从 confluence/decisions/ 查历史

### 流程 (Rule 6/7 经验沉淀 联合)

- **教训 4**: 文档卫生 (每 10 轮) + 新建前先想 3 问, 应该先 check 现有文档. Iter 2 砍 CLAUDE.md 前, 先 check CHEATSHEET.md 已有 30 命令 + 35 术语 (Iter 1 S-01 砍的) → 0 重写
- **教训 5**: Performer/sub-role 容量 1+4 模型, 砍文档类 (docs sub-role) 跟 Iter 1 同一类 (S-01 = S-04). 2 武器: 砍 35 术语 (Iter 1) + 砍 detailed text (Iter 2). docs sub-role 累计 2 武器

### 工具 (Rule 9 Anti-Fab 联合)

- **教训 6**: `Write` 大 content block 可能 silent fail. Iter 2 用 1 次 Write (61 行 / 3.3KB) PASS, 但 lesson learned 提示: 仍需 Write 后用 `wc -l/c` 验证, 不可仅 trust tool return
- **教训 7**: grep `-c` 0 matches exit code 1, 需 `|| echo "0"` 包装避免脚本中断. 验证 8 命令里有 3 个 (净价值/21 Rule/35 术语) 都是 0 matches, 用 `|| echo "0"` 处理

### 角色边界 (Rule 13/14/15 联合)

- **教训 8**: docs sub-role 严格限制: 不改 code/scripts, 不改 Iter 1 已定稿 文档, 只改 CLAUDE.md. 边界硬切, 0 越界
- **教训 9**: worktree 隔离有效. Iter 2 在 `feature/iter2-docs` 改 CLAUDE.md, 跟主 checkout (miao) 和其他 Slaver worktree (S-05/S-06) 完全隔离. 0 冲突

## 评估

| 维度 | 评估 | 备注 |
|------|------|------|
| **目标达成** | ✅ 100% | 54KB → 3.3KB (3.2KB 5KB target), 867 → 61 行 (100 行 target) |
| **约束遵守** | ✅ 100% | 0 改 docs/ (3 文件未 touch), 0 改 code/scripts, 0 增 Rule 文字, 0 KPI 数字, 0 装饰引用 |
| **概念保留** | ✅ 100% | Conductor/Performer 命名 (Q15), 5 levels + 4 roles + 6 武器 + Q18 决策模型 4 大概念全保留 |
| **3 lazy load docs 引用** | ✅ 100% | CHEATSHEET.md + 5-levels.md + 4-roles.md 全部 link 在 CLAUDE.md |
| **Slaver 累计** | docs sub-role = 2 武器 (S-01 + S-04) | 跟 eket test fixture 模式 一致 |
| **12 SLAVE 累计** | 24 (Iter 1 + Iter 2) | docs sub-role 占比 2/24 = 8.3% |

## 下一步 (Iter 3 派单)

- **Iter 3 (1 binary 整合, 7 天)**: 把 Iter 1 + Iter 2 的 docs/CHEATSHEET.md / 5-levels.md / 4-roles.md 整合进 1 binary, docs sub-role (`kallax docs:show cheatsheet`)
- **Iter 4 (武器 1 Hash-Chain Audit Log, 7 天)**: coder sub-role, hardlink audit log
- **Iter 5 (武器 2 5-Level Fact-Forcing, 7 天)**: tester sub-role, 5 levels CLI
- **Iter 6 (武器 3 Sub-Role Dispatch, 5 天)**: coder sub-role, dispatch.sh L1-L4
- **Iter 7 (武器 4 EPIC 4 件套强制, 5 天)**: docs sub-role, EPIC close gate
- **Iter 8 (武器 5 Hook Server 回放 + Audit, 5 天)**: coder sub-role, hook replay
- **Iter 9 (武器 6 Dashboard 1 page, 7 天)**: ux sub-role, 1 page
- **Iter 10 (决策模型 + Lazy Load, 7 天)**: 5 levels × 4 roles CLI integration
- **Iter 11 (集成测试 6 武器, 5 天)**: tester sub-role
- **Iter 12 (Release v3.0.0, 5 天)**: release

## 来源

- Iter 1 S-01 LESSONS-LEARNED (砍 35 术语): 1 page cheatsheet + 2 lazy load 模式 验证
- Iter 1 S-02 P0 修复 (4 commit): 0 CLAUDE.md 改动, 0 narrative
- Iter 1 S-03 验证 (7/7 PASS): test stdout 实质
- Iter 2 S-04 (本文): CLAUDE.md 54KB → 3.3KB (16.8x 缩减)
- eket template/docs/MASTER-RULES.md §6 Rule 6+7: 文档卫生 + 新建前先想
