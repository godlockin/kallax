/**
 * KALLAX Route Command — pre-execution complexity gate.
 * Simple → direct, Complex → expert panel.
 */
import type { Command } from 'commander';
import { logger } from '../utils/logger.js';

export function registerRouteCommands(program: Command): void {
  program
    .command('route <requirement>')
    .description('Analyze requirement complexity and route to direct or panel execution')
    .option('--json', 'Output as JSON')
    .action(async (requirement: string, opts: { json?: boolean }): Promise<void> => {
      const { routeTask, getComplexityThreshold } = await import('../core/task-router.js');
      const result = routeTask(requirement);

      if (result.isErr()) {
        logger.error({}, `ERROR: ${result.error.message}`);
        process.exit(1);
      }

      const { decision, confidence, dispatch } = result.value;

      if (opts.json === true) {
        logger.info({}, JSON.stringify({ decision, confidence, requirement, dispatch }, null, 2));
        return;
      }

      const threshold = getComplexityThreshold();

      logger.info({}, '');
      logger.info({}, '╔══════════════════════════════════════════════════════╗');
      logger.info({}, '║  KALLAX Task Router — Complexity Gate              ║');
      logger.info({}, '╠══════════════════════════════════════════════════════╣');
      logger.info({}, `║  Requirement: ${requirement.slice(0, 40).padEnd(40)}║`);
      logger.info({}, `║  Complexity:  ${String(decision.complexity.score)}/${String(threshold)}+ (threshold)                    ║`);
      logger.info({}, `║  Strategy:    ${decision.strategy.padEnd(40)}║`);
      logger.info({}, `║  Confidence:  ${String(Math.round(confidence * 100))}%                                 ║`);
      logger.info({}, '╠══════════════════════════════════════════════════════╣');

      if (decision.strategy === 'direct') {
        logger.info({}, `║  Mode:        ${decision.complexity.mode.padEnd(40)}║`);
        logger.info({}, `║  Subtasks:    ${String(decision.decomposition.subtasks.length).padEnd(40)}║`);
        logger.info({}, `║  Performer:   ${(decision.suggestedPerformer.capabilities.join('+') || 'general').padEnd(40)}║`);
        logger.info({}, '╠══════════════════════════════════════════════════════╣');
        logger.info({}, '║  Next:                                               ║');
        logger.info({}, '║  1. kallax ticket:create "<title>"                  ║');
        logger.info({}, '║  2. /kallax-expert <role>                           ║');
        logger.info({}, '║  3. Start working                                   ║');
      } else {
        logger.info({}, `║  Panel:                                              ║`);
        for (const role of decision.panel.required) {
          logger.info({}, `║    • ${role.padEnd(46)}║`);
        }
        if (decision.panel.optional.length > 0) {
          logger.info({}, `║  Optional:                                           ║`);
          for (const role of decision.panel.optional.slice(0, 3)) {
            logger.info({}, `║    • ${role.padEnd(46)}║`);
          }
        }
        logger.info({}, `║  Rounds:     ${String(decision.estimatedRounds).padEnd(40)}║`);
        logger.info({}, '╠══════════════════════════════════════════════════════╣');
        logger.info({}, '║  Next:                                               ║');
        logger.info({}, '║  1. /kallax-panel "analyze requirement"              ║');
        logger.info({}, '║  2. Expert panel analyzes → discusses → produces plan║');
        logger.info({}, '║  3. Execute according to plan                        ║');
      }
      logger.info({}, '╚══════════════════════════════════════════════════════╝');
      logger.info({}, '');
    });
}
