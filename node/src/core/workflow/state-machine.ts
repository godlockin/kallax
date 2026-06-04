/**
 * KALLAX Workflow State Machine
 * Defines states, transitions, and core types for workflow engine
 */

import * as crypto from 'node:crypto';

// ============================================================================
// State Definition
// ============================================================================

export const WorkflowState = {
  PENDING: 'pending',
  BACKLOG: 'backlog',
  ANALYSIS: 'analysis',
  DESIGN: 'design',
  DEVELOPMENT: 'development',
  TESTING: 'testing',
  REVIEW: 'review',
  DEPLOYMENT: 'deployment',
  DONE: 'done',
} as const;

export type WorkflowState = (typeof WorkflowState)[keyof typeof WorkflowState];

// Valid state transitions (from -> [to, ...])
const TRANSITIONS: { [K in WorkflowState]: readonly WorkflowState[] } = {
  [WorkflowState.PENDING]: [WorkflowState.BACKLOG],
  [WorkflowState.BACKLOG]: [WorkflowState.ANALYSIS],
  [WorkflowState.ANALYSIS]: [WorkflowState.DESIGN, WorkflowState.DEVELOPMENT],
  [WorkflowState.DESIGN]: [WorkflowState.DEVELOPMENT],
  [WorkflowState.DEVELOPMENT]: [WorkflowState.TESTING, WorkflowState.REVIEW],
  [WorkflowState.TESTING]: [WorkflowState.REVIEW],
  [WorkflowState.REVIEW]: [WorkflowState.DEPLOYMENT, WorkflowState.DEVELOPMENT],
  [WorkflowState.DEPLOYMENT]: [WorkflowState.DONE],
  [WorkflowState.DONE]: [],
};

// ============================================================================
// Validation Functions
// ============================================================================

export function isValidTransition(from: WorkflowState, to: WorkflowState): boolean {
  const allowed = TRANSITIONS[from];
  return allowed.includes(to);
}

export function isTerminalState(state: WorkflowState): boolean {
  return state === WorkflowState.DONE;
}

export function getNextStates(state: WorkflowState): readonly WorkflowState[] {
  return TRANSITIONS[state];
}

// ============================================================================
// Core Types
// ============================================================================

export interface WorkflowStep {
  readonly name: string;
  readonly description: string;
  readonly fromState: WorkflowState;
  readonly toState: WorkflowState;
  readonly requiredRoles: readonly string[];
  readonly actions: readonly string[];
}

export interface WorkflowTemplate {
  readonly name: string;
  readonly description: string;
  readonly steps: readonly WorkflowStep[];
}

export interface WorkflowEvent {
  readonly stepName: string;
  readonly fromState: WorkflowState;
  readonly toState: WorkflowState;
  readonly performedBy: string;
  readonly timestamp: number;
}

export interface WorkflowInstance {
  readonly id: string;
  readonly templateName: string;
  readonly ticketId: string | null;
  readonly currentState: WorkflowState;
  readonly completedSteps: readonly string[];
  readonly history: readonly WorkflowEvent[];
  readonly createdAt: number;
  readonly updatedAt: number;
}

export interface WorkflowContext {
  readonly ticketId?: string;
  readonly initiatedBy?: string;
}

// ============================================================================
// ID Generation
// ============================================================================

export function generateWorkflowId(): string {
  return `wf-${crypto.randomUUID().slice(0, 8)}`;
}
