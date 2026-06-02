/**
 * KALLAX Structured Logger
 * Uses pino for structured JSON logging - console.log is PROHIBITED
 */

import pino from 'pino';
import type { KallaxError, KallaxEvent } from '../types/index.js';

export interface LogContext {
  readonly taskId?: string;
  readonly ticketId?: string;
  readonly instanceId?: string;
  readonly performerId?: string;
  readonly conductorId?: string;
  readonly worktreePath?: string;
  readonly [key: string]: unknown;
}

export interface Logger {
  trace(context: LogContext, message: string): void;
  debug(context: LogContext, message: string): void;
  info(context: LogContext, message: string): void;
  warn(context: LogContext, message: string): void;
  error(context: LogContext, message: string): void;
  fatal(context: LogContext, message: string): void;
  child(bindings: LogContext): Logger;
  event(event: KallaxEvent): void;
  kallaxError(error: KallaxError): void;
}

const baseLogger = pino({
  level: process.env['KALLAX_LOG_LEVEL'] ?? 'info',
  formatters: {
    level: (label: string) => ({ level: label }),
    bindings: (bindings: pino.Bindings) => ({
      pid: bindings['pid'],
      hostname: bindings['hostname'],
      service: 'kallax',
    }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  base: {
    version: '1.0.0',
  },
});

function createLogger(pinoInstance: pino.Logger): Logger {
  return {
    trace(context: LogContext, message: string): void {
      pinoInstance.trace(context, message);
    },

    debug(context: LogContext, message: string): void {
      pinoInstance.debug(context, message);
    },

    info(context: LogContext, message: string): void {
      pinoInstance.info(context, message);
    },

    warn(context: LogContext, message: string): void {
      pinoInstance.warn(context, message);
    },

    error(context: LogContext, message: string): void {
      pinoInstance.error(context, message);
    },

    fatal(context: LogContext, message: string): void {
      pinoInstance.fatal(context, message);
    },

    child(bindings: LogContext): Logger {
      return createLogger(pinoInstance.child(bindings));
    },

    event(event: KallaxEvent): void {
      pinoInstance.info(
        {
          eventId: event.id,
          eventType: event.type,
          sourceId: event.sourceId,
          payload: event.payload,
        },
        `event:${event.type}`
      );
    },

    kallaxError(error: KallaxError): void {
      pinoInstance.error(
        {
          errorCode: error.code,
          errorMessage: error.message,
          metadata: error.metadata,
          cause: error.cause instanceof Error ? error.cause.message : error.cause,
          stack: error.stack,
        },
        `error:${error.code}`
      );
    },
  };
}

export const logger: Logger = createLogger(baseLogger);

/**
 * Create a child logger with specific context
 */
export function createChildLogger(context: LogContext): Logger {
  return logger.child(context);
}

/**
 * Create logger for a specific task
 */
export function createTaskLogger(taskId: string, additionalContext?: LogContext): Logger {
  return logger.child({ taskId, ...additionalContext });
}

/**
 * Create logger for a specific instance
 */
export function createInstanceLogger(instanceId: string, role: string): Logger {
  return logger.child({ instanceId, role });
}
