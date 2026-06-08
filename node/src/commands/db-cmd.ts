/**
 * KALLAX DB Command Registration
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';

export function registerDbCommands(program: Command, ctx: AppContext): void {
  const dbCmd = program.command('db').description('Database management (team collaboration)');

  dbCmd
    .command('init')
    .description('Create .kallax/kallax.db and initialize team collaboration tables')
    .action(async () => {
      try {
        const { existsSync, mkdirSync } = await import('node:fs');
        const Database = (await import('better-sqlite3')).default;
        const { initializeTeamSchema } = await import('../core/sqlite/index.js');

        const dbDir = '.kallax';
        const dbPath = '.kallax/kallax.db';

        if (existsSync(dbPath)) {
          process.stdout.write(JSON.stringify({
            action: 'init',
            status: 'exists',
            path: dbPath,
            message: 'Database already exists',
          }) + '\n');
          return;
        }

        if (!existsSync(dbDir)) mkdirSync(dbDir, { recursive: true });

        const db = new Database(dbPath);
        db.pragma('journal_mode = WAL');
        db.pragma('synchronous = NORMAL');
        db.pragma('foreign_keys = ON');

        initializeTeamSchema(db);
        db.close();

        process.stdout.write(JSON.stringify({
          action: 'init',
          status: 'ok',
          path: dbPath,
          tables: ['phases', 'epics', 'project_tickets', 'team_instances', 'heartbeat_log'],
        }) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  dbCmd
    .command('migrate')
    .description('Run pending database migrations')
    .option('--dry-run', 'Show migrations without applying')
    .action(async (opts?: { dryRun?: boolean }) => {
      try {
        const { createSQLiteManager } = await import('../core/sqlite/index.js');
        // Reinitialize DB to ensure schema is up to date
        const dbResult = createSQLiteManager({ path: '.kallax/data/kallax.db' });
        if (dbResult.isErr()) {
          logger.kallaxError(dbResult.error);
          process.exit(1);
        }

        const stats = dbResult.value.getStats();
        process.stdout.write(JSON.stringify({
          action: opts?.['dryRun'] ? 'dry-run' : 'migrate',
          ticketCount: stats.ticketCount,
          taskCount: stats.taskCount,
          instanceCount: stats.instanceCount,
          messageCount: stats.messageCount,
          status: 'ok',
        }) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  dbCmd
    .command('status')
    .description('Show database status and statistics')
    .action(async () => {
      try {
        const stats = ctx.db.getStats();
        process.stdout.write(JSON.stringify({
          tickets: stats.ticketCount,
          tasks: stats.taskCount,
          instances: stats.instanceCount,
          messages: stats.messageCount,
        }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
