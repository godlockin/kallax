# EPIC-021-C: output_format 4 节统一 (7 文件)

## 需求

EKET 7 位 default expert 中, output_format 结构性不一致 (architect 5 节 / backend 3 节 / frontend 缺省). KALLAX 强制统一 4 节模板, Master 拿到任意 expert 输出 = 期望格式一致.

## 接受标准 (AC)

详见 `ticket.json`. 6 条 AC.

## 4 节统一模板

```yaml
output_format: |
  ## 亮点
  - <发现 1>
  - <发现 2>
  - <发现 3> (若无则填 "无")

  ## 风险
  - [P0/P1/P2] <风险 1>
  - [P0/P1/P2] <风险 2>
  - [P0/P1/P2] <风险 3> (若无则填 "无")

  ## 建议
  - <建议 1> (估时 Xh, 代价 Y)
  - <建议 2> (估时 Xh, 代价 Y)
  - <建议 3> (估时 Xh, 代价 Y) (若无则填 "无")

  ## P0 阻塞条件
  - <具体 ticket ID 或具体阻塞描述>
  - 无 (若无 P0 阻塞, 显式写 "无" 不省略)
```

## 为什么是 4 节 (借 EKET 但收紧)

| 节 | 借自 EKET | KALLAX 改动 |
|---|---|---|
| 亮点 | ✅ EKET 有 | 不变 |
| 风险 | ✅ EKET 有 | **强标 P0/P1/P2** (EKET 无) |
| 建议 | ✅ EKET 有 | **强标 估时/代价** (EKET 无) |
| P0 阻塞条件 | ❌ EKET 无 | **KALLAX 独家**: master 仲裁用, 决定 ticket 能否 close |

## 为什么不要照搬 EKET 5 节

EKET architect 5 节 (模块地图/选型评估/亮点/风险/建议) 加 2 节是 architect 视角特有. KALLAX 7 位角色各异, 多 2 节会让 5/6/7 文件变冗长. 4 节 = 最小公倍数, 强制 Master 汇总效率.

## YAML 多行字符串 (借 EKET 设计巧思)

```yaml
# ✅ 正确 (可被脚本解析)
output_format: |
  ## 亮点
  - ...

## 风险
  ...
```

```yaml
# ❌ 错误 (Markdown body, 脚本无法解析)
output_format:
  "## 亮点
  - ..."
```

## 文件范围

7 文件 frontmatter 内的 `output_format` 字段, 不改 body section:
- `.kallax/experts/default/architect.md` (frontmatter only)
- `.kallax/experts/default/backend.md` (frontmatter only)
- `.kallax/experts/default/frontend.md` (frontmatter only)
- `.kallax/experts/default/ux.md` (frontmatter only)
- `.kallax/experts/default/product.md` (frontmatter only)
- `.kallax/experts/default/security.md` (frontmatter only)
- `.kallax/experts/default/pm.md` (frontmatter only)

## ⚠️ 阻塞说明

**blocked_by EPIC-021-A**: A 创建 7 文件, C 才能改它们的 frontmatter. 

**D blocked_by C**: D 也改 7 文件 (加 `Fact-Forcing Compliance` section), C 先 D 后避免同文件并发编辑.

## 预估工时

0.4 小时 (7 文件 × 5min/文件, 含 YAML 格式校验)

## 2-Group review 期望

- **A 组 (Forward)**: 校验 4 节齐全, 风险标 P0/P1/P2, 建议标 估时/代价
- **B 组 (Attack)**: 找某 expert 的 4 节是否真能涵盖该角色典型输出 (e.g. security 的"亮点"会不会被强制写非安全相关发现)

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-07 17:00 UTC | ready | master_main | 创建 |
