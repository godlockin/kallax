/**
 * KALLAX Expert and Recommend Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

export function registerExpertCommands(program: Command, ctx: AppContext): void {
  program
    .command('recommend')
    .description('Recommend related tasks from knowledge base')
    .option('-q, --query <query>', 'Search query', '')
    .option('-t, --tags <tags>', 'Filter by comma-separated tags')
    .option('-l, --limit <limit>', 'Max recommendations', '5')
    .action(async (opts?: { query?: string; tags?: string; limit?: string }) => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        const tags = opts?.['tags'] ? opts['tags'].split(',').map((t: string) => t.trim()) : undefined;
        const query = opts?.['query'] ?? '';
        const terms = query.toLowerCase().split(/\s+/).filter(Boolean);

        const result = kb.search({
          terms,
          tags,
          limit: parseInt(opts?.['limit'] ?? '5', 10),
          sortBy: 'relevance',
        });

        if (result.isErr()) { logger.kallaxError(result.error); process.exit(1); }

        if (result.value.length === 0) {
          process.stdout.write(JSON.stringify({ recommendations: [], count: 0 }) + '\n');
        } else {
          process.stdout.write(JSON.stringify({
            recommendations: result.value.map((r) => ({
              id: r.entry.id, title: r.entry.title, score: r.score,
              tags: r.entry.tags, preview: r.entry.content.slice(0, 100),
            })),
            count: result.value.length,
          }, null, 2) + '\n');
        }
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  program
    .command('expert:compose <task>')
    .description('Recommend expert team composition for a task')
    .action(async (task: string) => {
      try {
        const { getKnowledgeBase } = await import('../core/knowledge-base.js');
        const kb = getKnowledgeBase();

        // Search knowledge base for relevant expertise
        const terms = task.toLowerCase().split(/\s+/).filter(Boolean);
        const searchResult = kb.search({ terms, limit: 10, sortBy: 'relevance' });

        if (searchResult.isErr()) { logger.kallaxError(searchResult.error); process.exit(1); }

        // Extract unique skills from matched entries
        const skills = new Set<string>();
        for (const r of searchResult.value) {
          for (const tag of r.entry.tags) skills.add(tag);
        }

        // Query available performers
        const performersResult = ctx.db.listInstances({ role: 'performer' });
        const performers = performersResult.isOk() ? performersResult.value : [];

        process.stdout.write(JSON.stringify({
          task,
          matchedKnowledge: searchResult.value.length,
          skillsRequired: Array.from(skills),
          availablePerformers: performers.map((p: { id: string; status: string; capabilities: string[]; currentTaskId: string | null }) => ({
            id: p.id, status: p.status,
            capabilities: p.capabilities,
            currentTask: p.currentTaskId,
          })),
          recommendation: searchResult.value.length > 0
            ? `Found ${skills.size} relevant skill areas; ${performers.length} performers available`
            : 'No matching expertise found in knowledge base',
        }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
