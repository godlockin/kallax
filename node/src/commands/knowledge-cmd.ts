/**
 * KALLAX Knowledge Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

// read stdin helper — used when content is piped
async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(Buffer.from(chunk as Uint8Array));
  }
  return Buffer.concat(chunks).toString('utf-8');
}

export function registerKnowledgeCommands(program: Command, _ctx: AppContext): void {
  const knowledge = program.command('knowledge').description('Knowledge base management');

  knowledge
    .command('index <title>')
    .description('Index a knowledge entry')
    .option('-c, --content <content>', 'Content (reads stdin if omitted)')
    .option('-t, --tags <tags>', 'Comma-separated tags')
    .option('-s, --source <source>', 'Source identifier', 'manual')
    .action(async (title: string, opts: Record<string, string>): Promise<void> => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        let content = opts['content'] ?? '';
        if (content === '' && !process.stdin.isTTY) {
          content = (await readStdin()).trim();
        }

        const tagsOpt = opts['tags'];
        const tags = tagsOpt != null && tagsOpt !== ''
          ? tagsOpt.split(',').map((t: string) => t.trim())
          : [];

        const result = kb.add({ title, content, tags, source: opts['source'] ?? 'manual' });
        if (result.isErr()) throw result.error;

        process.stdout.write(`Indexed: ${result.value.id}\n`);
        process.stdout.write(`  Title: ${title}\n`);
        process.stdout.write(`  Tags: ${tags.join(', ') || '(none)'}\n`);
        process.stdout.write(`  Words: ${String(content.length)} chars\n`);
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  knowledge
    .command('search <query>')
    .description('Search knowledge base')
    .option('-t, --tags <tags>', 'Filter by comma-separated tags')
    .option('-l, --limit <limit>', 'Max results', '10')
    .option('-s, --sort <sort>', 'Sort: relevance|date', 'relevance')
    .action(async (query: string, opts: Record<string, string>): Promise<void> => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
        const tagsOpt = opts['tags'];
        const tags = tagsOpt != null && tagsOpt !== ''
          ? tagsOpt.split(',').map((t: string) => t.trim())
          : undefined;

        const result = kb.search({
          terms,
          tags,
          limit: parseInt(opts['limit'] ?? '10', 10),
          sortBy: (opts['sort'] as 'relevance' | 'date' | undefined) ?? 'relevance',
        });

        if (result.isErr()) throw result.error;

        if (result.value.length === 0) {
          process.stdout.write('No results found.\n');
        } else {
          for (const r of result.value) {
            process.stdout.write(`[${r.score.toFixed(1)}] ${r.entry.title} (${r.entry.id})\n`);
            process.stdout.write(`  Tags: ${r.entry.tags.join(', ') || '(none)'}\n`);
            process.stdout.write(`  Preview: ${r.entry.content.slice(0, 120)}...\n\n`);
          }
        }
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  knowledge
    .command('list')
    .description('List all knowledge entries')
    .option('-l, --limit <limit>', 'Max entries', '50')
    .action(async (opts: Record<string, string>): Promise<void> => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        const result = kb.list({ limit: parseInt(opts['limit'] ?? '50', 10) });
        if (result.isErr()) throw result.error;

        const stats = kb.getStats();
        process.stdout.write(`Total: ${String(stats.totalEntries)} entries, ${String(stats.totalWords)} words indexed\n\n`);

        for (const entry of result.value) {
          const date = new Date(entry.updatedAt).toISOString().slice(0, 10);
          process.stdout.write(`  ${date}  ${entry.id}  ${entry.title}\n`);
          process.stdout.write(`         tags: ${entry.tags.join(', ') || '(none)'}\n`);
        }
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  knowledge
    .command('gc')
    .description('Garbage collect old entries')
    .option('-d, --days <days>', 'Remove entries older than N days', '90')
    .action(async (opts: Record<string, string>): Promise<void> => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        const days = parseInt(opts['days'] ?? '90', 10);
        const result = kb.gc(days * 86400_000);

        if (result.isErr()) throw result.error;
        process.stdout.write(`GC complete: removed ${String(result.value)} entries older than ${String(days)} days\n`);
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  // review — staleness audit (merged from memory:review, EPIC-064-3)
  knowledge
    .command('review')
    .description('Review knowledge entries — staleness audit (fresh vs stale)')
    .option('-s, --stale <days>', 'Entries older than N days are stale', '30')
    .option('-n, --limit <limit>', 'Max entries shown per bucket', '50')
    .action(async (opts?: { stale?: string; limit?: string }): Promise<void> => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        const staleDays = parseInt(opts?.['stale'] ?? '30', 10);
        const limit = parseInt(opts?.['limit'] ?? '50', 10);

        const allResult = kb.list({ limit: 1000 });
        if (allResult.isErr()) throw allResult.error;

        const stats = kb.getStats();
        const stale: Array<{ id: string; title: string; ageDays: number; tags: string[] }> = [];
        const fresh: Array<{ id: string; title: string; tags: string[] }> = [];

        for (const entry of allResult.value) {
          const ageDays = (Date.now() - entry.updatedAt) / 86400_000;
          if (ageDays > staleDays) {
            stale.push({ id: entry.id, title: entry.title, ageDays: Math.round(ageDays), tags: [...entry.tags] });
          } else {
            fresh.push({ id: entry.id, title: entry.title, tags: [...entry.tags] });
          }
        }

        stale.sort((a, b) => b.ageDays - a.ageDays);

        process.stdout.write(JSON.stringify({
          stats: { total: stats.totalEntries, words: stats.totalWords },
          stale: stale.slice(0, limit),
          fresh: fresh.slice(0, limit),
          summary: `${String(stale.length)} stale entries (>${String(staleDays)}d), ${String(fresh.length)} fresh entries`,
        }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
