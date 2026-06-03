/**
 * KALLAX Memory Review Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

export function registerMemoryCommands(program: Command, _ctx: AppContext): void {
  program
    .command('memory:review')
    .description('Review knowledge entries — list all for audit')
    .option('-s, --stale <days>', 'Entries older than N days', '30')
    .option('-n, --limit <limit>', 'Max entries', '50')
    .action(async (opts?: { stale?: string; limit?: string }) => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        const staleDays = parseInt(opts?.['stale'] ?? '30', 10);
        const limit = parseInt(opts?.['limit'] ?? '50', 10);
        const cutoff = Date.now() - staleDays * 86400_000;

        const allResult = kb.list({ limit: 1000 });
        if (allResult.isErr()) { logger.kallaxError(allResult.error); process.exit(1); }

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
          summary: `${stale.length} stale entries (>${staleDays}d), ${fresh.length} fresh entries`,
        }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
