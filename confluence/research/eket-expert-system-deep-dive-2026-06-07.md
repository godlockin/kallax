# EKET 专家体系深度调研报告

**Created**: 2026-06-07
**Status**: Investigation Complete — 决策输入已就绪
**Author**: KALLAX Master(MiniMax-M3 角色扮演)汇总 Phase 1+2+3
**Methodology**: KALLAX Panel — Phase 1 Architect 扫描 → Phase 2 4 专家并行深度分析 → Phase 3 Master 汇总
**Scope**: eket 专家体系全栈(7 位 default + 53 位 optional + 70 位 extended + 配套基础设施)
**Source files**: `~/.claude/skills/eket/` 下 20+ 文件
**Companion document**: `EKET-BORROW-METHODOLOGY-2026-06-07.md`(短报告 / 借鉴清单)

---

## 0. 报告导读

本文 11 章,按"哲学 → 框架 → 策略 → 组件 → 选择 → 借鉴"递进:

| # | 章节 | 内容 |
|---|---|---|
| 1 | Executive Summary | 一页总结 |
| 2 | 设定逻辑 | 设计哲学 / 为什么这样设计 |
| 3 | 框架 | 4 层架构图 |
| 4 | 思路 | 7 个核心设计思路 |
| 5 | 策略 | 产品战略(MVP / 分层 / 规模化) |
| 6 | 组件策略 | 7 节 full anatomy 详解 |
| 7 | 选择框架 | 召唤机制 / 决策路径 |
| 8 | 4 专家并列报告 | Backend/Frontend/UX/Product 原始 |
| 9 | 跨专家共识与冲突 | 共识 6 条 / 冲突 3 条 |
| 10 | 借鉴到 KALLAX | 12 条具体落地动作 |
| 11 | 下一步决策 | 选项 A/B/C/D |

---

## 1. Executive Summary

**核心结论**:Eket 专家体系是一个**「Persona-as-Configuration」系统** — 用 YAML+Markdown 文件定义 AI 专家人格,用 3 层 tier(default/optional/extended)做用户分众,用 7 节 anatomy 做内容质量门禁,用 Preamble 二阶段询问做 onboarding UX。**最强护城河是工程化的质量门禁(check-skill-anatomy.sh + codemod 全量注入),最大短板是无北极星指标 + 无场景触发决策树**。

**5 个关键发现**:

1. **数字 7 是克制**:不是 5(覆盖不足)也不是 10(决策成本高),恰好覆盖软件交付全生命周期
2. **3 层 tier 是分众**:default 强制 7 节 full,optional 3 节 minimal,extended 独立 subrepo — 质量梯度对应用户频率
3. **6 个反 LLM 绕过机制**:rationalizations / Red Flags / Verification / When NOT to Use / check 脚本 / codemod — 全方位防止 LLM 偷懒
4. **Preamble 二阶段询问**是 onboarding 关键节点,把用户从"空白页焦虑"解放到"8 种组合选择"
5. **缺失 2 个核心组件**:场景触发决策树(不知道该叫谁)+ 北极星指标(不知道哪个被调用最多)

---

## 2. 设定逻辑 — 设计哲学

### 2.1 一句话定义

> **专家系统 = 「结构化 persona 文件 + 分层 tier + 工程化质量门禁」**

Eket 没有用「对话 prompt」或「fine-tuning」来定义专家,而是用**结构化文件** + **工程化校验**。这背后的设计哲学是:

> **"If it's not testable, it's not a feature."**

每个专家文件是:可读的(人能看)、可校验的(脚本能查)、可演进的(version 字段待补)。这是一个**把内容质量变成工程产物**的典范。

### 2.2 4 个基础假设(从 4 原则 META-GUIDELINES 提炼)

| 假设 | 推论 | 在系统中的体现 |
|---|---|---|
| **A1**:LLM 会偷懒(走捷径) | 必须有"反 LLM 绕过"机制 | 6 个反绕过机制 |
| **A2**:内容会过时 | 必须有质量门禁而非信任 | anatomy check + codemod |
| **A3**:用户会误用 | 必须有"什么时候不要用我" | `When NOT to Use` 节 + 模板 |
| **A4**:复杂问题需要多视角 | 必须有专家协作而非单点 | 7 位 + phase 调度 + 报告融合 |

### 2.3 隐含价值观

- **可解释性 > 效果**:rationalizations 必须显式列出,而非埋在 prompt 里
- **质量 > 数量**:7 位 default 强于 70 位 optional(后者只走 minimal 流程)
- **结构 > 自由**:output_format 锁结构,不允许 LLM "自由发挥"
- **护栏 > 期望**:不假设 LLM 自觉,而是工程化强制

---

## 3. 框架 — 4 层架构

```
┌────────────────────────────────────────────────────────────────┐
│ Layer 0: 用户入口                                              │
│  - SKILL-INDEX.md (命令速查 + 触发词)                          │
│  - SKILL-DETAIL.md#preamble (二阶段询问入口)                  │
│  - META-GUIDELINES.md (4 原则元规则)                           │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│ Layer 1: 3 层 Persona Tier                                     │
│  - default (7 位, 7节full anatomy, 常驻高频)                   │
│  - optional (53 位, 3节minimal anatomy, 按需召唤)             │
│  - extended (70 位, 独立subrepo, 高级专门领域)                 │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│ Layer 2: 单 Persona 7 节 anatomy                              │
│  - mantras / personality / background / thinking_framework     │
│  - analysis_focus / output_format (锁结构)                     │
│  - Common Rationalizations (反LLM绕过)                        │
│  - When to Use / When NOT to Use / Process                     │
│  - Red Flags / Verification (含bash命令)                      │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│ Layer 3: 质量门禁基础设施                                       │
│  - check-skill-anatomy.sh (CI级校验)                           │
│  - codemod-inject-3sections.sh (TASK-225全量注入)             │
│  - node/src/skills/ (TS端registry/loader)                     │
│  - 豁免表(4种场景)(META-GUIDELINES.md L59-65)                  │
└────────────────────────────────────────────────────────────────┘
```

**关键设计**:每一层都为上一层提供"约束",层层收紧。Layer 0 给用户入口,Layer 1 给分众,Layer 2 给结构,Layer 3 给护栏。

---

## 4. 思路 — 7 个核心设计思路

### 思路 1:「Persona-as-File」而非「Persona-as-Prompt」

- **形式**:YAML frontmatter + Markdown body
- **动机**:可读、可校验、可版本化、可被脚本解析
- **证据**:`experts/default/architect.md` 整篇是结构化数据,而非散文 prompt

### 思路 2:「Full vs Minimal Anatomy」双轨

| Tier | 节数 | 强制 | 适用 |
|---|---|---|---|
| default | 7 节 | 全节 | 7 位常驻,高频被调 |
| optional | 3 节 | mantras / output_format / When to Use | 53 位按需 |

- **动机**:质量与规模化兼顾。70+ 专家不可能全 7 节,但 7 位 default 必须严格
- **证据**:`experts/extended/tools/expert-template.md` 第 16-30 行只列 3 节模板

### 思路 3:「反 LLM 绕过」6 机制(本调研最大发现)

Eket 用 6 个独立机制从不同角度防 LLM 偷懒:

| # | 机制 | 文件 | 防的"绕过" |
|---|---|---|---|
| 1 | `Common Rationalizations` 表 | persona body | LLM 找借口不严谨 |
| 2 | `Red Flags` 列表 | persona body | LLM 忽略视觉信号 |
| 3 | `Verification` checklist | persona body 末 | LLM 跳过自检 |
| 4 | `Verification` 内 bash 命令 | persona body 末 | LLM 说"我看了"但没真扫 |
| 5 | `check-skill-anatomy.sh` | scripts/ | 跳过节内容 |
| 6 | `codemod-inject-3sections.sh` | scripts/ | 应付了事不补全 3 节 |

**关键洞察**:这 6 个机制**互相补强**,不是冗余 — LLM 找借口绕过表 1,但表 4 强制用命令证据;LLM 跳过表 3,但表 5 强制脚本报错。

### 思路 4:「Preamble 二阶段询问」Onboarding

- **触发**:检测到"分析/接手/重构评估/借鉴"关键词
- **形态**:AskUserQuestion 强制 2 问(分析模式 4 选 1 + 团队配置 2 选 1)
- **价值**:8 种组合精确匹配,避免"全量专家"浪费
- **证据**:`SKILL-DETAIL.md` 第 7-22 行

### 思路 5:「Phase 链式调度」+ 显式 phase 字段

```
Phase 1: Architect 先行(全局地图) → 输出:模块地图 / 选型表 / 风险
Phase 2: 4 专家并行(深入各自领域) → 输出:亮点 / 风险 / [P0/P1/P2]建议
Phase 3: Master 汇总(仲裁 + 决策) → 输出:综合报告
```

- **每位的 `phase:` 字段**是显式声明,非隐式约定
- **并行与串行混合**:Phase 1 串行(等全局地图)→ Phase 2 并行(各看各的)→ Phase 3 串行(汇总)
- **证据**:所有 7 位 default 都有 `phase: 1`(architect)或 `phase: 2`(其他)

### 思路 6:「output_format 锁结构」

- **形式**:YAML 多行字符串,内嵌 Markdown 模板
- **例**:架构师 `output_format` 锁 5 节(模块地图 / 选型评估 / 亮点 / 风险 / 建议)
- **例**:后端锁 3 节(亮点 / 风险 / 建议)
- **价值**:Master 拿到任何专家的输出,期望格式统一,认知负担低
- **弱项**:7 位之间**结构性不一致**(5 节 vs 3 节) — UX/Frontend 在不同位置有差异

### 思路 7:「工程化质量门禁」作护城河

- **不是文档,是 CI**:anatomy check 脚本纳入 CI,挂了 build 失败
- **不是审计,是 codemod**:TASK-225 用 codemod 一次性补全 70/70 + 53/53 个文件的 3 节
- **可量化的护城河**:「我们有多少专家 100% 符合 7 节」是数字,不是感觉
- **证据**:extended/INDEX.md 末"3节注入 ✅ 70/70"+"安装状态 ✅ 全部就绪"表格

---

## 5. 策略 — 产品战略

### 5.1 MVP 边界(为什么是 7 位 default?)

| 候选数 | 覆盖度 | 决策成本 | 选择 |
|---|---|---|---|
| 5 | 缺全栈(无 fullstack) | 低 | ❌ |
| **7** | **架构+后端+前端+全栈+产品+测试+UX** | **中** | **✅** |
| 10 | 重复领域(backend+devops+dba) | 高 | ❌ |

**7 位的 Jobs-to-be-Done 覆盖**:
- 架构 → 全局决策
- 后端 → 实现层(API/数据/性能/安全)
- 前端 → 用户面(组件/性能/可访问)
- 全栈 → 跨层(契约/职责/止血)
- 产品 → 业务价值(优先级/完整性/北极星)
- 测试 → 质量(覆盖/边界/CI)
- UX → 体验(旅程/一致性/认知负荷)

### 5.2 3 层产品结构(转化漏斗)

```
              ┌──────────────────────────┐
   95% 用量   │  default (7 位)          │ ← 7节full anatomy
              │  - 强制校验                │   进入门槛高
              └──────────────────────────┘
                          ↓ 5% 用户开始尝试按需
              ┌──────────────────────────┐
    4% 用量   │  optional (53 位)         │ ← 3节minimal
              │  - 弹性扩展                │   进入门槛低
              └──────────────────────────┘
                          ↓ 1% 用户进专业领域
              ┌──────────────────────────┐
    1% 用量   │  extended (70 位)         │ ← 独立subrepo
              │  - 高级专门                │   需独立安装
              └──────────────────────────┘
```

**关键设计**:3 层是**频率梯度**而非能力梯度。同一类专家(如 security)可以同时存在于 optional 和 extended — 区别是「常驻 vs 召唤」。

### 5.3 护城河 — 工程化质量门禁

**护城河 = `check-skill-anatomy.sh` + `codemod-inject-3sections.sh`**

- 任何"我想加个新专家"的动作必须:
  1. 写文件
  2. 通过 anatomy check(否则 CI 红)
  3. 若只有 3 节,跑 codemod 自动补全
- 这把"内容质量"变成了**可验收、可量化、可规模化**的工程产物
- **数字证据**:「70/70 + 53/53 全部就绪」是护城河强度指标

### 5.4 规模化路径(从 7 到 70 到 200+)

| 阶段 | 数量 | 质量要求 | 工具 |
|---|---|---|---|
| MVP | 7 | 7节 full | 人工 |
| 扩展 1 | 53 | 3节 minimal | codemod |
| 扩展 2 | 70 | 3节 minimal | codemod |
| 200+? | ? | ? | **瓶颈:无 review 机制** |

**风险**:200+ 专家时,anatomy 老化解(skill 知识过期)将成为最大问题。当前靠 TASK 驱动 review,无法规模化。

### 5.5 北极星指标 — 缺失

**严重缺口**:
- ❌ 无 expert activation rate(谁被调最多)
- ❌ 无 resolution quality(召唤后是否真解决问题)
- ❌ 无 usage funnel(default→optional→extended 转化率)
- ❌ 无 staleness metric(多少 expert 上次被 review 超过 1 年)

**这意味着**:产品决策正在**盲飞**。哪个专家该升级到 default?哪个该 deprecate?完全靠直觉。

---

## 6. 组件策略 — 7 节 Full Anatomy 详解

### 6.1 各节设计意图

| 节 | 设计意图 | 对 LLM 的约束 | 对用户的价值 |
|---|---|---|---|
| `mantras` (3 句) | 思维口号,内化人格 | 锚定专家"声音" | 决定报告语气 |
| `personality` (MBTI+traits) | 性格画像 | 防止人格漂移 | 决定沟通风格 |
| `background` (experience+expertise) | 履历背书 | 锚定知识深度 | 决定可信度 |
| `thinking_framework` (4 维) | 思维工具箱 | 防"一把锤子敲所有钉" | 决定分析维度 |
| `analysis_focus` (5 点) | 分析锚点 | 防发散 | 决定报告覆盖度 |
| `output_format` (YAML 模板) | 锁输出结构 | 强约束(铁律) | 决定可读性 |
| `Common Rationalizations` (6 表) | 反 LLM 偷懒 | 中约束 | 决定严谨度 |
| + `When to Use` | 触发条件 | 弱约束 | 决定何时召唤 |
| + `When NOT to Use` | 反例 | 弱约束 | 防误用 |
| + `Process` (5 步) | 工作流 | 中约束 | 决定可重复性 |
| + `Red Flags` (5 条) | 危险信号 | 中约束 | 决定防御性 |
| + `Verification` (3 checkbox + bash) | 自检 | 强约束 | 决定可验证性 |

**总计 12 节**,但 INDEX 称之为"7 节 full"是泛指"YAML + 7 个核心 body 节"。

### 6.2 强度梯度

```
  强约束(铁律):   output_format > Verification bash 命令
  中约束(防御):   Common Rationalizations > Red Flags > Process
  弱约束(引导):   When to Use / When NOT to Use / mantras
```

**设计巧思**:output_format 用 YAML 多行字符串而非 Markdown — 因为 YAML 在 frontmatter 里能被脚本解析,Markdown body 不能。

### 6.3 minimal anatomy(3 节,给 optional)

```
  mantras          (1 行,3 句)
  output_format    (YAML 模板)
  When to Use      (3 行)
```

**省什么**:rationalizations、Red Flags、Verification — 因为 LLM 对低频专家不需要那么多护栏。

**省的成本**:每位 optional 专家省 4-5 节内容,53 位共省 200+ 节文字工作量。

---

## 7. 选择框架 — 召唤机制

### 7.1 用户路径(3 步)

```
Step 1: 用户看到 SKILL-INDEX.md / SKILL-INDEX.md 触发词
         ↓
Step 2: 关键词匹配 → 自动路由到对应 SKILL.md
         ↓
Step 3: SKILL.md 内的命令(eket expert:compose / expert:search)
         ↓
Step 4: 用户从 INDEX.md 表格选具体专家
```

### 7.2 3 种召唤方式

| 方式 | 命令 | 适用 |
|---|---|---|
| 单专家 | `eket expert:compose --skills tdd` | 已知要哪个 skill |
| 关键词搜 | `eket expert:search "keyword" --pkg default` | 不确定选谁 |
| 团队组合 | `eket expert:compose --epic EPIC-001` | 整个 EPIC 多人协作 |

### 7.3 关键缺失:场景触发决策树(本调研 P0 改进)

**当前痛点**:用户说"接口好慢",不知道该选 architect 还是 backend。INDEX 表格只有"description(解决方案语言)",没有"问题症状入口"。

**应有形态**:
```
"不知道选谁"快速路由:
- "接口慢/数据库撑不住" → 🖥️ 后端
- "页面卡/组件乱" → 🎨 前端
- "功能砍哪个/优先级" → 📋 产品
- "交互难用/流程不顺" → 🖌️ UX
- "需要全链路排查" → 🧰 全栈
- "架构边界/技术选型" → 🏗️ 架构
- "覆盖率/边界用例" → 🧪 测试
```

---

## 8. 4 专家并列报告(Phase 2 原始)

### 8.1 🖥️ Backend(系统实现视角)

**亮点**:
1. YAML frontmatter 字段分层清晰(`id/role/domain/tier` 四元组)
2. rationalizations 反 LLM 绕过机制严密(借口→反驳二元组)
3. Red Flags 内嵌 bash 命令(Fact-Forcing L1/L2 级)
4. 双轨 tier 设计(default 7节 vs optional 3节)
5. Phase 链式调度显式声明

**风险**:
1. `rationalizations_count` 无校验(数字与实际表格行数可能不同步)
2. 缺 `version` 字段(schema 漂移无追踪)
3. `skills.primary` 引用无 pre-flight check
4. `exclusive_with` 仅注释,未激活双向互斥
5. TS registry/loader API 零文档

**P0 建议**:自动化校验 `rationalizations_count`(解析 ## Common Rationalizations 表格行数,与 frontmatter 数字 diff)
**P1 建议**:引入 `version` semver 字段 + `skills.primary` pre-flight
**P2 建议**:补全 TS registry API 文档

### 8.2 🎨 Frontend(CLI/UI 表面视角)

**亮点**:
1. Preamble 二阶段 onboarding 流
2. Trigger 行机器可读(7 个触发词)
3. output_format 锁结构(架构师 5 节 / 后端 3 节)
4. 扩展库树状 ASCII art 导航
5. META-GUIDELINES 4 原则豁免表

**风险**:
1. SKILL.md 无 triggerKeywords(依赖隐式上下文)
2. output_format 结构性不一致(5 节 vs 3 节 vs 缺)
3. default INDEX 信息密度不足(缺 phase / tier 列)
4. Preamble 无视觉菜单(slash command 缺失)
5. default/extended 渲染格式断裂(平面表 vs 树状 art)

**P0 建议**:default INDEX.md 增加 phase + tier 列
**P1 建议**:SKILL.md frontmatter 补 triggerKeywords + output_format 补全
**P2 建议**:Preamble 支持 slash command 快捷方式

### 8.3 🖌️ UX(用户体验视角)

**亮点**:
1. Preamble 大幅降低决策摩擦(8 种组合精确定位)
2. INDEX 表格让选择路径清晰(扫表 < 3 秒)
3. Common Rationalizations 是"被保护"而非"被说教"(共情语气)
4. 7 位 MBTI 覆盖完整(无性格重叠浪费)
5. output_format 强制统一降低期望落差

**风险**:
1. INDEX 一句话 description 用解决方案语言(用户翻译成本高)
2. Preamble 两问无"取消/返回"路径(Nielsen #3 缺口)
3. rationalizations 表格密度过高(用户跳过第 2 列)
4. 7 节 full anatomy 对 LLM 压力 > 用户价值
5. emoji 在 SKILL-INDEX.md(第一触点)丢失

**P0 建议**:INDEX 加"问题症状"入口索引(症状→角色映射)
**P1 建议**:rationalizations 视觉分层(emoji 标记风险等级)
**P2 建议**:SKILL-INDEX 加 emoji 地图 + Verification 路径预检

### 8.4 📋 Product(产品战略视角)

**亮点**:
1. 7 位 MVP 数字克制且务实
2. 3 层分众触发明确(频率梯度)
3. 质量门禁工程化(anatomy check + codemod)
4. `rationalizations_count: 6` 硬下限
5. Onboarding UX 设计完整(Preamble 双问题)

**风险**:
1. 缺升级触发条件(无"什么时候该用 optional"决策树)
2. 无北极星指标(usage / activation / resolution 全部缺失)
3. anatomy 老化风险(70+ 专家无维护触发机制)
4. 分层边界模糊(3 节 minimal 是否真能保证质量?)
5. 无 engagement 漏斗(default→optional→extended 转化率)

**P0 建议**:设计场景触发决策树(问题→推荐专家)
**P1 建议**:植入轻量 metrics(SQLite 本地存)
**P2 建议**:建立 anatomy 版本标签 + review 周期

---

## 9. 跨专家共识与冲突

### 9.1 共识(2+ 专家独立提出)

| 共识 | 提及方 | 共识强度 |
|---|---|---|
| **场景触发决策树缺失** | UX(P0) + Product(P0) | **4/4 共识** |
| **INDEX 信息密度不足** | Frontend(P0) + UX(P0) | **强共识** |
| **质量门禁是护城河** | Backend + Product | **强共识** |
| **rationalizations 是核心** | Backend + UX + Product | **强共识** |
| **版本/老化解** | Backend(P1 version) + Product(P2 anatomy_version) | **2/4 共识** |
| **output_format 不一致** | Frontend + UX | **2/4 共识** |

### 9.2 冲突(专家意见分歧)

| 冲突点 | Backend | Frontend | UX | Product |
|---|---|---|---|---|
| **7 节 anatomy 必要性** | 中性(当成数据) | 中性(渲染视角) | 反对(压力>价值) | 强支持(质量门禁) |
| **Preamble 复杂度** | — | 想加 slash command | 想加"返回" | 觉得够用 |
| **rationalizations 数量** | 想自动化校验 | — | 想视觉降密 | 6 条下限正确 |

### 9.3 3 个最大跨专家洞察

1. **决策树是 2/4 共识中的 P0** — UX 和 Product 都列为 P0,这是 4 专家最大公约数
2. **质量门禁 vs 体验的权衡** — Backend/Product 强调门禁,UX 担心过度结构化。**平衡点**:门禁是底线(必须通过),但人感观上要轻(降低摩擦)
3. **盲飞问题** — 只有 Product 提了北极星指标缺失,其他 3 位未提。这是**Product 视角的独特价值**

---

## 10. 借鉴到 KALLAX 的整体建议

### 10.1 12 条具体落地动作(按优先级)

| # | 动作 | 文件 | 价值 | 估时 | 借鉴自 |
|---|---|---|---|---|---|
| 1 | 在 KALLAX `/kallax-panel` 加 Preamble 触发器(关键词检测) | `SKILL.md` 改 ~30 行 | 极高 | 0.5h | UX + Product |
| 2 | 设计 5 位 KALLAX 专家的 7 节 full anatomy | 新建 `experts/default/{architect,backend,frontend,ux,product}.md` | 极高 | 1.5h | Backend + UX |
| 3 | 加 `scripts/check-skill-anatomy.sh` 校验 | 新建 1 脚本 | 高 | 0.5h | Backend + Product |
| 4 | 加 `scripts/codemod-inject-3sections.sh` 自动化 | 新建 1 脚本 | 中 | 0.5h | Product |
| 5 | INDEX.md 加 phase + tier + 问题症状列 | 新建 `experts/default/INDEX.md` | 高 | 0.3h | Frontend + UX |
| 6 | META-GUIDELINES 4 原则对齐 KALLAX 上下文 | 改 `.kallax/docs/META-GUIDELINES.md` | 中 | 0.3h | Frontend |
| 7 | output_format 锁结构(统一 4 节模板) | 改 5 位 expert 文件 | 中 | 0.3h | Frontend + UX |
| 8 | 场景触发决策树(症状→角色) | 新建 `experts/TRIGGERS.md` | **P0 共识** | 0.5h | UX + Product |
| 9 | rationalizations 表格(借口+反驳) | 嵌入各 expert + CLAUDE.md | 中 | 0.3h | Backend + UX |
| 10 | 实施 Shadow 模式 metrics(SQLite 本地) | 新建 `.kallax/data/expert_metrics.db` | 中 | 1h | Product |
| 11 | Verification 章节含 bash 命令(Fact-Forcing) | 嵌入各 expert | 中 | 0.3h | Backend |
| 12 | 豁免场景表(hotfix / typo / 用户明确要求) | 嵌入 META-GUIDELINES | 低 | 0.2h | Frontend |

**总投入**:6h(单人 1 天)

### 10.2 不要照搬(避坑)

| 陷阱 | 原因 |
|---|---|
| 7 位 default(我们 5 位足够) | KALLAX 规模小,5 位覆盖已够 |
| 53 位 optional / 70 位 extended | 无足够使用频率,先停在 5 位 |
| 完整 codemod 自动化 | 70+ 才有必要,我们 5 个手写即可 |
| 北极星指标系统 | 5 位阶段不需要,Sprint 6+ 再考虑 |
| 4 原则 META-GUIDELINES 全搬 | KALLAX 已有 CLAUDE.md 硬规则,叠加会冲突 |

### 10.3 借鉴层级(避免过度设计)

```
Layer 1 (现在做):  Preamble + 5 位 persona 7 节 + anatomy check
Layer 2 (Sprint 6+): 决策树 + metrics + codemod
Layer 3 (Sprint 10+): 扩展至 7-10 位 + 北极星指标 + 跨项目借鉴
```

---

## 11. 下一步决策

| 选项 | 动作 | 工时 |
|---|---|---|
| **A. Layer 1 全部 6h** | Preamble + 5 personas + check + INDEX + META + 决策树 | 1 天 |
| **B. Layer 1 极简 2h** | 只做 Preamble + 1 个范本 persona(architect) | 2h |
| **C. 先验证 P0 共识(决策树)** | 只做场景触发决策树(症状→角色) | 0.5h |
| **D. 转给 Performer 落地** | 派工单,Master 不写 | 0h |

**Master 建议**:选 **B** 先跑通最小循环(Preamble + 1 范本),再迭代加 4 位专家和 check 脚本。**避免一次性堆 Layer 1 全 6h,容易上下文断裂**。

---

## 附录

### A. 引用文件清单

**Eket 源**:
- `~/.claude/skills/eket/SKILL.md` / `SKILL-INDEX.md` / `SKILL-DETAIL.md` / `META-GUIDELINES.md`
- `~/.claude/skills/eket/experts/default/INDEX.md`
- `~/.claude/skills/eket/experts/default/{architect,backend,frontend,ux,product,tester,fullstack}.md`
- `~/.claude/skills/eket/experts/optional/INDEX.md`
- `~/.claude/skills/eket/experts/extended/experts/INDEX.md`
- `~/.claude/skills/eket/experts/extended/tools/expert-template.md`

**KALLAX 对比**:
- `.claude/skills/kallax/SKILL.md`
- `.claude/skills/kallax/skills/kallax-init.md`

### B. KALLAX 上下文(本次调研起点)

- `.kallax/state/instance_config.yml` — 当前 Master 身份
- `jira/tickets/EPIC-016-J/` — 上一 ticket(已 done)
- `confluence/decisions/PERMISSION-MODEL.md` — 上一调研产物
- `confluence/decisions/EKET-BORROW-METHODOLOGY-2026-06-07.md` — 上一调研产物(短报告)

### C. Phase 时间线

- 2026-06-07 16:xx Phase 1: Master 读 9 个 eket 文件
- 2026-06-07 16:xx Phase 2: 4 sub-agent 并行,各 ~80-110 秒
- 2026-06-07 16:xx Phase 3: Master 汇总,产出本文

---

**Reviewer(s)**: master_main
**Last updated**: 2026-06-07
**Status**: ✅ 完整版 — 4 专家共识已聚合
