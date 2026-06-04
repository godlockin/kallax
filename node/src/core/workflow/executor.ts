/**
 * KALLAX Workflow Executor
 * Template instantiation and step progression with role validation
 */

import { err, ok } from 'neverthrow';
import { KallaxError, KallaxErrorCode, type KallaxResult } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import {
  WorkflowState,
  generateWorkflowId,
  isValidTransition,
  type WorkflowStep,
  type WorkflowTemplate,
  type WorkflowInstance,
  type WorkflowEvent,
  type WorkflowContext,
} from './state-machine.js';

export interface WorkflowExecutor {
  readonly create: (template: WorkflowTemplate, context: WorkflowContext) => WorkflowInstance;
  readonly getNextSteps: (instance: WorkflowInstance, template: WorkflowTemplate) => readonly WorkflowStep[];
  readonly canTransition: (instance: WorkflowInstance, template: WorkflowTemplate, role: string) => boolean;
  readonly transition: (instance: WorkflowInstance, template: WorkflowTemplate, role: string) => KallaxResult<WorkflowInstance>;
  readonly getProgress: (instance: WorkflowInstance, template: WorkflowTemplate) => number;
}

export function createWorkflowExecutor(): WorkflowExecutor {
  return {
    create: createWorkflowInstance,
    getNextSteps,
    canTransition: checkCanTransition,
    transition: executeTransition,
    getProgress: calculateProgress,
  };
}

function createWorkflowInstance(template: WorkflowTemplate, context: WorkflowContext): WorkflowInstance {
  const now = Date.now();
  logger.info({ templateName: template.name, ticketId: context.ticketId }, 'workflow instance created');
  return {
    id: generateWorkflowId(),
    templateName: template.name,
    ticketId: context.ticketId ?? null,
    currentState: WorkflowState.PENDING,
    completedSteps: [],
    history: [],
    createdAt: now,
    updatedAt: now,
  };
}

function findNextStep(instance: WorkflowInstance, template: WorkflowTemplate): WorkflowStep | undefined {
  return template.steps.find((step) => !instance.completedSteps.includes(step.name));
}

function getNextSteps(instance: WorkflowInstance, template: WorkflowTemplate): readonly WorkflowStep[] {
  const next = findNextStep(instance, template);
  return next !== undefined ? [next] : [];
}

function checkCanTransition(instance: WorkflowInstance, template: WorkflowTemplate, role: string): boolean {
  const nextStep = findNextStep(instance, template);
  if (nextStep === undefined) return false;
  if (nextStep.fromState !== instance.currentState) return false;
  return nextStep.requiredRoles.includes(role);
}

function executeTransition(instance: WorkflowInstance, template: WorkflowTemplate, role: string): KallaxResult<WorkflowInstance> {
  const nextStep = findNextStep(instance, template);
  if (nextStep === undefined) {
    return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT, 'Workflow already complete'));
  }
  if (nextStep.fromState !== instance.currentState) {
    return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT,
      `Step "${nextStep.name}" needs state "${nextStep.fromState}", at "${instance.currentState}"`));
  }
  if (!isValidTransition(instance.currentState, nextStep.toState)) {
    return err(new KallaxError(KallaxErrorCode.INVALID_ARGUMENT,
      `No valid transition: "${instance.currentState}" -> "${nextStep.toState}"`));
  }
  if (!nextStep.requiredRoles.includes(role)) {
    return err(new KallaxError(KallaxErrorCode.PERMISSION_DENIED,
      `Role "${role}" not allowed for step "${nextStep.name}"`));
  }

  const event: WorkflowEvent = {
    stepName: nextStep.name,
    fromState: instance.currentState,
    toState: nextStep.toState,
    performedBy: role,
    timestamp: Date.now(),
  };

  const updatedInstance: WorkflowInstance = {
    ...instance,
    currentState: nextStep.toState,
    completedSteps: [...instance.completedSteps, nextStep.name],
    history: [...instance.history, event],
    updatedAt: Date.now(),
  };

  logger.info({
    workflowId: instance.id, step: nextStep.name,
    fromState: instance.currentState, toState: nextStep.toState, role,
    progress: calculateProgress(updatedInstance, template),
  }, 'workflow transition completed');

  return ok(updatedInstance);
}

function calculateProgress(instance: WorkflowInstance, template: WorkflowTemplate): number {
  if (template.steps.length === 0) return 100;
  return Math.round((instance.completedSteps.length / template.steps.length) * 100);
}
