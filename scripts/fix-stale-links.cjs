#!/usr/bin/env node
// scripts/fix-stale-links.cjs — 一键修复所有 stale markdown link (转 inline code)
const { readFileSync, writeFileSync, existsSync } = require('fs');
const { resolve, dirname, join, normalize } = require('path');

const REPO_ROOT = resolve(__dirname, '..');
process.chdir(REPO_ROOT);

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
for (const d of ['docs', 'confluence']) for (const f of walk(d)) all.add(f);
for (const f of require('fs').readdirSync('.')) if (f.endsWith('.md')) all.add(f);

// 提取所有 markdown link
const linkPattern = /\[([^\]]*)\]\(([^)]*\.(?:md|txt)[^)]*)\)/g;

let totalFixed = 0;
let totalFiles = 0;

for (const file of all) {
  if (!file.endsWith('.md')) continue;
  let content;
  try { content = readFileSync(file, 'utf-8'); } catch { continue; }

  const lines = content.split('\n');
  let changed = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    let newLine = line;
    let match;
    linkPattern.lastIndex = 0;
    while ((match = linkPattern.exec(line)) !== null) {
      const ref = match[2].replace(/#.*$/, '');
      if (/^https?:\/\//.test(ref)) continue;

      let resolved;
      const srcDir = dirname(file);
      if (ref.startsWith('/')) {
        resolved = normalize(ref.slice(1));
      } else {
        resolved = normalize(join(srcDir, ref));
      }

      if (!all.has(resolved)) {
        // 把 [text](path) 改成 `path`
        const replacement = `\`${match[2]}\``;
        newLine = newLine.replace(`[${match[1]}](${match[2]})`, replacement);
        totalFixed++;
        changed = true;
      }
    }
    if (changed) lines[i] = newLine;
  }

  if (changed) {
    writeFileSync(file, lines.join('\n'));
    totalFiles++;
  }
}

console.log(`Fixed ${totalFixed} stale links across ${totalFiles} files`);