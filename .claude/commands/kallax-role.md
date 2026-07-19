---
description: View or change agent role. Role enum 必填其一: `master` / `conductor` / `performer` (3 选 1)。其他值会 exit 1 不生效。无参时显示当前 role。
argument-hint: [master|conductor|performer] (1 required to change)
---

!bash "$(dirname "$0")/kallax-role.sh" $ARGUMENTS
