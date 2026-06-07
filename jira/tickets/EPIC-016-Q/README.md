# EPIC-016-Q: "然后就不动了" — 排查 post-result 卡死

## 需求

result 输出后显示「Crunched 1m 43s」然后会话不响应输入。与历史 5.5min 那次「Churned 3m 13s」同模式。阻塞新会话可用性。

## 接受标准 (AC)

详见 `ticket.json`。6 条 AC：
1. 现象记录：result 后不响应
2. 对照历史：5.5min 同模式
3. 嫌疑排序：(a) Stop hook 同步阻塞 (b) claude-mem worker 慢 (c) Recap idle (d) Claude Code bug
4. 诊断 SOP：fs_usage + lsof -p $PPID 持续 5min
5. 短期 workaround：Stop hook 加 `timeout 10s || true`
6. 长期：等平台 fix

## 技术要点

- 这本质是**调查 + 文档化** ticket，不是代码修复
- 主要交付：confluence/decisions/REVIEW-016-postresult-hang.md
- 含：现象、嫌疑、SOP、workaround
- 写完后**标记已调查**，避免重复劳动

## 测试计划

- [ ] SOP 可执行：用户能照着 fs_usage + lsof 复现诊断
- [ ] workaround 真的有效：~/.claude/settings.json Stop hook 加 timeout 10s 后不再卡

## 依赖

无

## 文件范围

- `confluence/decisions/REVIEW-016-postresult-hang.md` (new)

## 预估工时

3 小时（含实测诊断 1-2 小时）

## 状态变更历史

| 时间 | 状态 | 操作者 | 备注 |
|------|------|--------|------|
| 2026-06-06 06:00 UTC | ready | master_main | 创建 |
| 2026-06-06 15:30 UTC | ready | master_main | 保持 ready（独立 ticket，立即可派发）|
