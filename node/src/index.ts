/**
 * KALLAX CLI Entry Point
 * ESM module with strict TypeScript — zero `any`, zero `@ts-ignore`
 */

import { Command } from 'commander';
import { logger } from './utils/logger.js';
import { setupProcessCleanup } from './utils/process-cleanup.js';
import { createSQLiteManager } from './core/sqlite-manager.js';
import { createWorktreeManager } from './core/worktree-manager.js';
import { createOutputVerifier } from './core/output-verifier.js';
import { getIsolationChecker } from './core/isolation-checker.js';
import { createInstanceRegistry } from './core/instance-registry.js';
import { createTaskAssigner } from './core/task-assigner.js';
import { createRoleSelector } from './core/role-selector.js';
import { getGitService } from './core/git-service.js';
import { validateStartup } from './utils/startup-validator.js';
import { KallaxError, KallaxErrorCode, TaskStatus, TaskType } from './types/index.js';
import * as fs from 'node:fs';

// Commands
import { executeClaimCommand } from './commands/claim.js';
import { executeCompleteCommand } from './commands/complete.js';
import { executeConductorHeartbeat, executeConductorPoll } from './commands/conductor.js';
import { executeIsolationCheck } from './commands/isolation-check.js';
import {
  executePerformerRegister,
  executePerformerPoll,
  executePerformerStatus,
} from './commands/performer.js';
import {
  executeTaskCreate,
  executeTaskStatus,
  executeTaskProgress,
  executeTaskResume,
} from './commands/task.js';
import { executeVerifyOutput } from './commands/verify-output.js';
import { executeSystemDoctor, executeTeamStatus } from './commands/system.js';
import { analyzeComplexity, calculateDependencyDepth, countCrossModules } from './core/complexity-analyzer.js';
import { generateDagYaml, topologicalSort } from './core/dag-generator.js';
import { createDagExecutor } from './core/dag-executor.js';
import { renderDagTree, renderDagSummary } from './core/dag-visualizer.js';

// Re-export types and core modules
export * from './types/index.js';
export * from './core/index.js';
export * from './commands/index.js';
export * from './utils/index.js';

// ---------------------------------------------------------------------------
// Bootstrap — fail-fast: validate at startup, not at 2 AM
// ---------------------------------------------------------------------------

function bootstrap() {
  const projectRoot = process.cwd();

  // Fail-fast: validate environment before anything else
  const validation = validateStartup(projectRoot);
  if (validation.isErr()) {
    logger.fatal({ error: validation.error }, 'startup validation failed');
    process.exit(1);
  }

  const dbResult = createSQLiteManager({ path: '.kallax/data/kallax.db' });
  if (dbResult.isErr()) {
    logger.fatal({ error: dbResult.error }, 'failed to initialize database');
    process.exit(1);
  }

  const wmResult = createWorktreeManager({
    projectRoot,
    worktreeBasePath: '.kallax/worktrees',
  });
  if (wmResult.isErr()) {
    logger.fatal({ error: wmResult.error }, 'failed to initialize worktree manager');
    process.exit(1);
  }

  const db = dbResult.value;
  const worktreeManager = wmResult.value;
  const outputVerifier = createOutputVerifier({ projectRoot });
  const isolationChecker = getIsolationChecker();
  const instanceRegistry = createInstanceRegistry(db);
  const taskAssigner = createTaskAssigner(db, isolationChecker, instanceRegistry);
  const gitService = getGitService();

  return { db, worktreeManager, outputVerifier, isolationChecker, instanceRegistry, taskAssigner, gitService };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

setupProcessCleanup();

const ctx = bootstrap();
const program = new Command();

program
  .name('kallax')
  .description('KALLAX — Knowledge-Augmented Leveraged Learning Agent eXecutor')
  .version('1.0.0');

// ── Ticket commands ──────────────────────────────────────────────────────

const ticketCmd = program.command('ticket').description('Ticket management');

ticketCmd
  .command('create <title>')
  .description('Create a new ticket')
  .option('-d, --description <desc>', 'Ticket description', '')
  .option('-p, --priority <priority>', 'Priority (P0/P1/P2/P3)', 'P2')
  .option('-s, --scope <files>', 'File scope (comma-separated)', '')
  .action((title: string, opts?: { description?: string; priority?: string; scope?: string }) => {
    try {
      const now = Date.now();
      const id = `TICKET-${now.toString(36).toUpperCase()}`;
      const ticket = {
        id,
        title,
        description: opts?.['description'] ?? '',
        status: 'todo' as const,
        priority: (opts?.['priority'] ?? 'P2') as 'P0' | 'P1' | 'P2' | 'P3',
        assigneeId: null,
        createdAt: now,
        updatedAt: now,
        acceptanceCriteria: [],
        labels: [],
        fileScope: opts?.['scope'] ? opts['scope'].split(',').map((s: string) => s.trim()) : undefined,
      };
      const result = ctx.db.createTicket(ticket);
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify({ id, title, status: 'created' }) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Task commands ──────────────────────────────────────────────────────────

const task = program.command('task').description('Task management');

task
  .command('claim [taskId]')
  .description('Claim a task — auto-creates isolated worktree')
  .option('-t, --ticket <ticketId>', 'Claim task for specific ticket')
  .action(async (taskId?: string, opts?: { ticket?: string }) => {
    try {
      const result = await executeClaimCommand(
        ctx.db, ctx.worktreeManager, ctx.instanceRegistry, ctx.taskAssigner,
        { taskId, ticketId: opts?.['ticket'] },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info({ taskId: result.value.task.id, worktree: result.value.worktreePath }, 'task claimed');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('complete <taskId>')
  .description('Complete a task — Saga 5-step atomic completion')
  .option('--skip-tests', 'Skip test verification')
  .option('--skip-lint', 'Skip lint verification')
  .option('-l, --level <level>', 'Verification level (1-4)', '4')
  .action(async (taskId: string, opts?: { skipTests?: boolean; skipLint?: boolean; level?: string }) => {
    try {
      const result = await executeCompleteCommand(
        ctx.db, ctx.worktreeManager, ctx.outputVerifier,
        ctx.instanceRegistry, ctx.taskAssigner, ctx.gitService,
        {
          taskId,
          skipTests: opts?.['skipTests'],
          skipLint: opts?.['skipLint'],
          verificationLevel: (parseInt(opts?.['level'] ?? '4', 10) as 1 | 2 | 3 | 4),
        },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info(
        { taskId, commitHash: result.value.commitHash, prNumber: result.value.prNumber },
        'task completed',
      );
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('create <ticketId>')
  .description('Create a new task for a ticket')
  .option('-t, --type <type>', 'Task type (development, review, testing)', 'development')
  .action(async (ticketId: string, opts?: { type?: string }) => {
    try {
      const result = executeTaskCreate(ctx.db, ctx.taskAssigner, {
        ticketId,
        type: opts?.['type'] as TaskType | undefined,
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info({ taskId: result.value.task.id, ticketId }, 'task created');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('status [taskId]')
  .description('Show task status')
  .option('-t, --ticket <ticketId>', 'Filter by ticket')
  .option('-p, --performer <performerId>', 'Filter by performer')
  .option('-s, --status <status>', 'Filter by status')
  .action(async (taskId?: string, opts?: Record<string, string>) => {
    try {
      const result = executeTaskStatus(ctx.db, {
        taskId,
        ticketId: opts?.['ticket'],
        performerId: opts?.['performer'],
        statusFilter: opts?.['status'] as TaskStatus | undefined,
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('progress <taskId> <progress>')
  .description('Update task progress (0-100)')
  .option('-m, --message <message>', 'Progress message')
  .action(async (taskId: string, progress: string, opts?: { message?: string }) => {
    try {
      const result = executeTaskProgress(ctx.db, {
        taskId,
        progress: parseInt(progress, 10),
        message: opts?.['message'],
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info({ taskId, progress }, 'task progress updated');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

task
  .command('resume <taskId>')
  .description('Resume a failed or cancelled task')
  .action(async (taskId: string) => {
    try {
      const result = await executeTaskResume(ctx.db, ctx.taskAssigner, { taskId });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info({ taskId }, 'task resumed');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Conductor commands ─────────────────────────────────────────────────────

const conductor = program.command('conductor').description('Conductor (orchestrator) commands');

conductor
  .command('heartbeat')
  .description('Run conductor heartbeat — 5-question health check')
  .action(async () => {
    try {
      const result = await executeConductorHeartbeat(
        ctx.db, ctx.instanceRegistry, ctx.taskAssigner, ctx.isolationChecker, {},
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      const hr = result.value;
      process.stdout.write(JSON.stringify({
        q1_priority: hr.q1_priority,
        q2_performers: hr.q2_performers,
        q3_progress: hr.q3_progress,
        q4_blocked: hr.q4_blocked,
        q5_messages: hr.q5_messages,
      }, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

conductor
  .command('poll')
  .description('Poll for task assignments')
  .option('-a, --auto-assign', 'Automatically assign tasks to performers')
  .option('-m, --max <count>', 'Maximum assignments per poll', '5')
  .action(async (opts?: { autoAssign?: boolean; max?: string }) => {
    try {
      const result = await executeConductorPoll(
        ctx.db, ctx.instanceRegistry, ctx.taskAssigner, ctx.isolationChecker,
        {
          autoAssign: opts?.['autoAssign'],
          maxAssignments: parseInt(opts?.['max'] ?? '5', 10),
        },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Performer commands ─────────────────────────────────────────────────────

const performer = program.command('performer').description('Performer (executor) commands');

performer
  .command('register')
  .description('Register as a performer')
  .option('-n, --name <name>', 'Performer name')
  .option('-c, --capabilities <caps>', 'Comma-separated capabilities')
  .action(async (opts?: { name?: string; capabilities?: string }) => {
    try {
      const caps = opts?.['capabilities']?.split(',').map((c) => c.trim()) ?? [];
      const result = await executePerformerRegister(ctx.instanceRegistry, {
        name: opts?.['name'],
        capabilities: caps,
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      logger.info(
        { instanceId: result.value.instance.id, role: result.value.instance.role },
        'performer registered',
      );
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

performer
  .command('poll')
  .description('Poll for available tasks')
  .option('-a, --auto-claim', 'Automatically claim first available task')
  .action(async (opts?: { autoClaim?: boolean }) => {
    try {
      const result = await executePerformerPoll(
        ctx.db, ctx.instanceRegistry, ctx.taskAssigner, ctx.worktreeManager,
        { autoClaim: opts?.['autoClaim'] },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

performer
  .command('status')
  .description('Get performer status')
  .action(async () => {
    try {
      const result = await executePerformerStatus(ctx.db, ctx.instanceRegistry, ctx.worktreeManager);
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Isolation command ──────────────────────────────────────────────────────

program
  .command('isolation:check <taskIdA> [taskIdB]')
  .description('Check file-scope overlap between tasks')
  .option('-f, --files <files>', 'Comma-separated file paths')
  .action(async (taskIdA: string, taskIdB?: string, opts?: { files?: string }) => {
    try {
      const files = opts?.['files']?.split(',').map((f) => f.trim()) ?? [];
      const result = executeIsolationCheck(ctx.isolationChecker, ctx.db, {
        taskIdA,
        taskIdB,
        files: files.length > 0 ? files : undefined,
      });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      const r = result.value;
      process.stdout.write(JSON.stringify({
        hasConflicts: r.hasConflicts,
        conflicts: r.conflicts,
        recommendations: r.recommendations,
      }, null, 2) + '\n');
      process.exit(r.hasConflicts ? 1 : 0);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Verify command ─────────────────────────────────────────────────────────

program
  .command('verify:output <taskId>')
  .description('Verify task output — Fact-Forcing 4-Level check')
  .option('-l, --level <level>', 'Verification level (1-4)', '4')
  .option('-v, --verbose', 'Show detailed evidence')
  .action(async (taskId: string, opts?: { level?: string; verbose?: boolean }) => {
    try {
      const level = (parseInt(opts?.['level'] ?? '4', 10) as 1 | 2 | 3 | 4);
      const result = await executeVerifyOutput(
        ctx.db, ctx.worktreeManager, ctx.outputVerifier,
        { taskId, level, verbose: opts?.['verbose'] },
      );
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify({
        verification: result.value.verification,
        summary: result.value.summary,
        recommendations: result.value.recommendations,
      }, null, 2) + '\n');
      process.exit(result.value.verification.passed ? 0 : 1);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── System commands ────────────────────────────────────────────────────────

const system = program.command('system').description('System management');

system
  .command('doctor')
  .description('Run full system diagnostics')
  .action(async () => {
    try {
      const result = await executeSystemDoctor(ctx.db, ctx.instanceRegistry);
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      const doc = result.value;
      process.stdout.write(JSON.stringify({
        healthy: doc.healthy,
        checks: doc.checks,
        database: doc.database,
        cache: doc.cache,
        circuitBreakers: doc.circuitBreakers,
        recommendations: doc.recommendations,
      }, null, 2) + '\n');
      process.exit(doc.healthy ? 0 : 1);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

program
  .command('team:status')
  .description('Show team overview')
  .action(async () => {
    try {
      const result = await executeTeamStatus(ctx.db, ctx.instanceRegistry);
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }
      process.stdout.write(JSON.stringify(result.value, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Start command ──────────────────────────────────────────────────────────

program
  .command('start')
  .description('Start KALLAX in interactive mode')
  .option('-r, --role <role>', 'Role: conductor | performer')
  .action(async (opts?: { role?: string }) => {
    try {
      const roleSelector = createRoleSelector();

      if (opts?.['role']) {
        const setResult = await roleSelector.setRole(process.cwd(), opts.role as 'conductor' | 'performer');
        if (setResult.isErr()) {
          logger.kallaxError(setResult.error);
          process.exit(1);
        }
      }

      const detectResult = await roleSelector.detectRole(process.cwd());
      if (detectResult.isErr()) {
        logger.kallaxError(detectResult.error);
        process.exit(1);
      }

      const { role } = detectResult.value;
      logger.info({ role }, 'KALLAX starting');

      const regResult = await ctx.instanceRegistry.register(role);
      if (regResult.isErr()) {
        logger.kallaxError(regResult.error);
        process.exit(1);
      }

      const instance = regResult.value;
      logger.info(
        { instanceId: instance.id, role, hostname: instance.hostname },
        'instance registered — KALLAX is running',
      );
      process.stdout.write(`KALLAX ${role} started — instance: ${instance.id}\n`);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });


// ── Epic commands ──────────────────────────────────────────────────────────

const epic = program.command('epic').description('EPIC management');

epic
  .command('create <epicId> <title>')
  .description('Create a new EPIC')
  .action((epicId: string, title: string) => {
    try {
      const now = Date.now();
      const epicData = {
        epicId, title,
        createdAt: new Date().toISOString(),
        status: 'planning',
        tickets: [] as string[],
      };
      const dir = `jira/epics/${epicId}`;
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(`${dir}/epic.json`, JSON.stringify(epicData, null, 2));
      process.stdout.write(JSON.stringify(epicData, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

epic
  .command('analyze <epicId>')
  .description('Analyze EPIC complexity')
  .action((epicId: string) => {
    try {
      // Collect tickets for this epic
      const ticketsResult = ctx.db.listTickets({}); const tickets = ticketsResult.isOk() ? ticketsResult.value : [];
      const epicTickets = tickets.filter((t: { labels?: string[] }) => t.labels?.includes(epicId));

      if (epicTickets.length === 0) {
        logger.warn({ epicId }, 'No tickets found for epic');
        process.exit(0);
      }

      // Calculate metrics
      const depsMap = new Map<string, string[]>();
      const scopes: string[][] = [];
      let maxBlocked = 0;

      for (const t of epicTickets) {
        depsMap.set(t.id, []); // Simplified — real deps would come from ticket metadata
        if (t.fileScope) scopes.push(t.fileScope);
      }

      const depDepth = calculateDependencyDepth(depsMap);
      const crossModule = countCrossModules(scopes);

      const result = analyzeComplexity({
        subtaskCount: epicTickets.length,
        dependencyDepth: depDepth,
        maxBlockedBy: maxBlocked,
        crossModuleCount: crossModule,
      });

      process.stdout.write(JSON.stringify(result, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

epic
  .command('plan <epicId>')
  .description('Generate DAG YAML for EPIC')
  .action((epicId: string) => {
    try {
      const ticketsResult = ctx.db.listTickets({}); const tickets = ticketsResult.isOk() ? ticketsResult.value : []
        .filter((t: { labels?: string[] }) => t.labels?.includes(epicId));

      const yaml = generateDagYaml(tickets, epicId);
      const dir = 'jira/epics';
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(`${dir}/${epicId}-dag.yml`, yaml);
      process.stdout.write(yaml);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

epic
  .command('run <epicId>')
  .description('Execute EPIC in DAG mode')
  .option('--dry-run', 'Simulate without executing')
  .action(async (epicId: string, opts?: { dryRun?: boolean }) => {
    try {
      const dagPath = `jira/epics/${epicId}-dag.yml`;
      if (!fs.existsSync(dagPath)) {
        logger.error({ epicId }, 'DAG file not found. Run epic:plan first.');
        process.exit(1);
      }
      // Parse YAML (simple inline)
      const yamlContent = fs.readFileSync(dagPath, 'utf-8');
      logger.info({ epicId, dryRun: opts?.['dryRun'] }, 'executing EPIC via DAG');

      const executor = createDagExecutor({ dryRun: opts?.['dryRun'] });
      // Inline YAML parse — simplified for demo
      const epic = epicId;
      const nodes: Array<{ id: string; script: string; deps: string[]; priority?: number }> = [];

      for (const line of yamlContent.split('\n')) {
        if (line.match(/^\s*- id:/)) {
          const id = (line.match(/"([^"]+)"/) ?? [])[1] ?? '';
          nodes.push({ id, script: '', deps: [] });
        } else if (line.match(/^\s*script:/) && nodes.length > 0) {
          nodes[nodes.length - 1]!.script = (line.match(/"([^"]+)"/) ?? [])[1] ?? '';
        } else if (line.match(/^\s*deps:/) && nodes.length > 0) {
          const depsStr = (line.match(/\[(.*)\]/) ?? [])[1] ?? '';
          nodes[nodes.length - 1]!.deps = depsStr.split(',').map((s: string) => s.trim().replace(/"/g, '')).filter(Boolean);
        }
      }

      const schema = {
        epic,
        nodes,
        settings: { max_parallel: 3, retry_count: 2, timeout_seconds: 3600, on_failure: 'stop' as const },
      };

      const state = await executor.execute(schema);
      const statusMap = new Map<string, 'pending' | 'running' | 'done' | 'failed' | 'skipped'>();
      for (const [id, ns] of state.nodes) { statusMap.set(id, ns.status); }

      process.stdout.write(renderDagSummary(nodes.length, statusMap));
      process.stdout.write(renderDagTree(nodes, statusMap) + '\n');
      process.exit(state.status === 'completed' ? 0 : 1);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });


// ── Knowledge commands ──────────────────────────────────────────────────────

const knowledge = program.command('knowledge').description('Knowledge base management');

knowledge
  .command('index <title>')
  .description('Index a knowledge entry')
  .option('-c, --content <content>', 'Content (reads stdin if omitted)')
  .option('-t, --tags <tags>', 'Comma-separated tags')
  .option('-s, --source <source>', 'Source identifier', 'manual')
  .action(async (title: string, opts: Record<string, string>) => {
    try {
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
      const kb = getKnowledgeBase();

      let content = opts['content'] ?? '';
      if (!content && !process.stdin.isTTY) {
        content = (await readStdin()).trim();
      }

      const tags = opts['tags'] ? opts['tags'].split(',').map((t: string) => t.trim()) : [];

      const result = kb.add({ title, content, tags, source: opts['source'] ?? 'manual' });
      if (result.isErr()) throw result.error;

      process.stdout.write(`Indexed: ${result.value.id}\n`);
      process.stdout.write(`  Title: ${title}\n`);
      process.stdout.write(`  Tags: ${tags.join(', ') || '(none)'}\n`);
      process.stdout.write(`  Words: ${content.length} chars\n`);
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
  .action(async (query: string, opts: Record<string, string>) => {
    try {
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
      const kb = getKnowledgeBase();

      const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
      const tags = opts['tags'] ? opts['tags'].split(',').map((t: string) => t.trim()) : undefined;

      const result = kb.search({
        terms,
        tags,
        limit: parseInt(opts['limit'] ?? '10', 10),
        sortBy: (opts['sort'] as 'relevance' | 'date') ?? 'relevance',
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
  .action(async (opts: Record<string, string>) => {
    try {
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
      const kb = getKnowledgeBase();

      const result = kb.list({ limit: parseInt(opts['limit'] ?? '50', 10) });
      if (result.isErr()) throw result.error;

      const stats = kb.getStats();
      process.stdout.write(`Total: ${stats.totalEntries} entries, ${stats.totalWords} words indexed\n\n`);

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
  .action(async (opts: Record<string, string>) => {
    try {
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
      const kb = getKnowledgeBase();

      const days = parseInt(opts['days'] ?? '90', 10);
      const result = kb.gc(days * 86400_000);

      if (result.isErr()) throw result.error;
      process.stdout.write(`GC complete: removed ${result.value} entries older than ${days} days\n`);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Degradation commands ────────────────────────────────────────────────────

program
  .command('system:degradation')
  .description('Show degradation state and tier status')
  .action(async () => {
    try {
      const { getRecoveryManager } = await import('./core/recovery-manager.js');
      const rm = getRecoveryManager();
      const state = rm.getState();

      process.stdout.write('=== KALLAX Degradation Status ===\n\n');
      process.stdout.write(`Current Tier : ${state.currentTier} (${['Degraded','Shell','Node.js','Rust'][state.currentTier]})\n`);
      process.stdout.write(`Target Tier  : ${state.targetTier}\n`);
      process.stdout.write(`Crash Count  : ${state.crashCount}\n\n`);

      process.stdout.write('Tier Status:\n');
      for (const level of [3, 2, 1, 0] as const) {
        const tier = state.tiers[level];
        const icon = tier.healthy ? '✓' : '✗';
        const uptime = tier.degradedAt
          ? `degraded at ${new Date(tier.degradedAt).toISOString()}`
          : 'healthy';
        process.stdout.write(`  ${icon} L${level} ${tier.name.padEnd(10)} ${uptime} (probe: ${new Date(tier.lastProbeAt).toISOString()})\n`);
      }

      process.stdout.write('\nUse "kallax system:degradation probe" to force a probe cycle.\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

program
  .command('system:degradation-probe')
  .description('Force degradation probe cycle')
  .action(async () => {
    try {
      const { getRecoveryManager } = await import('./core/recovery-manager.js');
      const rm = getRecoveryManager();
      await rm.probeAll();
      const state = rm.getState();
      process.stdout.write(`Probe complete. Current tier: ${state.currentTier}\n`);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Task handoff command ────────────────────────────────────────────────────

task
  .command('handoff <taskId> <toPerformerId>')
  .description('Handoff a task to another performer')
  .option('-m, --message <message>', 'Handoff message')
  .action(async (taskId: string, toPerformerId: string, opts?: { message?: string }) => {
    try {
      const taskResult = ctx.db.getTask(taskId);
      if (taskResult.isErr()) {
        logger.kallaxError(taskResult.error);
        process.exit(1);
      }
      const task = taskResult.value;
      if (!task) {
        logger.error({ taskId }, 'task not found');
        process.exit(1);
      }

      const oldPerformerId = task.performerId;
      const now = Date.now();

      // Update task performer
      const updateResult = ctx.db.updateTask(taskId, {
        performerId: toPerformerId,
        status: 'pending',   // reset so new performer must claim
        progress: task.progress,
        updatedAt: now,
      });
      if (updateResult.isErr()) {
        logger.kallaxError(updateResult.error);
        process.exit(1);
      }

      // Unset old performer's current task if they held this one
      if (oldPerformerId) {
        const oldInstResult = ctx.db.listInstances({ role: 'performer' });
        if (oldInstResult.isOk()) {
          for (const inst of oldInstResult.value) {
            if (inst.currentTaskId === taskId) {
              await ctx.instanceRegistry.updateStatus(inst.id, 'idle');
            }
          }
        }
      }

      process.stdout.write(JSON.stringify({
        taskId, fromPerformer: oldPerformerId, toPerformer: toPerformerId,
        progress: task.progress, message: opts?.['message'] ?? '',
        status: 'handoff_ok',
      }) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Submit PR command ───────────────────────────────────────────────────────

program
  .command('submit:pr')
  .description('Submit a pull request — stage, commit, push, and create PR')
  .option('-t, --title <title>', 'PR title (defaults to branch name)')
  .option('-b, --body <body>', 'PR description body')
  .option('--base <branch>', 'Base branch', 'main')
  .option('--no-gate', 'Skip gate review before submission')
  .action(async (opts?: { title?: string; body?: string; base?: string; gate?: boolean }) => {
    try {
      const cwd = process.cwd();
      const branchResult = await ctx.gitService.getCurrentBranch(cwd);
      if (branchResult.isErr()) {
        logger.kallaxError(branchResult.error);
        process.exit(1);
      }
      const branch = branchResult.value;
      const prTitle = opts?.['title'] ?? branch;
      const prBody = opts?.['body'] ?? '';

      // Optional gate check
      const runGate = opts?.['gate'] !== false;
      if (runGate) {
        const { getGateReviewer } = await import('./core/gate-reviewer.js');
        const reviewer = getGateReviewer();
        const gateResult = await reviewer.review({ cwd, maxLevel: 2 });
        if (gateResult.isErr()) {
          logger.kallaxError(gateResult.error);
          process.exit(1);
        }
        if (!gateResult.value.passed) {
          logger.error({ checks: gateResult.value.checks }, 'gate review failed — aborting PR submission');
          process.exit(1);
        }
        logger.info({}, 'gate review passed');
      }

      // Stage, commit, push
      const stageResult = await ctx.gitService.stageAll(cwd);
      if (stageResult.isErr()) { logger.kallaxError(stageResult.error); process.exit(1); }

      const commitResult = await ctx.gitService.commit(cwd, `PR: ${prTitle}`);
      if (commitResult.isErr()) { logger.kallaxError(commitResult.error); process.exit(1); }

      const pushResult = await ctx.gitService.push(cwd, branch);
      if (pushResult.isErr()) { logger.kallaxError(pushResult.error); process.exit(1); }

      const prResult = await ctx.gitService.createPr(cwd, prTitle, prBody, opts?.['base']);
      if (prResult.isErr()) { logger.kallaxError(prResult.error); process.exit(1); }

      process.stdout.write(JSON.stringify({
        branch, commitHash: commitResult.value.hash, prNumber: prResult.value.number,
        prUrl: prResult.value.url, base: opts?.['base'] ?? 'main',
      }) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Gate review command ─────────────────────────────────────────────────────

program
  .command('gate:review')
  .description('Run gate review checks (4 levels)')
  .option('-l, --level <level>', 'Max gate level (1-4)', '4')
  .option('--ci', 'CI mode — exit with code 1 on failure')
  .action(async (opts?: { level?: string; ci?: boolean }) => {
    try {
      const { getGateReviewer } = await import('./core/gate-reviewer.js');
      const reviewer = getGateReviewer();
      const maxLevel = parseInt(opts?.['level'] ?? '4', 10) as 1 | 2 | 3 | 4;

      const result = await reviewer.review({ maxLevel, cwd: process.cwd() });
      if (result.isErr()) {
        logger.kallaxError(result.error);
        process.exit(1);
      }

      const r = result.value;
      process.stdout.write(JSON.stringify({
        passed: r.passed, maxLevel: r.maxLevel,
        checks: r.checks, summary: r.summary,
      }, null, 2) + '\n');

      if (opts?.['ci'] && !r.passed) process.exit(1);
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Dependency analyze command ──────────────────────────────────────────────

program
  .command('dependency:analyze <ticketId>')
  .description('Analyze task dependency relationships')
  .option('-d, --depth <depth>', 'Max dependency depth', '10')
  .action((ticketId: string, opts?: { depth?: string }) => {
    try {
      const ticketsResult = ctx.db.listTickets({});
      const tickets = ticketsResult.isOk() ? ticketsResult.value : [];

      // Build dependency map from ticket labels / parent references
      const depsMap = new Map<string, string[]>();
      const targetTicket = tickets.find((t: { id: string }) => t.id === ticketId);
      if (!targetTicket) {
        logger.error({ ticketId }, 'ticket not found');
        process.exit(1);
      }

      for (const t of tickets) {
        const deps: string[] = [];
        // Look for parent relationships or label-based deps
        if (t.parentTicketId) deps.push(t.parentTicketId);
        depsMap.set(t.id, deps);
      }

      const maxDepth = parseInt(opts?.['depth'] ?? '10', 10);
      const depDepth = calculateDependencyDepth(depsMap);
      const crossModule = countCrossModules(tickets.map((t: { fileScope?: string[] }) => t.fileScope ?? []));

      const result = analyzeComplexity({
        subtaskCount: tickets.length,
        dependencyDepth: Math.min(depDepth, maxDepth),
        maxBlockedBy: 0,
        crossModuleCount: crossModule,
      });

      process.stdout.write(JSON.stringify({
        ticketId, totalTickets: tickets.length, dependencyDepth: depDepth,
        crossModule, complexity: result,
      }, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── DB commands ──────────────────────────────────────────────────────────────

const dbCmd = program.command('db').description('Database migration management');

dbCmd
  .command('migrate')
  .description('Run pending database migrations')
  .option('--dry-run', 'Show migrations without applying')
  .action(async (opts?: { dryRun?: boolean }) => {
    try {
      const { createSQLiteManager } = await import('./core/sqlite-manager.js');
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

// ── Alerts command ───────────────────────────────────────────────────────────

program
  .command('alerts:list')
  .description('List active system alerts')
  .option('--since <hours>', 'Only alerts from last N hours', '24')
  .action(async (opts?: { since?: string }) => {
    try {
      const sinceHours = parseInt(opts?.['since'] ?? '24', 10);
      const thresholdMs = sinceHours * 3600_000;
      const now = Date.now();
      const alerts: Array<{ type: string; severity: string; message: string; timestamp: number }> = [];

      // 1. Stale instances
      const staleResult = await ctx.instanceRegistry.markStaleInstances(thresholdMs);
      if (staleResult.isOk()) {
        for (const inst of staleResult.value) {
          alerts.push({
            type: 'stale_instance', severity: 'warning',
            message: `Instance ${inst.id} (${inst.role}) stale since ${new Date(inst.lastHeartbeat).toISOString()}`,
            timestamp: now,
          });
        }
      }

      // 2. Failed tasks
      const failedTasks = ctx.db.listTasks({ status: 'failed', limit: 50 });
      if (failedTasks.isOk()) {
        for (const t of failedTasks.value) {
          const age = (now - t.updatedAt) / 3600_000;
          if (age <= sinceHours) {
            alerts.push({
              type: 'failed_task', severity: 'error',
              message: `Task ${t.id} (${t.type}) failed: ${t.error ?? 'unknown'}`,
              timestamp: t.updatedAt,
            });
          }
        }
      }

      // 3. Stale tickets (blocked > threshold)
      const blockedTickets = ctx.db.listTickets({ status: 'blocked', limit: 50 });
      if (blockedTickets.isOk()) {
        for (const t of blockedTickets.value) {
          const age = (now - t.updatedAt) / 3600_000;
          if (age <= sinceHours) {
            alerts.push({
              type: 'blocked_ticket', severity: 'info',
              message: `Ticket ${t.id} blocked since ${new Date(t.updatedAt).toISOString()}`,
              timestamp: t.updatedAt,
            });
          }
        }
      }

      process.stdout.write(JSON.stringify({ alerts, count: alerts.length, sinceHours }, null, 2) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Recommend command ────────────────────────────────────────────────────────

program
  .command('recommend')
  .description('Recommend related tasks from knowledge base')
  .option('-q, --query <query>', 'Search query', '')
  .option('-t, --tags <tags>', 'Filter by comma-separated tags')
  .option('-l, --limit <limit>', 'Max recommendations', '5')
  .action(async (opts?: { query?: string; tags?: string; limit?: string }) => {
    try {
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
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

// ── Expert compose command ──────────────────────────────────────────────────

program
  .command('expert:compose <task>')
  .description('Recommend expert team composition for a task')
  .action(async (task: string) => {
    try {
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
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
        availablePerformers: performers.map((p) => ({
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

// ── Doc commands ─────────────────────────────────────────────────────────────

const docCmd = program.command('doc').description('Documentation management');

docCmd
  .command('create <type> <title>')
  .description('Create a documentation entry')
  .option('-c, --content <content>', 'Document content or file path')
  .option('-t, --tags <tags>', 'Comma-separated tags', 'documentation')
  .action(async (type: string, title: string, opts?: { content?: string; tags?: string }) => {
    try {
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
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
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
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

// ── Spike commands ───────────────────────────────────────────────────────────

const spikeCmd = program.command('spike').description('Technical spike management');

spikeCmd
  .command('create <name>')
  .description('Create a technical spike')
  .option('-g, --goal <goal>', 'Spike goal', '')
  .option('-t, --timebox <minutes>', 'Timebox in minutes', '120')
  .action(async (name: string, opts?: { goal?: string; timebox?: string }) => {
    try {
      const now = Date.now();
      const id = `SPIKE-${now.toString(36).toUpperCase()}`;
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
      const kb = getKnowledgeBase();

      const result = kb.add({
        title: `[SPIKE] ${name}`,
        content: JSON.stringify({
          id, name, goal: opts?.['goal'] ?? '',
          timebox: parseInt(opts?.['timebox'] ?? '120', 10),
          status: 'active', createdAt: now,
        }),
        tags: ['spike', 'research'],
        source: 'spike-cli',
      });

      if (result.isErr()) { logger.kallaxError(result.error); process.exit(1); }

      process.stdout.write(JSON.stringify({
        id, name, goal: opts?.['goal'] ?? '',
        timebox: parseInt(opts?.['timebox'] ?? '120', 10),
        status: 'active', knowledgeId: result.value.id,
      }) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

spikeCmd
  .command('complete <name>')
  .description('Mark a technical spike as complete')
  .option('-f, --findings <findings>', 'Key findings')
  .action(async (name: string, opts?: { findings?: string }) => {
    try {
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
      const kb = getKnowledgeBase();

      const searchResult = kb.search({
        terms: name.toLowerCase().split(/\s+/).filter(Boolean),
        tags: ['spike'],
        limit: 5,
        sortBy: 'date',
      });

      if (searchResult.isErr()) { logger.kallaxError(searchResult.error); process.exit(1); }

      const active = searchResult.value.filter(
        (r) => r.entry.tags.includes('spike') && r.entry.content.includes('"active"'),
      );

      if (active.length === 0) {
        logger.error({ name }, 'no active spike found');
        process.exit(1);
      }

      const entry = active[0]!.entry;
      const existing = JSON.parse(entry.content);
      existing.status = 'completed';
      existing.completedAt = Date.now();
      existing.findings = opts?.['findings'] ?? '';

      const updateResult = kb.update(entry.id, {
        content: JSON.stringify(existing),
        tags: [...entry.tags, 'completed'],
      });

      if (updateResult.isErr()) { logger.kallaxError(updateResult.error); process.exit(1); }

      process.stdout.write(JSON.stringify({
        name, id: existing.id, status: 'completed',
        findings: opts?.['findings'] ?? '',
        elapsed: existing.completedAt - existing.createdAt,
      }) + '\n');
    } catch (error: unknown) {
      logger.kallaxError(KallaxError.fromUnknown(error));
      process.exit(1);
    }
  });

// ── Memory review command ────────────────────────────────────────────────────

program
  .command('memory:review')
  .description('Review knowledge entries — list all for audit')
  .option('-s, --stale <days>', 'Entries older than N days', '30')
  .option('-n, --limit <limit>', 'Max entries', '50')
  .action(async (opts?: { stale?: string; limit?: string }) => {
    try {
      const { getKnowledgeBase } = await import('./core/knowledge-base.js');
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

// ── Parse ──────────────────────────────────────────────────────────────────

program.parseAsync(process.argv).catch((error: unknown) => {
  logger.kallaxError(KallaxError.fromUnknown(error, KallaxErrorCode.INTERNAL_ERROR));
  process.exit(1);
});
