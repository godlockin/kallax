#!/usr/bin/env node
// scripts/strip-stale-links.cjs — 把 stale markdown link 转 inline code
// 接收 stdin (check-internal-refs 输出)，对每个 (file:line:ref → target NOT FOUND)
// 把 markdown link `[text](ref)` 替换为 inline code `` `ref` ``
// 仅处理 link 中 path 等于 stale ref 的情况

const { readFileSync, writeFileSync } = require('fs');
const { resolve } = require('path');

const REPO_ROOT = resolve(__dirname, '..');
process.chdir(REPO_ROOT);

// 从 argv 读取 file:line:ref 三元组
const args = process.argv.slice(2);
if (args.length === 0) {
  console.log('Usage: node scripts/strip-stale-links.cjs <file>:<line>:<ref> [...]');
  process.exit(2);
}

// 按文件分组
const byFile = {};
for (const arg of args) {
  const [f, l, ...r] = arg.split(':');
  const ref = r.join(':');
  if (!byFile[f]) byFile[f] = [];
  byFile[f].push({ line: parseInt(l), ref });
}

let totalStripped = 0;
for (const [file, refs] of Object.entries(byFile)) {
  const path = resolve(REPO_ROOT, file);
  let content;
  try { content = readFileSync(path, 'utf-8'); } catch { continue; }

  const lines = content.split('\n');
  for (const { line, ref } of refs) {
    if (line < 1 || line > lines.length) continue;
    const li = line - 1;

    // 匹配 [...](<ref>) 或 [..](<ref>#...) 模式
    const patterns = [
      new RegExp(`\\[([^\\]]*)\\]\\(${escapeRegex(ref)}([^)]*)\\)`, 'g'),
    ];
    for (const p of patterns) {
      const before = lines[li];
      lines[li] = lines[li].replace(p, (m, text) => {
        totalStripped++;
        return `\`${ref}\``;
      });
    }
  }

  writeFileSync(path, lines.join('\n'));
}

console.log(`Stripped ${totalStripped} stale links across ${Object.keys(byFile).length} files`);

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}