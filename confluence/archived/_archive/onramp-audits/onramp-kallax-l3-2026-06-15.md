# . — L3 完整审计 + 3 件套

**日期**: 2026-06-15
**调用**: /kallax-onramp
**深度**: L3 (5 default + 5 extended = 10 视角)

## 项目扫描

- **规模**: 525841 LOC, 22060 文件, 93 模块
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



## 3 件套 (guidance 抽取)

### 亮点 (可复用)
待各专家在 expert_outputs 中提取.

### 缺点 (需修)
待各专家在 expert_outputs 中提取.

### 隐患 (需防)
待各专家在 expert_outputs 中提取.

## 下一步

guidance 已落地 `docs/analysis/`. 如需将亮点升级为 KALLAX Rule 或扩展 skill, 启动 EPIC.