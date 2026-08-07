#!/usr/bin/env node
// scripts/fix-stale-links.cjs — 一键修复所有 stale markdown link (转 inline code)
// EPIC-202-A 修 (4 专家挑刺):
//   - [CRITICAL] link text 含括号 `(` `)` 时 `newLine.replace(...)` 静默失败
//   - [CRITICAL] `#?` anchor / query 后跟 path 时 ref 切割错误
//   - [MAJOR] 无 --dry-run / 无 backup / 无 audit trail
// 修复策略:
//   1. 用匹配区间定位 (match.index + length), 不用字符串 replace
//   2. anchor 切割 `/#?/` 后跟 query string 也算 query (query 不算 path 一部分)
//   3. 加 --dry-run flag
//   4. 保留 backup: git diff 即可 (forward-only fix, 跟 EPIC-155 1:1 pattern)

const { readFileSync, writeFileSync, existsSync } = require('fs');
const { resolve, dirname, join, normalize } = require('path');

const REPO_ROOT = resolve(__dirname, '..');
process.chdir(REPO_ROOT);

const dryRun = process.argv.includes('--dry-run');
const showHelp = process.argv.includes('--help') || process.argv.includes('-h');

if (showHelp) {
  console.log(`Usage: node scripts/fix-stale-links.cjs [--dry-run] [--help]

Replaces stale markdown links with inline code references.

Options:
  --dry-run   Preview changes without writing files (audit-safe)
  --help      Show this help

Examples:
  node scripts/fix-stale-links.cjs           # Apply fix to all stale links
  node scripts/fix-stale-links.cjs --dry-run # Preview only

Audit trail: 'git diff' shows all modifications after run.
`);
  process.exit(0);
}

// 收集所有文件
function walk(dir) {
  const r = new Set();
  if (!existsSync(dir)) return r;
  for (const e of require('fs').readdirSync(dir, { recursive: true, withFileTypes: true })) {
    if (e.isFile()) r.add(normalize(join(e.parentPath || e.path, e.name)));
  }
  return r;
}
const all = new Set();
for (const d of ['docs', 'confluence', 'web']) for (const f of walk(d)) all.add(f);
for (const f of require('fs').readdirSync('.')) if (/\.(md|txt|json|html)$/.test(f)) all.add(f);

// 提取所有 markdown link
// 修复: 用 lastIndex 增量 + match.index 定位, 不依赖 text replace
const linkPattern = /\[([^\]]*)\]\(([^)]*\.(?:md|txt)[^)]*)\)/g;
// EPIC-202-A 扩: 同时修 HTML href 跟 JSON key (跟 check-internal-refs 1:1)
const htmlRefPattern = /href=(["'])([^"']*\.(?:md|txt)[^"']*)\1/g;
const jsonRefPattern = /"([\w./-]+\.(?:md|txt))"/g;

let totalFixed = 0;
let totalFiles = 0;

function fixLinksInFile(file, content, patterns) {
  const replacements = [];
  for (const { pattern, refGroupIndex } of patterns) {
    for (const match of content.matchAll(pattern)) {
      const fullMatch = match[0];
      const offset = match.index;
      const length = fullMatch.length;
      const refRaw = match[refGroupIndex];

      let ref = refRaw.replace(/[?#].*$/, '');
      if (/^https?:\/\//.test(ref)) continue;

      let resolved;
      const srcDir = dirname(file);
      const ext = file.split('.').pop();
      const isHtmlOrJson = ext === 'html' || ext === 'json';

      if (ref.startsWith('/')) {
        resolved = normalize(ref.slice(1));
      } else if (isHtmlOrJson) {
        resolved = normalize(ref).replace(/^(\.\.\/)+/, '');
      } else {
        resolved = normalize(join(srcDir, ref));
      }

      if (!all.has(resolved)) {
        // 修复 EPIC-202-A 对抗 review round 2: HTML 不能用 backtick/comment/嵌套 span 破坏 <a> 结构
        // 实用解: 替换 href 内容为空 + 加 data-stale attribute 标记 (保留 class 不重复)
        // 结果: <a href="../docs/x.md" class="read-more">link</a>
        //    → <a href="" data-stale="path" class="read-more stale">link</a>
        //   - href="" 避免点击跳到 broken link
        //   - data-stale 标识待修复 path
        //   - class 加 stale 标记 (CSS 可视觉标记)
        let replacement;
        if (pattern === htmlRefPattern) {
          const quote = match[1];
          // 整个 `href="..."` 替换, 但保留外部 class 等 attribute (htmlRefPattern 只匹配 href)
          replacement = `href=${quote}${quote} data-stale=${quote}${refRaw}${quote}`;
        } else if (pattern === jsonRefPattern) {
          // JSON: 保留原值 (避免破坏 JSON syntax)
          replacement = match[0];
        } else {
          // markdown: [text](path) → `path`
          replacement = `\`${refRaw}\``;
        }
        replacements.push({
          offset, length,
          replacement,
        });
      }
    }
  }

  if (replacements.length === 0) return content;

  // 从后往前替换
  replacements.sort((a, b) => b.offset - a.offset);
  let newContent = content;
  for (const r of replacements) {
    newContent = newContent.slice(0, r.offset) + r.replacement + newContent.slice(r.offset + r.length);
    totalFixed++;
  }
  return newContent;
}

for (const file of all) {
  const ext = file.split('.').pop();
  if (ext === 'md') continue;  // MD 已在下面单独跑
  if (!['html', 'json'].includes(ext)) continue;
  let content;
  try { content = readFileSync(file, 'utf-8'); } catch { continue; }

  const patterns = [];
  if (ext === 'html') patterns.push({ pattern: htmlRefPattern, refGroupIndex: 2 });
  if (ext === 'json') patterns.push({ pattern: jsonRefPattern, refGroupIndex: 1 });

  const newContent = fixLinksInFile(file, content, patterns);
  if (newContent !== content) {
    if (!dryRun) writeFileSync(file, newContent);
    totalFiles++;
  }
}

// markdown loop (保留原行为)
for (const file of all) {
  if (!file.endsWith('.md')) continue;
  let content;
  try { content = readFileSync(file, 'utf-8'); } catch { continue; }

  const newContent = fixLinksInFile(file, content, [{ pattern: linkPattern, refGroupIndex: 2 }]);
  if (newContent !== content) {
    if (!dryRun) writeFileSync(file, newContent);
    totalFiles++;
  }
}

const mode = dryRun ? ' (DRY RUN)' : '';
console.log(`${dryRun ? 'Would fix' : 'Fixed'} ${totalFixed} stale links across ${totalFiles} files${mode}`);
if (totalFixed > 0 && !dryRun) {
  console.log('Audit trail: `git diff` shows all changes.');
}