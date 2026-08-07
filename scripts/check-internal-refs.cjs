#!/usr/bin/env node
// scripts/check-internal-refs.sh → Node.js 实现
// 检测 docs/ + confluence/ 内 stale cross-doc .md/.txt references
// 退出码: 0=PASS, 1=stale found

const { readdirSync, readFileSync, existsSync } = require('fs');
const { resolve, dirname, join, normalize } = require('path');

const REPO_ROOT = resolve(__dirname, '..');
process.chdir(REPO_ROOT);

const jsonOut = process.argv.includes('--json');
const skipArchived = process.argv.includes('--skip-archived');

// 收集所有现有文件
function walk(dir) {
  const results = new Set();
  if (!existsSync(dir)) return results;
  for (const entry of readdirSync(dir, { recursive: true, withFileTypes: true })) {
    if (entry.isFile()) {
      results.add(normalize(join(entry.parentPath || entry.path, entry.name)));
    }
  }
  return results;
}

const allFiles = new Set();
for (const d of ['docs', 'confluence']) {
  for (const f of walk(d)) allFiles.add(f);
}
// 根目录 .md
for (const f of readdirSync('.')) {
  if (f.endsWith('.md')) allFiles.add(f);
}

// 提取引用
// 仅匹配 Markdown link 语法: [text](path.md) 或 [text](path.txt)
const refPattern = /\[([^\]]*)\]\(([^)]*\.(?:md|txt)[^)]*)\)/g;
const stale = [];
let totalRefs = 0;

function collectRefs(dir) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir, { recursive: true, withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.md')) continue;
    const filePath = normalize(join(entry.parentPath || entry.path, entry.name));
    if (skipArchived && filePath.includes('_archived')) continue;
    let content;
    try { content = readFileSync(filePath, 'utf-8'); } catch { continue; }

    const lines = content.split('\n');
    for (let li = 0; li < lines.length; li++) {
      let match;
      const line = lines[li];
      refPattern.lastIndex = 0;
      while ((match = refPattern.exec(line)) !== null) {
        let ref = match[2];
        // 去锚点
        ref = ref.replace(/#.*$/, '');
        if (!ref || /^https?:\/\//.test(ref)) continue;

        let resolved;
        const srcDir = dirname(filePath);
        if (ref.startsWith('/')) {
          resolved = normalize(ref.slice(1));
        } else {
          resolved = normalize(join(srcDir, ref));
        }

        totalRefs++;
        if (!allFiles.has(resolved)) {
          stale.push({ file: filePath, line: li + 1, ref, target: resolved });
        }
      }
    }
  }
}

collectRefs('docs');
collectRefs('confluence');

// Output
if (jsonOut) {
  console.log(JSON.stringify({ total_refs: totalRefs, stale_refs: stale.length, stale }, null, 2));
} else {
  console.log(`=== check-internal-refs: ${totalRefs} refs, ${stale.length} stale ===`);
  if (stale.length > 0) {
    for (const s of stale) {
      console.log(`  ${s.file}:${s.line}:${s.ref} -> ${s.target} (NOT FOUND)`);
    }
    console.log(`\nFAIL: ${stale.length} stale reference(s)`);
  } else {
    console.log('PASS: 0 stale references');
  }
}

process.exit(stale.length > 0 ? 1 : 0);
