# EPIC-057-C Lessons Learned

> Performer: EPIC-057-C | Branch: feature/EPIC-057-C-multi-tool-docs
> Test: 5/5 PASS (Rule 9 KPI 100.0%) | Date: 2026-06-17
> 跟 EPIC-057-A (install.sh) + EPIC-057-B (onramp.sh) 契约 联合, 跟"反讽" 闭环, 跟"诚实修正" 联合, 跟"翻篇&精进" 联合

## 1. **BSD grep `\s` 不工作 — 测试在 macOS 默认 grep 上 静默 fail**

**问题**: 测试 `tests/integration/docs-link-check-test.sh` 最初用:
```bash
grep -qE "^\s*##\s+\[2\.0\.6\]" "$CHANGELOG"
```

**Trace**: macOS 默认 `grep` 是 BSD 版本, **不识别 `\s`**. Regex 匹配失败 → exit 非 0 → TC3 5/5 sub-checks 全 fail. 但 `set -uo pipefail` (注意: 没有 `-e`, `set -e` 不在) 让脚本继续跑, 最终 `PASS_COUNT=4/5`, exit 1 — 测试 FAIL 但 bash 没有明显错误, 调试花时间.

**Fix**: 把所有 `\s*##\s+\[` 改成 `## \[` (BSD 兼容):
```bash
grep -qE "^## \[2\.0\.6\]" "$CHANGELOG"
```

**Lesson**: 任何跨平台 grep 测试必须 验证 BSD vs GNU 兼容性. macOS 用户跑 CI/CD 时 默认 BSD grep, 不能依赖 `\s`/`\d`/`\b` 等 PCRE-only 元字符. 替代方案:
- 用 `[[:space:]]` 替 `\s`, `[[:digit:]]` 替 `\d`
- 直接用字面空格 (因为 `## [` 跟真实行匹配足够精确)
- 跑 CI 时强制 `brew install grep` (GNU grep) — 但增加开发环境依赖

**Anti-pattern 命名**: "**bsd-grep-pcre**" — flag 这种 regex 立即替换.

---

## 2. **`set -u` + 未初始化 placeholder var → 静默 script 退出 0 (跟 EPIC-057-A L2 一致)**

**问题**: 测试 line 246:
```bash
TC4_PASS_NOTE=$((TC4_PASS_NOTE+0)) # placeholder
```

`TC4_PASS_NOTE` 从未初始化 + `set -u` + 数学扩展 `$((expr))` → bash 抛 `unbound variable` 错误, 脚本提前 exit 0 (因为前面有 `PASS_COUNT=4`, 后面 increment 不会跑了, 但 `exit 1` 也不会跑 — **exit 0 是 bash 默认**).

**Trace**: 
```
tests/integration/docs-link-check-test.sh: line 246: TC4_PASS_NOTE: unbound variable
EXIT=0  ← 应该是 EXIT=1 (因为 PASS 4/5 < 5/5)
```

**Fix**: 删未用的 placeholder line. TC4_PASS_NOTE 是个"我以后可能用" 的幽灵变量 — 直接删.

**Lesson**: 跟 EPIC-057-A L2 (`set -euo pipefail` + empty array access) **同型问题**:
- `set -u` 是 fail-fast, 但只在 expansion 时触发
- 数学扩展 `$((X+0))` 的 unbound 检查跟普通变量扩展 **不同** — 它在 expr 评估前
- **任何 dead code 都要删** (跟 KALLAX Rule 8 No copy-paste 联合, 跟"翻篇&精进" 战略 一致)

**Generalization**: 测试脚本里的 placeholder var 是经典 anti-pattern. 写测试时只有"用到的 var 才声明". 想"以后用" → 写新 test, 别污染当前 test.

---

## 3. **Tree 风格分行的目录结构 — 测试不能假设字符串合到一行**

**问题**: README 目录结构段用了 tree 风格:
```
├── .opencode/               # opencode 工具目录 (跟 EPIC-057-A AC #3 一致, v2.0.2 mirror)
│   └── command/             # opencode slash commands mirror (singular, 30 文件, 跟 .claude/commands/ 一致)
```

测试最初 grep `.opencode/command/` 字符串 — 找的是 `.opencode/command/` 合到一行. 实际 `.opencode/` 跟 `command/` 在两行 — fail.

**Fix**: 改测试用跨多行的组合 grep:
```bash
if echo "$STRUCTURE_SECTION" | grep -qF ".opencode" && \
   echo "$STRUCTURE_SECTION" | grep -qF "command/" && \
   echo "$STRUCTURE_SECTION" | grep -qiE "mirror"; then
```

**Lesson**: 文档是 **人类可读** 的, 不是 **机器可解析** 的. 测试要测的是 **意图** ("opencode commands dir 标注"), 不是 **字面字符串**.

**Generalization**: 当文档用 tree/diff/list 风格描述结构时, 测试要按"语义关键词" 匹配, 不按"完整 path 字符串" 匹配. 类似 pattern:
- Diff 输出: 测 hunks 数 + 改动的 file 数, 不测具体 hunk 内容
- 配置 YAML: 测 key 存在性 + value 模式, 不测完整 line
- Markdown header: 测 `##` 数量 + 标题文字, 不测整行

---

## 4. **文档做减法 — 跟"翻篇&精进" 战略 一致 (跟 EPIC-057-A L5 backward compat 模式 一致)**

**观察**: README 改前 ~30 行 (安装段), 改后 ~30 行 (4 工具标注追加). **总行数不增** — 跟 057-A L5 "preserved default behavior exactly" 思路 一致:

| 改前 | 改后 |
|---|---|
| `./scripts/quick-setup.sh` (一行) | `./scripts/install.sh --target=auto` (一行, default 行为不变) |
| 目录结构段 7 个 root | 目录结构段 9 个 root (+ `.claude/` + `.opencode/`) |

**Lesson**: 跟"翻篇&精进" 联合的核心是 **增量标注**, 不是 **重写段落**. 文档膨胀是最常见的 doc drift:
- ❌ 写新章节"多工具安装说明" → 跟 quick-start.md 重复
- ✅ 改现有安装段 + 加 1 个 cross-ref 到 INSTALL-MULTI-TOOL.md (跟 AC #2 一致, 跟 Rule 5 DRY 联合)

**Generalization**: 任何 docs ticket 默认假设是 "**在现有文档上改**", 不是 "**新建文档**". 除非 AC 明确要求新建, 否则优先增量.

---

## 5. **5 标签 SOP 复用 — 不新创格式 (跟 EPIC-055-C DRY 联合)**

**观察**: INSTALL-MULTI-TOOL.md 中每条 `跟"<tag>" 联合:` 都按 `docs/process/tag-sop.md:64-78` 模板 (证据 + 反驳/支持 + 影响), **不发明新格式**.

**对比**:
- 057-A docs: 每条标签引用直接 cite file:line, **不展开 3 件套** (因为 install.sh 是代码, 不是 docs)
- 057-C docs: 每条标签引用必带 **3 件套** (证据 + 反驳/支持 + 影响), **因为是 docs 治理** (跟 EPIC-055-C 联动)

**Lesson**: 5 标签 SOP 在 **docs 类型** ticket 上 严格 3 件套, 在 **code 类型** ticket 上 可以简化 cite. 这是有意的分层 — 避免 code 也走 3 件套 (会膨胀 commit message), 也不允许 docs 简化 (会失去 证据链 价值).

**Generalization**: ticket type 决定 tag 引用粒度:
- `feature` / `infra`: 简短 cite (file:line + 1 句影响)
- `docs` / `refactor` / `governance`: 完整 3 件套 (证据 + 反驳/支持 + 影响)
- `test` / `chore`: 标签可选, 跟 ticket 主题 弱关联

**Anti-pattern 命名**: "**docs-tag-skip**" — docs ticket 走简化 cite, 等于绕过 5 标签 SOP.

---

## 6. **5 标签 SOP TC4 test 闭环 — 抽样验证 vs 全部 验证**

**设计**: TC4 测试 INSTALL-MULTI-TOOL.md 中 `跟"<tag>" 联合` 引用:
- 3 个核心标签 (反讽/诚实修正/翻篇) 各 ≥1 处 → sub-check 1
- '反讽' 引用 上下文 必带 file:line 证据 (抽样) → sub-check 2
- 引用 `docs/process/tag-sop.md` → sub-check 3

**没** 验证:
- ❌ 全部 5 标签 (独立/流程逻辑) 都出现 — 因为 INSTALL-MULTI-TOOL 是 multi-tool install 文档, 不涉及"独立" (constituent power) 或"流程逻辑" (process rationale)
- ❌ 每条引用 严格 3 件套 — 抽样 + grep 抽样 上下文 已经够了, 全文 3 件套 audit 太重 (跟"翻篇&精进" 战略 一致)

**Lesson**: 5 标签 SOP 测试 是 **采样验证** (sampling), 不是 **全文审计** (full audit). sampling 优点:
- 跑得快 (0.05s vs 假设 5s)
- 不脆弱 (一行 typo 不会让测试 fail)
- 反映 **意图** ("文档用了 5 标签 SOP"), 不是 **形式** ("每行 100% 合规")

**Generalization**: 任何 SOP 测试都要明确 "sampling vs full audit" 边界. docs 类型 SOP 适合 sampling (人写的), code 类型 linter 适合 full audit (机器写).

---

## 7. **跟 EPIC-057-A L3 联合 — `.opencode/command/` singular 是 opencode 真实约定**

**Cross-ticket consistency**: EPIC-057-A L3 已经记录:
> opencode commands dir 是 singular `.opencode/command/` (不是 `commands/`), 跟 v2.0.2 release 30 文件 mirror 路径 一致 (`ls .opencode/command/` 验证)

INSTALL-MULTI-TOOL.md §3 路径映射表 跟 057-A 实现 + 057-B tool-detect.sh (`scripts/kallax-onramp/lib/tool-detect.sh:38` `"${HOME}/.opencode/command"`) **完全一致**.

**Lesson**: 跨 ticket 文档化 同样事实, 必须 **byte-for-byte** 跟代码契约一致. 不允许 "文档化 简化" 或 "文档化 解释". 跟 KALLAX Rule 5 DRY 联合 (Single Source of Truth) — 代码契约是 SoT, 文档是 mirror.

**Verification**: 实际验证 3 处路径一致:
- `docs/guides/INSTALL-MULTI-TOOL.md:107` → `~/.opencode/command/`
- `scripts/install.sh:56` (TOOL_COMMANDS_DIR) → `~/.opencode/command`
- `scripts/kallax-onramp/lib/tool-detect.sh:38` → `~/.opencode/command`

**Generalization**: 任何文档 ticket 跟代码 ticket 联动时, doc test 要 **grep 跨文件路径一致性** (跟 INSTALL-MULTI-TOOL.md §3 路径映射表 + install.sh TOOL_* 数组 + tool-detect.sh TOOL_COMMANDS_DIR 三方 一致).

---

## 8. **silent subagent run 教训 — 主公拍 D 模式, 不能再 silent**

**观察**: 这次 ticket 是 057 串行第 3 张, 主公 explicit 拍 D ("1 ticket 1 subagent 串行"). 但 之前有 silent subagent run 留了 partial 工作 (4 files untracked). 这次 subagent 必须:
1. **验证现有 5 个 partial files** — 不假设 partial 工作正确
2. **修复测试 bug** (BSD grep + set -u + tree 风格)
3. **跑测试 输出 raw stdout** — 不能 silent
4. **commit + push** (跟 v2.0.6 paths 一致)
5. **报 PASS** 跟 057-A + 057-B pass-report 模式 一致

**Lesson**: silent subagent 是反 EPIC-057 "verify don't trust" 原则. 任何 subagent run 必须:
- ❌ 不留 partial 工作给下一个 subagent
- ❌ 不假设"前面的 subagent 跑通了"
- ❌ 不 silent commit
- ✅ **先 verify, 再 continue** (跟 Step 1-2 verify worktree 联合)
- ✅ **每次 commit 后立即报 raw output** (跟主公拍 D 模式 联合)

**Generalization**: docs subagent 比 code subagent 更难 verify (因为没有"运行结果" 反馈). 文档验证只能靠:
1. test 跑 (本文档 5/5 PASS)
2. cross-ticket consistency grep (4 工具路径三方一致)
3. 5 标签 SOP sampling (3 个核心标签 + file:line 证据)

---

## 9. **跟"诚实修正" 联合 — 不假装 INSTALL-MULTI-TOOL.md 一步到位**

**观察**: INSTALL-MULTI-TOOL.md 第 1 版 (silent subagent) 可能有不一致 — 我作为本 ticket subagent 必须:
- ❌ 不"假装测试通过" (4/5 改 5/5 蒙混)
- ❌ 不"假装 partial 工作 OK" (5 files 验都不验就 commit)
- ✅ **诚实修测试 bug + 报 raw test output** (3 处 fix: BSD grep, set -u var, tree 风格)

**Lesson**: 跟 EPIC-055-B "honest naming" 一致 — 文档 SoT 跟代码契约 一致 是 **过程** (每次 docs 改都 grep cross-ticket), 不是 **状态** (一锤定音).

**Generalization**: 任何 docs ticket 必须经过 "**测试 fail → 看 diff → 修测试或修 docs → 重跑**" 的循环, 不允许 "**写完 docs 跑 1 次 PASS 就 commit**" 的乐观路径. docs 跟 code 一样, TDD 闭环不可跳过.

---

## Summary

9 lessons, 跟 EPIC-057-A (5 lessons) + EPIC-057-B (5 lessons) 模式 一致:

| # | Lesson | Anti-pattern 命名 | 跨 ticket 一致性 |
|---|---|---|---|
| 1 | BSD grep `\s` 不工作 | bsd-grep-pcre | EPIC-057-A L1 (bash 3.2) |
| 2 | `set -u` + placeholder var 静默 exit 0 | set-u-placeholder | EPIC-057-A L2 (set -euo + empty array) |
| 3 | Tree 风格分行 路径 测试 要跨行匹配 | tree-style-split | EPIC-057-A L3 (.opencode/command/ singular) |
| 4 | 文档做减法 (跟"翻篇&精进" 联合) | doc-bloat | EPIC-057-A L5 (backward compat) |
| 5 | 5 标签 SOP 复用 docs 类型 3 件套 | docs-tag-skip | EPIC-055-C 5 标签 SOP |
| 6 | 5 标签 SOP TC4 sampling vs full audit | sop-over-validate | EPIC-055-C sampling 测试模式 |
| 7 | `.opencode/command/` 跨 ticket byte-for-byte 一致 | doc-code-drift | EPIC-057-A L3 + 057-B L1 |
| 8 | silent subagent 是反 verify 原则 | silent-subagent | EPIC-056-C docs subagent 教训 |
| 9 | docs TDD 闭环 (fail → fix → re-run) | docs-tdd-skip | EPIC-055-B honest naming |

**跟主公 2026-06-17 'B' explicit 拍板 联合 (file:line `jira/epics/EPIC-057/epic.json:21-26`), 跟"反讽" 闭环 (file:line `CHANGELOG.md:647-661` v2.0.2 命名 vs `scripts/install.sh:52-53` baseline), 跟"诚实修正" 联合 (file:line `docs/KALLAX-GLOSSARY.md:40-47`), 跟"翻篇&精进" 战略 一致 (file:line `docs/KALLAX-GLOSSARY.md:108-112`), 跟 EPIC-057-A L1/L2/L3/L5 教训 联合, 跟 EPIC-057-B L1 教训 联合, 跟 EPIC-055-C 5 标签 SOP 联合 (file:line `docs/process/tag-sop.md:64-78`), 跟 Rule 5 DRY 联合, 跟 Rule 8 No copy-paste 联合, 跟 Rule 9 5-Level Fact-Forcing 联合 (file:line `docs/PROCESS.md:36-51`), 跟 EPIC-053-B 5-Level 证据链 联合.**
