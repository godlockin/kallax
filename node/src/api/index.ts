/**
 * KALLAX API Module
 * Re-exports all API server functionality
 */

export { createApiServer, registerApiServerCleanup } from './server.js';
export type { ApiServer, ApiServerDependencies, EndpointRole } from './server.js';
export { createAuthMiddleware } from './middleware/auth.js';
export { createRateLimiter } from './middleware/rate-limiter.js';
export { createTaskRoutes } from './routes/tasks.js';
export type { TaskRouteDependencies } from './routes/tasks.js';
export { createAgentRoutes } from './routes/agents.js';
export type { AgentRouteDependencies } from './routes/agents.js';
export { createSystemRoutes } from './routes/system.js';
export type { SystemRouteDependencies } from './routes/system.js';
export { createWorkflowRoutes } from './routes/workflow.js';
export type { WorkflowRouteDependencies } from './routes/workflow.js';
export { createKnowledgeRoutes } from './routes/knowledge.js';
export type { KnowledgeRouteDependencies } from './routes/knowledge.js';
export {
  ServerConfigSchema,
  type ServerConfig,
  type ApiResponse,
  type ApiErrorResponse,
  type ApiErrorBody,
  type ApiResult,
  type PaginationParams,
  type PaginatedResponse,
  type HealthStatus,
  type SystemStats,
  type TaskStats,
  type InstanceStats,
  type PerformanceStats,
  createSuccessResponse,
  createErrorResponse,
  createPaginatedResponse,
} from './types.js';
