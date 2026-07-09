/**
 * KALLAX Commands Module
 * Re-exports all command functions
 */

// Claim
export { executeClaimCommand } from './claim.js';
export type { ClaimCommandOptions, ClaimResult } from './claim.js';

// Complete
export { executeCompleteCommand } from './complete.js';
export type { CompleteCommandOptions, CompleteResult } from './complete.js';

// Conductor
export {
  executeConductorHeartbeat,
  executeConductorPoll,
} from './conductor.js';
export type {
  ConductorHeartbeatOptions,
  ConductorHeartbeatResult,
  ConductorPollOptions,
  ConductorPollResult,
  PriorityCheckResult,
  PerformerCheckResult,
  PerformerStatus,
  ProgressCheckResult,
  BlockedCheckResult,
  MessageCheckResult,
  Assignment,
} from './conductor.js';

// Performer
export {
  executePerformerRegister,
  executePerformerPoll,
  executePerformerStatus,
} from './performer.js';
export type {
  PerformerRegisterOptions,
  PerformerRegisterResult,
  PerformerPollOptions,
  PerformerPollResult,
  PerformerStatusResult,
} from './performer.js';

// Task
export {
  executeTaskCreate,
  executeTaskStatus,
  executeTaskProgress,
  executeTaskResume,
} from './task.js';
export type {
  TaskCreateOptions,
  TaskCreateResult,
  TaskStatusOptions,
  TaskStatusResult,
  TaskWithTicket,
  TaskSummary,
  TaskProgressOptions,
  TaskResumeOptions,
  TaskResumeResult,
} from './task.js';

// Isolation Check
export { executeIsolationCheck } from './isolation-check.js';
export type { IsolationCheckOptions, IsolationCheckResult } from './isolation-check.js';

// Verify Output
export { executeVerifyOutput } from './verify-output.js';
export type { VerifyOutputOptions, VerifyOutputResult, VerificationSummary } from './verify-output.js';

// System
export {
  executeSystemDoctor,
  executeTeamStatus,
} from './system.js';

// Recommender
export type {
  SystemDoctorResult,
  HealthCheck,
  CacheHealthStats,
  TeamStatusResult,
  InstanceSummary,
  TaskDistribution,
  TeamHealth,
} from './system.js';

export { registerInitCommands } from './init.js';
