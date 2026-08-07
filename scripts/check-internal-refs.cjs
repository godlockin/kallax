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
const includeScripts = process.argv.includes('--scripts');
// scripts scope 默认忽略注释行 (避免 false positive), 用 --scripts-strict 启用严格模式
const scriptsStrict = process.argv.includes('--scripts-strict');

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
for (const d of ['docs', 'confluence', 'web']) {
  for (const f of walk(d)) allFiles.add(f);
}
// 根目录 .md / .txt / .json / .html
for (const f of readdirSync('.')) {
  if (/\.(md|txt|json|html)$/.test(f)) allFiles.add(f);
}

// 提取引用
// 匹配 Markdown/HTML/JSON link 语法: [text](path.md) 或 [text](path.txt) 或 html href="path.md" 或 json "key":"path.md"
// 收紧: ref 必须含 / 或 .md/.txt 结尾, 且不含空格 (避免误报中英文本)
const mdRefPattern = /\[([^\]]*)\]\(([^)]*\.(?:md|txt)[^)]*)\)/g;
// 修复 EPIC-202-A 对抗 review: htmlRefPattern 含 backtick (fix-stale-links 输出 href="`path`" 形式)
const htmlRefPattern = /href=["'`]([^"'`]*\.(?:md|txt)[^"'`]*)["'`]/g;
const jsonRefPattern = /"([\w./-]+\.(?:md|txt))"/g;
const stale = [];
let totalRefs = 0;

function checkRef(filePath, lineNum, ref) {
  // 去锚点 + query string (修复 EPIC-202-A: `#?tab=active` 跟 `?query=value` 都被认作非 path 部分)
  ref = ref.replace(/[?#].*$/, '');
  if (!ref || /^https?:\/\//.test(ref)) return;
  // 收紧: 必须看起来像路径 (含 / 或 以 .md/.txt 结尾), 不含空格
  if (!/[\w./-]+\.(?:md|txt)$/.test(ref) && !ref.includes('/')) return;
  if (/\s/.test(ref)) return;

  let resolved;
  const ext = filePath.split('.').pop();
  const isHtmlOrJson = ext === 'html' || ext === 'json';
  const srcDir = dirname(filePath);

  if (ref.startsWith('/')) {
    resolved = normalize(ref.slice(1));
  } else if (isHtmlOrJson) {
    // HTML/JSON ref 期望相对 REPO_ROOT (跟 markdown 相对 srcDir 不同).
    // 例: web/showcase/index.html 写 `../docs/community/README.md` → docs/community/README.md
    // 直接 normalize (保留 ../) + 去 REPO_ROOT 前缀
    resolved = normalize(ref);
    // 去掉前导 ../
    while (resolved.startsWith('../')) resolved = resolved.slice(3);
  } else {
    // markdown 相对 srcDir
    resolved = normalize(join(srcDir, ref));
  }

  totalRefs++;
  if (!allFiles.has(resolved)) {
    stale.push({ file: filePath, line: lineNum, ref, target: resolved });
  }
}

function collectRefs(dir) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir, { recursive: true, withFileTypes: true })) {
    if (!entry.isFile()) continue;
    const filePath = normalize(join(entry.parentPath || entry.path, entry.name));
    if (skipArchived && filePath.includes('_archived')) continue;
    const ext = entry.name.split('.').pop();
    if (!['md', 'html', 'json', 'sh', 'cjs', 'js'].includes(ext)) continue;

    let content;
    try { content = readFileSync(filePath, 'utf-8'); } catch { continue; }

    const lines = content.split('\n');
    const pattern = ext === 'md' ? mdRefPattern
      : ext === 'html' ? htmlRefPattern
      : jsonRefPattern;

    // scripts scope (loose): 跳过注释行
    const skipComments = includeScripts && !scriptsStrict;

    for (let li = 0; li < lines.length; li++) {
      const line = lines[li].trim();
      if (skipComments && (line.startsWith('#') || line.startsWith('//') || line.startsWith('/*'))) continue;
      pattern.lastIndex = 0;
      let match;
      while ((match = pattern.exec(line)) !== null) {
        // 修复 EPIC-202-A: ref 取 path 部分 (match[2] 是 (path), match[1] 是 [text])
        // 不同 pattern 结构不同, 这里按 pattern 顺序取最后一个非空 group
        const ref = match[2] || match[1];
        checkRef(filePath, li + 1, ref);
      }
    }
  }
}

collectRefs('docs');
collectRefs('confluence');
if (includeScripts) collectRefs('scripts');
collectRefs('web');  // EPIC-202-A: web/ HTML scope 总是开启

// Output
const scopeNote = includeScripts ? ' (scope: docs+confluence+scripts[loose])' : '';
if (jsonOut) {
  console.log(JSON.stringify({ total_refs: totalRefs, stale_refs: stale.length, scope: includeScripts ? 'scripts' : 'docs+confluence', stale }, null, 2));
} else {
  console.log(`=== check-internal-refs${scopeNote}: ${totalRefs} refs, ${stale.length} stale ===`);
  if (stale.length > 0) {
    for (const s of stale) {
      console.log(`  ${s.file}:${s.line}:${s.ref} -> ${s.target} (NOT FOUND)`);
    }
    if (includeScripts && !scriptsStrict) {
      console.log(`\nNote: scripts scope in loose mode skips comment lines; remaining stale are likely var assignments or grep patterns (false positives).`);
    }
    console.log(`\nFAIL: ${stale.length} stale reference(s)`);
  } else {
    console.log('PASS: 0 stale references');
  }
}

process.exit(stale.length > 0 ? 1 : 0);
