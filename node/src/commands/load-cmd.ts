/**
 * KALLAX Load Command — Lazy Load 详细文档 (Iter 2, Q14=B 决策)
 *
 * 不在 cold start 时加载详细文档 (S-04 CLAUDE.md 5KB trim 联合):
 * - `kallax load cheatsheet`  → docs/CHEATSHEET.md (27 行)
 * - `kallax load 5-levels`   → docs/5-levels.md (143 行)
 * - `kallax load 4-roles`    → docs/4-roles.md (181 行)
 * - `kallax load all`        → 3 个文件依次输出
 * - `kallax load` (无参数)   → 列出可用 topics
 *
 * 约束:
 * - 0 缓存 (每次 fs.readFileSync 重读, 0 memory cost)
 * - 0 cold start 加载 (slaver 仅在用户显式调用时读)
 * - 文件不存在 → 友好错误 + exit 1
 * - PAGER 兼容: `kallax load cheatsheet | less` 直通 stdout
 *
 * Source: Iter 2 / Q14=B 决策 (lazy load 架构) + S-04 CLAUDE.md 5KB trim 联合
 */

import { Command } from 'commander';
import * as fs from 'node:fs';
import * as path from 'node:path';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';

interface LazyTopic {
  readonly key: string;
  readonly title: string;
  readonly file: string;
  readonly description: string;
}

const LAZY_TOPICS: readonly LazyTopic[] = [
  {
    key: 'cheatsheet',
    title: 'KALLAX Cheatsheet (1 页)',
    file: 'docs/CHEATSHEET.md',
    description: 'Setup 3 步 / 30 命令速查 / 5 levels / 4 roles / 6 武器 / Q18 决策模型',
  },
  {
    key: '5-levels',
    title: 'KALLAX 5 Levels Fact-Forcing',
    file: 'docs/5-levels.md',
    description: 'L1 git log / L2 test stdout / L3 4-expert / L4 independent witness / L5 boundary',
  },
  {
    key: '4-roles',
    title: 'KALLAX 4 Roles',
    file: 'docs/4-roles.md',
    description: 'Conductor + Performer (coder/reviewer/tester/docs, 1+4 容量)',
  },
] as const;

function findProjectRoot(): string {
  let dir = process.cwd();
  while (dir !== '/') {
    if (fs.existsSync(`${dir}/.git`) || fs.existsSync(`${dir}/.kallax/IDENTITY.md`)) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return process.cwd();
}

function resolveTopicFile(topic: LazyTopic, projectRoot: string): string {
  return path.join(projectRoot, topic.file);
}

function listTopics(): void {
  const lines: string[] = [
    'KALLAX lazy-load topics:',
    '',
  ];
  for (const topic of LAZY_TOPICS) {
    lines.push(`  ${topic.key.padEnd(12)} — ${topic.title}`);
    lines.push(`  ${' '.repeat(12)}   ${topic.description}`);
    lines.push(`  ${' '.repeat(12)}   file: ${topic.file}`);
    lines.push('');
  }
  lines.push('Usage: kallax load <topic> | kallax load all');
  process.stdout.write(lines.join('\n'));
}

function emitTopic(topic: LazyTopic, projectRoot: string): void {
  const filePath = resolveTopicFile(topic, projectRoot);
  if (!fs.existsSync(filePath)) {
    logger.error({
      topic: topic.key,
      expectedPath: filePath,
    }, `lazy-load topic '${topic.key}' missing on disk (${topic.file})`);
    process.stderr.write(`error: topic '${topic.key}' not found at ${filePath}\n`);
    process.stderr.write(`hint: run from project root, or check ${topic.file} exists\n`);
    process.exit(1);
  }
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    process.stdout.write(content);
    if (!content.endsWith('\n')) {
      process.stdout.write('\n');
    }
  } catch (error: unknown) {
    const err = KallaxError.fromUnknown(error, KallaxErrorCode.INTERNAL_ERROR);
    logger.kallaxError(err);
    process.exit(1);
  }
}

export function registerLoadCommands(program: Command, _ctx: AppContext): void {
  const loadCmd = program
    .command('load [topic]')
    .description('Lazy-load a KALLAX doc on demand (cheatsheet / 5-levels / 4-roles / all)');

  loadCmd.action((topicArg?: string) => {
    const projectRoot = findProjectRoot();
    const topic = (topicArg ?? '').trim().toLowerCase();

    if (topic === '' || topic === 'list') {
      listTopics();
      return;
    }

    if (topic === 'all') {
      for (const t of LAZY_TOPICS) {
        process.stdout.write(`\n=== ${t.title} (${t.file}) ===\n\n`);
        emitTopic(t, projectRoot);
      }
      return;
    }

    const match = LAZY_TOPICS.find((t) => t.key === topic);
    if (!match) {
      process.stderr.write(`error: unknown topic '${topicArg}'\n\n`);
      listTopics();
      process.exit(1);
    }

    emitTopic(match, projectRoot);
  });
}