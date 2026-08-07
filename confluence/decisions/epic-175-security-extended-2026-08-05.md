# EPIC-175 Security Rules Extended — Decision Record

> **Date**: 2026-08-05
> **Phase**: PHASE-022, Phase 5 D
> **EPIC**: EPIC-175
> **Status**: DONE
> **Expert**: compliance

---

## Context

主公 2026-08-05 Phase 5 D 拍板: 借鉴 loopx AGENTS.md Security Rules 强化 + Release Capability Usage Gate + Contributor Attribution.

**已借鉴 EPIC-163**:
- Public/Private Boundary (EPIC-163 已借鉴)

**本 EPIC 借鉴剩余 3 项**:
1. **Release Contributor Attribution** — CHANGELOG 加 community contributors 段, dual-language
2. **Release Capability Usage Gate** — release 引入新能力必含激活/禁用/隐私/链接
3. **Capability And Extension Placement 决策树** — docs/reference 加 capability-placement.md

---

## Decisions

### Decision 1: Community Contributors Template (AC1)

**Option A**: 加模板到每个 CHANGELOG entry (中英双语)
**Option B**: 加单独 section 在顶部
**Option C**: 加到每个 entry 的固定位置

**Selected**: Option A — 加模板到 v3.32.21 entry (中英双语, 跟 loopx 1:1)

**Rationale**: 模板位置固定, 方便贡献者添加, 跟 loopx CHANGELOG 模式一致

### Decision 2: Release Capability Usage Gate (AC2)

**Option A**: 扫描 CHANGELOG.md 检测 capability 4 字段
**Option B**: 扫描 PR body 检测 capability 4 字段
**Option C**: 两处都检测

**Selected**: Option A — 扫描 CHANGELOG.md 检测 (pre-commit hook 场景)

**Rationale**: CHANGELOG.md 是 release artifact, 自然包含 capability 描述

### Decision 3: Automation Monitor Heartbeat Integration (AC3)

**Option A**: 独立 monitor 进程
**Option B**: 集成到 EPIC-166 heartbeat daemon
**Option C**: 独立脚本, daemon 可调用

**Selected**: Option C — 独立脚本 `automation-monitor-todos.sh`, daemon 可调用

**Rationale**: 跟 EPIC-166 daemon 1:1 协同, 保持职责分离

### Decision 4: Benchmark Smoke Classification (AC4)

**Option A**: 2 类 (unit/integration)
**Option B**: 3 类 (boundary/ledger/classifier)
**Option C**: 4 类 (boundary/ledger/classifier/adapter)

**Selected**: Option C — 4 类 (跟 loopx 1:1)

**Rationale**: 覆盖所有常见 benchmark smoke 场景

### Decision 5: Capability Placement Decision Tree (AC5)

**Option A**: 3 类 placement (name/extend/built-in)
**Option B**: 4 类 placement (name/extend/built-in/provider)
**Option C**: 5 类 placement (name/extend/built-in/provider/package)

**Selected**: Option C — 5 类 placement (跟 loopx docs/reference/extensions.md 1:1)

**Rationale**: 覆盖所有 KALLAX capability 场景

---

## Deliverables

| AC | Deliverable | Status |
|----|-------------|--------|
| AC1 | CHANGELOG Community Contributors 模板 | ✅ |
| AC2 | scripts/check-release-capability.sh | ✅ |
| AC3 | scripts/automation-monitor-todos.sh | ✅ |
| AC4 | scripts/check-benchmark-smoke.sh | ✅ |
| AC5 | docs/reference/capability-placement.md | ✅ |
| AC6 | docs/process/projection-sink-design.md | ✅ |
| AC7 | tests/integration/security-rules-extended.test.sh | ✅ |
| AC8 | 5-Level Verify L1-L5 | ✅ |
| AC9 | 4-PR 全程 | ⏳ |
| AC10 | 0 改 source code, 0 增 Rule, 0 增 immutable script | ✅ |

---

## Compatibility

- **0 改 source code** (node/src/ + rust/src/ 完全不动)
- **0 增 Rule, 0 增 immutable script**
- **跟 EPIC-163 Security Rules 1:1 协同**
- **跟 EPIC-166 Heartbeat Daemon 1:1 协同**

---

## References

- [loopx AGENTS.md Security Rules](https://github.com/godlockin/loopx/blob/main/AGENTS.md)
- [loopx docs/reference/extensions.md](https://github.com/godlockin/loopx/blob/main/docs/reference/extensions.md)
- `loopx-vs-kallax-governance-gap-2026-08-05.md`
- [EPIC-166 Heartbeat Daemon](epic-166-daemon-runtime-verification-2026-08-05.md)
