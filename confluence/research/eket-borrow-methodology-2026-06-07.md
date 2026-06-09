# KALLAX ← EKET 借鉴方法论报告

**Created**: 2026-06-07
**Status**: Analysis Complete — 待 Phase 0 落地
**Author**: KALLAX Master
**Purpose**: 从 eket 既有实践提取「专家体系」与「引导式初始化」可借鉴方法论,映射到 KALLAX gap

---

## 0. 触发与目的

用户请求:「之前在eket里有深度研究既存项目的专家组设定和引导式初始化脚本,我想借鉴过来」

本报告分两段:
- **第 1 段**:本次简短分析(Phase 0 草案),产物即本文
- **第 2 段**:Phase 1-3 深度调研,产物见 `EKET-EXPERT-SYSTEM-DEEP-DIVE-2026-06-07.md`

---

## 1. Eket 3 块可借鉴方法论

### 🔹 块 1:专家 Persona Anatomy(7 节 full / 3 节 minimal)

**Eket 形态**(`experts/default/architect.md`):

```yaml
# 顶部 frontmatter(强制)
id: eket.architect.001        # 命名空间.角色.序号
name: Alex Chen
tier: default                 # default = 7 节 full;optional = 3 节 minimal
rationalizations_count: 6     # 强制 ≥ 6
phase: 1                      # 执行阶段

# 7 节 full anatomy(强制)
1. mantras                    # 3-5 句思维口号
2. personality (INTJ + traits + strengths/weaknesses)
3. background (experience + domain_expertise + notable_skills)
4. thinking_framework (4 个思考维度)
5. analysis_focus (5 个分析锚点)
6. output_format (YAML 多行字符串,锁住输出结构)
7. Common Rationalizations    # LLM 借口 vs 反驳对照表(防绕过)

# 额外强制节
- When to Use / When NOT to Use
- Process (5 步流程)
- Red Flags (5 条)
- Verification (3 个 checkbox,末尾强制)
```

**KALLAX 当前**:`SKILL.md` 只有 1 个命令索引,没有 persona 文件,没有 anatomy 校验。

### 🔹 块 2:引导式初始化 Preamble(二阶段询问)

**Eket 形态**(`SKILL-DETAIL.md#preamble`):

```markdown
当用户要求对**既存项目**进行深度分析时,先 AskUserQuestion:

Q1 分析模式: 借鉴研究 / 接手维护 / 重构评估 / 快速了解
Q2 团队配置: 默认全栈(7 位) / 引导式定制(用户裁剪)
```

**触发条件**:
- 关键词检测:「分析 / 接手 / 重构评估 / 借鉴」
- 先询问再执行,不直接拍脑袋

**执行流程锁定**: Phase1(Architect)→ Phase2(其余并行)→ Phase3(Master 汇总)

**KALLAX 当前**:`/kallax-panel` 直接执行,没有 preamble 询问。

### 🔹 块 3:多项目并行研究(7 项目借鉴扫描)

**Eket 形态**(observation #2725, #2908, #2907):

```
Phase 0: Architect 选定目标(7 个候选项目) + 拆解研究维度
Phase 1: Architect 用 bash 并行扫 7 个 README
Phase 2: 4 专家按领域深入(Backend/Frontend/UX/PM 各看自己的层)
Phase 3: 产出「可借鉴点」+「应避免点」(每项目两列表,非单边赞美)
Phase 4: 具体化为本项目 tickets(TASK-121 沙箱隔离 / TASK-122 技能注册中心)
```

**KALLAX 当前**:`PERMISSION-PANEL-RAW-2026-06-07.md` 是单项目深度研究(就是当前 kallax 自己),没有「跨项目借鉴」流程。

---

## 2. 3 块方法的 KALLAX 移植优先级

| 优先级 | 块 | 价值 | 实施成本 | 建议 |
|---|---|---|---|---|
| **P0** | 引导式 Preamble(块 2) | 极高 — 避免 LLM 拍脑袋,降低误用率 | 低 — 改 SKILL.md 几行 + 加 AskUserQuestion 触发器 | **首批做** |
| **P1** | 专家 Persona Anatomy(块 1) | 高 — 把 5 专家从「名字」升级为「可校验的独立人」 | 中 — 7 个 `.md` + 1 个 anatomy check 脚本 | **第二批做** |
| **P2** | 多项目借鉴研究(块 3) | 中 — 偶尔用,但能把"我们怎么知道做对"问题外部化 | 中 — 流程化,不写新工具 | **第三批做** |

---

## 3. 立即可落地的 3 件事(Phase 0 草案)

| # | 动作 | 文件 | 大小 | 备注 |
|---|---|---|---|---|
| 1 | 在 `/kallax-panel` 和 `/kallax-expert` SKILL.md 加 Preamble 段 | `SKILL.md` 改 ~30 行 | 小 | 关键词触发 → AskUserQuestion → 选模式 |
| 2 | 5 位专家拆出独立 `.md` 档案(`experts/default/{architect,backend,frontend,ux,product}.md`) | 新建 5 文件 | 中 | 7 节 full anatomy,加 rationalizations × 6 |
| 3 | 加 `scripts/check-skill-anatomy.sh` | 新建 1 脚本 | 中 | CI/手动跑,5/5 PASS 才合规 |

---

## 4. 灵感来源 vs 避免(避免照搬)

| Eket 的 | KALLAX 借鉴的 | 避免照搬的 |
|---|---|---|
| 7 位 default + 53 optional | 5 位 default + 视情况扩 | 别一次堆 7 位(我们规模小) |
| YAML 多行字符串锁输出 | 借鉴:在 persona 内 `output_format:` 锁住 | 别强加 persona 给 LLM 制造压力 |
| 强制 6 个 rationalizations | 借鉴:防 LLM 借口绕过 | 别超过 8 个,会变空文 |
| Preamble 询问 | **直接搬**(成本最低价值最高) | 别扩展成 3 问(摩擦过高) |
| 多项目研究 7 个 | 借鉴:每次研究 ≤ 3 个项目 | 别全 7(成本爆炸) |

---

## 5. 下一步选项

| 选项 | 动作 |
|---|---|
| **A. Phase 0 立即做(块 1 + 块 2)** | 先建 Preamble 触发器 + 5 个 expert persona(7 节 anatomy) + anatomy check 脚本。约 1-1.5h |
| **B. 只做 Preamble 块 2** | 最低成本:在 SKILL.md 加 ~30 行 Preamble,其他保持原样 |
| **C. 先看 eket 完整 persona 模板** | 把 5 位 eket 专家的 `output_format` + `rationalizations` 章节拉出来给用户评估 |
| **D. 转给 Performer 落地** | 派工单给 Conductor 派发,Master 不写代码 |

---

## 6. 相关产物

- **本报告路径**: `confluence/decisions/EKET-BORROW-METHODOLOGY-2026-06-07.md`
- **后续报告路径(待生成)**: `confluence/decisions/EKET-EXPERT-SYSTEM-DEEP-DIVE-2026-06-07.md`
- **上游引用**: `confluence/decisions/PERMISSION-MODEL.md`(本次触发的起源是 PERMISSION 调研)
- **eket 源文件**:
  - `~/.claude/skills/eket/SKILL-INDEX.md`
  - `~/.claude/skills/eket/SKILL-DETAIL.md#preamble`
  - `~/.claude/skills/eket/META-GUIDELINES.md`
  - `~/.claude/skills/eket/experts/default/INDEX.md`
  - `~/.claude/skills/eket/experts/default/architect.md`(范本)

---

**Reviewer(s)**: master_main
**Last updated**: 2026-06-07
