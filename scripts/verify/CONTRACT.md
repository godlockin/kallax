# scripts/verify/ CONTRACT (EPIC-117-B)

> Anthropic《Building Effective Agents》: "invest as much effort in ACI as HCI"
> KALLAX 反例: v3.22.0 session 修 10 个 check 脚本 0-arg 兼容 → 没做 ACI 统一

## 3 条统一约定

所有 `scripts/verify/check-*.sh` 必须遵守:

### 1. 0-arg auto-discovery

无参调用时不能崩溃。按顺序尝试:
- pre-commit context (`KALLAX_PRE_COMMIT=1`) → skip
- staged files 里的 `EPIC-NNN` pattern
- staged content 里的 `EPIC-NNN` pattern
- 当前 branch name 里的 `EPIC-NNN` pattern
- 都拿不到 → `WARN: ... skipped` + `exit 0`

**反模式**: `EPIC_ID="${1:?}"` (0-arg 直接崩)

### 2. `KALLAX_PRE_COMMIT=1` bypass

pre-commit hook 循环调用时, 默认延迟到 CI 做全量扫描:
```bash
if [[ "${KALLAX_PRE_COMMIT:-0}" == "1" ]]; then
    echo "WARN: <name> skipped (pre-commit context, deferred to CI)" >&2
    exit 0
fi
```

**理由**: pre-commit 只看 staged, 假阳性高 (如 code comment 里的 EPIC-070 触发 check-checkin-points auto-discovery)

### 3. Exit code 语义

| Code | 含义 |
|------|------|
| **0** | PASS (或安全 skip) |
| **1** | FAIL (真正违反规则, 阻塞 commit) |
| **2** | ERROR (参数错 / 文件缺失 / 环境异常, 阻塞 commit) |

**反模式**: `exit 2` 表示 "无数据 skip" (应该 exit 0)

## Audit

`scripts/verify/audit-contract.sh` 扫全部 `check-*.sh` 合规率:
- 静态扫描: 有无 `KALLAX_PRE_COMMIT` 分支 / 有无 auto-discovery / 有无 `${1:?}` 反模式
- 输出: `PASS <n>/<total>` + 违规明细

## 联动

- EPIC-069-D fact-forcing (hook 层强制)
- v3.22.0 session Lesson: 10 个 hook 修 0-arg 兼容 (症状 → 根因 → 治理)
