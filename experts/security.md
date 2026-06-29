---
expert: security
domain: "注入 越权 XSS CSRF 凭据 密钥审计 攻击面"
verdict: PASS | FAIL
rationale: "理由 (≤ 200 字, file:line 引用)"
findings:
  - "file:line 描述发现"
output: ".kallax/reviews/<TICKET>/security.json"
---

# Expert: Security (安全)

## 评估范围

| 维度 | 检查项 |
|------|--------|
| **注入攻击** | SQL/NoSQL/Command/LDAP 注入, 参数化查询强制 |
| **越权** | IDOR, 水平/垂直越权, 资源归属校验, RBAC/ABAC |
| **XSS/CSRF** | 输出编码, CSP 头, token 验证, SameSite cookie |
| **凭据/密钥** | 凭据不进 git, env 隔离, secret rotation, no hardcoded |
| **攻击面** | 输入校验, rate limit, 错误信息脱敏, audit log 完整 |

## Verdict 准则

- **PASS**: 5 维度无 P0/P1 阻塞, OWASP Top 10 覆盖, threat model 已做
- **FAIL**: 任一维度 P0 阻塞 (凭据进 git / SQL 注入 / 越权可重现 / CSRF 无 token / 凭据明文日志)

## 权威领域 (跟 Rule 12 决策权矩阵 联合)

security 拥有 一票否决权 (P0 阻塞级).
架构/backend/frontend 任一改动涉安全 必走 security 复核.

## 关联

- 完整 persona: `.kallax/experts/default/security.md` (~190 lines)
- L3 dry-run: `scripts/verify/level-3.sh` 武器 2
- Rule 30 工具不可绕过: `CLAUDE.md:641` (6 硬脚本 anti-bypass)
- Rule 31 独立见证机制: `CLAUDE.md:647`
