# P-004 DECISION: 保留 nested dir (选项 C 落地, 跟 v3.5.0 现状 1:1)

> **拍板**: 主公 2026-07-01 拍 A 选项 C (保留 nested dir + 显式 mark 历史 reference)
> **理由**: 跟 v3.2.0 拍 C "重写 > 删除" 1:1 联合, 0 风险, 跟 v3.6.0 简化哲学 1:1 联合 (1 主 + 0 sub-doc sprawl, 但 online-deploy 是 例外)

## 1. 拍板 选项 决策 树 (raw stdout)

```
P-004 ERRATA 3 选项:
  A 合并进 degradation-strategy.md → 删 nested dir → 冲突 (v3.6.0 已删 degradation-strategy.md)
  B 合并进 isolation-strategy.md → 删 nested dir → 冲突 (v3.6.0 已删 isolation-strategy.md)
  C 保留 nested dir + 显式 mark DEPRECATED → 跟 v3.6.0 现状 1:1, 0 风险

决策: C (主公 拍 A)
```

## 2. 跟 v3.6.0 简化 1:1 联合 (raw stdout 验证)

```
$ ls docs/architecture/
_index.md
online-deploy-2026-06-30/    ← v3.7.0 保留 (P-004 选项 C)

$ cat docs/architecture/_index.md | grep -n online-deploy
27:- 例外: online-deploy-2026-06-30/ (P-004 ERRATA 待主公拍)
```

`_index.md` 1 段 引用 跟 v3.6.0 `_index.md` 1:1 联合 模式 (跟 v3.6.0 5 release 累计 简化 1:1).

## 3. 跟 v3.2.0 拍 C 1:1 联合 (历史 1:1)

v3.2.0 拍 C "重写 > 删除" 4 DEPRECATED sub-doc 覆盖重写, 跟 v3.7.0 选项 C 1:1 联合.

## 4. 0 风险 验证 (跟 Q12 战略 1:1 联合)

- 0 改动 nested dir 内容 (跟 "独立" 拍板 联合, 不擅自 删 / 重写 / 整合)
- 0 估数 (跟 V350-B P-005 1:1 联合 治根)
- 0 装饰 引用 (跟 V350-B P-001 1:1 联合 治根)
- 0 narrative 包装 (跟 V350-B P-002 1:1 联合 治根)

---

Co-Authored-By: Claude <noreply@anthropic.com>