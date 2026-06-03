/**
 * KALLAX Doc Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

export function registerDocCommands(program: Command, _ctx: AppContext): void {
  const docCmd = program.command('doc').description('Documentation management');

  docCmd
    .command('create <type> <title>')
    .description('Create a documentation entry')
    .option('-c, --content <content>', 'Document content or file path')
    .option('-t, --tags <tags>', 'Comma-separated tags', 'documentation')
    .action(async (type: string, title: string, opts?: { content?: string; tags?: string }) => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        const tags = opts?.['tags'] ? opts['tags'].split(',').map((t: string) => t.trim()) : ['documentation'];
        const content = opts?.['content'] ?? `# ${title}\n\nType: ${type}\nCreated: ${new Date().toISOString()}`;

        const result = kb.add({
          title: `[${type.toUpperCase()}] ${title}`,
          content,
          tags: [...tags, type, 'documentation'],
          source: 'doc-cli',
        });

        if (result.isErr()) { logger.kallaxError(result.error); process.exit(1); }

        process.stdout.write(JSON.stringify({
          id: result.value.id, title: result.value.title, type,
          tags: result.value.tags, words: result.value.content.length,
        }) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  docCmd
    .command('status')
    .description('Show documentation summary')
    .action(async () => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();
        const stats = kb.getStats();
        const docsResult = kb.search({ terms: ['documentation'], limit: 100, sortBy: 'date' });

        const docs = docsResult.isOk() ? docsResult.value : [];
        const byType = new Map<string, number>();
        for (const d of docs) {
          const typeTag = d.entry.tags.find((t: string) => ['design', 'api', 'guide', 'spec'].includes(t));
          const type = typeTag ?? 'other';
          byType.set(type, (byType.get(type) ?? 0) + 1);
        }

        process.stdout.write(JSON.stringify({
          totalEntries: stats.totalEntries,
          documentCount: docs.length,
          byType: Object.fromEntries(byType),
          lastUpdated: docs.length > 0 ? docs[0]!.entry.updatedAt : null,
        }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
