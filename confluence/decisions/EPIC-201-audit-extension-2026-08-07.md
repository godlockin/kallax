# EPIC-201: docs audit 极致扩展 — 拍板记录 (2026-08-07)

> **起源**: EPIC-200 retrospective 自查 — 3 个潜在不足 (check-internal-refs scope 窄, 缺 DEPRECATED index, scripts/ 没扫)。

## 拍板决定

### A. check-internal-refs 扩 scope

**之前**: 仅扫 .md 文件 → 漏掉 experts HTML, showcase-catalog.json, evidence .txt, scripts .sh
**之后**: 支持 .md / .html / .json / .sh / .cjs / .js
**Pattern 改进**:
- markdown: `[text](path.md)`
- HTML: `href="path.md"`
- JSON: `"key": "path.md"`
- 收紧: ref 必须含 `/` 或 `.md`/`.txt` 结尾, 不含空格 (避免中英文本误报)
- 修复双重目录前缀 bug (`docs/docs/CHEATSHEET.md`)

**退出码契约**: docs+confluence scope 仍 0=ok / 1=stale; scripts scope 用 loose 模式 (跳过注释行) 仅作参考, 不参与 fail-fast。

### B. docs/_deprecated-index.md

**问题**: 22 个 DEPRECATED header 文件散落, reader 不知道全貌。
**方案**: 1 页索引, 列出全部 22 文件 + 现代替代 + 分类统计。

| 分组 | 文件数 |
|------|-------|
| docs/_archived/ | 7 |
| docs/architecture/online-deploy-2026-06-30/ | 3 |
| docs/superpowers/ | 6 |
| 根级 docs/ | 5 |
| confluence/ | 2 |
| **总计** | **22** |

### C. scripts/ stale ref 扫描

**方法**: `node scripts/check-internal-refs.cjs --scripts` 启 loose 模式 (跳过注释行)。
**发现**: 8 处 stale, 大部分是 var assignment / grep pattern, 不是真 ref (scripts grep pattern 是 ref-detector, 不该被检测为 ref)。
**行动**: `post-process.sh` 3 个 var (GLOSSARY/PHASE-INDEX/ACCUMULATED) 加 DEPRECATED path 注释, fail-soft 行为保留 (var 检查后 if [ -f ] 处理)。
**scripts scope 限制**: 仅作 governance-debt audit, 不参与 CI fail-fast。

## 验证

```bash
node scripts/check-internal-refs.cjs              # 0 stale (docs+confluence)
node scripts/check-internal-refs.cjs --scripts   # 8 stale (scripts loose mode, 仅供参考)
```

## 联动

- EPIC-199: 7 DEPRECATED header 起步
- EPIC-200: 15 DEPRECATED header 扩展
- **EPIC-201 (本)**: 加 _deprecated-index.md 22 文件全索引 + 工具扩 scope

---

Co-Authored-By: Claude <noreply@anthropic.com>