---
description: Summon a specific expert for analysis. Requires `<role>` (e.g. backend / architect / security / auditor). 可选 `context` 放第 2 位。无 role 时 fallback 到 expert list (不报错)。Role 名必须小写, 看 /kallax-list 找全名。
argument-hint: <role> [context]
---

!bash "$(dirname "$0")/kallax-expert.sh" $ARGUMENTS
