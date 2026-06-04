/**
 * KALLAX Workflow Templates
 * Predefined workflow templates for common KALLAX processes
 */

import type { WorkflowTemplate, WorkflowStep } from './state-machine.js';
import { WorkflowState } from './state-machine.js';

const C = 'conductor';
const P = 'performer';
const R = 'reviewer';

function step(name: string, desc: string, from: WorkflowState, to: WorkflowState, roles: readonly string[], actions: readonly string[]): WorkflowStep {
  return { name, description: desc, fromState: from, toState: to, requiredRoles: roles, actions };
}

// FEATURE_DEV — 8 steps: triage → analyze → design → develop → test → review → deploy → done
const FEATURE_DEV_STEPS: readonly WorkflowStep[] = [
  step('triage', 'Ticket triage and prioritization', WorkflowState.PENDING, WorkflowState.BACKLOG, [C], ['Review ticket', 'Set priority', 'Assign to backlog']),
  step('analyze', 'Requirements analysis and scope', WorkflowState.BACKLOG, WorkflowState.ANALYSIS, [C, P], ['Define AC', 'Estimate effort', 'Find deps']),
  step('design', 'Technical design and architecture', WorkflowState.ANALYSIS, WorkflowState.DESIGN, [C, P], ['Design doc', 'Define interfaces', 'Plan impl']),
  step('develop', 'Implementation with unit tests', WorkflowState.DESIGN, WorkflowState.DEVELOPMENT, [P], ['Write code', 'Write tests', 'Run linter']),
  step('test', 'Integration testing and QA', WorkflowState.DEVELOPMENT, WorkflowState.TESTING, [P], ['Run integration', 'Verify AC', 'Check coverage']),
  step('review', 'Peer code review', WorkflowState.TESTING, WorkflowState.REVIEW, [R], ['Review diff', 'Leave comments', 'Approve']),
  step('deploy', 'Merge and deploy', WorkflowState.REVIEW, WorkflowState.DEPLOYMENT, [C], ['Merge branch', 'Run CI/CD', 'Verify health']),
  step('complete', 'Final sign-off', WorkflowState.DEPLOYMENT, WorkflowState.DONE, [C], ['Verify prod', 'Close ticket', 'Notify']),
];
export const FEATURE_DEV_TEMPLATE: WorkflowTemplate = { name: 'feature-dev', description: 'Full feature lifecycle from triage through deployment', steps: FEATURE_DEV_STEPS };

// PARALLEL_REVIEW — 5 steps: triage → analyze → develop → review → done
const PARALLEL_REVIEW_STEPS: readonly WorkflowStep[] = [
  step('triage', 'Ticket triage', WorkflowState.PENDING, WorkflowState.BACKLOG, [C], ['Review ticket', 'Set priority']),
  step('analyze', 'Quick requirements analysis', WorkflowState.BACKLOG, WorkflowState.ANALYSIS, [C, P], ['Define scope', 'Find quick wins']),
  step('develop', 'Parallel design + implementation', WorkflowState.ANALYSIS, WorkflowState.DEVELOPMENT, [P], ['Design in code', 'Implement', 'Write tests']),
  step('review', 'Peer review', WorkflowState.DEVELOPMENT, WorkflowState.REVIEW, [R], ['Review implementation', 'Approve']),
  step('complete', 'Completion and sign-off', WorkflowState.REVIEW, WorkflowState.DONE, [C], ['Merge', 'Close ticket']),
];
export const PARALLEL_REVIEW_TEMPLATE: WorkflowTemplate = { name: 'parallel-review', description: 'Expedited with combined design+implementation', steps: PARALLEL_REVIEW_STEPS };

// BUG_FIX — 5 steps: triage → analyze → fix → verify → deploy
const BUG_FIX_STEPS: readonly WorkflowStep[] = [
  step('triage', 'Urgent bug triage', WorkflowState.PENDING, WorkflowState.BACKLOG, [C], ['Assess severity', 'Assign hotfix priority']),
  step('analyze', 'Root cause analysis', WorkflowState.BACKLOG, WorkflowState.ANALYSIS, [C, P], ['Find root cause', 'Plan fix']),
  step('fix', 'Implement bug fix', WorkflowState.ANALYSIS, WorkflowState.DEVELOPMENT, [P], ['Write fix', 'Add regression test']),
  step('verify', 'Verify fix', WorkflowState.DEVELOPMENT, WorkflowState.TESTING, [P, R], ['Run tests', 'Check no regression']),
  step('deploy', 'Deploy hotfix', WorkflowState.TESTING, WorkflowState.DONE, [C], ['Deploy hotfix', 'Verify prod', 'Close ticket']),
];
export const BUG_FIX_TEMPLATE: WorkflowTemplate = { name: 'bug-fix', description: 'Urgent fix with expedited deployment path', steps: BUG_FIX_STEPS };

export const WORKFLOW_TEMPLATES: readonly WorkflowTemplate[] = [FEATURE_DEV_TEMPLATE, PARALLEL_REVIEW_TEMPLATE, BUG_FIX_TEMPLATE];

export function getTemplate(name: string): WorkflowTemplate | undefined {
  return WORKFLOW_TEMPLATES.find((t) => t.name === name);
}

export function listTemplateNames(): readonly string[] {
  return WORKFLOW_TEMPLATES.map((t) => t.name);
}
