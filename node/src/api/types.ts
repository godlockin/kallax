/**
 * KALLAX API Types
 * Request/Response types and server configuration
 */

import { z } from 'zod';
import type { KallaxError } from '../types/index.js';

// ============================================================================
// Shared Types (used by server.ts and middleware/auth.ts)
// ============================================================================

export type EndpointRole = 'conductor' | 'performer' | 'admin';

// ============================================================================
// Response Wrappers
// ============================================================================

export interface ApiResponse<T> {
  readonly success: true;
  readonly data: T;
  readonly timestamp: number;
}

export interface ApiErrorBody {
  readonly code: string;
  readonly message: string;
  readonly details?: Readonly<Record<string, unknown>>;
}

export interface ApiErrorResponse {
  readonly success: false;
  readonly error: ApiErrorBody;
  readonly timestamp: number;
}

export type ApiResult<T> = ApiResponse<T> | ApiErrorResponse;

// ============================================================================
// Pagination
// ============================================================================

export interface PaginationParams {
  readonly page: number;
  readonly limit: number;
}

export interface PaginatedResponse<T> {
  readonly items: readonly T[];
  readonly total: number;
  readonly page: number;
  readonly limit: number;
  readonly totalPages: number;
}

// ============================================================================
// Server Configuration
// ============================================================================

export const ServerConfigSchema = z.object({
  port: z.number().default(9877),
  host: z.string().default('127.0.0.1'),
  apiKey: z.string().default('kallax-dev-key'),
  corsOrigins: z.array(z.string()).default(['*']),
  rateLimit: z.object({
    windowMs: z.number().default(60000),
    maxRequests: z.number().default(100),
  }).default({}),
  bodyLimit: z.string().default('1mb'),
});

export type ServerConfig = z.infer<typeof ServerConfigSchema>;

// ============================================================================
// Health & Stats
// ============================================================================

export interface HealthStatus {
  readonly status: 'healthy' | 'degraded' | 'unhealthy';
  readonly uptime: number;
  readonly version: string;
  readonly dbConnected: boolean;
  readonly timestamp: number;
}

export interface TaskStats {
  readonly total: number;
  readonly pending: number;
  readonly claimed: number;
  readonly completed: number;
  readonly failed: number;
}

export interface InstanceStats {
  readonly total: number;
  readonly active: number;
  readonly performers: number;
  readonly conductors: number;
}

export interface PerformanceStats {
  readonly uptime: number;
  readonly memoryUsageMb: number;
  readonly cpus: number;
}

export interface SystemStats {
  readonly tasks: TaskStats;
  readonly instances: InstanceStats;
  readonly performance: PerformanceStats;
}

// ============================================================================
// Request Types
// ============================================================================

export interface CreateTaskRequest {
  readonly ticketId: string;
  readonly type?: string;
}

export interface ClaimTaskRequest {
  readonly performerId: string;
}

export interface UpdateProgressRequest {
  readonly progress: number;
  readonly message?: string;
}

export interface RegisterAgentRequest {
  readonly name: string;
  readonly capabilities?: readonly string[];
}

export interface HeartbeatRequest {
  readonly status?: string;
  readonly currentTaskId?: string | null;
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Create a successful API response
 */
export function createSuccessResponse<T>(data: T): ApiResponse<T> {
  return {
    success: true,
    data,
    timestamp: Date.now(),
  };
}

/**
 * Create an error API response from a KallaxError
 */
export function createErrorResponse(error: KallaxError): ApiErrorResponse {
  const details = Object.keys(error.metadata).length > 0
    ? (error.metadata as Record<string, unknown>)
    : undefined;

  const errorBody: ApiErrorBody = {
    code: error.code,
    message: error.message,
    ...(details !== undefined ? { details } : {}),
  };

  return {
    success: false,
    error: errorBody,
    timestamp: Date.now(),
  };
}

/**
 * Create a paginated response
 */
export function createPaginatedResponse<T>(
  items: readonly T[],
  total: number,
  page: number,
  limit: number
): PaginatedResponse<T> {
  return {
    items,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };
}
