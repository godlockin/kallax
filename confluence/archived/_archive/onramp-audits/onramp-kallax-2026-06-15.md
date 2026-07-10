# kallax — L3 完整审计 + 3 件套

**日期**: 2026-06-15
**调用**: /kallax-onramp
**深度**: L3 (5 default + 5 extended = 10 视角)

## 项目扫描

- **规模**: 525960 LOC, 22063 文件, 93 模块
- **语言**: Shell:31,TS:32,PY:0,MD:30,RS:5,GO:0
- **CLAUDE.md**: true
- **README**: true
- **Git 活跃**: 388 commits / 30d

## 10 视角并行分析


### 1. 🏗️ 架构

**角色**: architect
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/experts/default/architect.md
**描述**: No description

name: 🏗️ 架构 tier: default worktree_role: conductor review_group: A phase: 1 rationalizations_count: 8 version: 1.0.0 last_reviewed: 2026-06-11 tickets_served: [EPIC-030] trigger: 架构,边界,选型,微服务,模块,API契约,服务拆分,系统设计,模块耦合,接口定义,技术债务,扩展性,分布式,一致性,部署架构,灰度,发布,重构,集成,服务,治理,链路

### 2. 💻 后端

**角色**: backend
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/experts/default/backend.md
**描述**: No description

name: 💻 后端 tier: default worktree_role: performer review_group: A phase: 2 rationalizations_count: 8 version: 1.0.0 last_reviewed: 2026-06-11 tickets_served: [EPIC-030] trigger: API,接口慢,数据库,SQL,查询慢,索引,n+1,事务,缓存,性能,后端,服务端,数据层,连接池,锁竞争,慢查询,超时,内存,GC,泄漏,死锁,压测,瓶颈,监控,告警,分布式,ETL,数据迁移,数据管道,Kafka,Spark,Presto,Flink,数据血缘,BI报表,OLAP,数据仓库,Snowflake,ClickHouse,Redshift,BigQuery

### 3. 🛡️ 安全

**角色**: security
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/experts/default/security.md
**描述**: No description

name: 🛡️ 安全 tier: default worktree_role: auditor review_group: B phase: 2 rationalizations_count: 8 version: 1.0.0 last_reviewed: 2026-06-11 tickets_served: [EPIC-030] trigger: 注入,越权,XSS,CSRF,漏洞,鉴权,安全,认证,授权,加密,敏感数据,合规,攻击面,威胁,防护,权限,控制,数据,泄露,撞库,提权,审计,密钥,签名,GDPR,SOX,数据隐私,跨境数据,合规审计,安全合规,隐私保护,数据保护

### 4. compliance-rule-merge

**角色**: compliance-rule-merge
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/compliance-rule-merge.md
**描述**: KALLAX 扩展组专家 — 治 3 假 PASS 根因 4 (14 Rule 升级率 100%). 跟 Rule 32 联合, 跟"循环论证" 联合.

description: KALLAX 扩展组专家 — 治 3 假 PASS 根因 4 (14 Rule 升级率 100%). 跟 Rule 32 联合, 跟"循环论证" 联合. triggerKeywords: [compliance, rule-merge, 软约束升级阈值, 根因修复 4, EPIC-051, 18 Rule 升级率 100%, 撤销冗余 Rule, 5 release 软约束] filePath: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/compliance-rule-merge.md --- # KALLAX Extended Expert — Compliance: 根因修复 4 (14 Rule 升级率 100%) > **跟"召唤合适专家" 拍 explicit 约束 联合, 跟"现状、目标、需求" 拍 explicit 约束 联合** ## 任务

### 5. auditor-independent-witness

**角色**: auditor-independent-witness
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/auditor-independent-witness.md
**描述**: KALLAX 扩展组专家 — 治 3 假 PASS 根因 3 (独立见证机制缺失). 跟 Rule 31 联合, 跟"瞒报 = P0" 联合.

description: KALLAX 扩展组专家 — 治 3 假 PASS 根因 3 (独立见证机制缺失). 跟 Rule 31 联合, 跟"瞒报 = P0" 联合. triggerKeywords: [auditor, independent-witness, 独立见证机制, audit-log-sink, 不可篡改, 根因修复 3, EPIC-050, 瞒报 P0] filePath: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/auditor-independent-witness.md --- # KALLAX Extended Expert — Auditor: 根因修复 3 (独立见证机制缺失) > **跟"召唤合适专家" 拍 explicit 约束 联合, 跟"现状、目标、需求" 拍 explicit 约束 联合** ## 任务

### 6. process-engineering-self-verify

**角色**: process-engineering-self-verify
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/process-engineering-self-verify.md
**描述**: KALLAX 扩展组专家 — 治 3 假 PASS 根因 2 (自验证主体 = 造假主体). 跟 Rule 30 联合, 跟"激励扭曲" 联合.

description: KALLAX 扩展组专家 — 治 3 假 PASS 根因 2 (自验证主体 = 造假主体). 跟 Rule 30 联合, 跟"激励扭曲" 联合. triggerKeywords: [process-engineering, self-verify, 自验证失效, 激励扭曲, 根因修复 2, EPIC-049, 独立见证机制, independent-witness] filePath: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/process-engineering-self-verify.md --- # KALLAX Extended Expert — Process Engineering: 根因修复 2 (自验证主体 = 造假主体) > **跟"召唤合适专家" 拍 explicit 约束 联合, 跟"现状、目标、需求" 拍 explicit 约束 联合** ## 任务

### 7. security-tool-bypass

**角色**: security-tool-bypass
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/security-tool-bypass.md
**描述**: KALLAX 扩展组专家 — 治 3 假 PASS 根因 1 (工具可绕过 = 架构缺陷). 跟 Rule 29 联合, 跟 BE-7 修复模式 联合.

description: KALLAX 扩展组专家 — 治 3 假 PASS 根因 1 (工具可绕过 = 架构缺陷). 跟 Rule 29 联合, 跟 BE-7 修复模式 联合. triggerKeywords: [security, tool-bypass, 工具可绕过, 架构缺陷, 根因修复 1, EPIC-048, 独立审计, file-lock 漏洞] filePath: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/security-tool-bypass.md --- # KALLAX Extended Expert — Security: 根因修复 1 (工具可绕过 = 架构缺陷) > **跟"召唤合适专家" 拍 explicit 约束 联合, 跟"现状、目标、需求" 拍 explicit 约束 联合, 跟"目标专家" 拍 explicit 约束 联合** ## 任务

### 8. decision-gate-complex-only

**角色**: decision-gate-complex-only
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/decision-gate-complex-only.md
**描述**: KALLAX 扩展组专家 — 治 3 假 PASS 根因 5 (ai-copilot 名不副实). 跟 Rule 33 联合, 跟"决策疲劳" 联合.

description: KALLAX 扩展组专家 — 治 3 假 PASS 根因 5 (ai-copilot 名不副实). 跟 Rule 33 联合, 跟"决策疲劳" 联合. triggerKeywords: [decision-gate, complex-only, 复杂才问, ai-copilot, 根因修复 5, EPIC-052, 决策疲劳, decision-gate 复杂阶段] filePath: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.claude/skills/kallax/extended/decision-gate-complex-only.md --- # KALLAX Extended Expert — Decision Gate: 根因修复 5 (ai-copilot 名不副实) > **跟"召唤合适专家" 拍 explicit 约束 联合, 跟"现状、目标、需求" 拍 explicit 约束 联合** ## 任务

### 9. 🎨 前端

**角色**: frontend
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/experts/default/frontend.md
**描述**: No description

name: 🎨 前端 tier: default worktree_role: performer review_group: B phase: 2 rationalizations_count: 8 version: 1.0.0 last_reviewed: 2026-06-11 tickets_served: [EPIC-030] trigger: 页面卡,渲染慢,组件,React,Vue,状态管理,LCP,包体积,白屏,加载慢,交互延迟,卡顿,重渲染,样式,样式冲突,首屏,FCP,CLS,布局抖动,动画,滚动,事件,DOM,虚拟DOM,服务端渲染,CSR,SSR,hydrate

### 10. 🖌️ UX

**角色**: ux
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/experts/default/ux.md
**描述**: No description

name: 🖌️ UX tier: default worktree_role: performer review_group: B phase: 2 rationalizations_count: 8 version: 1.0.0 last_reviewed: 2026-06-11 tickets_served: [EPIC-030] trigger: 交互,体验差,旅程,可用性,一致性,认知负荷,操作步骤,用户路径,反馈,提示不清,界面,易用性,操作复杂,表单,对话框,按钮,点击率,留存,流失,跳出,转化,认知,易学,易用,操作,流程

### 11. 📋 产品

**角色**: product
**Skill 路径**: /Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/experts/default/product.md
**描述**: No description

name: 📋 产品 tier: default worktree_role: conductor review_group: A phase: 1 rationalizations_count: 8 version: 1.0.0 last_reviewed: 2026-06-11 tickets_served: [EPIC-030] trigger: 优先级,需求,价值,ROI,MVP,功能取舍,用户价值,商业价值,砍需求,范围,产品方向, roadmap,规划,优先级排序,要不要做,AB,test,技术债,版本,灰度,做不做,取舍,合同审查,知识产权,反垄断,劳动法,争议解决,法律合规,商业合同,合同管理,法务



## 3 件套 (guidance 抽取)

### 亮点 (可复用)
待各专家在 expert_outputs 中提取.

### 缺点 (需修)
待各专家在 expert_outputs 中提取.

### 隐患 (需防)
待各专家在 expert_outputs 中提取.

## 下一步

guidance 已落地 `docs/analysis/`. 如需将亮点升级为 KALLAX Rule 或扩展 skill, 启动 EPIC.