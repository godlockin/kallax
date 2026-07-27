# state.json 路径 + 多实例约定

> 主 CLAUDE.md 不再展开 (跟 source code 强绑定, 跟新读者无关)

**主 CLAUDE.md**: root, 引用本文件
**本文件加载场景**: 排查 authz fail-closed / understanding KALLAX state 写读路径

---

## 写者 (session_start.sh, line 236+)

- 主写: `.kallax/state/state.json` (authz 读)
- 备份: `.kallax/instances/<id>/state.json` (历史 / audit 兼容)
- atomic via tmp + mv 防 partial read

---

## 读者 (9 个 authz 脚本)

- `scripts/permission/check.sh` 等读 `.kallax/state/state.json`
- role 必从 state.json 读, 禁止 env 兜底 (PHASE-002 9c)

---

## 多实例

- `instances/<id>/` 是 per-instance 历史
- `state/` 是当前活跃实例的入口 (单一权威)

---

## 踩过的坑

- authz 之前找 `.kallax/state/state.json`, session_start 写到 `instances/.../state.json`, 导致所有 authz fail-closed
- EPIC-068-A 修: session_start 双写, 9 个脚本不改

---

## Future paths

**注**: 当 v3.32.0 / v4.x 推出 multi-machine state (网络可达共享存储) 时, 本 spec 需升级:
- 当前 location 是机器本地 `.kallax/state/`
- 未来可能 `s3://...` 或 etcd backend
- 跟 env 兜底关系已经是 Rule 9 KPI (X/Y) 拒 fakery
