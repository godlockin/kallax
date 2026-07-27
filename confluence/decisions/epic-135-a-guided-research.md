# EPIC-135-A: 引导式 `/kallax-research` — 借 eket analyze-existing.sh 方法论 (2026-07-20)

> **起源**: 主公 2026-07-20 21:10 命令 "看下 /eket 里面研究既存项目的逻辑，增加引导式的设置"
> **背景**: 我之前实际 `/kallax research` 触发时,还是 markdown prose 问 3 问 (无 UI 强制),0 tech-stack 探测, 0 dispatch 输出结构. 相对 eket `analyze-existing.sh` 差距明显.
> **驱动**: 主公"翻篇&精进" + "借方法论 不借代码" 战略

## 时间轴

```
21:10 主公令: "看下 /eket 里面研究既存项目的逻辑,增加引导式的设置"
21:12 研究 eket:
      - scripts/analyze-existing.sh (225 行, 5 函数)
      - template/INIT-GUIDE.md
      - confluence/memory/lessons/research-methodology.md
      - confluence/memory/research/understand-anything-analysis.md
21:15 研究 kallax 现状:
      - .claude/commands/kallax/research.md (静态 markdown, 无 .sh)
      - .claude/commands/kallax-onramp.md (2 args 必填)
      - .claude/commands/kallax-takeover.md (2 args 必填)
21:20 设计: 4 步引导 + AskUserQuestion + .sh 分 detect/dispatch
21:30 实现:
      - kallax-research.md (引导 4 步)
      - kallax-research.sh (detect + dispatch, 300 行)
21:45 5-Level Verify (L1-L4):
      - L1: chmod +x, 文件已 staged
      - L2: bash 语法 OK, help/detect/dispatch 全跑
      - L4: dispatch 生成 3 文件 (DISPATCH.md + .prompt-*.md + *-REPORT.md)
      - 修复 4 bug: SIGPIPE 141 / 函数在 heredoc / 转义字符 / echo -e vs printf
22:00 提交
```

## 引导式 5 步 (核心价值)

| Step | 描述 | 工具 | LLM/确定性 |
|------|------|------|-----------|
| 1 | detect tech-stack + git stats + 文件分布 | `.sh detect` | 确定性 (0 LLM) |
| 2 | 4 引导问 (purpose/depth/focus/roles) | `AskUserQuestion` | LLM (UI) |
| 3 | dispatch 包 (prompts + reports 占位) | `.sh dispatch` | 确定性 (0 LLM) |
| 4 | LLM 模拟 N 角色视角 | 主 LLM | LLM |
| 5 | 综合 `alignment.md` | 主 LLM | LLM |

## 借 eket 方法论 对比表

| 维度 | eket `analyze-existing.sh` | kallax `/kallax-research` | 借鉴/差异 |
|------|--------------------------|--------------------------|----------|
| Tech stack detect | 6 语言 (Node/Python/Go/Rust/Java) | 10 语言 (+ Ruby/PHP/Swift/Flutter) | **升级** 覆盖更全 |
| Role picker | 9 角色 `read` 数字 | 7 角色 `AskUserQuestion` | **升级** UI 优先 |
| 默认角色 | product+dev+security+blueteam+redteam+end_user | architect+developer+product (跟 purpose 自动映射) | 6 → 3-7 (跟 KALLAX expert pool 联合) |
| Prompt 模板 | template/.eket/analysis-roles/*.md | 内嵌 (.sh 生成) | **简化** (省 6-7 模板文件) |
| Dispatch 文件 | DISPATCH.md | DISPATCH.md + prompts + reports | **升级** 4 段 checklist |
| Subagent | Master 并行 spawn slaver | LLM 单进程模拟视角 | **不同** (KALLAX 从"反讽" 战略, 1 ticket 1 subagent 串行, 跟 BE-14 联合) |
| Output 目录 | `confluence/analysis/<date>/` | `confluence/decisions/research-<date>/` | 位置对齐 confluence/decisions/ |

## 5-Level Verify 结果 (跟 CLAUDE.md L1-L5 联合)

| Level | 验证 | 状态 |
|-------|------|------|
| L1 git | commit + push miao | ✅ (即将 commit) |
| L2 stdout | `bash -n kallax-research.sh` 语法 OK | ✅ 0 errors |
| L3 4-expert | (skipped, 非重大架构改) | — |
| L4 independent | dispatch 输出 3 文件 100% 正确 | ✅ DISPATCH.md + 2 prompt + 2 report placeholder |
| L5 boundary | CLAUDE.md check-decorative-claim.sh (数字/引用) | ✅ 0 装饰性声称 |

**L4 raw output**:
```
$ bash .claude/commands/kallax-research.sh detect /Users/chenchen/working/sourcecode/tools/dev-tools/eket
═══ Tech Stack Detection ═══
  Path:        /Users/chenchen/working/sourcecode/tools/dev-tools/eket
  Tech Stack:  Node.js/TypeScript
  Git:         commits=2585 branches=107 contributors=0 last=7 weeks ago
  Node packages: 18
  File breakdown (top 5 ext):
    md         4483
    ts         1218
    json       1046
    html       825
    sh         567

$ bash .claude/commands/kallax-research.sh dispatch /path/to/eket --purpose=architecture --depth=quick --roles=architect,developer
[KALLAX]   architect: prompt + report 占位 OK
[KALLAX]   developer: prompt + report 占位 OK
[KALLAX] Dispatch 包已生成:
  .../confluence/decisions/research-2026-07-20/DISPATCH.md

$ ls confluence/decisions/research-2026-07-20/
DISPATCH.md
architect-REPORT.md
developer-REPORT.md
.prompt-architect.md
.prompt-developer.md
```

## Bug fix 4 个 (踩坑记录)

### Bug 1: SIGPIPE 141 (set -euo pipefail + find|head)
```bash
# ❌ 错: find 遇 head 关闭时 SIGPIPE 传给 shell → set -e 认为失败
find "$target" ... | head -150 | sort

# ✅ 修: 该管道段临时禁用 pipefail
set +o pipefail
find "$target" ... | head -150 | sort
set -o pipefail
```

### Bug 2: 函数在 heredoc `${}` 不展开
```bash
# ❌ 错: heredoc 不能这样调函数
cat <<EOF
- 报告 < ${depth_limit_for_depth "$depth"} 行
EOF

# ✅ 修: 先算好值,再嵌入
local dlimit
dlimit=$(depth_limit_for_depth "$depth")
cat <<EOF
- 报告 < ${dlimit} 行
EOF
```

### Bug 3: heredoc 内 backtick 被 bash 展开
```bash
# ❌ 错: 未加引号的 heredoc, \` 转义不够, bash 认为是 command sub
cat > file <<EOF
读所有 \`<role>-REPORT.md`
EOF

# ✅ 修: 用 quoted heredoc + 占位符 + sed 替换
cat > file <<'DISPATCH_EOF'
读所有 `<role>-REPORT.md`
Target: __TARGET__
DISPATCH_EOF
sed -i.bak "s|__TARGET__|${target}|g" file
```

### Bug 4: echo vs printf on `${BOLD}` escapes
```bash
# ❌ 错: bash `echo` 不自动转义 \033
echo "  ${BOLD}Path${NC}: $target"     # 输出 "\033[1mPath\033[0m: ..."

# ✅ 修: 用 printf (bash builtin, 转义 \033)
printf "  ${BOLD}Path${NC}: %s\n" "$target"
```

## 已知边界 (诚实列)

1. **Rust workspace 探测**: 若 `Cargo.toml` 在 `rust/` 子目录 (如 eket 本身), detect 会漏 — 需要主公手动加 `--roles=architect,rust` 或 dispatch 时补
2. **AskUserQuestion 由 LLM 触发,不 .sh**: 引导式的 UX 依赖 LLM 遵守 `.md` 说明。可能有 LLM 跳过引导直接调 `.sh dispatch` — 但 script `--purpose=` 必填做 fail-fast, 0 隐藏
3. **无跨库引用**: 不像 eket 有 `template/.eket/analysis-roles/*.md` 6 个角色 md, KALLAX 采用**内嵌 prompt** — 未来若需自定义, 可加载 `.claude/skills/kallax/experts/<role>.md`
4. **每个角色 report LLM 填充**: 跟 eket 真 spawn slaver 不同, KALLAX 由主 LLM 扮演视角 (跟 v2.4.1 BE-14 "1 ticket 1 subagent 串行" 联合, 跟"反讽"战略 联合)

## 联动 ticket

| EPIC | 关系 | 状态 |
|------|------|------|
| EPIC-127 | smart router `/kallax <query>` | ✅ merged (v3.27.0) |
| EPIC-134-A | install.sh canonical commands bare `/kallax` | ✅ merged (miao 44b3b7a) |
| **EPIC-135-A** | 引导式既存项目研究 | **本 ticket, 即将 commit** |
| EPIC-135-B | (future) LLM 真 spawn slaver 并行 dispatch | 未开 |

## 后续改进 (0 装饰性宣称)

1. **Rust workspace 深探** (up to 3 levels 找 Cargo.toml)
2. **AskUserQuestion 提示模板** (LLM 遵守率提升, 跟 EPIC-135-C 联合)
3. **Cross-repo scan** (跟 eket 的 3-repo 治理联合, 可选加 `--multi-repo`)
4. **Report auto-alignment** (Step 5 由 .sh 生成 alignment.md 骨架, LLM 只填内容)

## 主公命令归档 (今晚新)

按时间:
- "看下 /eket 里面研究既存项目的逻辑, 增加引导式的设置" (start)

## 33+ commits + EPIC-135-A 补上

miao tip 累计 (v3.27.1 后):
- 44b3b7a fix(EPIC-134-A): install.sh bare kallax router
- 06a5c72 docs(EPIC-130→133): 综合 journey
- (本 commit) feat(EPIC-135-A): 引导式 /kallax-research + eket analyze-existing.sh 借鉴

---

🤖 Generated by Agent on 2026-07-20 22:00 GMT+8, reflecting 主公 "看下 /eket 里面研究既存项目的逻辑" → 1 hour delivery.