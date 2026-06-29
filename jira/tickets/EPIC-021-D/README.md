# EPIC-021-D: Fact-Forcing 5-Level 嵌入 (7 文件)

## 需求

把 KALLAX 5-Level Fact-Forcing 嵌入 7 个 expert 文件的 `Verification` 节 + 新增 `Fact-Forcing Compliance` 节. EKET 只有 L1/L2 级 (bash 命令), KALLAX 5-Level 是独家超越点, 体现"执行式 persona 不可伪造".

## 接受标准 (AC)

详见 `ticket.json`. 6 条 AC.

## Fact-Forcing 5-Level 定义 (KALLAX 独家)

| Level | 含义 | 通用 bash | 角色特化 |
|---|---|---|---|
| **L1 存在性** | 文件存在于 diff | `git diff --name-only` | 所有角色 |
| **L2 实质性** | 字节数 > 阈值, 非 stub | `git diff --stat \| awk '{sum+=$3}END{print sum}'` | 所有角色 (>200 字节) |
| **L3 接线正确** | import/export 无断裂, type check 通过 | `tsc --noEmit` / `cargo check` / `bash -n` | 角色特化 |
| **L4 数据流动** | 集成测试通过, 覆盖率不下降 | `npm test` / `cargo test` / `bash scripts/test-*.sh` | 角色特化 |

## 模板 (借 EKET Verification, 升级 5-Level)

### Verification 节 (改 EKET 3 checkbox → 5-Level)

```markdown
## Verification

执行顺序: L1 → L2 → L3 → L4, 任一失败 = ticket not done.

### L1 存在性
```bash
git diff --name-only <commit-range> | wc -l  # 期望 >= 1
```

### L2 实质性
```bash
git diff --stat <commit-range> | tail -1  # 检查总字节数
# 或: git diff <commit-range> | wc -c
```

### L3 接线正确
```bash
# role-specific:
# - Backend: tsc --noEmit
# - Frontend: tsc --noEmit
# - Security: bash -n <shell-scripts>
# - 其他: 见角色节
```

### L4 数据流动
```bash
# role-specific:
# - Backend: npm test -- --testPathPattern=<module>
# - Frontend: npm run test:e2e
# - Security: bash scripts/test-no-hang.sh
# - 其他: 见角色节
```
```

### Fact-Forcing Compliance 节 (新增, 在 Verification 上方)

```markdown
## Fact-Forcing Compliance

Performer 在 `task:complete <TICKET>` 前**必须勾选 4 项**:

- [ ] L1_存在性: git diff --name-only 核对文件存在
- [ ] L2_实质性: diff 字节数 > 200, 非 stub 占位符
- [ ] L3_接线正确: import/export 无断裂, tsc --noEmit 通过
- [ ] L4_数据流动: 集成测试通过, 覆盖率不下降

任一未勾选 = ticket 状态保持 in_progress, 不能 close.
```

## 角色特化 (L3/L4)

每文件的 L3/L4 命令针对该角色典型工作:

| 角色 | L3 命令 | L4 命令 |
|---|---|---|
| 🏗️ Architect | `bash -n` (架构文档无语法) | `bash scripts/verify-architecture.sh` |
| 💻 Backend | `tsc --noEmit` (Node 项目) | `npm test -- backend` |
| 🎨 Frontend | `tsc --noEmit` + `eslint` | `npm run test:e2e` |
| 🖌️ UX | `bash -n` (UX 文档) | `bash scripts/test-ux-flow.sh` (人工 + 脚本) |
| 📋 Product | `bash -n` (产品文档) | `bash scripts/verify-priority.sh` |
| 🛡️ Security | `bash -n` + `shellcheck` | `bash scripts/test-no-hang.sh` + 手动攻击模拟 |
| 🧭 PM | `bash -n` (PM 文档) | `bash scripts/verify-tickets-completed.sh` |

## 文件范围

7 文件 (改 Verification 节 + 新增 Fact-Forcing Compliance 节):
- `.kallax/experts/default/architect.md` (body section 修改)
- `.kallax/experts/default/backend.md` (body section 修改)
- `.kallax/experts/default/frontend.md` (body section 修改)
- `.kallax/experts/default/ux.md` (body section 修改)
- `.kallax/experts/default/product.md` (body section 修改)
- `.kallax/experts/default/security.md` (body section 修改)
- `.kallax/experts/default/pm.md` (body section 修改)

## ⚠️ 阻塞说明

**blocked_by EPIC-021-A + EPIC-021-C**: A 创建文件, C 改 frontmatter, D 最后改 body section. 串行避免并发编辑.

## 预估工时

0.4 小时 (7 文件 × 3.5min/文件, 含 4 级 bash 命令)

## 2-Group review 期望

- **A 组 (Forward)**: 校验 5-Level 命令可执行 (手动跑 L1-L4 各 1 次)
- **B 组 (Attack)**: 找 L3/L4 是否漏角色特化 (e.g. security 的 L4 是否含攻击模拟, 不只是 happy path)

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 17:00 UTC | ready | master_main | 创建 |
