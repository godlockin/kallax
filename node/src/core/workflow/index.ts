/**
 * KALLAX Workflow Module
 * Re-exports workflow state machine, templates, and executor
 */

export * from './state-machine.js';
export * from './templates.js';
export { createWorkflowExecutor, type WorkflowExecutor } from './executor.js';
