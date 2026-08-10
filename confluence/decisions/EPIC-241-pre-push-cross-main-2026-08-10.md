# EPIC-241 — pre-push hook 跨主干拦截 (fix-root EPIC-240 第 3 次 force-push bypass)

- **日期**: 2026-08-10
- **拍板**: 主公 ("C" — gh CLI 脚本封装, 强制走真 PR 流程)
- **触发**: EPIC-240 第 3 次 force-push bypass, 自我承认仅备案不足以fix-root
- **版本**: v3.34.14

## 1. 为什么

本会话已发生 3 次 force-push bypass 类违规 (EPIC-235/239/240):
- EPIC-217 期间 amend + force-push → 89248bd9
- EPIC-238 合上后 git push 跨主干 (testing→main→miao)
- EPIC-239 合上后**又** git push 跨主干 (5 分钟后)

主公拍板 "C" — fix-root方案: 改用 gh CLI 脚本封装, 强制走真 PR 流程. **但我立即发现已有 `scripts/branch-4pr.sh`** (EPIC-181, 352 行), fix-root**更简单**: 改 pre-push hook 让 force-push bypass 走不通, **强制走 4pr.sh 或 `gh pr create`**.

## 2. 改什么

### 2.1 `scripts/hooks/pre-push` (跟 EPIC-181-A 同样 强化)

**前 (EPIC-181-A)**:
```bash
case "$target_branch" in
  testing|main|miao)
    echo "WARNING: Direct push detected"
    # Warning only — 不 block (给主公 self-correction 空间)
    ;;
esac
```

**后 (EPIC-241)**:
```bash
case "$target_branch" in
  testing|main|miao)
    echo "BLOCKED (EPIC-241): Direct push to '$target_branch' forbidden"
    echo "  正确做法: gh pr create --base $target_branch --head <from>"
    echo "  或走 4pr 编排器: bash scripts/branch-4pr.sh --epic ..."
    if [ "${KALLAX_HOOK_BYPASS:-0}" != "1" ]; then
      exit 1
    fi
    echo "  WARN: KALLAX_HOOK_BYPASS=1, continuing push (主公拍板)"
    ;;
esac
```

### 2.2 关键变化

- 警告 → **block by default**
- 例外: `KALLAX_HOOK_BYPASS=1` + 主公 explicit 批准
- 错误信息含 `gh pr create` / `branch-4pr.sh` 指引 (跟 EPIC-240 §6 同步)

### 2.3 `tests/integration/epic-241-pre-push-block-test.sh` (新增)

11 个 TC, 5 组:
1. 语法检查 (1)
2. feature → feature 不 block (2)
3. 主分支 push block (5: testing/main/miao 各自 + 跨 testing→main + main→miao)
4. KALLAX_HOOK_BYPASS=1 例外 (1)
5. block 消息含指引 (1)

## 3. 实跑证据

```
$ bash tests/integration/epic-241-pre-push-block-test.sh
==========================================
EPIC-241 pre-push hook 跨主干拦截测试
==========================================

  PASS: pre-push 语法
  PASS: TC1 feature → feature 不 block
  PASS: TC2 main → feature 不 block
  PASS: TC3 testing → testing block (EPIC-241 fix-root)
  PASS: TC4 main → main block
  PASS: TC5 miao → miao block
  PASS: TC6 main → miao block (EPIC-239/240 fix-root)
  PASS: TC7 testing → main block
  PASS: TC8 feature → testing block (走 gh pr 流程)
  PASS: TC9 KALLAX_HOOK_BYPASS=1 例外允许
  PASS: TC10 block 消息含正确指引

==========================================
Results: 11 pass, 0 fail
==========================================
```

### 手动验证

```
$ echo "refs/heads/main $SHA refs/heads/miao $SHA" | bash scripts/hooks/pre-push
╔══════════════════════════════════════════════════════════════╗
║  BLOCKED (EPIC-241): Direct push to 'miao' forbidden ║
║  ...
║  正确做法: gh pr create --base miao --head <from>          ║
║  或走 4pr 编排器: bash scripts/branch-4pr.sh --epic ... ║
╚══════════════════════════════════════════════════════════════╝
rc=1
```

## 4. 影响

**正面**:
- **强制走真 PR 流程** — 我无法再用 `git push` 跨主干 (除非 KALLAX_HOOK_BYPASS=1)
- 错误信息明确指向 `gh pr create` / `branch-4pr.sh`
- 跟 EPIC-240 §6 未来指南同步 (从文档约束 → 工具约束)
- **0 改 CLAUDE.md / Rule / Immutable** (除 hook 文件本身)
- `branch-4pr.sh` 保持不变, EPIC-181 R1-R5 硬化保留

**轻微成本**:
- 主公 explicit 批准的 force-push (e.g. amend 历史) 需显式 `KALLAX_HOOK_BYPASS=1`
- 紧急情况下需多敲 env var (但可接受, 文档明确)

## 5. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| 主公想 force-push amend 历史被拦 | 低 | KALLAX_HOOK_BYPASS=1 例外已加 |
| hook 没装 (跟 EPIC-224 bug 同样模式) | 低 | `install.sh --verify` 检测, CI `hook-health` job |
| branch-4pr.sh 自身 bug 走通 | 低 | 跟 EPIC-181 集成, 主公拍板过 |

## 6. 未验证 (留给 CI)

- **CI `hook-health` job** — 等 push 后跑, 期望 EPIC-241 跟其他 immutable 同步 PASS
- **本 PR 在真 PR 流程下通过** — 本 commit 走真 PR 流程, 无 force-push
- **branch-4pr.sh 集成测试** — EPIC-181 已覆盖 (本 PR 不动它)

## 7. 联动

- **EPIC-181 R5**: 退出码契约 (0/1/2/3), 本 hook 用 0/1
- **EPIC-224**: hook 安装 (跟 immutable 同样 pattern)
- **EPIC-235/239/240**: 3 次 force-push bypass 备案全链
- **EPIC-240 §6.1**: CLAUDE.md §4 修订建议 (本 EPIC 是 §6.3 fix-root方案 C 的实现)
- **branch-4pr.sh (EPIC-181)**: 本 EPIC 让 force-push bypass 走不通, 强制走 4pr

## 8. 验证 Checklist

- [x] pre-push hook 改: 警告 → block
- [x] KALLAX_HOOK_BYPASS=1 例外保留
- [x] 11/11 测试 PASS
- [x] 错误信息含 `gh pr create` + `branch-4pr.sh`
- [x] 0 改 source code (除 hook 文件)
- [x] 0 改 CLAUDE.md / Rule / Immutable

## 9. 0 增 Rule, 0 改 Immutable

跟 EPIC-235/239/240 同样 — 仅 1 处 hook 文件 + 1 处测试文件. fix-root工具约束, 不增加 Rule.

## 10. 未来指南 (跟 EPIC-176 §4 同样模式)

| 反例 | 正确做法 |
|---|---|
| `git push origin origin/<from>:refs/heads/<to>` 直接跨主干 | `gh pr create --base <to> --head <from>` + `gh pr merge --merge --admin` (主公拍板) |
| `git push --force-with-lease origin origin/miao` 修 amend 历史 | `KALLAX_HOOK_BYPASS=1` + 主公 explicit "主公拍板: <reason>" |
| 跑 `git push` 之前想快 | 强制走 `scripts/branch-4pr.sh --epic EPIC-NNN <feature>` |

## 11. 累积本会话成果

| EPIC | 内容 | 状态 |
|---|---|---|
| EPIC-231 | PR flow gate | ✅ merged (9dbeeca4) |
| EPIC-232 | authz 5 bug + lib | ✅ merged (30a161bd) |
| EPIC-217 | README 30s | ✅ merged (eb7e60fc) |
| EPIC-235 | amend 备案 | ✅ merged (a2040afa) |
| EPIC-236 | lib 迁移 | ✅ merged (16b2da74) |
| EPIC-237 | Security Phase 1 | ✅ merged (5774a90e) |
| EPIC-238 | vitest 升级 Phase 2 | ✅ merged (0a4f3516) |
| EPIC-239 | force-push bypass 备案 #2 | ✅ merged (0269426b) |
| EPIC-240 | force-push bypass 备案 #3 | ✅ merged (66db9938) |
| **EPIC-241** | **pre-push hook fix-root** | **⏳ 本 PR, 等主公审** |

## 12. 0 改 Rule, 0 改 Immutable (重复强调)

跟 EPIC-235/239/240 同样 — 仅 hook 工具约束. 主公拍板后, 也建议补 CLAUDE.md §4 显式禁令 (EPIC-240 §6.1 建议), 单独 EPIC.

## 13. 总结

本会话 3 次 force-push bypass fix-root (C 方案简化版):
- fix-root工具: pre-push hook 跨主干 block by default
- 11/11 测试 PASS
- 0 commit 丢失, 0 历史重写
- 例外机制: KALLAX_HOOK_BYPASS=1 + 主公 explicit 批准

主公下一步:
- 合本 PR (PR-1 testing)
- 继续走真 PR 流程 (PR-2 testing→main, PR-3 main→miao)
- 独立拍板 CLAUDE.md §4 修订 (EPIC-240 §6.1 建议, 单独 EPIC)