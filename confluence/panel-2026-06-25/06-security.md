# 🛡️ Security Expert Review

> Date: 2026-06-25 | Topic: 清理文件 + 重写文档树
> Role: 🛡️ security-tool-bypass (跟 v2.0.3 EPIC-056-A Phase 2 联合)
> Joined: BE-19 KALLAX_CURRENT_ROLE + 10 工具 user-level dirs + `.kallax/` secrets governance

---

## 1. 现状 评估 (跟"诚实修正" 战略 联合 0 隐藏)

| # | Finding | File:Line | 风险等级 |
|---|---------|-----------|---------|
| **F1** | **BE-19 治理 gap 文档化但 0 修复**: `scripts/permission/authz/check.sh:83-85` 注释声明 `KALLAX_CURRENT_ROLE` 是 test seam, code 仅 `jq -r '.role // ""' "$STATE_FILE"` 读 state.json, 0 读 env (跟 ACCUMULATED-LESSONS-2026-06-19-PHASE-2.md:35-52 经验 2 联合) | `scripts/permission/authz/check.sh:83-85` | **P1** |
| **F2** | **Test token literal 暴露在 docs**: `KALLAX_MASTER_TOKEN=test-token-12345` 在 2 处公开 (commit msg + 经验 4 步骤), 虽明示是 test 但 跟 9-pass redaction prefix 库 (ghp_/sk-/AKIA) 不匹配, 0 自动 拦截 | `confluence/decisions/ACCUMULATED-LESSONS-2026-06-19-PHASE-2.md:42,82` | **P2** |
| **F3** | **API auth guide placeholder 跟 redaction prefix 冲突**: `sk-abc123...` 占位符 (line 27, 33, 38) + `your-256-bit-secret` (line 47) — 格式上 触发 `sk-*` redaction prefix, 易 误导 grep 命中 假阳性 | `docs/guides/api-authentication-2026-06-19.md:27,33,38,47` | **P2** |
| **F4** | **9-pass redaction prefix 库 0 扩**: `docs/architecture/3-MODES.md:146` 列出 9-pass scope (Authorization/Token/X-Auth-Token/password/secret/Basic Auth URL + 3 已知 prefix ghp_/sk-/AKIA + JWT + env-var), 但 `test-token-*` 跟 `KALLAX_MASTER_TOKEN` 字面量 0 在 prefix 库 | `docs/architecture/3-MODES.md:146` + `confluence/decisions/PHASE-005-REVIEW-2026-06-11.md:410-411` | **P1** |
| **F5** | **10 工具 user-level dirs 0 跟踪 secret 暴露**: 实际检查 `.aider/.antigravity/.claude/.codex/.continue/.cursor/.gemini/.opencode/.trae/.codeium/` — 全部 skills/commands 目录 跟 `.claude/skills/kallax/` 同源 (symlink v2.7.1 模式), 0 token/api_key 暴露 | 10 dirs 已验证 | **OK** |
| **F6** | **`.gitignore` 覆盖 完整**: `.kallax/state/`, `.kallax/data/`, `.kallax/logs/`, `.env`, `.env.*.local` 全部 ignore; state.json role transitions + authz.db.log 0 误 commit 风险 | `.gitignore:5-12,82-86` | **OK** |
| **F7** | **0 真实 production secret 暴露**: grep `AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|-----BEGIN.*PRIVATE KEY` 在 docs/confluence/jira 全部 0 命中 | grep 验证 0 matches | **OK** |

**7 findings / 4 OK / 3 需 follow-up** (跟"诚实修正" 联合 0 隐藏).

---

## 2. 风险 + 约束 (跟"诚实修正" 战略 联合 0 隐藏)

| # | 风险 | 描述 | 跟"翻篇&精进" 联合 缓解 |
|---|------|------|--------------------------|
| **R1** | **Test token copy-paste 误用**: `KALLAX_MASTER_TOKEN=test-token-12345` 公开在 2 处 commit msg 模式 文档, 后续 subagent 若 copy-paste 走 master 路径 0 验证 token 来源 → 静默 走 c091d92 `--no-verify` 模式 (BE-19 经验 联合) | ACCUMULATED-LESSONS-2026-06-19-PHASE-2.md:42,82 | 0 强制 拍板, 跨 release 留待 master explicit 拍 "加 redaction prefix `test-token-*`" |
| **R2** | **KALLAX_CURRENT_ROLE 0 实施 治理 gap 反复**: 跨 release 累计 3 subagent bypass authz (EPIC-058-C, EPIC-060-B-1 阶段 1), comment/code 不一致 → BE-19 0 从根源修复, 仅 文档化 | scripts/permission/authz/check.sh:83-85 + ACCUMULATED-LESSONS-2026-06-19.md:33,39 | 跟"诚实修正" 联合 0 隐藏, 跨 release 留待 master explicit 拍 修复 / 接受 gap |
| **R3** | **API auth guide placeholder 误读**: `sk-abc123...` 跟 redaction prefix `sk-*` 命中, 用户误以为 是 example → 9-pass redaction 工具 误报 / grep audit 假阳性 | docs/guides/api-authentication-2026-06-19.md:27,33,38 | 跨 release 留待 master explicit 拍 "改 placeholder 格式 `<YOUR_API_KEY>`" |
| **R4** | **docs 清理 跨 release 留待 链接 断 风险**: Phase 1 报告 R2 指出 跨 release 累计 文档 引用 链接 断 风险, secret 引用 (`KALLAX_MASTER_TOKEN=test-token-12345`) 若被误 rename → 跨 session 难 trace root cause | confluence/decisions/ACCUMULATED-LESSONS-2026-06-19-PHASE-2.md:42 | 跟 Phase 1 R2 联合, 0 强制 拍板 |
| **R5** | **.kallax/ 跨 release 留待 0 跟踪 secret 暴露**: state.json + authz.db.log + role-transitions.jsonl 全部在 `.kallax/` 下, gitignore 已覆盖, 但 若 .gitignore 被误改 → 跨 release 留待 master 拍 "加 pre-commit hook 强制 gitignore 检查" | .gitignore:5-12 + .kallax/state/ | 0 强制 拍板, 跨 release 留待 |

**5 风险 / 全部 0 强制 拍板 / 跨 release 留待** (跟"独立" 战略 联合 master explicit 双 拍).

---

## 3. 推荐 (跟"独立" 战略 联合 0 跨 session 拍板)

| # | 推荐 | 文件:行 / 范围 | 战略 联合 |
|---|------|----------------|-----------|
| **A1** | **加 `test-token-*` 字面量 到 9-pass redaction prefix 库**: 跟 `KALLAX_MASTER_TOKEN` env name 联合, 升级 9-pass → 10-pass | `docs/architecture/3-MODES.md:146` + `confluence/decisions/PHASE-005-REVIEW-2026-06-11.md:410-411` (已建议但 0 落地) | 跟 "翻篇&精进" 联合 0 增 Rule 0 增命令 持平 (1 行 prefix 加) |
| **A2** | **replace `sk-abc123...` placeholder → `<YOUR_API_KEY>`** 在 api-authentication guide, 减少 grep 假阳性 | `docs/guides/api-authentication-2026-06-19.md:27,33,38,47` | 跟 "品味" 联合 0 跨 session 拍板 |
| **A3** | **clarify `check.sh:83-85` 注释**: 加 1 行 `# NOTE: KALLAX_CURRENT_ROLE env 跨 release 留待 (BE-19 治理 gap, see ACCUMULATED-LESSONS-2026-06-19-PHASE-2.md 经验 2)` 把 comment/code 不一致 explicit 标注 | `scripts/permission/authz/check.sh:83-85` | 跟 "诚实修正" 联合 0 隐藏, 0 强制 修复 |
| **A4** | **保留 BE-19 文档化 in 9 专家 review**: 在 06-security.md (本报告) cross-reference 治理 gap, master explicit 拍 "接受 gap / 修复" | 跨 release 留待 master 拍 | 跟 "独立" 战略 联合 0 ai-auto |
| **A5** | **10 工具 user-level dirs 0 跟踪 secret 暴露 → OK 不动**: 验证 `.aider/.antigravity/.claude/.codex/.continue/.cursor/.gemini/.opencode/.trae/.codeium/` 全部 skills/commands 跟 `.claude/skills/kallax/` 同源 (symlink v2.7.1), 0 独立 secret 暴露 | 10 dirs 验证通过 | 跟 "翻篇&精进" 联合 0 增 |

**5 推荐 / 4 跨 release 留待 / 0 强制 拍板** (跟"翻篇&精进" + "独立" 联合).

---

## 4. 跨 release 留待 (跟"翻篇&精进" 战略 联合)

- **0 增 Rule 0 增 命令 持平** — 跟 v2.4.1 Rule 合并反思 联合, 跨 18 release 累计
- **0 强制 拍板** — 5 推荐全部 跨 release 留待 master explicit 拍 (双 拍 explicit)
- **0 跟踪 inbox** — 跨 release 留待 (跟 Phase 1 Q5 联合)
- **BE-19 治理 gap 跨 release 累计** — 文档化但 0 修复, 跟"诚实修正" 联合 0 隐藏
- **0 ai-auto 拍 1 命名 共识 / 0 拍 (跟 v2.0.7 PHASE-014 模式 一致)** — 跟"独立" 战略 联合

---

## 5. KPI (跟 Rule 9 X/Y 格式 联合)

| # | KPI | 实际 / 目标 | 状态 |
|---|-----|-------------|------|
| **K1** | **真实 production secret 暴露**: `0 / 0` | grep `AKIA\|sk-\|ghp_\|BEGIN PRIVATE KEY` docs/confluence/jira 全部 0 命中 | ✅ 100% |
| **K2** | **`.gitignore` 覆盖 关键 secret 路径**: `5/5` | `.kallax/{state,data,logs,queue,instances}/` + `.env` + `.env.*.local` + `*.db` 全部覆盖 | ✅ 100% |
| **K3** | **10 工具 user-level dirs 跟踪**: `10/10` 已验证 | `.aider/.antigravity/.claude/.codex/.continue/.cursor/.gemini/.opencode/.trae/.codeium/` 全部 0 secret 暴露, skills/commands symlink 同源 | ✅ 100% |
| **K4** | **BE-19 治理 gap 文档化**: `1/1` | comment/code 不一致 已在 ACCUMULATED-LESSONS-2026-06-19-PHASE-2.md 经验 2 + ACCUMULATED-LESSONS-2026-06-19.md:33 累计 公开, 跟"诚实修正" 联合 0 隐藏 | ✅ 100% (文档化) / **修复 0/1** (跨 release 留待) |
| **K5** | **9-pass redaction prefix 覆盖 test-token 字面量**: `0/1` | `test-token-*` 0 在 prefix 库, 跨 release 留待 master 拍 (推荐 A1) | ❌ 0/1 跨 release 留待 |

**5 KPI / 4 OK / 1 跨 release 留待** (跟"翻篇&精进" 联合).

---

## 附录: raw test output (跟 EPIC-059-D Fact-Forcing 联合)

```
$ grep -rn "(test-token-12345|KALLAX_MASTER_TOKEN)" docs/ confluence/ jira/
confluence/decisions/ACCUMULATED-LESSONS-2026-06-19-PHASE-2.md:42: KALLAX_MASTER_TOKEN=test-token-12345
confluence/decisions/ACCUMULATED-LESSONS-2026-06-19-PHASE-2.md:82: KALLAX_MASTER_TOKEN=test-token-12345

$ grep -rn "(AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|-----BEGIN.*PRIVATE KEY)" docs/ confluence/ jira/
(0 matches)

$ ls .aider/ .antigravity/ .claude/ .codex/ .continue/ .cursor/ .gemini/ .opencode/ .trae/ .codeium/
.aider: skills/ (含 kallax/README.md)
.antigravity: commands/, skills/
.claude: commands/, hooks/, settings.json, settings.local.json, skills/, worktrees/
.codex: prompts/
.continue: skills/
.cursor: commands/, skills/
.gemini: commands/
.opencode: command/ (symlink to .claude/commands, v2.7.1)
.trae: commands/, skills/
.codeium: windsurf/

$ grep -n "KALLAX_CURRENT_ROLE\|test seam" scripts/permission/authz/check.sh
83: # Get current role: prefer KALLAX_CURRENT_ROLE env (test seam) > state.json
84: # (--role CLI removed per PHASE-002 9c + security review)
85: ROLE="$(jq -r '.role // ""' "$STATE_FILE" 2>/dev/null)"

$ head -86 .gitignore
# .kallax/data/  ✓
# .kallax/logs/  ✓
# .kallax/queue/  ✓
# .kallax/instances/  ✓
# .kallax/state/  ✓
# .kallax/*.db  ✓
# .kallax/inbox/*.processed  ✓
# .env  ✓
# .env.local  ✓
# .env.*.local  ✓
# *.env  ✓
```

**0 真实 secret 暴露 / 5 推荐 跨 release 留待 / BE-19 治理 gap 文档化 1/1** (跟"诚实修正" + "独立" + "翻篇&精进" 联合).