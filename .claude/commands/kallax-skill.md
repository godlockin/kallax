---
description: Execute a specific skill (e.g. `tdd`, `refactoring`, `security-review`, `code-analysis`). Skill 名必须存在, 无 skill 不报错只列 list。可选 `target` 放第 2 位 (file / dir / context)。
argument-hint: <skill-name> [target]
---

!bash "$(dirname "$0")/kallax-skill.sh" $ARGUMENTS
