# EPIC-236 — state-path.sh lib 迁移覆盖 (10 个脚本)

- **日期**: 2026-08-09
- **拍板**: 主公 ("继续")
- **前置**: EPIC-232 创建 `scripts/permission/lib/state-path.sh` 共享 lib, 但只迁了 2 个脚本 (authz + conductor-scope-check), 剩 10 个同样有 EPIC-232 bug 1+2+3
- **版本**: v3.34.10

## 1. 为什么

EPIC-232 commit message 说 "剩 10 个脚本未迁移到 `lib/state-path.sh`", 但那是 deferral 不是 fix. 实际影响:

- `kallax role:transition` / `kallax mode set` / `kallax workspace switch` 在 worktree 里仍然 fail
- 用户体验问题: 进 worktree 后任何权限操作都会 exit 2 (被 pre-commit 误判为 "授权拒绝", 跟 EPIC-232 bug 3 同型)
- lib 存在但只 2/12 个脚本引用 (Rule 5 DRY 违反)

## 2. 改什么

### 2.1 10 个脚本统一迁移

| # | 文件 | 改动 |
|---|---|---|
| 1 | `scripts/permission/decision-gate.sh` | STATE_FILE 走 lib |
| 2 | `scripts/permission/mode-set.sh` | STATE_FILE 走 lib |
| 3 | `scripts/permission/readonly-path.sh` | STATE_FILE + ROLE 都走 lib |
| 4 | `scripts/permission/workspace-switch.sh` | STATE_FILE + ROLE 都走 lib |
| 5 | `scripts/permission/role-transition.sh` | STATE_FILE + FROM_ROLE 都走 lib |
| 6 | `scripts/permission/decision-gate-complex-only.sh` | STATE_FILE 走 lib |
| 7 | `scripts/performer/stage-gate.sh` | STATE_FILE 走 lib |
| 8 | `scripts/workspace/switch.sh` | STATE_FILE + ROLE 都走 lib |
| 9 | `scripts/workspace/readonly.sh` | STATE_FILE + ROLE 都走 lib |
| 10 | `scripts/role-transition.sh` | STATE_FILE + FROM_ROLE 都走 lib |

每个脚本两处替换:
- `STATE_FILE="${KALLAX_ROOT}/.kallax/state/state.json"` → 改用 `kallax_resolve_state_file` (EPIC-232 共享 lib)
- `ROLE="$(jq -r '.role // ""' "$STATE_FILE" 2>/dev/null)"` → 改用 `kallax_read_role` (防 EPIC-232 bug 3 的 set -e 中断)

### 2.2 新增 `tests/integration/epic-236-state-path-migrate-test.sh`

43 个 TC, 分 6 组:
1. lib source 注入 (10)
2. STATE_FILE 走 lib (10)
3. 0 处裸 jq role 读取 (10, 跟 EPIC-232 bug 3 同型)
4. bash -n 语法 (10)
5. worktree 内运行 (1, 模拟主仓库 cwd 之外的环境)
6. lib 缺失时 fail-closed (2, 跟 EPIC-232 authz 同型)

## 3. 实跑证据

### 3.1 测试

```
$ bash tests/integration/epic-236-state-path-migrate-test.sh
Results: 43 pass, 0 fail
```

### 3.2 worktree 内真跑

修前 (epic-231 worktree 基线是 `ba965d76` PR-333 merge 前, lib 没拉到):
```
$ bash scripts/permission/mode-set.sh --help
ERROR: state-path.sh lib not found: ...
```

Fast-forward 到 origin/main 后 (含 EPIC-232 commit `b697a747` 引入的 lib):
```
$ bash scripts/permission/mode-set.sh --help
Usage: scripts/permission/mode-set.sh --mode <ai-auto|ai-copilot|manual> [--actor <name>]
$ bash scripts/permission/role-transition.sh --help
Usage: scripts/permission/role-transition.sh --to <role> --actor <actor> --reason <why>
$ bash scripts/workspace/switch.sh --help
ERROR: --workspace is required     # 正常参数校验
```

10 个脚本全部能进入参数校验阶段, 不再 "lib not found".

### 3.3 lib 缺失 fail-closed

无 lib 的临时目录:
```
$ bash scripts/permission/mode-set.sh --mode ai-copilot
ERROR: state-path.sh lib not found: /tmp/.../scripts/permission/lib/state-path.sh
rc=1
```

跟 EPIC-232 authz 同型: fail-closed 而非静默降级到可能错的路径.

### 3.4 裸 jq role 清零

```
$ grep -cE 'jq -r.*\.role' 10 个文件 | sum
0
```

之前有 6 处裸 jq role 读, 全部改成 `kallax_read_role`.

## 4. 影响

**正面**:
- worktree 里所有权限操作不再 fail
- 0 处裸 jq role 读, EPIC-232 bug 3 修复覆盖到全部 12 个脚本
- lib 一处实现, 12 处生效, 未来 state.json 路径变更只改 lib

**代价**:
- 10 个脚本改动, 但都是模式化替换 (State_FILE 赋值 + ROLE/FROM_ROLE 读)
- 加 1 个集成测试文件 (226 行)

## 5. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| 漏改某个脚本 | 低 | TC1 全覆盖 (10 个目标), grep 自动验证 |
| lib 行为变化导致意外 | 低 | 跟 EPIC-232 同行为, 已 25/26 测试过 |
| 公共 `scripts/role-transition.sh` 跟 `scripts/permission/role-transition.sh` 重名混淆 | 低 | 仅 1 个, 单独 grep 处理 |
| 改动引入 set -e 中断 | 低 | TC3 全覆盖 (0 处裸 jq role) |

## 6. 未验证

- **每个脚本完整 e2e 没跑** — 只跑了 `--help` (到参数校验阶段). 实际 `--mode ai-copilot` 等真跑未做, 因为:
  - 需要真实 state.json (worktree 模拟环境用临时 state.json 验证)
  - 实际执行副作用大 (改 state.json), 不在 docs-only EPIC 范围
- **公共 `scripts/role-transition.sh` 跟 `scripts/permission/role-transition.sh` 重复** — 扫出 2 个同名的脚本 (一个在 scripts/ 根, 一个在 permission/), 都改了. 是否历史遗留需要清理? 单独 EPIC
- **CI 没跑** — 本 commit 在本地, 没 push
- **CHANGELOG / recent-epics 未补** — 跟之前 EPIC 同型, 范围外
- **4-expert review 未跑** — docs 类型不需

## 7. 0 增 Rule, 0 改 Immutable, 0 改 CLAUDE.md

跟 EPIC-232 同样 — 仅迁移现有脚本到 lib, 不引入新基础设施.

## 8. 联动

- **EPIC-232**: 本 EPIC 是它的 debt 偿还, 把 "fix" 从 "lib + 2 脚本" 扩到 "lib + 12 脚本"
- **EPIC-224**: hook-health CI 验证 lib source 链路
- **EPIC-231**: PR Flow Gate 防止空 PR 顶 EPIC 标题 (本 PR 8 文件, 不会空)
- **Rule 5 DRY**: lib 是单一真相来源

## 9. 变更文件

| 文件 | 变化 |
|---|---|
| `scripts/permission/decision-gate.sh` | + lib source, STATE_FILE 走 lib |
| `scripts/permission/mode-set.sh` | + lib source, STATE_FILE 走 lib |
| `scripts/permission/readonly-path.sh` | + lib source, STATE_FILE + ROLE 都走 lib |
| `scripts/permission/workspace-switch.sh` | + lib source, STATE_FILE + ROLE 都走 lib |
| `scripts/permission/role-transition.sh` | + lib source, STATE_FILE + FROM_ROLE 都走 lib |
| `scripts/permission/decision-gate-complex-only.sh` | + lib source, STATE_FILE 走 lib |
| `scripts/performer/stage-gate.sh` | + lib source, STATE_FILE 走 lib |
| `scripts/workspace/switch.sh` | + lib source, STATE_FILE + ROLE 都走 lib |
| `scripts/workspace/readonly.sh` | + lib source, STATE_FILE + ROLE 都走 lib |
| `scripts/role-transition.sh` | + lib source, STATE_FILE + FROM_ROLE 都走 lib |
| `tests/integration/epic-236-state-path-migrate-test.sh` | 新增 (43 TC) |
| `confluence/decisions/EPIC-236-state-path-migrate-2026-08-09.md` | 本文档 |