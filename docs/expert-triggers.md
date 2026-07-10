# TRIGGERS — Expert Selection Decision Tree

> **来源**: EXPERT-EXTENSION-SCHEME §2.3
> **版本**: 1.0.0
> **日期**: 2026-06-07

---

## Overview

当用户描述一个需求/问题时，按以下 4 个信号段匹配 expert：

1. **性能/稳定性** — 速度、延迟、吞吐量、崩溃
2. **安全/合规** — 漏洞、攻击、鉴权、合规
3. **业务/价值** — 优先级、价值、需求取舍
4. **跨层/架构** — 系统设计、技术选型、跨模块

每段包含症状关键词 → expert链（含 fallback）。

---

## Segment 1: 性能/稳定性 (Performance / Stability)

**症状关键词**: 慢、卡、延迟、崩溃、OOM、超时、响应慢、性能、吞吐、负载

**Expert链**:
```
用户描述包含: "接口慢" / "数据库慢" / "查询慢" / "SQL慢" / "索引" / "n+1" / "缓存"
  → backend (primary)
  → architect (fallback:涉及分布式/微服务架构时)

用户描述包含: "页面卡" / "渲染慢" / "LCP" / "白屏" / "加载慢" / "卡顿" / "重渲染"
  → frontend (primary)
  → ux (fallback: 涉及用户旅程/认知负荷时)

用户描述包含: "崩溃" / "OOM" / "内存泄漏" / "进程挂起"
  → backend (primary: 进程/内存)
  → architect (fallback: 系统架构导致时)

用户描述包含: "超时" / "timeout" / "响应慢"
  → backend (primary)
  → frontend (fallback: 涉及前端请求超时处理时)
```

**Fallback chain**: backend → architect → frontend → ux

---

## Segment 2: 安全/合规 (Security / Compliance)

**症状关键词**: 注入、XSS、CSRF、越权、漏洞、鉴权、认证、授权、安全、攻击、合规

**Expert 链**:
```
用户描述包含: "注入" / "SQL注入" / "命令注入" / "XSS" / "CSRF"
  → security (primary)
  → backend (fallback: 涉及数据层时)

用户描述包含: "越权" / "权限" / "鉴权" / "认证" / "授权"
  → security (primary)
  → backend (fallback: 涉及后端实现时)

用户描述包含: "漏洞" / "威胁" / "攻击面" / "防护"
  → security (primary)
  → architect (fallback: 涉及系统架构时)

用户描述包含: "合规" / "GDPR" / "SOC2" / "PCI" / "隐私"
  → security (primary: system risk only)
  → pm (fallback: 涉及跨团队协调时)
```

**Fallback chain**: security → backend → architect → pm

---

## Segment 3: 业务/价值 (Business / Value)

**症状关键词**: 优先级、价值、ROI、MVP、需求、功能取舍、要不要做、商业价值

**Expert 链**:
```
用户描述包含: "优先级" / "RICE" / "排序" / "先做哪个"
  → product (primary)
  → pm (fallback: 涉及跨ticket规划时)

用户描述包含: "价值" / "ROI" / "商业价值" / "用户价值"
  → product (primary)
  → architect (fallback: 涉及技术可行性时)

用户描述包含: "MVP" / "最小可行" / "先不做" / "砍功能"
  → product (primary)
  → pm (fallback: 涉及任务规划时)

用户描述包含: "需求" / "功能取舍" / "要不要做" / "范围"
  → product (primary)
  → architect (fallback: 涉及技术边界时)
```

**Fallback chain**: product → pm → architect

---

## Segment 4: 跨层/架构 (Cross-Cutting / Architecture)

**症状关键词**: 架构、边界、选型、微服务、模块耦合、接口定义、技术债务、扩展性、分布式

**Expert 链**:
```
用户描述包含: "架构" / "系统设计" / "模块边界" / "服务拆分"
  → architect (primary)
  → backend (fallback: 涉及数据层/API设计时)
  → pm (fallback: 涉及跨团队协调时)

用户描述包含: "技术选型" / "技术债务" / "重构"
  → architect (primary)
  → backend (fallback: 涉及后端技术栈时)
  → frontend (fallback: 涉及前端技术栈时)

用户描述包含: "接口契约" / "API定义" / "模块耦合"
  → architect (primary: 跨模块)
  → backend (fallback: 后端API设计)
  → frontend (fallback: 前端接口消费)

用户描述包含: "扩展性" / "分布式" / "一致性" / "部署"
  → architect (primary)
  → backend (fallback: 涉及数据库/缓存一致性时)

用户描述包含: "跨层" / "前后端桥接" / "BFF"
  → architect (primary)
  → frontend (fallback)
  → backend (fallback)
```

**Fallback chain**: architect → backend → frontend → pm

---

## L1 Matching Algorithm (scripts/expert-match.sh)

```
Input: <requirement string>

Step 1: Tokenize requirement (split on space/comma/semicolon)
Step 2: For each expert, compute score:
  - keyword match (w1=0.30): each matched trigger keyword → +30 pts
  - symptom tree hit (w2=0.25): if requirement hits TRIGGERS.md segment → +25 pts
  - domain relevance (w4=0.15): baseline score based on worktree_role match
Step 3: Select expert with highest score
Step 4: If score >= 70 (threshold 0.7) → L1 HIT (return expert id)
        If score < 70 → L1 MISS (return best effort + flag for L2/L3)
Step 5: Log to ~/.kallax/logs/expert_resolution_audit.jsonl
```

**Weights**: w1=0.30 (keyword), w2=0.25 (symptom tree), w4=0.15 (domain), w3=0.30 (semantic sim, placeholder L2)

**Threshold**: 0.7 (=70 pts out of max 100 for w1+w2+w4; w3 is placeholder 0 for L1)

---

## Notes

- L1 only uses keyword + symptom tree + domain (no semantic similarity)
- L2 (Sprint 2) adds semantic similarity via embeddings
- L3 (Sprint 3) adds confidence calibration + learning
- TRIGGERS.md is the single source of truth for symptom-to-expert mapping
- Keywords are in **用户症状语言** (user symptom language), not technical implementation language
- Security expert scope: system risk only (compliance audits → external auditors)