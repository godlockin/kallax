# EPIC-280 Decision: DSH Path A admission — 9 → 10 immutable scripts

> **决策类型**: P0 战略拍板 (沿用 EPIC-225 check-jargon 模式)
> **拍板人**: 主公 (Stéven)
> **拍板日期**: 2026-08-21 (口头) / 2026-08-22 (书面归档)
> **实施人**: master (master@kallax.local)
> **Refs**: tip `6c2867f8` (PR #475 落地) / DSH report §4 Path A / EPIC-225 / EPIC-279 / EPIC-277-E

## 1. 背景

DSH (DeepSeek-Harness) Path A 借鉴提议改 `confluence/decisions/` 为 `{proposed,implemented,rejected}/{class}/` 双轴生命周期 (Agent Note ADR 体系). 落地需新增 `scripts/verify/verify-agent-note-format.sh` 接 hook chain.

KALLAX CLAUDE.md §5 列 9-immutable scripts fail-closed, 改动 immutable 数字强制主公亲自拍板 (沿用 EPIC-225 check-jargon.sh admission 同一规则).

### 1.1 前置债

- **PR #475 已落地**: tip `6c2867f8` `feat(EPIC-280): DSH Path A admission — verify-agent-note-format 接 hook (immutable 9→10)`
- **Bypass 用过**: `KALLAX_HOOK_BYPASS=1` (immutable-scripts.md 自身含 7 violations pre-existing, 历史 first_commit 不在 baseline ancestor, 沿用 EPIC-241 备案 pattern)
- **B 组红蓝对抗 blocker**: 缺 confluence/decisions/ 书面决策记录 → 本文补齐

## 2. 拍板内容

| 字段 | 值 |
|------|-----|
| 拍板决定 | 同意 9 → 10 admission |
| 新增脚本 | `scripts/verify/verify-agent-note-format.sh` (canonical) + `scripts/hooks/verify-agent-note-format.sh` (fallback) |
| admission 模式 | 沿用 EPIC-225 check-jargon / EPIC-279 check-doc-budgets 同步接入 hook chain |
| 优先级 | P0（落地范围：Agent Note admission） |
| 阻塞 | 无未解决 blocker；本文补齐 B 组记录 |
| tip | `6c2867f8` (testing 已合) |

## 3. 实施路径

1. 加 `scripts/verify/verify-agent-note-format.sh` 到 `.claude/rules/immutable-scripts.md` §5 (现 10 个)
2. `scripts/hooks/install.sh` + pre-commit 接入 (跟 check-jargon/check-doc-budgets 并列)
3. `KALLAX_HOOK_BYPASS=1` 用法备案 (immutable-scripts.md 自身含 7 violations pre-existing, 历史 first_commit 不在 baseline ancestor, 沿用 EPIC-241 备案 pattern)
4. PR #475 落地 (testing tip `6c2867f8`)

### 3.1 验证

raw_output: `bash scripts/hooks/install.sh --verify`（exit=0）

```text
$ bash scripts/hooks/install.sh --verify
verify-agent-note-format.sh 已接入；命令 exit=0
```

## 4. 跟现有 EPIC 关系

| EPIC | 关系 |
|------|------|
| EPIC-225 check-jargon.sh | 参考其接入模式（canonical、fallback、install --verify、pre-commit） |
| EPIC-279 check-doc-budgets.sh | 同模式 (1 天前刚合) |
| EPIC-223 check-ticket-schema.sh | 同样是 admission 历史先例 |
| EPIC-277-E (2026-08-21) | hooks/ 接入 4 个新脚本；install --verify 是验证机制 |
| EPIC-241 | 复用 bypass 备案格式 |

## 5. 后续债

- **bypass 使用记录**: #475、#479 均有备案
- **跨 EPIC 复用率**: 280、281、282、283 覆盖相同接入模式；指标结果见 sprint metrics 原始输出
- **累计 pre-existing jargon**: 7+ violations (immutable-scripts.md + check-claim-evidence.sh)
- **主公后续拍板**: 预存 jargon 历史词是否系统化豁免 (避免逐 bypass)

## 6. 文件指针

- `confluence/research/agent-note-adr-proposal-2026-08-21.md` — paper
- `scripts/verify/verify-agent-note-format.sh` — canonical
- `scripts/hooks/verify-agent-note-format.sh` — fallback
- `.claude/rules/immutable-scripts.md` — §5 admission
- tip `6c2867f8` (PR #475) — testing 合入

---

## 7. 主公签字 (引用对话原文)

> 主公 2026-08-21: "1 同意"
> 上下文: DSH Path A admission 9→10 immutable scripts
> 拍板性质: 战略拍板 (沿用 EPIC-225 模式)
> 实施前置: EPIC-225 / EPIC-279 接入模式已确立

---

**Written by master 2026-08-22 (主公拍板后补书面归档)**
**Signed-off-by: master <master@kallax.local>**
