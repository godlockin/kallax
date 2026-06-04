/**
 * KALLAX Workflow Command Registration
 * CLI commands for workflow lifecycle management
 */

import { Command } from 'commander';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError } from '../types/index.js';
import {
  WORKFLOW_TEMPLATES,
  getTemplate,
  createWorkflowExecutor,
  type WorkflowTemplate,
} from '../core/workflow/index.js';

export function registerWorkflowCommands(program: Command, _ctx: AppContext): void {
  const workflow = program.command('workflow').description('Workflow lifecycle management');
  const executor = createWorkflowExecutor();

  workflow
    .command('list')
    .description('List all available workflow templates')
    .action(() => {
      try {
        const lines = WORKFLOW_TEMPLATES.map(
          (t: WorkflowTemplate) =>
            `  ${t.name.padEnd(20)} ${t.description} (${t.steps.length} steps)`,
        );
        process.stdout.write(`Available workflow templates (${WORKFLOW_TEMPLATES.length}):\n`);
        process.stdout.write(lines.join('\n') + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  workflow
    .command('start <templateName> [ticketId]')
    .description('Start a new workflow from a template')
    .option('-r, --role <role>', 'Initiator role (conductor/performer)', 'conductor')
    .action(async (templateName: string, ticketId?: string, opts?: { role?: string }) => {
      try {
        const template = getTemplate(templateName);
        if (template === undefined) {
          process.stderr.write(
            `Unknown template "${templateName}". Use "workflow list" to see available.\n`,
          );
          process.exit(1);
        }

        const instance = executor.create(template, {
          ticketId,
          initiatedBy: opts?.['role'],
        });

        const firstStep = template.steps[0];
        process.stdout.write(JSON.stringify({
          workflowId: instance.id,
          template: instance.templateName,
          ticketId: instance.ticketId,
          currentState: instance.currentState,
          totalSteps: template.steps.length,
          nextStep: firstStep?.name ?? '',
          createdAt: instance.createdAt,
        }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
