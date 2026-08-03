---
paths:
  - .kallax/**
  - scripts/permission/**
  - .kallax/instances/**
  - .kallax/state/**
---

# state.json 路径约定 (EPIC-068-A)

> **Path-scoped rule**: 只在 `.kallax/**` 或 `scripts/permission/**` 文件被操作时加载.

**写者** (session_start.sh, line 236+):
- 主写: `.kallax/state/state.json` (authz 读)
- 备份: `.kallax/instances/<id>/state.json` (历史/audit 兼容)
- atomic via tmp + mv 防 partial read

**读者** (9 个 authz 脚本):
- `scripts/permission/check.sh` 等读 `.kallax/state/state.json`
- role 必从 state.json 读,禁止 env 兜底 (PHASE-002 9c)

**多实例**:
- `instances/<id>/` 是 per-instance 历史
- `state/` 是当前活跃实例的入口 (单一权威)

**踩过的坑**:
- authz 之前找 `.kallax/state/state.json`, session_start 写到 `instances/.../state.json`, 导致所有 authz fail-closed
- EPIC-068-A 修: session_start 双写, 9 个脚本不改