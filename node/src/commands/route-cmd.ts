/**
 * KALLAX Route Command — pre-execution complexity gate.
 * Simple → direct, Complex → expert panel.
 */
import type { Command } from 'commander';

export function registerRouteCommands(program: Command): void {
  program
    .command('route <requirement>')
    .description('Analyze requirement complexity and route to direct or panel execution')
    .option('--json', 'Output as JSON')
    .action(async (requirement: string, opts: { json?: boolean }) => {
      const { routeTask, getComplexityThreshold } = await import('../core/task-router.js');
      const result = routeTask(requirement);

      if (result.isErr()) {
        console.error(`ERROR: ${result.error.message}`);
        process.exit(1);
      }

      const { decision, confidence } = result.value;

      if (opts.json) {
        console.log(JSON.stringify({ decision, confidence, requirement }, null, 2));
        return;
      }

      const threshold = getComplexityThreshold();

      console.log('');
      console.log('╔══════════════════════════════════════════════════════╗');
      console.log('║  KALLAX Task Router — Complexity Gate              ║');
      console.log('╠══════════════════════════════════════════════════════╣');
      console.log(`║  Requirement: ${requirement.slice(0, 40).padEnd(40)}║`);
      console.log(`║  Complexity:  ${decision.complexity.score}/${threshold}+ (threshold)                    ║`);
      console.log(`║  Strategy:    ${decision.strategy.padEnd(40)}║`);
      console.log(`║  Confidence:  ${Math.round(confidence * 100)}%                                 ║`);
      console.log('╠══════════════════════════════════════════════════════╣');

      if (decision.strategy === 'direct') {
        console.log(`║  Mode:        ${decision.complexity.mode.padEnd(40)}║`);
        console.log(`║  Subtasks:    ${String(decision.decomposition.subtasks.length).padEnd(40)}║`);
        console.log(`║  Performer:   ${(decision.suggestedPerformer.capabilities.join('+') || 'general').padEnd(40)}║`);
        console.log('╠══════════════════════════════════════════════════════╣');
        console.log('║  Next:                                               ║');
        console.log('║  1. kallax ticket:create "<title>"                  ║');
        console.log('║  2. /kallax-expert <role>                           ║');
        console.log('║  3. Start working                                   ║');
      } else {
        console.log(`║  Panel:                                              ║`);
        for (const role of decision.panel.required) {
          console.log(`║    • ${role.padEnd(46)}║`);
        }
        if (decision.panel.optional.length > 0) {
          console.log(`║  Optional:                                           ║`);
          for (const role of decision.panel.optional.slice(0, 3)) {
            console.log(`║    • ${role.padEnd(46)}║`);
          }
        }
        console.log(`║  Rounds:     ${String(decision.estimatedRounds).padEnd(40)}║`);
        console.log('╠══════════════════════════════════════════════════════╣');
        console.log('║  Next:                                               ║');
        console.log('║  1. /kallax-panel "analyze requirement"              ║');
        console.log('║  2. Expert panel analyzes → discusses → produces plan║');
        console.log('║  3. Execute according to plan                        ║');
      }
      console.log('╚══════════════════════════════════════════════════════╝');
      console.log('');
    });
}
