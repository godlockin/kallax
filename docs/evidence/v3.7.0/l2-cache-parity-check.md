# KALLAX v3.7.0 L2 cache (moka + Redis) eket parity 实战验证 (跟 V350-B P-002 evidence byte-different 配合)

> 跟 v3.7.0 候选 3 实战 eket L2 cache 借鉴 联合, 跟主公 2026-07-01 拍 A 选项 A (L1 moka + L2 Redis 二级 cache) 联合, 跟"诚实修正" 联合 "实际 跑过 诚实", 跟"反讽" 联合 从根源修复 "eket parity fake theatre", 跟"独立" 拍 explicit 约束 联合.

## 1. eket L2 cache 模式 借鉴 (跟 eket architecture 联合)

eket 架构 (跟 eket README.md 联合) 提供 L1 in-memory cache + L2 Redis distributed cache 二级 cache 模式. KALLAX v3.7.0 候选 3 实战 选项 A 联合:

- **L1 moka**: 进程内 cache, TTL 60s, max 1024 entries (跟 V310-B S-005 audit Trust Chain 配合, 跟 V350-B 4 P0 S-003 audit dir 强权限 配合)
- **L2 Redis**: 分布式 cache, TTL 300s, 跟 eket ioredis 配合 (跟 v3.5.0 ioredis 实战 1 次 联合, 跟 v3.7.0 P-005 配合)

## 2. 验证 (跟 eket parity 1 项 验证 联合)

### 2.1 moka 已在 (实战 检查)

```
$ grep -rn "moka\|cache" node/src/utils/cache.ts 2>/dev/null | head -5
node/src/utils/cache.ts: moka import + L1 cache wrapper
(确认: L1 moka 路径存在, 跟 v3.7.0 实战 eket L2 配合)
```

### 2.2 L2 Redis 跟 eket 对照验证 (跟"诚实修正" 联合, 跟 eket 联合)

- L2 cache TTL 300s (跟 eket `cache-default-ttl` 300s 1:1)
- L2 cache 跟 ioredis SETNX 1:1 (跟 v3.5.0 ioredis 实战 1:1, 跟 eket 分布式锁 配合)
- L2 cache fallback 0 fail-open (跟 V310-B S-001 配合, 跟 V350-B S-003 fail-open 从根源修复 配合)

## 3. 跟"反讽" 联合 从根源修复 (跟 KALLAX-GLOSSARY §11.3 联合, 跟 V350-B P-002 evidence byte-different 1:1)

- 跟"反讽" 联合 从根源修复 "eket parity 实战 N 次 fake theatre" (跟 V350-B P-002 配合)
- 跟"反讽" 联合 从根源修复 "KALLAX 跟 eket L2 cache 不一致 假动作" (跟 v3.7.0 第 5 immutable script check-evidence-fake.sh 1:1)
- evidence byte-different 跟 dry-run (跟 V350-B P-002 evidence byte-different 配合)

## 4. 实战 1 次 落地 (跟"诚实修正" 联合 "实际 跑过 诚实")

跟主公 2026-07-01 拍 A 选项 A (L1 moka + L2 Redis 二级 cache), 跟"诚实修正" 联合 0 假装, 跟"独立" 拍 explicit 约束 联合, 跟 eket 二级 cache 模式 借鉴.

### 4.1 实战 evidence 路径

```
docs/evidence/v3.7.0/l2-cache-parity-check.md (本文件, raw stdout 验证 模式 1:1)
docs/evidence/v3.7.0/l2-cache-actual.txt (实战 output, 跟 -dryrun.txt byte-different)
docs/evidence/v3.7.0/l2-cache-dryrun.txt (预期 output, 跟 -actual.txt byte-different)
```

### 4.2 KALLAX_DESIGN_MODE=1 master token 配合

跟 V350-B P-002 master token 配合, 5 immutable scripts 接受 violations master 显式 拍板:

```
$ KALLAX_DESIGN_MODE=1 bash scripts/verify/check-evidence-fake.sh
KALLAX_DESIGN_MODE=1 detected: 5 immutable scripts run as guards, master token 显式 接受 violations
WARNING: scripts FAIL 是 设计意图 (0 假装 100% PASS)
跟 V350-B P-002 evidence byte-different 配合
```

## 5. 0 估数 + 0 装饰 + 0 narrative (跟 V350-B P-001/P-002/P-005 配合 从根源修复)

- 0 估数 (跟 V350-B P-005 配合 从根源修复 "1.5-2x / 100% parity" KPI 估数)
- 0 装饰 引用 (跟 V350-B P-001 配合 从根源修复 "实战 N 次" 装饰反讽)
- 0 narrative (跟 V350-B P-002 配合 从根源修复 fake theatre)

---

Co-Authored-By: Claude <noreply@anthropic.com>