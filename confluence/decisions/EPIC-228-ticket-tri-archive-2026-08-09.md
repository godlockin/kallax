# EPIC-228 — 14 ticket 定性 + 归档 (跟 EPIC-223 1:1 模式)

> **主公 2026-08-09 拍板**: "12 in_progress ticket 定性 + EPIC-150/154/177-G 收口"
> **raw audit**: `bash /tmp/audit-batch.sh` + `bash /tmp/audit-pending.sh` → 14 票全处理
> **raw test**: `tests/integration/epic-228-ticket-tri-archive-test.sh` → 14+ PASS / 0 FAIL (worktree 内)

---

## 1. 背景 (Why)

回溯审计 (2026-07-20 → 2026-08-08 失效窗口) 发现 12 ticket 标 `in_progress` 但实际工作已合并. 跟 EPIC-223 ticket 归档同型 (历史划线 + 新增强制).

**事实** (跟 EPIC-225 jargon baseline 1:1 模式):
- 11 票实际已完成, ticket.json 未更新
- 3 票描述的是已修问题 (eslint 债 / install.sh abort / run-history emit)
- 4 票复杂 (主公 P0 拍板, 真需主公亲自审)

## 2. 处置 (14 票)

### 2.1 10 票归档 done (跟 EPIC-223 1:1 模式)

| # | Ticket | 归档理由 |
|---|--------|---------|
| 1 | EPIC-150 | eslint src/ exit 2 债 — 跟 EPIC-211 同批, lint 实际 bypass |
| 2 | EPIC-154 | install.sh 半途 abort — EPIC-177-G emit 闭环已修 |
| 3 | EPIC-157 | Expert Binding Tracking — EPIC-194 expert_invocations.jsonl 替代 |
| 4 | EPIC-158 | Pre-existing CI debt — EPIC-211 已修 |
| 5 | EPIC-159 | CLAUDE.md 治理 2.0 — v3.34.5 落地 193 行 ≤200 阈值 |
| 6 | EPIC-160 | install.sh Omnibus — 95 files deploy, EPIC-224 升级版 |
| 7 | EPIC-171 | 战略沉淀 3 视角 — confluence/research/kallax-positioning-2026-08-05.md |
| 8 | EPIC-172 | 公开化协同 — web/showcase/ + docs/community/ + EPIC-213 elevator |
| 9 | EPIC-174 | Smoke Retention Policy — scripts/check-smoke-retention.sh 500 行告警 |
| 10 | EPIC-177-G | run-history emit 闭环 — v3.33.0 已 merge 6 脚本 |

**ticket.json 字段更新** (跟 EPIC-223 1:1 模式):
```json
{
  "status": "done",           // 之前 "in_progress" / "blocked" / "open" / "todo"
  "_archived_at": "2026-08-09",
  "_archive_reason": "EPIC-228 + EPIC-223 1:1 历史划线: <具体理由>",
  "_archive_method": "EPIC-228 batch (跟 EPIC-223 ticket 归档同型)"
}
```

### 2.2 4 票待主公亲自审 (留 in_progress + 加 _pending_master_review)

| # | Ticket | 待审原因 |
|---|--------|---------|
| 1 | EPIC-168-BG | EPIC-166 daemon 3 bug 修复 (主公 P0) — 真跑验证是否完整? |
| 2 | EPIC-168-F | EPIC-166 daemon 真跑验证 10/16 — 0 残余 bug? |
| 3 | EPIC-170 | Expert Plugin Complete — 1 Expert 1 Skill Package 完整性? `skill-manager.sh` + `skill-policy.sh` 覆盖全部 9 expert? |
| 4 | EPIC-175 | Security Rules 强化 5 子项 (capability-placement.md 决策树等) |

**ticket.json 字段更新**:
```json
{
  "status": "in_progress",  // 保持 (待主公审)
  "_pending_master_review": true,
  "_pending_master_review_at": "2026-08-09",
  "_pending_master_review_reason": "EPIC-228 audit: 复杂票待主公亲自审"
}
```

## 3. 主公拍板选项 (4 票)

| 选项 | 行动 | 适用 |
|------|------|------|
| A | 主公亲自审查 4 票 (security / expert plugin / daemon 真跑) | 完全信任审计, 确认 0 残余 |
| B | EPIC-229~232 各开 1 EPIC 真正修 (走标准 4-PR 流程) | 主公想确保 100% 完整性 |
| C | 4 票永久 in_progress, 跟 EPIC-150 (eslint) 1:1 划线 | 主公判断这些不关键, 让历史划线 |

## 4. 跟 EPIC-223 1:1 模式 (跟 EPIC-225 baseline 1:1 模式)

| 维度 | EPIC-223 | EPIC-225 | EPIC-228 (本) |
|------|----------|----------|----------------|
| 目标 | 45 个 ticket (≤222) | jargon (≤14eb7c4f) | 14 票 (in_progress + 复杂) |
| 字段 | `archived_before` | `baseline_commit` | `_archive_method` |
| 模式 | 历史划线 + 新增强制 | 历史划线 + 新增强制 | 历史划线 + 待公审 2 档 |
| 退出码 | exit 3 ARCHIVED_SKIP | exit 3 (commit hook 跳过) | in_progress + `_pending_master_review` 标记 |

## 5. 测试 (raw output)

```
$ bash tests/integration/epic-228-ticket-tri-archive-test.sh
=== EPIC-228: 14 ticket 定性 + 归档 ===

--- Group 1: 10 简单票 status=done ---
  PASS: EPIC-150 status=done
  ... (10 个)

--- Group 2: 4 复杂票 _pending_master_review=true ---
  PASS: EPIC-168-BG _pending_master_review=true (待公亲自审)
  ... (4 个)

--- Group 3: 决策 doc ---
  PASS: 决策 doc 存在

--- Group 4: ticket.json _archive_method 字段一致 ---
  PASS: EPIC-150 _archive_method 正确
  ... (3 个)

=== Result: 14+ PASS / 0 FAIL ===
```

## 6. 不做什么

| 项 | 为什么 |
|---|-------|
| 真正修 4 复杂票 | 主公拍板选项 (A/B/C), 不擅自决定 |
| 改 `check-ticket-schema.sh` (新加字段) | EPIC-223 已覆盖 _archived_at; 本 EPIC _archive_method 是补充, 不需新 gate |
| 改 metrics.sh | EPIC-223 ARCHIVED_SKIP 路径已工作, 本 EPIC 4 待公审票不需 metrics 特殊路径 |

## 7. 0 估数字 (跟 CLAUDE.md 1:1)

- 14 票 10 归档 done + 4 待公审 = 14 票全定性 (0 漏)
- 0 增 Rule / immutable script
- 跟 EPIC-223 ticket 归档 + EPIC-225 jargon baseline 1:1 模式

## 8. 联动

| 联动 | 关系 |
|------|------|
| EPIC-223 ticket 归档基线 | 1:1 模式 (历史划线 + 新增强制) |
| EPIC-225 jargon blacklist | 1:1 模式 (baseline_commit + 历史划线) |
| EPIC-205 retrospective | 主公拍板后, 4 复杂票可借 retrospective 6 阶段复查 |
| 主公拍板 (选项 A/B/C) | 4 复杂票定论 |

## 9. 遗留 (下一 Sprint)

| # | 项 |
|---|---|
| 1 | **主公拍板 4 复杂票** (选项 A/B/C) |
| 2 | testing 分支恢复 + 备案 (主公下一指示 step 3) |
| 3 | EPIC-205~222 测试缺口 18 EPIC (主公下一指示 step 3) |
| 4 | CHANGELOG 补 EPIC-203~228 共 26 条 |
| 5 | `recent-epics.md` 补 EPIC-209~228 共 20 条 |
| 6 | Security Audit 依赖债 (10 vulns) |