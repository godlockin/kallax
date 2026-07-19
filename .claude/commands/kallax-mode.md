---
description: Switch between operation modes. Mode enum 必填其一: `conductor` / `performer` / `standalone` (3 选 1)。其他值会 exit 1 不生效。
argument-hint: [conductor|performer|standalone] (1 required)
---

!bash "$(dirname "$0")/kallax-mode.sh" $ARGUMENTS
