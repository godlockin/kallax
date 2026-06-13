# EPIC-045: Session Watchdog — 30min Timeout + API Error Retry + 12h Cap Warning

## 需求

BE-14 API Error 卡住 2 subagent, 3.5h 跑完假 PASS. 需要实现 session timeout watchdog 机制:
- 30min timeout 自动 abort (不讓 subagent 假 PASS 存活)
- API Error retry 3 次, 仍失败 abort
- 12h cap 80% (9.6h) warning

跟战略建议 5.4 联合: "session timeout 必须可中断 (session_watchdog.sh)"

## 接受标准 (AC)

详见 `ticket.json`. 6 条 AC:
1. AC1: session_watchdog.sh 存在于 scripts/io/ 并可执行
2. AC2: 30min timeout 自动 abort 功能存在
3. AC3: API Error retry 3 次逻辑存在
4. AC4: 12h cap 80% (9.6h) warning 功能存在
5. AC5: Rule 23 添加到 CLAUDE.md
6. AC6: 集成测试 session-watchdog-test.sh 通过

## 技术要点

- **BE-7 修复模式**: umask 077 + install -m 700 (防 symlink 漏洞)
- **BE-14 防御**: 30min timeout + API error retry 3 次
- **BE-12 防御**: 12h cap 80% (9.6h) warning
- 集成到 session_start.sh + pre-commit hook

## 测试计划

- [ ] L1: session_watchdog.sh 存在于 scripts/io/
- [ ] L2: 30min timeout 自动 abort 逻辑存在
- [ ] L3: API Error retry 3 次逻辑存在
- [ ] L4: 12h cap 80% warning 逻辑存在

## 依赖

- BE-14 API Error 卡住教训 (ACCUMULATED-LESSONS-2026-06-13.md 5.4)
- BE-7 file-lock 自身安全教训 (umask 077 + install -m 700)

## 文件范围

- `scripts/io/session_watchdog.sh` (new)
- `CLAUDE.md` (update - Rule 23)

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-13 | in_progress | Performer-EPIC-045 | 创建 |