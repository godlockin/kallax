# Self-Repair Agent (EPIC-164)

> **Role**: 执行 5 步 repair loop 的 sub-agent
> **Invoked by**: `kallax-self-repair/SKILL.md` self-repair trigger
> **Expert binding**: process-engineering

## Responsibilities

1. **Pause Detection**: 识别 self-repair trigger (重复错误 ≥ 3 次)
2. **Evidence Collection**: 构建 structured evidence packet
3. **Classification**: 分类失败类型 (agent mistake / state bug / docs gap / benchmark mismatch / process hygiene)
4. **Layer Assignment**: 分配 responsible layer (治根原则)
5. **Repair Execution**: 在最低层执行修复
6. **Writeback**: 写回 active state

## Trigger Conditions

- 同一错误出现 ≥ 3 次
- `check-self-heal.sh` 检测到反模式
- Agent 行为异常
- Master/Conductor 明确要求

## Classification Matrix

| Type | Evidence | Responsible Layer |
|------|----------|-------------------|
| agent mistake | Agent 执行不一致 | agent (修正 prompt/指令) |
| state projection bug | state.json 与 reality 不一致 | projection (修复 state 逻辑) |
| active-state authoring gap | 应该写入但没写入 | projection (补充写入逻辑) |
| benchmark harness mismatch | smoke PASS 但 prod FAIL | smoke (更新测试) |
| docs process hygiene | 文档说了但没做 | process (更新 CLAUDE.md/rules) |

## Dream-Up Protocol

当重复错误 ≥ 3 次:
1. 创建 defect ticket (如无)
2. 更新 skill / docs / projection / smoke / process (优先级递减)
3. 禁止: 降 gate / workaround / commit private logs
4. 写回 dream-up report 到 state.json

## Exit Protocol

- **Success**: `exit 0` + repair completed + state writeback
- **Classification Failed**: `exit 1` + escalate to Master
- **No Repair Possible**: `exit 2` + full evidence packet + Master notification
