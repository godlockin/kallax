# KALLAX 5 Levels Fact-Forcing

> KALLAX 5 级验证机制, 跟 eket 5 levels 概念 一致, 但 KALLAX 实做 (eket 5 levels 是名字, 武器 2)

## 入口命令

```bash
kallax verify l1 TICKET-001       # 单 level
kallax verify l2 TICKET-001
kallax verify l3 TICKET-001
kallax verify l4 TICKET-001
kallax verify l5 TICKET-001
kallax verify all TICKET-001      # 一次跑 L1-L5
```

---

## L1: 存在性 (git log SHA 真变)

**目的**: 验证 commit 真存在 + SHA 真变 (反 "Amend SHA 没变" 反模式)

**验证命令**:
```bash
git log --oneline -1                          # 看 HEAD SHA
git diff HEAD~1 --stat                        # 看变更文件
git show HEAD --name-only                     # 看变更文件列表
```

**PASS 标准**: HEAD SHA 跟 ticket 期望 SHA 一致 + 变更文件 ≥ 1

**典型 FAIL 模式**:
- Subagent 报 "commit 完成" 但 git log 看不到 (Amend 撤销)
- SHA 跟 commit message 不匹配

---

## L2: 实质性 (test stdout 真实跑)

**目的**: 验证测试真跑过 + stdout 真实 (反 "should work" 估数)

**验证命令**:
```bash
cargo test --all --no-fail-fast 2>&1 | tee /tmp/test-stdout.log
grep -E "test result:.*(passed|failed)" /tmp/test-stdout.log
```

**PASS 标准**: test result 行存在 + 0 failed (或 failure < 阈值且已知)

**典型 FAIL 模式**:
- "Tests should pass" 估数 (无 raw stdout)
- trigger 字段复制 test case 文本 (verbatim 反模式)
- integration test 跳过

---

## L3: 接线正确 (4-expert 评审)

**目的**: 4 个 expert 真实审 PR (architect/backend/frontend/security), 反 "自审" 反模式

**验证命令**:
```bash
# 4 expert 各自输出 review JSON
kallax expert:run architect --ticket TICKET-001
kallax expert:run backend --ticket TICKET-001
kallax expert:run frontend --ticket TICKET-001
kallax expert:run security --ticket TICKET-001

# 汇总 review
kallax expert:aggregate TICKET-001
```

**PASS 标准**: 4 expert 全输出 review + 无 P0 issue (P1/P2 备案 OK)

**典型 FAIL 模式**:
- Expert 没真跑 (只 mark PASS)
- Self-review (subagent 审自己)

---

## L4: 独立见证 (independent witness 重跑)

**目的**: 独立 Slaver session 重跑 L1-L3, 不可被原 subagent 篡改

**验证命令**:
```bash
# Spawn 独立 witness (新 session, 无原 subagent 上下文)
kallax witness:spawn TICKET-001 --independent

# Witness 跑 L1-L3 输出
kallax witness:output TICKET-001

# 对比原 subagent 报告
kallax witness:diff TICKET-001
```

**PASS 标准**: Witness 输出跟原 subagent 一致 (PASS/PASS) 或原 FAIL 真 (不瞒报)

**典型 FAIL 模式**:
- Subagent 报 PASS, witness 重跑 FAIL (瞒报)
- Witness 引用原 subagent 上下文 (不独立)
- audit-log-sink 可被 subagent 写 (Rule 30 不可绕过)

---

## L5: 边界检查 (boundary input/异常路径/并发)

**目的**: 边界输入/异常路径/并发竞争 真实测, 反 "happy path only"

**验证命令**:
```bash
# 边界输入
kallax test:boundary TICKET-001 --input empty
kallax test:boundary TICKET-001 --input max
kallax test:boundary TICKET-001 --input unicode

# 异常路径
kallax test:exception TICKET-001 --error-network
kallax test:exception TICKET-001 --error-permission

# 并发竞争
kallax test:concurrent TICKET-001 --workers 4
```

**PASS 标准**: 边界/异常/并发 case 全过, 或已知 fail 备案 (BE-7 模式)

**典型 FAIL 模式**:
- Happy path PASS 但边界 fail (e.g. empty input 崩)
- 异常路径无 graceful error
- 并发产生 dirty read/write

---

## 跟 eket 5 levels 区别

| 维度 | eket 5 levels | KALLAX 5 levels |
|------|---------------|-----------------|
| **定义** | 概念 (5 levels of fact-forcing) | 概念 + 实做 (武器 2) |
| **工具** | 无独立 binary | `kallax verify l1..l5` CLI |
| **L4 独立见证** | 概念 | 实做 (witness:spawn) |
| **L5 边界** | 概念 | 实做 (test:boundary/exception/concurrent) |
| **集成** | eket skill 速查 | pre-commit hook + ticket-status 联动 |

**结论**: eket 5 levels 是命名空间, KALLAX 是 5 levels 实施框架 (武器 2)
